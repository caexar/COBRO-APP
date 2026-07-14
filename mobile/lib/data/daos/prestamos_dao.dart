import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/prestamos_table.dart';

part 'prestamos_dao.g.dart';

@DriftAccessor(tables: [Prestamos])
class PrestamosDao extends DatabaseAccessor<AppDatabase> with _$PrestamosDaoMixin {
  PrestamosDao(super.db);

  Future<List<Prestamo>> obtenerTodos() {
    return (select(prestamos)..where((tbl) => tbl.eliminadoEn.isNull())).get();
  }

  Stream<List<Prestamo>> observarTodos() {
    return (select(prestamos)..where((tbl) => tbl.eliminadoEn.isNull())).watch();
  }

  Future<List<Prestamo>> obtenerPorCliente(int clienteId) {
    return (select(prestamos)
          ..where((tbl) => tbl.clienteId.equals(clienteId) & tbl.eliminadoEn.isNull()))
        .get();
  }

  Future<Prestamo?> obtenerPorId(int id) {
    return (select(prestamos)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<Prestamo>> obtenerNoSincronizados() {
    return (select(prestamos)..where((tbl) => tbl.sincronizado.equals(false))).get();
  }

  Future<int> insertar(PrestamosCompanion prestamo) => into(prestamos).insert(prestamo);

  /// Actualización parcial (ver nota en ClientesDao.actualizar sobre por qué
  /// no se usa `.replace()`). Requiere que `prestamo.id` esté seteado.
  Future<int> actualizar(PrestamosCompanion prestamo) {
    return (update(prestamos)..where((tbl) => tbl.id.equals(prestamo.id.value))).write(prestamo);
  }

  /// El backend nunca borra un préstamo: solo cambia su estado a "anulado".
  Future<int> anular(int id) {
    return (update(prestamos)..where((tbl) => tbl.id.equals(id))).write(
      const PrestamosCompanion(
        estado: Value('anulado'),
        sincronizado: Value(false),
      ),
    );
  }
}
