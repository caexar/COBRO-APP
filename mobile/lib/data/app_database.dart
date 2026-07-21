import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cambios_pendientes_dao.dart';
import 'daos/cargas_capital_dao.dart';
import 'daos/cierre_caja_gastos_dao.dart';
import 'daos/cierres_caja_dao.dart';
import 'daos/clientes_dao.dart';
import 'daos/cuotas_dao.dart';
import 'daos/pagos_dao.dart';
import 'daos/prestamos_dao.dart';
import 'daos/prestamos_extras_dao.dart';
import 'tables/cambios_pendientes_table.dart';
import 'tables/cargas_capital_table.dart';
import 'tables/cierre_caja_gastos_table.dart';
import 'tables/cierres_caja_table.dart';
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
  tables: [
    Clientes,
    Prestamos,
    PrestamosExtras,
    Cuotas,
    Pagos,
    CambiosPendientes,
    CargasCapital,
    CierresCaja,
    CierreCajaGastos,
  ],
  daos: [
    ClientesDao,
    PrestamosDao,
    PrestamosExtrasDao,
    CuotasDao,
    PagosDao,
    CambiosPendientesDao,
    CargasCapitalDao,
    CierresCajaDao,
    CierreCajaGastosDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_abrirConexion());

  AppDatabase.paraPruebas(super.executor);

  /// Instancia única compartida por toda la app: Drift debe abrir un solo
  /// archivo de base de datos, no una conexión nueva por cada repositorio.
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 -> v2: prestamos.referencia (nombre corto opcional para que el
      // cobrador distinga préstamos cuando un cliente tiene más de uno).
      if (from < 2) {
        await m.addColumn(prestamos, prestamos.referencia);
      }
      // v2 -> v3: tabla cargas_capital (aportes de capital del cobrador).
      if (from < 3) {
        await m.createTable(cargasCapital);
      }
      // v3 -> v4: cambios_pendientes.usuarioId, para que la cola de
      // sincronización no se mezcle entre cobradores que comparten
      // dispositivo.
      if (from < 4) {
        await m.addColumn(cambiosPendientes, cambiosPendientes.usuarioId);
      }
      // v4 -> v5: cargas_capital.tipo (carga/retiro) y eliminadoEn (soft
      // delete), para poder registrar retiros de capital y deshacer un
      // movimiento por error. Solo hace falta el ALTER si la tabla ya
      // existía con el esquema viejo (from >= 3): si venía de antes de v3,
      // el paso de arriba ya la crea con `createTable` usando la definición
      // *actual* de la tabla (que ya incluye estas columnas), y agregarlas
      // de nuevo fallaría con "duplicate column".
      if (from >= 3 && from < 5) {
        await m.addColumn(cargasCapital, cargasCapital.tipo);
        await m.addColumn(cargasCapital, cargasCapital.eliminadoEn);
      }
      // v5 -> v6: soporte para POST /api/sync.
      // - uuid_local en clientes/prestamos/pagos/cargas_capital: clave de
      //   deduplicación que genera la app al crear el registro localmente (no
      //   al sincronizar), la misma que ya usa el backend (ver columna
      //   equivalente agregada del lado servidor).
      // - origen/creadoPorUsuarioId en cargas_capital: para distinguir un
      //   movimiento que descargó `POST /sync` (asignado por un admin vía
      //   `POST /admin/cargas-capital`) de uno que registró el propio
      //   cobrador, y resaltarlo en HistorialCapitalScreen.
      //
      // clientes/prestamos/pagos existen desde v1, así que agregar su
      // columna nueva es un addColumn incondicional. cargas_capital es la
      // única de las cuatro que puede haber nacido recién en este mismo
      // upgrade (paso v2->v3 de arriba, `m.createTable`, que usa la
      // definición *actual* de la tabla): si `from < 3`, esa tabla ya nació
      // con estas tres columnas incluidas y agregarlas de nuevo fallaría con
      // "duplicate column" — mismo cuidado ya aplicado arriba para
      // tipo/eliminadoEn.
      if (from < 6) {
        await m.addColumn(clientes, clientes.uuidLocal);
        await m.addColumn(prestamos, prestamos.uuidLocal);
        await m.addColumn(pagos, pagos.uuidLocal);
      }
      if (from >= 3 && from < 6) {
        await m.addColumn(cargasCapital, cargasCapital.uuidLocal);
        await m.addColumn(cargasCapital, cargasCapital.origen);
        await m.addColumn(cargasCapital, cargasCapital.creadoPorUsuarioId);
      }
      // v6 -> v7: tablas cierres_caja y cierre_caja_gastos (cierre de caja diario, con sus
      // gastos del día) — tablas enteramente nuevas, no hay forma de que ya existieran en un
      // paso anterior, así que el `createTable` acá siempre es incondicional (a diferencia de
      // cargas_capital en el paso v2->v3, no hay ningún `addColumn` posterior sobre estas dos
      // tablas del que cuidarse todavía).
      if (from < 7) {
        await m.createTable(cierresCaja);
        await m.createTable(cierreCajaGastos);
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
