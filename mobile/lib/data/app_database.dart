import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cambios_pendientes_dao.dart';
import 'daos/clientes_dao.dart';
import 'daos/cuotas_dao.dart';
import 'daos/pagos_dao.dart';
import 'daos/prestamos_dao.dart';
import 'daos/prestamos_extras_dao.dart';
import 'tables/cambios_pendientes_table.dart';
import 'tables/clientes_table.dart';
import 'tables/cuotas_table.dart';
import 'tables/pagos_table.dart';
import 'tables/prestamos_extras_table.dart';
import 'tables/prestamos_table.dart';

part 'app_database.g.dart';

/// Base de datos local SQLite (vía Drift) que refleja el esquema del backend
/// Laravel para trabajar offline-first. Se sincroniza contra la API a través
/// de la tabla [CambiosPendientes].
@DriftDatabase(
  tables: [Clientes, Prestamos, PrestamosExtras, Cuotas, Pagos, CambiosPendientes],
  daos: [ClientesDao, PrestamosDao, PrestamosExtrasDao, CuotasDao, PagosDao, CambiosPendientesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_abrirConexion());

  AppDatabase.paraPruebas(super.executor);

  /// Instancia única compartida por toda la app: Drift debe abrir un solo
  /// archivo de base de datos, no una conexión nueva por cada repositorio.
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 -> v2: prestamos.referencia (nombre corto opcional para que el
      // cobrador distinga préstamos cuando un cliente tiene más de uno).
      if (from < 2) {
        await m.addColumn(prestamos, prestamos.referencia);
      }
    },
  );
}

LazyDatabase _abrirConexion() {
  return LazyDatabase(() async {
    final carpetaDocumentos = await getApplicationDocumentsDirectory();
    final archivo = File(p.join(carpetaDocumentos.path, 'cobro_app.sqlite'));
    return NativeDatabase.createInBackground(archivo);
  });
}
