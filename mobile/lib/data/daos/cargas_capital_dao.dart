import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cargas_capital_table.dart';

part 'cargas_capital_dao.g.dart';

@DriftAccessor(tables: [CargasCapital])
class CargasCapitalDao extends DatabaseAccessor<AppDatabase> with _$CargasCapitalDaoMixin {
  CargasCapitalDao(super.db);

  /// Cargas de capital de [usuarioId]. Cada cobrador solo ve/suma las
  /// suyas, aunque compartan dispositivo.
  Future<List<CargaCapital>> obtenerTodas(int usuarioId) {
    return (select(cargasCapital)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.creadoEn)]))
        .get();
  }

  Future<int> insertar(CargasCapitalCompanion cargaCapital) => into(cargasCapital).insert(cargaCapital);
}
