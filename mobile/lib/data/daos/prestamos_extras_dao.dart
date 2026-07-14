import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/prestamos_extras_table.dart';

part 'prestamos_extras_dao.g.dart';

@DriftAccessor(tables: [PrestamosExtras])
class PrestamosExtrasDao extends DatabaseAccessor<AppDatabase> with _$PrestamosExtrasDaoMixin {
  PrestamosExtrasDao(super.db);

  Future<List<PrestamosExtra>> obtenerPorPrestamo(int prestamoId) {
    return (select(prestamosExtras)..where((tbl) => tbl.prestamoId.equals(prestamoId))).get();
  }

  Future<List<PrestamosExtra>> obtenerNoSincronizados() {
    return (select(prestamosExtras)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  Future<int> insertar(PrestamosExtrasCompanion extra) => into(prestamosExtras).insert(extra);

  /// Actualización parcial (ver nota en ClientesDao.actualizar). Requiere
  /// que `extra.id` esté seteado.
  Future<int> actualizar(PrestamosExtrasCompanion extra) {
    return (update(prestamosExtras)..where((tbl) => tbl.id.equals(extra.id.value))).write(extra);
  }

  Future<int> eliminar(int id) =>
      (delete(prestamosExtras)..where((tbl) => tbl.id.equals(id))).go();
}
