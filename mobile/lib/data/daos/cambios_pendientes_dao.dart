import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cambios_pendientes_table.dart';

part 'cambios_pendientes_dao.g.dart';

@DriftAccessor(tables: [CambiosPendientes])
class CambiosPendientesDao extends DatabaseAccessor<AppDatabase>
    with _$CambiosPendientesDaoMixin {
  CambiosPendientesDao(super.db);

  /// Todos los cambios de [usuarioId] que el botón de sincronización todavía
  /// debe enviar (cada cobrador solo ve/sincroniza su propia cola, aunque
  /// compartan dispositivo).
  Future<List<CambiosPendiente>> obtenerPendientes(int usuarioId) {
    return (select(cambiosPendientes)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.creadoEn)]))
        .get();
  }

  /// Igual que [obtenerPendientes], pero reactivo (útil para un contador en el botón de sync).
  Stream<List<CambiosPendiente>> observarPendientes(int usuarioId) {
    return (select(cambiosPendientes)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.creadoEn)]))
        .watch();
  }

  /// Encola un cambio local pendiente de enviar al servidor.
  Future<int> encolar({
    required int usuarioId,
    required String tabla,
    required int registroId,
    required String tipoOperacion,
    String? payload,
  }) {
    return into(cambiosPendientes).insert(
      CambiosPendientesCompanion.insert(
        usuarioId: Value(usuarioId),
        tabla: tabla,
        registroId: registroId,
        tipoOperacion: tipoOperacion,
        payload: Value(payload),
      ),
    );
  }

  Future<bool> actualizar(CambiosPendientesCompanion cambio) =>
      update(cambiosPendientes).replace(cambio);

  /// Se llama cuando un intento de sincronización falla, para reintentar después.
  Future<void> registrarFallo(int id, String error) async {
    final cambio = await (select(cambiosPendientes)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    if (cambio == null) return;

    await (update(cambiosPendientes)..where((tbl) => tbl.id.equals(id))).write(
      CambiosPendientesCompanion(
        intentos: Value(cambio.intentos + 1),
        ultimoError: Value(error),
      ),
    );
  }

  /// Se llama cuando un cambio se aplicó con éxito en el servidor.
  Future<int> eliminar(int id) {
    return (delete(cambiosPendientes)..where((tbl) => tbl.id.equals(id))).go();
  }
}
