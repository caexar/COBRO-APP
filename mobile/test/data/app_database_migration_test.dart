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
    db.execute('PRAGMA user_version = 1;');
    db.close();
  }

  test('agrega la columna referencia sin perder los préstamos ya guardados', () async {
    crearBaseDeDatosVieja();

    final db = AppDatabase.paraPruebas(NativeDatabase(archivoDb));

    final prestamos = await db.prestamosDao.obtenerTodos();

    expect(prestamos, hasLength(1));
    expect(prestamos.first.montoCapital, 100000.0);
    expect(prestamos.first.clienteId, 1);
    expect(prestamos.first.referencia, isNull);

    await db.close();

    // La migración debe quedar registrada: reabrir el mismo archivo no debe
    // volver a intentar migrar ni fallar.
    final rawDespues = sqlite3.sqlite3.open(archivoDb.path);
    final version = rawDespues.select('PRAGMA user_version;').first['user_version'] as int;
    rawDespues.close();
    expect(version, 2);

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

    final nuevo = await dbReabierta.prestamosDao.obtenerPorId(nuevoId);
    expect(nuevo?.referencia, 'Préstamo moto');

    final ambos = await dbReabierta.prestamosDao.obtenerTodos();
    expect(ambos, hasLength(2));
  });
}
