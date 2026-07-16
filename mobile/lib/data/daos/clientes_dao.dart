import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/clientes_table.dart';

part 'clientes_dao.g.dart';

@DriftAccessor(tables: [Clientes])
class ClientesDao extends DatabaseAccessor<AppDatabase> with _$ClientesDaoMixin {
  ClientesDao(super.db);

  /// Clientes no eliminados de [usuarioId], ordenados por nombre. Cada
  /// cobrador solo puede ver los suyos, aunque compartan dispositivo.
  Future<List<Cliente>> obtenerTodos(int usuarioId) {
    return (select(clientes)
          ..where((tbl) => tbl.eliminadoEn.isNull() & tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .get();
  }

  Future<Cliente?> obtenerPorId(int id, int usuarioId) {
    return (select(clientes)
          ..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId)))
        .getSingleOrNull();
  }

  /// Para detectar si un cliente descargado por `GET /api/restaurar` ya se
  /// insertó en un intento anterior (mismo criterio de deduplicación que ya
  /// usa `POST /api/sync` del lado servidor).
  Future<Cliente?> obtenerPorUuidLocal(String uuidLocal, int usuarioId) {
    return (select(clientes)
          ..where((tbl) => tbl.uuidLocal.equals(uuidLocal) & tbl.usuarioId.equals(usuarioId)))
        .getSingleOrNull();
  }

  Future<List<Cliente>> obtenerNoSincronizados() {
    return (select(clientes)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  /// Coincidencias por nombre (LIKE, sin distinguir mayúsculas) de [usuarioId], para el buscador.
  Future<List<Cliente>> buscarPorNombre(String termino, int usuarioId) {
    return (select(clientes)
          ..where(
            (tbl) =>
                tbl.eliminadoEn.isNull() &
                tbl.usuarioId.equals(usuarioId) &
                tbl.nombre.like('%$termino%'),
          )
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .get();
  }

  /// Coincidencias por cédula (LIKE) de [usuarioId], usado como complemento
  /// cuando el término de búsqueda contiene dígitos.
  Future<List<Cliente>> buscarPorCedula(String termino, int usuarioId) {
    return (select(clientes)
          ..where(
            (tbl) =>
                tbl.eliminadoEn.isNull() &
                tbl.usuarioId.equals(usuarioId) &
                tbl.cedula.like('%$termino%'),
          )
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .get();
  }

  /// true si ya existe (para este cobrador) otro cliente activo con este nombre.
  Future<bool> existeNombre(String nombre, int usuarioId, {int? excluirId}) async {
    final consulta = select(clientes)
      ..where(
        (tbl) =>
            tbl.eliminadoEn.isNull() & tbl.usuarioId.equals(usuarioId) & tbl.nombre.equals(nombre),
      );

    if (excluirId != null) {
      consulta.where((tbl) => tbl.id.equals(excluirId).not());
    }

    return (await consulta.get()).isNotEmpty;
  }

  /// true si ya existe (para este cobrador) otro cliente activo con esta cédula.
  Future<bool> existeCedula(String cedula, int usuarioId, {int? excluirId}) async {
    final consulta = select(clientes)
      ..where(
        (tbl) =>
            tbl.eliminadoEn.isNull() & tbl.usuarioId.equals(usuarioId) & tbl.cedula.equals(cedula),
      );

    if (excluirId != null) {
      consulta.where((tbl) => tbl.id.equals(excluirId).not());
    }

    return (await consulta.get()).isNotEmpty;
  }

  Future<int> insertar(ClientesCompanion cliente) => into(clientes).insert(cliente);

  /// Actualización parcial: solo escribe los campos presentes en [cliente]
  /// (a diferencia de `.replace()`, que exige que todas las columnas
  /// requeridas estén en el companion). Requiere que `cliente.id` esté
  /// seteado; [usuarioId] evita que se pueda editar un cliente ajeno aunque
  /// se conozca su id.
  Future<int> actualizar(ClientesCompanion cliente, int usuarioId) {
    return (update(clientes)
          ..where((tbl) => tbl.id.equals(cliente.id.value) & tbl.usuarioId.equals(usuarioId)))
        .write(cliente);
  }

  /// Soft delete: el backend nunca elimina físicamente un cliente.
  Future<int> marcarComoEliminado(int id) {
    return (update(clientes)..where((tbl) => tbl.id.equals(id))).write(
      ClientesCompanion(
        eliminadoEn: Value(DateTime.now()),
        sincronizado: const Value(false),
      ),
    );
  }

  /// Se llama tras confirmar en `POST /api/sync` que el servidor ya tiene
  /// este registro (creado o reconciliado), para dejar de reintentarlo.
  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(clientes)..where((tbl) => tbl.id.equals(id))).write(
      ClientesCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
