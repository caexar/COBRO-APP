import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cuotas_dao.dart';
import '../../../data/daos/pagos_dao.dart';
import '../../../data/daos/prestamos_dao.dart';
import '../../prestamos/data/prestamos_repository.dart';
import 'pago_processor.dart';

export '../../../data/app_database.dart' show Pago;
export 'pago_processor.dart' show ManejoExcedenteRequeridoException, PoliticaMoraRequeridaException;

/// Registra pagos localmente con la misma lógica de mora/excedente que
/// `App\Services\PagoProcessor` del backend (ver [PagoProcessor]) y encola el
/// alta en `cambios_pendientes` para la próxima sincronización.
///
/// A diferencia del backend, donde `politica_mora` es fija por préstamo, acá
/// el cobrador la elige en el momento de un pago con faltante. Cuando eso
/// pasa, el préstamo local se actualiza con esa elección (para que quede
/// consistente con lo recién aplicado) y también se vuelve a encolar.
class PagosRepository {
  PagosRepository({AppDatabase? database, SecureStorageService? secureStorage, PrestamosRepository? prestamosRepository})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService(),
        _prestamosRepository = prestamosRepository ?? PrestamosRepository(database: database, secureStorage: secureStorage);

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final PrestamosRepository _prestamosRepository;
  final _procesador = const PagoProcessor();

  PagosDao get _pagosDao => _database.pagosDao;
  CuotasDao get _cuotasDao => _database.cuotasDao;
  PrestamosDao get _prestamosDao => _database.prestamosDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<List<Pago>> listarPorPrestamo(int prestamoId) => _pagosDao.obtenerPorPrestamo(prestamoId);

  /// Todos los pagos del cobrador, de cualquier préstamo (para reportes
  /// globales como el CSV exportable, no para el flujo normal de un
  /// préstamo puntual).
  Future<List<Pago>> listarTodos() async {
    final usuarioId = await _usuarioIdActual();
    return _pagosDao.obtenerTodos(usuarioId);
  }

  /// Calcula y guarda el pago contra la cuota pendiente más antigua del
  /// préstamo. Si el abono no alcanza a cubrirla y no se indicó
  /// [politicaMora], o si la supera y no se indicó [manejoExcedente], lanza
  /// [PoliticaMoraRequeridaException] o [ManejoExcedenteRequeridoException]
  /// respectivamente — quien llame debe preguntarle al cobrador y volver a
  /// invocar con la decisión ya resuelta.
  Future<List<Pago>> registrar({
    required int prestamoId,
    required double montoAbonado,
    required DateTime fechaPago,
    String? politicaMora,
    String? manejoExcedente,
  }) async {
    final detalle = await _prestamosRepository.obtenerDetalle(prestamoId);
    final pagosExistentes = await _pagosDao.obtenerPorPrestamo(prestamoId);

    final plan = _procesador.procesar(
      cuotas: detalle.cuotas,
      pagosExistentes: pagosExistentes,
      montoTotalPrestamo: detalle.montoTotal,
      montoAbonado: montoAbonado,
      fechaPago: fechaPago,
      politicaMora: politicaMora,
      manejoExcedente: manejoExcedente,
    );

    for (final actualizacion in plan.actualizacionesCuotas) {
      await _cuotasDao.actualizar(
        CuotasCompanion(
          id: Value(actualizacion.cuotaId),
          estado: actualizacion.nuevoEstado != null ? Value(actualizacion.nuevoEstado!) : const Value.absent(),
          montoEsperado: actualizacion.nuevoMontoEsperado != null
              ? Value(actualizacion.nuevoMontoEsperado!)
              : const Value.absent(),
          sincronizado: const Value(false),
        ),
      );
    }

    final pagosInsertados = <Pago>[];
    for (final pago in plan.pagos) {
      final id = await _pagosDao.insertar(
        PagosCompanion.insert(
          prestamoId: prestamoId,
          cuotaId: Value(pago.cuotaId),
          montoAbonado: pago.montoAbonado,
          montoAplicado: pago.montoAplicado,
          fechaPago: pago.fechaPago,
          diasMora: Value(pago.diasMora),
          saldoRestanteDespues: pago.saldoRestanteDespues,
        ),
      );
      pagosInsertados.add(
        Pago(
          id: id,
          prestamoId: prestamoId,
          cuotaId: pago.cuotaId,
          montoAbonado: pago.montoAbonado,
          montoAplicado: pago.montoAplicado,
          fechaPago: pago.fechaPago,
          diasMora: pago.diasMora,
          saldoRestanteDespues: pago.saldoRestanteDespues,
          creadoEn: DateTime.now(),
          actualizadoEn: DateTime.now(),
          sincronizado: false,
        ),
      );
    }

    final politicaCambio =
        plan.politicaMoraAplicada != null && plan.politicaMoraAplicada != detalle.prestamo.politicaMora;
    final estadoCambio = detalle.prestamo.estado != plan.nuevoEstadoPrestamo;

    if (estadoCambio || politicaCambio) {
      await _prestamosDao.actualizar(
        PrestamosCompanion(
          id: Value(prestamoId),
          estado: Value(plan.nuevoEstadoPrestamo),
          politicaMora: politicaCambio ? Value(plan.politicaMoraAplicada) : const Value.absent(),
          sincronizado: const Value(false),
        ),
      );

      if (politicaCambio) {
        await _cambiosPendientesDao.encolar(
          usuarioId: detalle.prestamo.usuarioId,
          tabla: 'prestamos',
          registroId: prestamoId,
          tipoOperacion: 'actualizar',
          payload: jsonEncode({'politica_mora': plan.politicaMoraAplicada}),
        );
      }
    }

    await _cambiosPendientesDao.encolar(
      usuarioId: detalle.prestamo.usuarioId,
      tabla: 'pagos',
      registroId: pagosInsertados.first.id,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'prestamo_id': prestamoId,
        'monto_abonado': montoAbonado,
        'fecha_pago': fechaPago.toIso8601String(),
        'manejo_excedente': manejoExcedente,
      }),
    );

    return pagosInsertados;
  }
}
