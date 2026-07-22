import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ruta_items_table.dart';

part 'ruta_items_dao.g.dart';

@DriftAccessor(tables: [RutaItems])
class RutaItemsDao extends DatabaseAccessor<AppDatabase> with _$RutaItemsDaoMixin {
  RutaItemsDao(super.db);

  /// Ítems de [rutaId], ordenados por `orden` (posición manual dentro de la ruta).
  Future<List<RutaItem>> obtenerPorRuta(int rutaId) {
    return (select(rutaItems)
          ..where((tbl) => tbl.rutaId.equals(rutaId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.orden)]))
        .get();
  }

  Future<RutaItem?> obtenerPorId(int id) {
    return (select(rutaItems)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// El ítem pendiente de [rutaId] que apunta a [prestamoId], si existe —
  /// usado para marcarlo cobrado tras registrar un pago real de ese
  /// préstamo (ver `RutasRepository.marcarCobradoSiPertenece`).
  Future<RutaItem?> obtenerPendientePorRutaYPrestamo(int rutaId, int prestamoId) {
    return (select(rutaItems)
          ..where(
            (tbl) =>
                tbl.rutaId.equals(rutaId) & tbl.prestamoId.equals(prestamoId) & tbl.estado.equals('pendiente'),
          ))
        .getSingleOrNull();
  }

  /// Para asignar el siguiente `orden` al agregar un préstamo nuevo a la ruta.
  Future<int> contarPorRuta(int rutaId) async {
    return (await (select(rutaItems)..where((tbl) => tbl.rutaId.equals(rutaId))).get()).length;
  }

  Future<int> insertar(RutaItemsCompanion item) => into(rutaItems).insert(item);

  Future<void> actualizarOrden(int id, int orden) async {
    await (update(rutaItems)..where((tbl) => tbl.id.equals(id))).write(RutaItemsCompanion(orden: Value(orden)));
  }

  Future<void> marcarCobrado(int id, DateTime cobradoEn) async {
    await (update(rutaItems)..where((tbl) => tbl.id.equals(id))).write(
      RutaItemsCompanion(
        estado: const Value('cobrado'),
        cobradoEn: Value(cobradoEn),
        actualizadoEn: Value(DateTime.now()),
        sincronizado: const Value(false),
      ),
    );
  }

  Future<int> eliminar(int id) {
    return (delete(rutaItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> eliminarPorRuta(int rutaId) {
    return (delete(rutaItems)..where((tbl) => tbl.rutaId.equals(rutaId))).go();
  }

  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(rutaItems)..where((tbl) => tbl.id.equals(id))).write(
      RutaItemsCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
