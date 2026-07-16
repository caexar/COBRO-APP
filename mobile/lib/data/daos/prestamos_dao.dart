import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/prestamos_table.dart';

part 'prestamos_dao.g.dart';

@DriftAccessor(tables: [Prestamos])
class PrestamosDao extends DatabaseAccessor<AppDatabase> with _$PrestamosDaoMixin {
  PrestamosDao(super.db);

  /// Préstamos no eliminados de [usuarioId] (cualquier estado). Cada
  /// cobrador solo ve los suyos, aunque compartan dispositivo.
  Future<List<Prestamo>> obtenerTodos(int usuarioId) {
    return (select(prestamos)
          ..where((tbl) => tbl.eliminadoEn.isNull() & tbl.usuarioId.equals(usuarioId)))
        .get();
  }

  Future<List<Prestamo>> obtenerPorCliente(int clienteId, int usuarioId) {
    return (select(prestamos)
          ..where(
            (tbl) =>
                tbl.clienteId.equals(clienteId) &
                tbl.usuarioId.equals(usuarioId) &
                tbl.eliminadoEn.isNull(),
          ))
        .get();
  }

  Future<Prestamo?> obtenerPorId(int id, int usuarioId) {
    return (select(prestamos)
          ..where((tbl) => tbl.id.equals(id) & tbl.usuarioId.equals(usuarioId)))
        .getSingleOrNull();
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

  /// Se llama tras confirmar en `POST /api/sync` que el servidor ya tiene
  /// este registro (creado o reconciliado), para dejar de reintentarlo.
  Future<int> marcarSincronizado(int id, int servidorId) {
    return (update(prestamos)..where((tbl) => tbl.id.equals(id))).write(
      PrestamosCompanion(servidorId: Value(servidorId), sincronizado: const Value(true)),
    );
  }
}
