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

  Future<int> insertar(ClientesCompanion cliente) => into(clientes).insert(cliente);

  Future<bool> actualizar(ClientesCompanion cliente) => update(clientes).replace(cliente);

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
