import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/pagos_table.dart';

part 'pagos_dao.g.dart';

@DriftAccessor(tables: [Pagos])
class PagosDao extends DatabaseAccessor<AppDatabase> with _$PagosDaoMixin {
  PagosDao(super.db);

  Future<List<Pago>> obtenerPorPrestamo(int prestamoId) {
    return (select(pagos)
          ..where((tbl) => tbl.prestamoId.equals(prestamoId) & tbl.eliminadoEn.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.fechaPago)]))
        .get();
  }

  Future<List<Pago>> obtenerNoSincronizados() {
    return (select(pagos)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  Future<int> insertar(PagosCompanion pago) => into(pagos).insert(pago);

  /// Actualización parcial (ver nota en ClientesDao.actualizar). Requiere
  /// que `pago.id` esté seteado.
  Future<int> actualizar(PagosCompanion pago) {
    return (update(pagos)..where((tbl) => tbl.id.equals(pago.id.value))).write(pago);
  }
}
