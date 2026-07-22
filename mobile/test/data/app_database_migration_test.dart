import 'dart:io';

import 'package:cobro_app/data/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Verifica que abrir una base de datos SQLite "vieja" (schemaVersion 1, sin
/// la columna `referencia` en `prestamos`, tal como quedó cualquier
/// dispositivo que ya tenía la app instalada antes de este cambio) migre
/// correctamente a la versión actual sin perder los datos ya guardados.
/// `cambios_pendientes` tal como existió entre v1 y v3 (sin `usuario_id`,
/// agregada recién en v4). Compartido por los tres fixtures "viejos": la
/// tabla existe desde el scaffold inicial, antes de cualquiera de las tres
/// migraciones que se prueban en este archivo.
const _crearCambiosPendientesV1a3 = '''
  CREATE TABLE cambios_pendientes (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tabla" TEXT NOT NULL,
    "registro_id" INTEGER NOT NULL,
    "tipo_operacion" TEXT NOT NULL,
    "payload" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "intentos" INTEGER NOT NULL DEFAULT 0,
    "ultimo_error" TEXT NULL
  );
''';

/// `cargas_capital` tal como quedó entre v3 y v5 (sin `tipo` ni
/// `eliminado_en`, agregadas recién en v5).
const _crearCargasCapitalV3a4 = '''
  CREATE TABLE cargas_capital (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "usuario_id" INTEGER NOT NULL,
    "monto" REAL NOT NULL,
    "descripcion" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

/// `cargas_capital` tal como quedó entre v5 y v6 (con `tipo`/`eliminado_en`,
/// pero sin `uuid_local`/`origen`/`creado_por_usuario_id`, agregadas recién
/// en v6).
const _crearCargasCapitalV5a6 = '''
  CREATE TABLE cargas_capital (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "usuario_id" INTEGER NOT NULL,
    "monto" REAL NOT NULL,
    "tipo" TEXT NOT NULL DEFAULT 'carga',
    "descripcion" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

/// `cambios_pendientes` tal como quedó desde v4 en adelante (con `usuario_id`).
const _crearCambiosPendientesV4masAdelante = '''
  CREATE TABLE cambios_pendientes (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "usuario_id" INTEGER NULL,
    "tabla" TEXT NOT NULL,
    "registro_id" INTEGER NOT NULL,
    "tipo_operacion" TEXT NOT NULL,
    "payload" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "intentos" INTEGER NOT NULL DEFAULT 0,
    "ultimo_error" TEXT NULL
  );
''';

/// `clientes` tal como existió desde v1 hasta v6 (sin `uuid_local`, agregada
/// recién en v6).
const _crearClientesV1a6 = '''
  CREATE TABLE clientes (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "usuario_id" INTEGER NOT NULL,
    "nombre" TEXT NOT NULL,
    "cedula" TEXT NOT NULL,
    "telefono" TEXT NOT NULL,
    "direccion" TEXT NOT NULL,
    "referencia" TEXT NULL,
    "foto_url" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

/// `prestamos` tal como quedó entre v2 y v6 (con `referencia`, sin
/// `uuid_local`, agregada recién en v6).
const _crearPrestamosV2a6 = '''
  CREATE TABLE prestamos (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "cliente_id" INTEGER NOT NULL,
    "referencia" TEXT NULL,
    "usuario_id" INTEGER NOT NULL,
    "monto_capital" REAL NOT NULL,
    "porcentaje_interes" REAL NOT NULL,
    "frecuencia_pago" TEXT NOT NULL,
    "dias_personalizado" INTEGER NULL,
    "plazo_cuotas" INTEGER NOT NULL,
    "fecha_inicio" INTEGER NOT NULL,
    "estado" TEXT NOT NULL DEFAULT 'activo',
    "politica_mora" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

/// `pagos` tal como existió desde v1 hasta v6 (sin `uuid_local`, agregada
/// recién en v6).
const _crearPagosV1a6 = '''
  CREATE TABLE pagos (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "prestamo_id" INTEGER NOT NULL,
    "cuota_id" INTEGER NULL,
    "monto_abonado" REAL NOT NULL,
    "monto_aplicado" REAL NOT NULL,
    "fecha_pago" INTEGER NOT NULL,
    "dias_mora" INTEGER NOT NULL DEFAULT 0,
    "saldo_restante_despues" REAL NOT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

/// `clientes`/`prestamos`/`pagos`/`cargas_capital` en su forma final de v6 (con `uuid_local` ya
/// agregado, y `origen`/`creado_por_usuario_id` en `cargas_capital`) — el esquema completo justo
/// antes del paso v6->v7 que agrega `cierres_caja`/`cierre_caja_gastos`.
const _crearClientesV6 = '''
  CREATE TABLE clientes (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "usuario_id" INTEGER NOT NULL,
    "nombre" TEXT NOT NULL,
    "cedula" TEXT NOT NULL,
    "telefono" TEXT NOT NULL,
    "direccion" TEXT NOT NULL,
    "referencia" TEXT NULL,
    "foto_url" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1)),
    "uuid_local" TEXT NULL
  );
