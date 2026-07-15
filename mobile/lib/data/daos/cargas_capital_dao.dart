import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cargas_capital_table.dart';

part 'cargas_capital_dao.g.dart';

@DriftAccessor(tables: [CargasCapital])
class CargasCapitalDao extends DatabaseAccessor<AppDatabase> with _$CargasCapitalDaoMixin {
  CargasCapitalDao(super.db);

  /// Movimientos de capital (cargas y retiros) no eliminados de
  /// [usuarioId]. Cada cobrador solo ve/suma los suyos, aunque compartan
  /// dispositivo.
  Future<List<CargaCapital>> obtenerTodas(int usuarioId) {
    return (select(cargasCapital)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId) & tbl.eliminadoEn.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.creadoEn)]))
        .get();
  }

  Future<int> insertar(CargasCapitalCompanion cargaCapital) => into(cargasCapital).insert(cargaCapital);

  /// Soft-delete: nunca se borra la fila, solo se marca `eliminadoEn` (mismo
  /// patrón que `prestamos`/`pagos`), para poder deshacer un movimiento
  /// registrado por error.
  Future<int> eliminar(int id) {
    return (update(cargasCapital)..where((tbl) => tbl.id.equals(id))).write(
      CargasCapitalCompanion(eliminadoEn: Value(DateTime.now()), sincronizado: const Value(false)),
    );
  }
}
