import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cuotas_dao.dart';
import '../../../data/daos/prestamos_dao.dart';
import '../../../data/daos/prestamos_extras_dao.dart';
import 'prestamo_calculator.dart';

export '../../../data/app_database.dart' show Cuota, Prestamo, PrestamosExtra;

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
  PrestamosRepository({AppDatabase? database, SecureStorageService? secureStorage})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final _calculadora = const PrestamoCalculator();

  PrestamosDao get _prestamosDao => _database.prestamosDao;
  PrestamosExtrasDao get _extrasDao => _database.prestamosExtrasDao;
  CuotasDao get _cuotasDao => _database.cuotasDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<List<Prestamo>> listarPorCliente(int clienteId) => _prestamosDao.obtenerPorCliente(clienteId);

  Future<PrestamoDetalle> obtenerDetalle(int prestamoId) async {
    final prestamo = await _prestamosDao.obtenerPorId(prestamoId);
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
        usuarioId: usuarioId,
        montoCapital: montoCapital,
        porcentajeInteres: porcentajeInteres,
        frecuenciaPago: frecuenciaPago,
        diasPersonalizado: Value(diasPersonalizado),
        plazoCuotas: plazoCuotas,
        fechaInicio: fechaInicio,
        politicaMora: Value(politicaMora),
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
      tabla: 'prestamos',
      registroId: prestamoId,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'cliente_id': clienteId,
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