''';

const _crearPrestamosV6 = '''
  CREATE TABLE prestamos (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "cliente_id" INTEGER NOT NULL,
    "referencia" TEXT NULL,
    "usuario_id" INTEGER NOT NULL,
    "monto_capital" REAL NOT NULL,
    "porcentaje_interes" REAL NOT NULL,
    "frecuencia_pago" TEXT NOT NULL,
    "dias_personalizado" INTEGER NULL,
    "plazo_cuotas" INTEGER NOT NULL,
    "fecha_inicio" INTEGER NOT NULL,
    "estado" TEXT NOT NULL DEFAULT 'activo',
    "politica_mora" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1)),
    "uuid_local" TEXT NULL
  );
''';

const _crearPagosV6 = '''
  CREATE TABLE pagos (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "prestamo_id" INTEGER NOT NULL,
    "cuota_id" INTEGER NULL,
    "monto_abonado" REAL NOT NULL,
    "monto_aplicado" REAL NOT NULL,
    "fecha_pago" INTEGER NOT NULL,
    "dias_mora" INTEGER NOT NULL DEFAULT 0,
    "saldo_restante_despues" REAL NOT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1)),
    "uuid_local" TEXT NULL
  );
''';

const _crearCargasCapitalV6 = '''
  CREATE TABLE cargas_capital (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "usuario_id" INTEGER NOT NULL,
    "monto" REAL NOT NULL,
    "tipo" TEXT NOT NULL DEFAULT 'carga',
    "descripcion" TEXT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "eliminado_en" INTEGER NULL,
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1)),
    "uuid_local" TEXT NULL,
    "origen" TEXT NOT NULL DEFAULT 'cobrador',
    "creado_por_usuario_id" INTEGER NULL
  );
''';

/// `cierres_caja`/`cierre_caja_gastos` en su forma final de v7 (volcado real de
/// `sqlite_master` para estas dos tablas, sin cambios desde que se agregaron en v7 — no
/// dependen de nada de rutas/ruta_items, que son tablas completamente nuevas en v8).
const _crearCierresCajaV7 = '''
  CREATE TABLE "cierres_caja" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "servidor_id" INTEGER NULL UNIQUE,
    "uuid_local" TEXT NULL,
    "usuario_id" INTEGER NOT NULL,
    "fecha" INTEGER NOT NULL,
    "capital_inicio" REAL NOT NULL,
    "capital_cierre" REAL NOT NULL,
    "justificacion_diferencia" TEXT NULL,
    "gastos_total" REAL NOT NULL DEFAULT 0.0,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
    "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
  );
''';

const _crearCierreCajaGastosV7 = '''
  CREATE TABLE "cierre_caja_gastos" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "cierre_caja_id" INTEGER NOT NULL REFERENCES cierres_caja (id),
    "monto" REAL NOT NULL,
    "detalle" TEXT NOT NULL,
    "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
  );
