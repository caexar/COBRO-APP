import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cuotas_dao.dart';
import '../../../data/daos/pagos_dao.dart';
import '../../../data/daos/prestamos_dao.dart';
import '../../../data/daos/prestamos_extras_dao.dart';
import '../../clientes/data/clientes_repository.dart';
import 'prestamo_calculator.dart';

export '../../../data/app_database.dart' show Cuota, Prestamo, PrestamosExtra;

/// Préstamo con su cliente, el total ya cobrado (`monto_aplicado`) y el
/// saldo que todavía falta por cobrar. Vista combinada para las pantallas
/// de "Cobros pendientes" e "Historial de préstamos".
class PrestamoResumen {
  const PrestamoResumen({
    required this.prestamo,
    required this.cliente,
    required this.totalPagado,
    required this.saldoPendiente,
  });

  final Prestamo prestamo;
  final Cliente cliente;
  final double totalPagado;
  final double saldoPendiente;

  bool get enMora => prestamo.estado == 'en_mora';
}

/// Orden de [PrestamosRepository.listarPendientes]/[listarPagados] para las
/// pantallas "Cobros pendientes" e "Historial de préstamos". `alfabetico` es
/// el comportamiento por defecto (ya viene así de [ClientesRepository.buscar],
/// que ordena por nombre); los otros dos ordenan por `fecha_inicio` del
/// préstamo. El nombre del enum (`.name`) se usa tal cual como valor guardado
/// en `SecureStorageService.guardarOrdenPrestamos` — no renombrar sin migrar
/// el valor ya persistido.
enum OrdenPrestamos { alfabetico, masAntiguoPrimero, masRecientePrimero }

/// Préstamo con sus extras y cuotas ya cargados, para la pantalla de detalle.
class PrestamoDetalle {
  const PrestamoDetalle({required this.prestamo, required this.extras, required this.cuotas});

  final Prestamo prestamo;
  final List<PrestamosExtra> extras;
  final List<Cuota> cuotas;

  double get montoInteres => (prestamo.montoCapital * (prestamo.porcentajeInteres / 100));

  double get montoExtras => extras.fold<double>(0, (acumulado, extra) => acumulado + extra.valor);

  double get montoTotal => prestamo.montoCapital + montoInteres + montoExtras;
}

/// CRUD local de préstamos: genera las cuotas con [PrestamoCalculator] (misma
/// lógica que el backend) y encola el alta en `cambios_pendientes`.
class PrestamosRepository {
  PrestamosRepository({AppDatabase? database, SecureStorageService? secureStorage, ClientesRepository? clientesRepository})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService(),
        _clientesRepository = clientesRepository ?? ClientesRepository(database: database, secureStorage: secureStorage);

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final ClientesRepository _clientesRepository;
  final _calculadora = const PrestamoCalculator();
  final _uuid = const Uuid();

  PrestamosDao get _prestamosDao => _database.prestamosDao;
  PrestamosExtrasDao get _extrasDao => _database.prestamosExtrasDao;
  CuotasDao get _cuotasDao => _database.cuotasDao;
  PagosDao get _pagosDao => _database.pagosDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<List<Prestamo>> listarPorCliente(int clienteId) async {
    final usuarioId = await _usuarioIdActual();
    return _prestamosDao.obtenerPorCliente(clienteId, usuarioId);
  }

  /// Todos los préstamos del cobrador, de cualquier estado (para reportes
  /// globales como el dashboard, donde un préstamo ya pagado o anulado
  /// sigue contando para la ganancia históricamente realizada).
  Future<List<Prestamo>> listarTodos() async {
    final usuarioId = await _usuarioIdActual();
    return _prestamosDao.obtenerTodos(usuarioId);
  }

  /// Préstamos `activo`/`en_mora` del cobrador con su cliente y saldo
  /// pendiente, filtrados por [busqueda] con el mismo criterio flexible de
  /// [ClientesRepository.buscar] (nombre siempre, cédula si el texto tiene
  /// dígitos) y ordenados según [orden]. Pensado para la pantalla de "Cobros
  /// pendientes".
  Future<List<PrestamoResumen>> listarPendientes({
    String busqueda = '',
    OrdenPrestamos orden = OrdenPrestamos.alfabetico,
  }) async {
    final usuarioId = await _usuarioIdActual();
    final clientes = await _clientesRepository.buscar(busqueda);
    final resumenes = <PrestamoResumen>[];

    for (final cliente in clientes) {
      final prestamosCliente = await _prestamosDao.obtenerPorCliente(cliente.id, usuarioId);

      for (final prestamo in prestamosCliente) {
        if (prestamo.estado != 'activo' && prestamo.estado != 'en_mora') continue;

        resumenes.add(await _resumenDe(prestamo, cliente));
      }
    }

    _ordenar(resumenes, orden);
    return resumenes;
  }

  /// Préstamos `pagado` del cobrador con su cliente y saldo pendiente (0
  /// salvo redondeos), filtrados por [busqueda] con el mismo criterio que
  /// [listarPendientes] y ordenados según [orden]. Pensado para la pantalla
  /// de "Historial de préstamos" (mismo listado que "Cobros pendientes" pero
  /// solo lo que ya se terminó de cobrar).
  Future<List<PrestamoResumen>> listarPagados({
    String busqueda = '',
    OrdenPrestamos orden = OrdenPrestamos.alfabetico,
  }) async {
    final usuarioId = await _usuarioIdActual();
    final clientes = await _clientesRepository.buscar(busqueda);
    final resumenes = <PrestamoResumen>[];

    for (final cliente in clientes) {
      final prestamosCliente = await _prestamosDao.obtenerPorCliente(cliente.id, usuarioId);

      for (final prestamo in prestamosCliente) {
        if (prestamo.estado != 'pagado') continue;

        resumenes.add(await _resumenDe(prestamo, cliente));
      }
    }

    _ordenar(resumenes, orden);
    return resumenes;
  }

