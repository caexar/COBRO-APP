import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/clientes_table.dart';

part 'clientes_dao.g.dart';

@DriftAccessor(tables: [Clientes])
class ClientesDao extends DatabaseAccessor<AppDatabase> with _$ClientesDaoMixin {
  ClientesDao(super.db);

  /// Clientes no eliminados, ordenados por nombre.
  Future<List<Cliente>> obtenerTodos() {
    return (select(clientes)
          ..where((tbl) => tbl.eliminadoEn.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .get();
  }

  /// Igual que [obtenerTodos] pero reactivo, para refrescar la UI cuando cambien los datos.
  Stream<List<Cliente>> observarTodos() {
    return (select(clientes)
          ..where((tbl) => tbl.eliminadoEn.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .watch();
  }

  Future<Cliente?> obtenerPorId(int id) {
    return (select(clientes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<Cliente>> obtenerNoSincronizados() {
    return (select(clientes)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  /// Coincidencias por nombre (LIKE, sin distinguir mayúsculas), para el buscador.
  Future<List<Cliente>> buscarPorNombre(String termino) {
    return (select(clientes)
          ..where((tbl) => tbl.eliminadoEn.isNull() & tbl.nombre.like('%$termino%'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.nombre)]))
        .get();
  }

  /// Coincidencias por cédula (LIKE), usado como complemento cuando el
  /// término de búsqueda contiene dígitos.
  Future<List<Cliente>> buscarPorCedula(String termino) {
    return (select(clientes)
          ..where((tbl) => tbl.eliminadoEn.isNull() & tbl.cedula.like('%$termino%'))
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
  /// requeridas estén en el companion). Requiere que `cliente.id` esté seteado.
  Future<int> actualizar(ClientesCompanion cliente) {
    return (update(clientes)..where((tbl) => tbl.id.equals(cliente.id.value))).write(cliente);
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
}
