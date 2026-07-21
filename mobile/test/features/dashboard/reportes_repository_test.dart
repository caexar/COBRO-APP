import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:cobro_app/features/capital/data/cierres_caja_repository.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/dashboard/data/dashboard_repository.dart';
import 'package:cobro_app/features/dashboard/data/reportes_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

/// Todas las celdas de [sheet] concatenadas en un solo texto, para poder
/// seguir usando `contains` como cuando el reporte era un CSV plano.
String _textoPlano(Sheet sheet) {
  return sheet.rows
      .map((fila) => fila.map((celda) => celda?.value?.toString() ?? '').join(','))
      .join('\n');
}

void main() {
  late AppDatabase db;
  late ClientesRepository clientesRepository;
  late PrestamosRepository prestamosRepository;
  late PagosRepository pagosRepository;
  late ReportesRepository reportesRepository;
  late CierresCajaRepository cierresCajaRepository;

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
    pagosRepository = PagosRepository(
      database: db,
      secureStorage: secureStorage,
      prestamosRepository: prestamosRepository,
    );
    final cargasCapitalRepository = CargasCapitalRepository(database: db, secureStorage: secureStorage);
    cierresCajaRepository = CierresCajaRepository(database: db, secureStorage: secureStorage);
    reportesRepository = ReportesRepository(
      prestamosRepository: prestamosRepository,
      pagosRepository: pagosRepository,
      clientesRepository: clientesRepository,
      dashboardRepository: DashboardRepository(
        prestamosRepository: prestamosRepository,
        pagosRepository: pagosRepository,
        cargasCapitalRepository: cargasCapitalRepository,
      ),
      cierresCajaRepository: cierresCajaRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<(int clienteA, int clienteB, int prestamoA, int prestamoB)> crearEscenario() async {
    final clienteA = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '111',
      telefono: '3000000001',
      direccion: 'Calle 1',
    );
    final clienteB = await clientesRepository.crear(
      nombre: 'Maria Gomez',
      cedula: '222',
      telefono: '3000000002',
      direccion: 'Calle 2',
    );

    final prestamoA = await prestamosRepository.crear(
      clienteId: clienteA,
      referencia: 'Préstamo moto',
      montoCapital: 20000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );
    final prestamoB = await prestamosRepository.crear(
      clienteId: clienteB,
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 1,
      fechaInicio: DateTime(2026, 1, 1),
    );

    return (clienteA, clienteB, prestamoA, prestamoB);
  }

  test('incluye las hojas de resumen, préstamos e historial de pagos', () async {
    final (clienteA, _, prestamoA, prestamoB) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoB, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));

    final excel = await reportesRepository.construirXlsx();

    expect(excel.tables.keys, containsAll(['Resumen', 'Prestamos', 'Historial de pagos', 'Total por cliente']));
    expect(_textoPlano(excel['Prestamos']), contains('Juan Perez'));
    expect(_textoPlano(excel['Prestamos']), contains('Préstamo moto'));
    expect(_textoPlano(excel['Historial de pagos']), contains('Juan Perez'));
    expect(clienteA, isPositive);
  });

  test('filtra el historial de pagos por rango de fechas', () async {
    final (_, _, prestamoA, _) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 2, 5));

    final excel = await reportesRepository.construirXlsx(desde: DateTime(2026, 2, 1), hasta: DateTime(2026, 2, 28));

    final historial = _textoPlano(excel['Historial de pagos']);
    // Solo el pago de febrero debe aparecer en el historial filtrado (puede
    // aparecer también en el listado de préstamos, así que no se cuenta 0).
    expect(historial, isNot(contains('02/01/2026')));
    expect(historial, contains('05/02/2026'));
  });

  test('incluye la hoja de cierre de caja (diario y resumen agregado del rango)', () async {
    await cierresCajaRepository.crear(
      fecha: DateTime(2026, 1, 1),
      capitalInicio: 100000,
      capitalCierre: 120000,
      gastos: const [GastoCierreCaja(monto: 10000, detalle: 'almuerzo')],
    );
    await cierresCajaRepository.crear(
      fecha: DateTime(2026, 1, 5),
      capitalInicio: 120000,
      capitalCierre: 200000,
      justificacionDiferencia: 'Ajuste por cambio no registrado',
    );

    final excel = await reportesRepository.construirXlsx(desde: DateTime(2026, 1, 1), hasta: DateTime(2026, 1, 31));

    final cierre = _textoPlano(excel['Cierre de caja']);
    expect(cierre, contains('almuerzo'));
    expect(cierre, contains('Ajuste por cambio no registrado'));

    final resumen = _textoPlano(excel['Resumen cierre de caja']);
    // Capital inicio del primer día (100.000) y capital cierre del último (200.000).
    expect(resumen, contains('100.000'));
    expect(resumen, contains('200.000'));
  });

  test('filtra el historial de pagos por cliente', () async {
    final (clienteA, _, prestamoA, prestamoB) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoB, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));

    final excel = await reportesRepository.construirXlsx(clienteId: clienteA);

    final historial = _textoPlano(excel['Historial de pagos']);
    expect(historial, contains('Juan Perez'));
    expect(historial, isNot(contains('Maria Gomez')));
  });

  test('exportarYCompartir genera bytes de un .xlsx válido', () async {
    await crearEscenario();

    final excel = await reportesRepository.construirXlsx();
    final bytes = excel.save();

    expect(bytes, isNotNull);
    // Firma ZIP: un .xlsx es un .zip por dentro.
    expect(bytes!.take(2), [0x50, 0x4B]);
  });
}
