import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/pagos_table.dart';
import '../tables/prestamos_table.dart';

part 'pagos_dao.g.dart';

@DriftAccessor(tables: [Pagos, Prestamos])
class PagosDao extends DatabaseAccessor<AppDatabase> with _$PagosDaoMixin {
  PagosDao(super.db);

  Future<List<Pago>> obtenerPorPrestamo(int prestamoId) {
    return (select(pagos)
          ..where((tbl) => tbl.prestamoId.equals(prestamoId) & tbl.eliminadoEn.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.fechaPago)]))
        .get();
  }

  /// Todos los pagos no eliminados de préstamos de [usuarioId] (para
  /// reportes que no están acotados a un solo préstamo, ej. exportar CSV).
  /// Filtra con un join contra `prestamos` porque `pagos` no guarda el
  /// dueño directamente — solo `prestamo_id`.
  Future<List<Pago>> obtenerTodos(int usuarioId) async {
    final consulta = select(pagos).join([
      innerJoin(prestamos, prestamos.id.equalsExp(pagos.prestamoId)),
    ])
      ..where(pagos.eliminadoEn.isNull() & prestamos.usuarioId.equals(usuarioId))
      ..orderBy([OrderingTerm(expression: pagos.fechaPago)]);

    final filas = await consulta.get();
    return filas.map((fila) => fila.readTable(pagos)).toList();
  }

  Future<List<Pago>> obtenerNoSincronizados() {
    return (select(pagos)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  Future<Pago?> obtenerPorId(int id) {
    return (select(pagos)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertar(PagosCompanion pago) => into(pagos).insert(pago);

  /// Actualización parcial (ver nota en ClientesDao.actualizar). Requiere
  /// que `pago.id` esté seteado.
  Future<int> actualizar(PagosCompanion pago) {
    return (update(pagos)..where((tbl) => tbl.id.equals(pago.id.value))).write(pago);
  }

  /// Se llama tras confirmar en `POST /api/sync` que el servidor ya tiene
  /// este registro, para dejar de reintentarlo. Los pagos nunca se editan
  /// después de creados, así que esto solo pasa una vez por pago.
  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(pagos)..where((tbl) => tbl.id.equals(id))).write(
      PagosCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
