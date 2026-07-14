import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cuotas_table.dart';

part 'cuotas_dao.g.dart';

@DriftAccessor(tables: [Cuotas])
class CuotasDao extends DatabaseAccessor<AppDatabase> with _$CuotasDaoMixin {
  CuotasDao(super.db);

  Future<List<Cuota>> obtenerPorPrestamo(int prestamoId) {
    return (select(cuotas)
          ..where((tbl) => tbl.prestamoId.equals(prestamoId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.numeroCuota)]))
        .get();
  }

  Future<Cuota?> obtenerPorId(int id) {
    return (select(cuotas)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<Cuota>> obtenerNoSincronizadas() {
    return (select(cuotas)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  Future<int> insertar(CuotasCompanion cuota) => into(cuotas).insert(cuota);

  /// Actualización parcial (ver nota en ClientesDao.actualizar). Requiere
  /// que `cuota.id` esté seteado.
  Future<int> actualizar(CuotasCompanion cuota) {
    return (update(cuotas)..where((tbl) => tbl.id.equals(cuota.id.value))).write(cuota);
  }
}