''';

void main() {
  late Directory carpetaTemporal;
  late File archivoDb;

  setUp(() {
    carpetaTemporal = Directory.systemTemp.createTempSync('cobro_app_migration_test');
    archivoDb = File('${carpetaTemporal.path}/cobro_app.sqlite');
  });

  tearDown(() {
    if (carpetaTemporal.existsSync()) {
      carpetaTemporal.deleteSync(recursive: true);
    }
  });

  /// Crea el archivo con el esquema "v1": la tabla `prestamos` tal como
  /// existía antes de agregar `referencia`, con una fila ya guardada.
  void crearBaseDeDatosVieja() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    // Copia exacta del CREATE TABLE que generaba Drift antes de agregar
    // `referencia` (verificado volcando `sqlite_master` con el esquema
    // actual y quitando esa columna), para que el resto de defaults/checks
    // coincida con lo que de verdad quedó guardado en dispositivos viejos.
    db.execute('''
      CREATE TABLE prestamos (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "servidor_id" INTEGER NULL UNIQUE,
        "cliente_id" INTEGER NOT NULL,
        "usuario_id" INTEGER NOT NULL,
        "monto_capital" REAL NOT NULL,
        "porcentaje_interes" REAL NOT NULL,
        "frecuencia_pago" TEXT NOT NULL,
        "dias_personalizado" INTEGER NULL,
        "plazo_cuotas" INTEGER NOT NULL,
        "fecha_inicio" INTEGER NOT NULL,
        "estado" TEXT NOT NULL DEFAULT 'activo',
        "politica_mora" TEXT NULL,
        "creado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        "actualizado_en" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        "eliminado_en" INTEGER NULL,
        "sincronizado" INTEGER NOT NULL DEFAULT 0 CHECK ("sincronizado" IN (0, 1))
      );
    ''');
    db.execute('''
      INSERT INTO prestamos
        (cliente_id, usuario_id, monto_capital, porcentaje_interes, frecuencia_pago, plazo_cuotas, fecha_inicio, creado_en, actualizado_en)
      VALUES
        (1, 1, 100000.0, 20.0, 'diario', 10, 1752192000, 1752192000, 1752192000);
    ''');
    // clientes y pagos existen desde v1 igual que prestamos (aunque este
    // test no las use directamente): sin ellas, el paso v5->v6 (agregar
    // uuid_local) fallaría con "no such table" al migrar desde v1, algo que
    // no pasaría en un dispositivo real.
    db.execute(_crearClientesV1a6);
    db.execute(_crearPagosV1a6);
    // cambios_pendientes existe desde v1 igual que prestamos; sin esta
    // tabla el paso v3->v4 (agregar usuario_id) fallaría con "no such
    // table" al migrar desde v1, algo que no pasaría en un dispositivo real.
    db.execute(_crearCambiosPendientesV1a3);
    db.execute('PRAGMA user_version = 1;');
    db.close();
  }

  test('agrega la columna referencia sin perder los préstamos ya guardados', () async {
    crearBaseDeDatosVieja();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));

    final prestamos = await db.prestamosDao.obtenerTodos(1);

    expect(prestamos, hasLength(1));
    expect(prestamos.first.montoCapital, 100000.0);
    expect(prestamos.first.clienteId, 1);
    expect(prestamos.first.referencia, isNull);

    await db.close();

    // La migración debe quedar registrada (incluye los pasos v2->v3 de
    // cargas_capital, v3->v4 de cambios_pendientes.usuarioId, v4->v5 de
    // cargas_capital.tipo/eliminadoEn y v5->v6 de uuid_local/origen, porque
    // venía desde v1): reabrir el mismo archivo no debe volver a intentar
    // migrar ni fallar.
    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 8);

    final dbReabierta = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(dbReabierta.close);

    final nuevoId = await dbReabierta.prestamosDao.insertar(
      PrestamosCompanion.insert(
        clienteId: 1,
        usuarioId: 1,
        montoCapital: 5000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 1,
        fechaInicio: DateTime(2026, 7, 14),
        referencia: const Value('Préstamo moto'),
      ),
    );

    final nuevo = await dbReabierta.prestamosDao.obtenerPorId(nuevoId, 1);
    expect(nuevo?.referencia, 'Préstamo moto');

    final ambos = await dbReabierta.prestamosDao.obtenerTodos(1);
    expect(ambos, hasLength(2));
  });

  /// Crea el archivo con el esquema "v2": ya tiene `prestamos.referencia`
  /// (la migración anterior), pero todavía no existe la tabla
  /// `cargas_capital`, con un préstamo ya guardado.
  void crearBaseDeDatosV2() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearPrestamosV2a6);
    db.execute('''
      INSERT INTO prestamos
        (cliente_id, referencia, usuario_id, monto_capital, porcentaje_interes, frecuencia_pago, plazo_cuotas, fecha_inicio, creado_en, actualizado_en)
      VALUES
        (1, 'Préstamo moto', 1, 100000.0, 20.0, 'diario', 10, 1752192000, 1752192000, 1752192000);
    ''');
    // clientes y pagos: mismo motivo que en crearBaseDeDatosVieja arriba.
    db.execute(_crearClientesV1a6);
    db.execute(_crearPagosV1a6);
    db.execute(_crearCambiosPendientesV1a3);
    db.execute('PRAGMA user_version = 2;');
    db.close();
  }

  test('agrega la tabla cargas_capital sin perder los préstamos ya guardados', () async {
    crearBaseDeDatosV2();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    final prestamos = await db.prestamosDao.obtenerTodos(1);
    expect(prestamos, hasLength(1));
    expect(prestamos.first.referencia, 'Préstamo moto');

    final cargaId = await db.cargasCapitalDao.insertar(
      CargasCapitalCompanion.insert(usuarioId: 1, monto: 500000),
    );

    final cargas = await db.cargasCapitalDao.obtenerTodas(1);
    expect(cargas, hasLength(1));
    expect(cargas.first.id, cargaId);
    expect(cargas.first.monto, 500000);
  });

  /// Crea el archivo con el esquema "v3": ya tiene la tabla `cargas_capital`,
  /// pero `cambios_pendientes` todavía no tiene `usuario_id`, con una fila
  /// ya encolada.
  void crearBaseDeDatosV3() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearCambiosPendientesV1a3);
    db.execute('''
      INSERT INTO cambios_pendientes (tabla, registro_id, tipo_operacion, payload)
      VALUES ('clientes', 1, 'crear', '{}');
    ''');
    // Estas tablas ya existen desde v1-v3 (aunque este test no las use
    // directamente): sin ellas, los pasos v4->v5 (tipo/eliminadoEn) y v5->v6
    // (uuid_local) fallarían con "no such table" al migrar desde v3, algo
    // que no pasaría en un dispositivo real.
    db.execute(_crearCargasCapitalV3a4);
    db.execute(_crearClientesV1a6);
    db.execute(_crearPrestamosV2a6);
    db.execute(_crearPagosV1a6);
    db.execute('PRAGMA user_version = 3;');
    db.close();
  }

  test('agrega cambios_pendientes.usuarioId sin perder lo ya encolado', () async {
    crearBaseDeDatosV3();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    // La fila vieja no tenía dueño: no debe aparecer para ningún cobrador.
    final pendientesViejosUsuario1 = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientesViejosUsuario1, isEmpty);

    await db.cambiosPendientesDao.encolar(
      usuarioId: 1,
      tabla: 'clientes',
      registroId: 2,
      tipoOperacion: 'crear',
    );
    await db.cambiosPendientesDao.encolar(
      usuarioId: 2,
      tabla: 'clientes',
      registroId: 3,
      tipoOperacion: 'crear',
    );

    final pendientesUsuario1 = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientesUsuario1.map((p) => p.registroId), [2]);

    final pendientesUsuario2 = await db.cambiosPendientesDao.obtenerPendientes(2);
    expect(pendientesUsuario2.map((p) => p.registroId), [3]);
  });

  /// Crea el archivo con el esquema "v4": ya tiene `cambios_pendientes.usuario_id`
  /// y la tabla `cargas_capital`, pero esta última todavía no tiene `tipo` ni
  /// `eliminado_en`, con una carga de capital ya guardada.
  void crearBaseDeDatosV4() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearCambiosPendientesV4masAdelante);
    db.execute(_crearCargasCapitalV3a4);
    db.execute('''
      INSERT INTO cargas_capital (usuario_id, monto, descripcion, creado_en)
      VALUES (1, 500000.0, 'Aporte inicial', 1752192000);
    ''');
    // clientes/prestamos/pagos: mismo motivo que en crearBaseDeDatosV3 arriba.
    db.execute(_crearClientesV1a6);
    db.execute(_crearPrestamosV2a6);
    db.execute(_crearPagosV1a6);
    db.execute('PRAGMA user_version = 4;');
    db.close();
  }

  test('agrega tipo y eliminadoEn a cargas_capital sin perder lo ya guardado', () async {
    crearBaseDeDatosV4();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    final cargas = await db.cargasCapitalDao.obtenerTodas(1);
    expect(cargas, hasLength(1));
    // La columna tipo llega con su default 'carga' para filas viejas, que
    // todas eran aportes (el concepto de retiro no existía antes de v5).
    expect(cargas.first.tipo, 'carga');
    expect(cargas.first.monto, 500000.0);

    final retiroId = await db.cargasCapitalDao.insertar(
      CargasCapitalCompanion.insert(usuarioId: 1, monto: 20000, tipo: const Value('retiro')),
    );
    await db.cargasCapitalDao.eliminar(retiroId);

    // El retiro recién insertado y luego eliminado no debe aparecer, la
    // carga vieja sigue intacta.
    final trasEliminar = await db.cargasCapitalDao.obtenerTodas(1);
    expect(trasEliminar, hasLength(1));
    expect(trasEliminar.first.descripcion, 'Aporte inicial');

    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 8);
  });

  /// Crea el archivo con el esquema "v5": clientes/prestamos/pagos/cargas_capital
  /// ya con su forma final salvo por `uuid_local` (y `origen`/
  /// `creado_por_usuario_id` en cargas_capital), agregadas recién en v6, con
  /// un cliente, un préstamo, un pago y una carga de capital ya guardados.
  void crearBaseDeDatosV5() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearCambiosPendientesV4masAdelante);
    db.execute(_crearClientesV1a6);
    db.execute(_crearPrestamosV2a6);
    db.execute(_crearPagosV1a6);
    db.execute(_crearCargasCapitalV5a6);

    db.execute('''
      INSERT INTO clientes (usuario_id, nombre, cedula, telefono, direccion, creado_en, actualizado_en)
      VALUES (1, 'Juan Perez', '111', '3000000001', 'Calle 1', 1752192000, 1752192000);
    ''');
    db.execute('''
      INSERT INTO prestamos
        (cliente_id, usuario_id, monto_capital, porcentaje_interes, frecuencia_pago, plazo_cuotas, fecha_inicio, creado_en, actualizado_en)
      VALUES
        (1, 1, 100000.0, 20.0, 'diario', 10, 1752192000, 1752192000, 1752192000);
    ''');
    db.execute('''
      INSERT INTO pagos (prestamo_id, monto_abonado, monto_aplicado, fecha_pago, saldo_restante_despues, creado_en, actualizado_en)
      VALUES (1, 12500.0, 12500.0, 1752192000, 112500.0, 1752192000, 1752192000);
    ''');
    db.execute('''
      INSERT INTO cargas_capital (usuario_id, monto, tipo, descripcion, creado_en)
      VALUES (1, 500000.0, 'carga', 'Aporte inicial', 1752192000);
    ''');
    db.execute('PRAGMA user_version = 5;');
    db.close();
  }

  test('agrega uuid_local (y origen/creadoPorUsuarioId en cargas_capital) sin perder lo ya guardado', () async {
    crearBaseDeDatosV5();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    final cliente = await db.clientesDao.obtenerPorId(1, 1);
    expect(cliente, isNotNull);
    expect(cliente!.nombre, 'Juan Perez');
    expect(cliente.uuidLocal, isNull);

    final prestamo = await db.prestamosDao.obtenerPorId(1, 1);
    expect(prestamo, isNotNull);
    expect(prestamo!.montoCapital, 100000.0);
    expect(prestamo.uuidLocal, isNull);

    final pago = await db.pagosDao.obtenerPorId(1);
    expect(pago, isNotNull);
    expect(pago!.montoAbonado, 12500.0);
    expect(pago.uuidLocal, isNull);

    final cargas = await db.cargasCapitalDao.obtenerTodas(1);
    expect(cargas, hasLength(1));
    expect(cargas.first.descripcion, 'Aporte inicial');
    expect(cargas.first.uuidLocal, isNull);
    // Filas viejas: todas eran del propio cobrador, nunca de un admin.
    expect(cargas.first.origen, 'cobrador');
    expect(cargas.first.creadoPorUsuarioId, isNull);

    // Las columnas nuevas deben quedar utilizables para registros nuevos.
    final nuevoClienteId = await db.clientesDao.insertar(
      ClientesCompanion.insert(
        usuarioId: 1,
        nombre: 'Maria Gomez',
        cedula: '222',
        telefono: '3000000002',
        direccion: 'Calle 2',
        uuidLocal: const Value('uuid-cliente-2'),
      ),
    );
    final nuevoCliente = await db.clientesDao.obtenerPorId(nuevoClienteId, 1);
    expect(nuevoCliente?.uuidLocal, 'uuid-cliente-2');

    final cargaAdminId = await db.cargasCapitalDao.insertar(
      CargasCapitalCompanion.insert(
        usuarioId: 1,
        monto: 200000,
        servidorId: const Value(99),
        origen: const Value('admin'),
        creadoPorUsuarioId: const Value(7),
        sincronizado: const Value(true),
      ),
    );
    final cargaAdmin = await (db.select(db.cargasCapital)..where((t) => t.id.equals(cargaAdminId))).getSingle();
    expect(cargaAdmin.origen, 'admin');
    expect(cargaAdmin.creadoPorUsuarioId, 7);

    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 8);
  });

  /// Crea el archivo con el esquema "v6": clientes/prestamos/pagos/cargas_capital ya con su
  /// forma final (incluido `uuid_local`), pero sin `cierres_caja` ni `cierre_caja_gastos`
  /// (tablas enteramente nuevas, agregadas recién en v7), con un cliente ya guardado.
  void crearBaseDeDatosV6() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearCambiosPendientesV4masAdelante);
    db.execute(_crearClientesV6);
    db.execute(_crearPrestamosV6);
    db.execute(_crearPagosV6);
    db.execute(_crearCargasCapitalV6);

    db.execute('''
      INSERT INTO clientes (usuario_id, nombre, cedula, telefono, direccion, creado_en, actualizado_en, uuid_local)
      VALUES (1, 'Juan Perez', '111', '3000000001', 'Calle 1', 1752192000, 1752192000, 'uuid-cliente-1');
    ''');
    db.execute('PRAGMA user_version = 6;');
    db.close();
  }

  test('agrega las tablas cierres_caja y cierre_caja_gastos sin perder lo ya guardado', () async {
    crearBaseDeDatosV6();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    final cliente = await db.clientesDao.obtenerPorId(1, 1);
    expect(cliente, isNotNull);
    expect(cliente!.nombre, 'Juan Perez');
    expect(cliente.uuidLocal, 'uuid-cliente-1');

    // Las tablas nuevas nacen vacías pero utilizables.
    expect(await db.cierresCajaDao.obtenerTodos(1), isEmpty);

    final cierreId = await db.cierresCajaDao.insertar(
      CierresCajaCompanion.insert(
        usuarioId: 1,
        fecha: DateTime(2026, 7, 21),
        capitalInicio: 100000,
        capitalCierre: 150000,
        uuidLocal: const Value('uuid-cierre-1'),
      ),
    );
    await db.cierreCajaGastosDao.insertar(
      CierreCajaGastosCompanion.insert(cierreCajaId: cierreId, monto: 10000, detalle: 'almuerzo'),
    );

    final cierres = await db.cierresCajaDao.obtenerTodos(1);
    expect(cierres, hasLength(1));
    expect(cierres.first.capitalCierre, 150000);

    final gastos = await db.cierreCajaGastosDao.obtenerPorCierre(cierreId);
    expect(gastos, hasLength(1));
    expect(gastos.first.detalle, 'almuerzo');

    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 8);
  });

  /// Crea el archivo con el esquema "v7": clientes/prestamos/pagos/cargas_capital en su forma
  /// final, más cierres_caja/cierre_caja_gastos ya creadas, pero sin rutas/ruta_items (tablas
  /// enteramente nuevas, agregadas recién en v8), con un cliente y un préstamo ya guardados.
  void crearBaseDeDatosV7() {
    final db = sqlite3.sqlite3.open(archivoDb.path);
    db.execute(_crearCambiosPendientesV4masAdelante);
    db.execute(_crearClientesV6);
    db.execute(_crearPrestamosV6);
    db.execute(_crearPagosV6);
    db.execute(_crearCargasCapitalV6);
    db.execute(_crearCierresCajaV7);
    db.execute(_crearCierreCajaGastosV7);

    db.execute('''
      INSERT INTO clientes (usuario_id, nombre, cedula, telefono, direccion, creado_en, actualizado_en, uuid_local)
      VALUES (1, 'Juan Perez', '111', '3000000001', 'Calle 1', 1752192000, 1752192000, 'uuid-cliente-1');
    ''');
    db.execute('''
      INSERT INTO prestamos
        (id, cliente_id, usuario_id, monto_capital, porcentaje_interes, frecuencia_pago, plazo_cuotas, fecha_inicio, creado_en, actualizado_en, uuid_local)
      VALUES
        (1, 1, 1, 100000.0, 20.0, 'diario', 10, 1752192000, 1752192000, 1752192000, 'uuid-prestamo-1');
    ''');
    db.execute('PRAGMA user_version = 7;');
    db.close();
  }

  test('agrega las tablas rutas y ruta_items sin perder lo ya guardado', () async {
    crearBaseDeDatosV7();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));
    addTearDown(db.close);

    final cliente = await db.clientesDao.obtenerPorId(1, 1);
    expect(cliente, isNotNull);
    expect(cliente!.nombre, 'Juan Perez');

    final prestamo = await db.prestamosDao.obtenerPorId(1, 1);
    expect(prestamo, isNotNull);

    // Las tablas nuevas nacen vacías pero utilizables.
    expect(await db.rutasDao.obtenerTodas(1), isEmpty);

    final rutaId = await db.rutasDao.insertar(
      RutasCompanion.insert(usuarioId: 1, nombre: 'Ruta barrio Centro', uuidLocal: const Value('uuid-ruta-1')),
    );
    await db.rutaItemsDao.insertar(
      RutaItemsCompanion.insert(rutaId: rutaId, prestamoId: 1, uuidLocal: const Value('uuid-item-1')),
    );

    final rutas = await db.rutasDao.obtenerTodas(1);
    expect(rutas, hasLength(1));
    expect(rutas.first.nombre, 'Ruta barrio Centro');

    final items = await db.rutaItemsDao.obtenerPorRuta(rutaId);
    expect(items, hasLength(1));
    expect(items.first.prestamoId, 1);
    expect(items.first.estado, 'pendiente');

    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 8);
  });
}
