import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cierres_caja_table.dart';

part 'cierres_caja_dao.g.dart';

@DriftAccessor(tables: [CierresCaja])
class CierresCajaDao extends DatabaseAccessor<AppDatabase> with _$CierresCajaDaoMixin {
  CierresCajaDao(super.db);

  /// Cierres de [usuarioId], del más reciente al más antiguo por `fecha`.
  Future<List<CierreCaja>> obtenerTodos(int usuarioId) {
    return (select(cierresCaja)
          ..where((tbl) => tbl.usuarioId.equals(usuarioId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.fecha, mode: OrderingMode.desc)]))
        .get();
  }

  Future<CierreCaja?> obtenerPorId(int id, int usuarioId) {
    return (select(cierresCaja)..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId))).getSingleOrNull();
  }

  Future<int> insertar(CierresCajaCompanion cierre) => into(cierresCaja).insert(cierre);

  /// Se llama tras confirmar en `POST /api/sync` que el servidor ya tiene este registro.
  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(cierresCaja)..where((tbl) => tbl.id.equals(id))).write(
      CierresCajaCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
