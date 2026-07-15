import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cargas_capital_dao.dart';

export '../../../data/app_database.dart' show CargaCapital;

/// CRUD local de movimientos de capital: aportes (`tipo = 'carga'`) y
/// retiros (`tipo = 'retiro'`) que el cobrador registra sobre el negocio.
/// Encola cada alta/baja en `cambios_pendientes`, mismo patrón que
/// clientes/préstamos/pagos.
class CargasCapitalRepository {
  CargasCapitalRepository({AppDatabase? database, SecureStorageService? secureStorage})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;

  CargasCapitalDao get _cargasCapitalDao => _database.cargasCapitalDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<List<CargaCapital>> listarTodas() async {
    final usuarioId = await _usuarioIdActual();
    return _cargasCapitalDao.obtenerTodas(usuarioId);
  }

  /// Registra un movimiento de capital ([tipo] `'carga'` o `'retiro'`, monto
  /// siempre positivo) y encola el alta para la próxima sincronización. La
  /// fecha es siempre "ahora" (no se pide editable).
  Future<int> crear({required double monto, String? descripcion, String tipo = 'carga'}) async {
    final usuarioId = await _usuarioIdActual();
    final ahora = DateTime.now();

    final id = await _cargasCapitalDao.insertar(
      CargasCapitalCompanion.insert(
        usuarioId: usuarioId,
        monto: monto,
        tipo: Value(tipo),
        descripcion: Value(descripcion),
        creadoEn: Value(ahora),
      ),
    );

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'cargas_capital',
      registroId: id,
      tipoOperacion: 'crear',
      payload: jsonEncode({'monto': monto, 'tipo': tipo, 'descripcion': descripcion, 'fecha': ahora.toIso8601String()}),
    );

    return id;
  }

  /// Deshace un movimiento registrado por error (soft-delete) y encola la
  /// baja para la próxima sincronización.
  Future<void> eliminar(int id) async {
    final usuarioId = await _usuarioIdActual();
    await _cargasCapitalDao.eliminar(id);

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'cargas_capital',
      registroId: id,
      tipoOperacion: 'eliminar',
    );
  }
}
