import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cierre_caja_gastos_table.dart';

part 'cierre_caja_gastos_dao.g.dart';

@DriftAccessor(tables: [CierreCajaGastos])
class CierreCajaGastosDao extends DatabaseAccessor<AppDatabase> with _$CierreCajaGastosDaoMixin {
  CierreCajaGastosDao(super.db);

  Future<List<CierreCajaGasto>> obtenerPorCierre(int cierreCajaId) {
    return (select(cierreCajaGastos)..where((tbl) => tbl.cierreCajaId.equals(cierreCajaId))).get();
  }

  Future<int> insertar(CierreCajaGastosCompanion gasto) => into(cierreCajaGastos).insert(gasto);
}
