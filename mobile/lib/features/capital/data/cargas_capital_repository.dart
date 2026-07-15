import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cargas_capital_dao.dart';

export '../../../data/app_database.dart' show CargaCapital;

/// CRUD local (solo alta y lectura) de cargas de capital: dinero que el
/// cobrador mete al negocio. Encola el alta en `cambios_pendientes`, mismo
/// patrón que clientes/préstamos/pagos.
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

  /// Registra una carga de capital y encola el alta para la próxima
  /// sincronización. La fecha es siempre "ahora" (no se pide editable).
  Future<int> crear({required double monto, String? descripcion}) async {
    final usuarioId = await _usuarioIdActual();
    final ahora = DateTime.now();

    final id = await _cargasCapitalDao.insertar(
      CargasCapitalCompanion.insert(
        usuarioId: usuarioId,
        monto: monto,
        descripcion: Value(descripcion),
        creadoEn: Value(ahora),
      ),
    );

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'cargas_capital',
      registroId: id,
      tipoOperacion: 'crear',
      payload: jsonEncode({'monto': monto, 'descripcion': descripcion, 'fecha': ahora.toIso8601String()}),
    );

    return id;
  }
}
