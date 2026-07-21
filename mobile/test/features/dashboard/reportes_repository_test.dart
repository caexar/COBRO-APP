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
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
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

  test('incluye las secciones de resumen, préstamos e historial de pagos', () async {
    final (clienteA, _, prestamoA, prestamoB) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoB, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));

    final csv = await reportesRepository.construirCsv();

    expect(csv, contains('Resumen de cartera'));
    expect(csv, contains('Préstamos'));
    expect(csv, contains('Juan Perez'));
    expect(csv, contains('Préstamo moto'));
    expect(csv, contains('Historial de pagos'));
    expect(csv, contains('Total ingresado por cliente en el rango'));
    expect(clienteA, isPositive);
  });

  test('filtra el historial de pagos por rango de fechas', () async {
    final (_, _, prestamoA, _) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 2, 5));

    final csvFiltrado = await reportesRepository.construirCsv(
      desde: DateTime(2026, 2, 1),
      hasta: DateTime(2026, 2, 28),
    );

    final filas = csvFiltrado.split('\r\n');
    final filasDePago = filas.where((f) => f.contains('Juan Perez') && f.contains('10.000'));
    // Solo el pago de febrero debe aparecer en el historial filtrado (puede
    // aparecer también en el listado de préstamos, así que no se cuenta 0).
    expect(filasDePago, isNotEmpty);
    expect(csvFiltrado, isNot(contains('02/01/2026')));
    expect(csvFiltrado, contains('05/02/2026'));
  });

  test('incluye la sección de cierre de caja (diario y resumen agregado del rango)', () async {
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

    final csv = await reportesRepository.construirCsv(desde: DateTime(2026, 1, 1), hasta: DateTime(2026, 1, 31));

    expect(csv, contains('Cierre de caja'));
    expect(csv, contains('almuerzo'));
    expect(csv, contains('Ajuste por cambio no registrado'));

    expect(csv, contains('Resumen de cierre de caja (rango)'));
    final seccionResumen = csv.split('Resumen de cierre de caja (rango)').last;
    // Capital inicio del primer día (100.000) y capital cierre del último (200.000).
    expect(seccionResumen, contains('100.000'));
    expect(seccionResumen, contains('200.000'));
  });

  test('filtra el historial de pagos por cliente', () async {
    final (clienteA, _, prestamoA, prestamoB) = await crearEscenario();

    await pagosRepository.registrar(prestamoId: prestamoA, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));
    await pagosRepository.registrar(prestamoId: prestamoB, montoAbonado: 10000, fechaPago: DateTime(2026, 1, 2));

    final csvFiltrado = await reportesRepository.construirCsv(clienteId: clienteA);

    final seccionHistorial = csvFiltrado.split('Historial de pagos').last;
    expect(seccionHistorial, contains('Juan Perez'));
    expect(seccionHistorial, isNot(contains('Maria Gomez')));
  });
}
