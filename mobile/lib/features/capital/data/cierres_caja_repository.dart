import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cierre_caja_gastos_dao.dart';
import '../../../data/daos/cierres_caja_dao.dart';

export '../../../data/app_database.dart' show CierreCaja, CierreCajaGasto;

/// Un gasto a registrar dentro de un cierre de caja (monto + detalle libre,
/// ej. "almuerzo", "gasolina").
class GastoCierreCaja {
  const GastoCierreCaja({required this.monto, required this.detalle});

  final double monto;
  final String detalle;
}

/// CRUD local de cierres de caja diarios: el cierre y sus gastos se guardan
/// juntos y encolan **una sola fila** en `cambios_pendientes` (no una por
/// gasto) — mismo patrón que `PrestamosRepository.crear()` con sus
/// extras/cuotas. No hay flujo de edición desde el móvil para un cierre ya
/// guardado, igual que `cargas_capital`.
class CierresCajaRepository {
  CierresCajaRepository({AppDatabase? database, SecureStorageService? secureStorage})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final _uuid = const Uuid();

  CierresCajaDao get _cierresCajaDao => _database.cierresCajaDao;
  CierreCajaGastosDao get _gastosDao => _database.cierreCajaGastosDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<List<CierreCaja>> listarTodos() async {
    final usuarioId = await _usuarioIdActual();
    return _cierresCajaDao.obtenerTodos(usuarioId);
  }

  Future<List<CierreCajaGasto>> obtenerGastos(int cierreCajaId) {
    return _gastosDao.obtenerPorCierre(cierreCajaId);
  }

  /// Crea el cierre y sus gastos, y encola el alta para la próxima
  /// sincronización. `gastosTotal` se calcula acá como la suma de [gastos]
  /// (mismo criterio que el backend: nunca se confía en un total aparte,
  /// siempre se deriva de la lista de gastos).
  Future<int> crear({
    required DateTime fecha,
    required double capitalInicio,
    required double capitalCierre,
    String? justificacionDiferencia,
    List<GastoCierreCaja> gastos = const [],
  }) async {
    final usuarioId = await _usuarioIdActual();
    final gastosTotal = gastos.fold<double>(0, (acumulado, gasto) => acumulado + gasto.monto);

    final cierreId = await _cierresCajaDao.insertar(
      CierresCajaCompanion.insert(
        usuarioId: usuarioId,
        fecha: fecha,
        capitalInicio: capitalInicio,
        capitalCierre: capitalCierre,
        justificacionDiferencia: Value(justificacionDiferencia),
        gastosTotal: Value(gastosTotal),
        uuidLocal: Value(_uuid.v4()),
      ),
    );

    for (final gasto in gastos) {
      await _gastosDao.insertar(
        CierreCajaGastosCompanion.insert(cierreCajaId: cierreId, monto: gasto.monto, detalle: gasto.detalle),
      );
    }

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'cierres_caja',
      registroId: cierreId,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'fecha': fecha.toIso8601String(),
        'capital_inicio': capitalInicio,
        'capital_cierre': capitalCierre,
        'justificacion_diferencia': justificacionDiferencia,
        'gastos_total': gastosTotal,
        'gastos': gastos.map((gasto) => {'monto': gasto.monto, 'detalle': gasto.detalle}).toList(),
      }),
    );

    return cierreId;
  }
}
