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

  Future<CargaCapital?> obtenerPorId(int id, int usuarioId) {
    return (select(cargasCapital)
          ..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId)))
        .getSingleOrNull();
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

  /// Se llama tras confirmar en `POST /api/sync` que el servidor ya tiene
  /// este registro, para dejar de reintentarlo. No aplica a los movimientos
  /// que llegan descargados de un admin: esos ya nacen con `servidorId` y
  /// `sincronizado = true` desde el primer momento (ver
  /// `CargasCapitalRepository.guardarDescargadaDeAdmin`).
  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(cargasCapital)..where((tbl) => tbl.id.equals(id))).write(
      CargasCapitalCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }

  /// true si ya existe localmente un movimiento con este `servidorId` —
  /// evita duplicar un movimiento de admin que ya se descargó antes.
  Future<bool> existePorServidorId(int servidorId) async {
    final fila = await (select(cargasCapital)..where((tbl) => tbl.servidorId.equals(servidorId))).getSingleOrNull();
    return fila != null;
  }
}
