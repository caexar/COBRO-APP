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
    // cargas_capital, v3->v4 de cambios_pendientes.usuarioId y v4->v5 de
    // cargas_capital.tipo/eliminadoEn, porque venía desde v1): reabrir el
    // mismo archivo no debe volver a intentar migrar ni fallar.
    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 5);

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
    db.execute('''
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
    ''');
    db.execute('''
      INSERT INTO prestamos
        (cliente_id, referencia, usuario_id, monto_capital, porcentaje_interes, frecuencia_pago, plazo_cuotas, fecha_inicio, creado_en, actualizado_en)
      VALUES
        (1, 'Préstamo moto', 1, 100000.0, 20.0, 'diario', 10, 1752192000, 1752192000, 1752192000);
    ''');
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
    // La tabla ya existe desde v3 (aunque este test no la use directamente):
    // sin ella, el paso v4->v5 (agregar tipo/eliminadoEn) fallaría con "no
    // such table" al migrar desde v3, algo que no pasaría en un dispositivo real.
    db.execute(_crearCargasCapitalV3a4);
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
    db.execute('''
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
    ''');
    db.execute(_crearCargasCapitalV3a4);
    db.execute('''
      INSERT INTO cargas_capital (usuario_id, monto, descripcion, creado_en)
      VALUES (1, 500000.0, 'Aporte inicial', 1752192000);
    ''');
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
    expect(version, 5);
  });
}