  /// [PrestamoResumen] de un solo préstamo puntual (a diferencia de
  /// [listarPendientes]/[listarPagados], que arman la lista completa de un
  /// estado) — pensado para pantallas que ya conocen el `prestamoId` de
  /// antemano, como `RutaDetalleScreen`.
  Future<PrestamoResumen> obtenerResumen(int prestamoId) async {
    final usuarioId = await _usuarioIdActual();
    final prestamo = await _prestamosDao.obtenerPorId(prestamoId, usuarioId);
    if (prestamo == null) {
      throw StateError('El préstamo ya no existe.');
    }

    final cliente = await _clientesRepository.obtenerPorId(prestamo.clienteId);
    if (cliente == null) {
      throw StateError('El cliente de este préstamo ya no existe.');
    }

    return _resumenDe(prestamo, cliente);
  }

  Future<PrestamoResumen> _resumenDe(Prestamo prestamo, Cliente cliente) async {
    final detalle = await obtenerDetalle(prestamo.id);
    final pagos = await _pagosDao.obtenerPorPrestamo(prestamo.id);
    final totalAplicado = pagos.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
    final saldoPendiente = detalle.montoTotal - totalAplicado;

    return PrestamoResumen(
      prestamo: prestamo,
      cliente: cliente,
      totalPagado: totalAplicado,
      saldoPendiente: saldoPendiente < 0 ? 0 : saldoPendiente,
    );
  }

  /// Aplica [orden] a [resumenes] in-place. `alfabetico` no hace nada (ya
  /// viene ordenado por nombre de cliente desde [ClientesRepository.buscar]);
  /// los otros dos ordenan por `fecha_inicio` del préstamo.
  void _ordenar(List<PrestamoResumen> resumenes, OrdenPrestamos orden) {
    switch (orden) {
      case OrdenPrestamos.alfabetico:
        break;
      case OrdenPrestamos.masAntiguoPrimero:
        resumenes.sort((a, b) => a.prestamo.fechaInicio.compareTo(b.prestamo.fechaInicio));
      case OrdenPrestamos.masRecientePrimero:
        resumenes.sort((a, b) => b.prestamo.fechaInicio.compareTo(a.prestamo.fechaInicio));
    }
  }

  /// Lanza [StateError] si el préstamo no existe **o pertenece a otro
  /// cobrador** — nunca revela si es lo uno o lo otro, para no filtrar la
  /// existencia de datos ajenos.
  Future<PrestamoDetalle> obtenerDetalle(int prestamoId) async {
    final usuarioId = await _usuarioIdActual();
    final prestamo = await _prestamosDao.obtenerPorId(prestamoId, usuarioId);
    if (prestamo == null) {
      throw StateError('El préstamo ya no existe.');
    }

    final extras = await _extrasDao.obtenerPorPrestamo(prestamoId);
    final cuotas = await _cuotasDao.obtenerPorPrestamo(prestamoId);

    return PrestamoDetalle(prestamo: prestamo, extras: extras, cuotas: cuotas);
  }

  /// Crea el préstamo, sus extras y sus cuotas (calculadas localmente con
  /// [PrestamoCalculator]) y encola el alta para la próxima sincronización.
  Future<int> crear({
    required int clienteId,
    String? referencia,
    required double montoCapital,
    required double porcentajeInteres,
    List<ExtraPrestamo> extras = const [],
    required String frecuenciaPago,
    int? diasPersonalizado,
    required int plazoCuotas,
    required DateTime fechaInicio,
    String politicaMora = 'mantener',
  }) async {
    final usuarioId = await _usuarioIdActual();

    final resultado = _calculadora.calcular(
      montoCapital: montoCapital,
      porcentajeInteres: porcentajeInteres,
      extras: extras,
      frecuenciaPago: frecuenciaPago,
      diasPersonalizado: diasPersonalizado,
      plazoCuotas: plazoCuotas,
      fechaInicio: fechaInicio,
    );

    final prestamoId = await _prestamosDao.insertar(
      PrestamosCompanion.insert(
        clienteId: clienteId,
        referencia: Value(referencia),
        usuarioId: usuarioId,
        montoCapital: montoCapital,
        porcentajeInteres: porcentajeInteres,
        frecuenciaPago: frecuenciaPago,
        diasPersonalizado: Value(diasPersonalizado),
        plazoCuotas: plazoCuotas,
        fechaInicio: fechaInicio,
        politicaMora: Value(politicaMora),
        uuidLocal: Value(_uuid.v4()),
      ),
    );

    for (final extra in extras) {
      await _extrasDao.insertar(
        PrestamosExtrasCompanion.insert(prestamoId: prestamoId, concepto: extra.concepto, valor: extra.valor),
      );
    }

    for (final cuota in resultado.cuotas) {
      await _cuotasDao.insertar(
        CuotasCompanion.insert(
          prestamoId: prestamoId,
          numeroCuota: cuota.numeroCuota,
          fechaEsperada: cuota.fechaEsperada,
          montoEsperado: cuota.montoEsperado,
        ),
      );
    }

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'prestamos',
      registroId: prestamoId,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'cliente_id': clienteId,
        'referencia': referencia,
        'monto_capital': montoCapital,
        'porcentaje_interes': porcentajeInteres,
        'extras': extras.map((extra) => {'concepto': extra.concepto, 'valor': extra.valor}).toList(),
        'frecuencia_pago': frecuenciaPago,
        'dias_personalizado': diasPersonalizado,
        'plazo_cuotas': plazoCuotas,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'politica_mora': politicaMora,
      }),
    );

    return prestamoId;
  }
}
