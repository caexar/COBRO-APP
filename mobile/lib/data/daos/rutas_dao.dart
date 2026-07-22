import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/rutas_table.dart';

part 'rutas_dao.g.dart';

@DriftAccessor(tables: [Rutas])
class RutasDao extends DatabaseAccessor<AppDatabase> with _$RutasDaoMixin {
  RutasDao(super.db);

  /// Rutas de [usuarioId], ordenadas por `orden` (posición manual de la lista).
  Future<List<Ruta>> obtenerTodas(int usuarioId) {
    return (select(rutas)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.orden)]))
        .get();
  }

  Future<Ruta?> obtenerPorId(int id, int usuarioId) {
    return (select(rutas)..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId))).getSingleOrNull();
  }

  /// Para asignar el siguiente `orden` al crear una ruta nueva.
  Future<int> contarPorUsuario(int usuarioId) async {
    return (await (select(rutas)..where((tbl) => tbl.usuarioId.equals(usuarioId))).get()).length;
  }

  Future<int> insertar(RutasCompanion ruta) => into(rutas).insert(ruta);

  /// Actualización parcial (ver nota en `ClientesDao.actualizar` sobre por
  /// qué no se usa `.replace()`). Requiere que `ruta.id` esté seteado;
  /// [usuarioId] evita editar una ruta ajena aunque se conozca su id.
  Future<int> actualizar(RutasCompanion ruta, int usuarioId) {
    return (update(rutas)..where((tbl) => tbl.id.equals(ruta.id.value) & tbl.usuarioId.equals(usuarioId))).write(ruta);
  }

  Future<void> actualizarOrden(int id, int orden) async {
    await (update(rutas)..where((tbl) => tbl.id.equals(id))).write(RutasCompanion(orden: Value(orden)));
  }

  /// El backend nunca borra una ruta ya sincronizada por este camino (no hay
  /// flujo de borrado por sync, ver `RutasRepository.eliminar`) — esto solo
  /// borra el registro local.
  Future<int> eliminar(int id, int usuarioId) {
    return (delete(rutas)..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId))).go();
  }

  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(rutas)..where((tbl) => tbl.id.equals(id))).write(
      RutasCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
