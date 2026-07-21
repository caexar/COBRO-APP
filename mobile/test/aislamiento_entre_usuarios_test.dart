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
  _SecureStorageFalso(this.usuarioId);

  final int usuarioId;

  @override
  Future<int?> leerUsuarioId() async => usuarioId;
}

/// Todo lo que necesita un cobrador para operar, apuntando a la MISMA base
/// de datos (simula dos cobradores que comparten dispositivo, cada uno con
/// su propia sesión).
class _RepositoriosDeUnCobrador {
  _RepositoriosDeUnCobrador(AppDatabase db, int usuarioId)
    : secureStorage = _SecureStorageFalso(usuarioId),
      clientes = ClientesRepository(database: db, secureStorage: _SecureStorageFalso(usuarioId)),
      prestamos = PrestamosRepository(database: db, secureStorage: _SecureStorageFalso(usuarioId)) {
    pagos = PagosRepository(database: db, secureStorage: secureStorage, prestamosRepository: prestamos);
    cargasCapital = CargasCapitalRepository(database: db, secureStorage: secureStorage);
    cierresCaja = CierresCajaRepository(database: db, secureStorage: secureStorage);
    dashboard = DashboardRepository(
      prestamosRepository: prestamos,
      pagosRepository: pagos,
      cargasCapitalRepository: cargasCapital,
    );
    reportes = ReportesRepository(
      prestamosRepository: prestamos,
      pagosRepository: pagos,
      clientesRepository: clientes,
      dashboardRepository: dashboard,
      cierresCajaRepository: cierresCaja,
    );
  }

  final SecureStorageService secureStorage;
  final ClientesRepository clientes;
  final PrestamosRepository prestamos;
  late final PagosRepository pagos;
  late final CargasCapitalRepository cargasCapital;
  late final CierresCajaRepository cierresCaja;
  late final DashboardRepository dashboard;
  late final ReportesRepository reportes;
}

void main() {
  late AppDatabase db;
  late _RepositoriosDeUnCobrador cobrador1;
  late _RepositoriosDeUnCobrador cobrador2;

  setUp(() {
    // Una sola base de datos compartida: es exactamente el escenario de dos
    // cobradores usando la misma app/dispositivo con sesiones distintas.
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    cobrador1 = _RepositoriosDeUnCobrador(db, 1);
    cobrador2 = _RepositoriosDeUnCobrador(db, 2);
  });

  tearDown(() async {
    await db.close();
  });

  /// Cada cobrador crea un cliente, un préstamo con un pago (uno de ellos
  /// con excedente `cobro_extra`) y una carga de capital, con montos bien
  /// distintos para que cualquier cruce sea obvio en los asserts.
  Future<void> sembrarDatosDeAmbosCobradores() async {
    final cliente1 = await cobrador1.clientes.crear(
      nombre: 'Juan Perez',
      cedula: '111',
      telefono: '3000000001',
      direccion: 'Calle 1',
    );
    final prestamo1 = await cobrador1.prestamos.crear(
      clienteId: cliente1,
      referencia: 'Préstamo de Juan',
      montoCapital: 100000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );
    final cuotas1 = (await cobrador1.prestamos.obtenerDetalle(prestamo1)).cuotas;
    await cobrador1.pagos.registrar(
      prestamoId: prestamo1,
      montoAbonado: 50000,
      fechaPago: cuotas1[0].fechaEsperada,
    );
    await cobrador1.cargasCapital.crear(monto: 10000, descripcion: 'Aporte de cobrador 1');

    final cliente2 = await cobrador2.clientes.crear(
      nombre: 'Maria Gomez',
      cedula: '222',
      telefono: '3000000002',
      direccion: 'Calle 2',
    );
    final prestamo2 = await cobrador2.prestamos.crear(
      clienteId: cliente2,
      referencia: 'Préstamo de Maria',
      montoCapital: 999000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 3,
      fechaInicio: DateTime(2026, 1, 1),
    );
    final cuotas2 = (await cobrador2.prestamos.obtenerDetalle(prestamo2)).cuotas;
    await cobrador2.pagos.registrar(
      prestamoId: prestamo2,
      montoAbonado: 333000,
      fechaPago: cuotas2[0].fechaEsperada,
    );
    await cobrador2.cargasCapital.crear(monto: 777000, descripcion: 'Aporte de cobrador 2');
  }

  test('cada cobrador solo ve sus propios clientes', () async {
    await sembrarDatosDeAmbosCobradores();

    final clientes1 = await cobrador1.clientes.listar();
    expect(clientes1.map((c) => c.nombre), ['Juan Perez']);

    final clientes2 = await cobrador2.clientes.listar();
    expect(clientes2.map((c) => c.nombre), ['Maria Gomez']);

    // El buscador tampoco cruza: buscar "a" (está en ambos nombres) desde
    // cada sesión solo debe devolver lo propio.
    final busqueda1 = await cobrador1.clientes.buscar('a');
    expect(busqueda1.every((c) => c.nombre == 'Juan Perez'), isTrue);
  });

  test('cada cobrador solo ve sus propios préstamos, en cualquier listado', () async {
    await sembrarDatosDeAmbosCobradores();

    final todos1 = await cobrador1.prestamos.listarTodos();
    expect(todos1, hasLength(1));
    expect(todos1.first.referencia, 'Préstamo de Juan');

    final todos2 = await cobrador2.prestamos.listarTodos();
    expect(todos2, hasLength(1));
    expect(todos2.first.referencia, 'Préstamo de Maria');

    final pendientes1 = await cobrador1.prestamos.listarPendientes();
    expect(pendientes1.map((p) => p.cliente.nombre), ['Juan Perez']);
  });

  test('un cobrador no puede abrir el detalle de un préstamo ajeno aunque conozca su id', () async {
    await sembrarDatosDeAmbosCobradores();

    final prestamoDeJuan = (await cobrador1.prestamos.listarTodos()).first;

    await expectLater(
      cobrador2.prestamos.obtenerDetalle(prestamoDeJuan.id),
      throwsA(isA<StateError>()),
    );

    // El propio dueño sí puede.
    final detalle = await cobrador1.prestamos.obtenerDetalle(prestamoDeJuan.id);
    expect(detalle.prestamo.id, prestamoDeJuan.id);
  });

  test('cada cobrador solo ve sus propias cargas de capital', () async {
    await sembrarDatosDeAmbosCobradores();

    final cargas1 = await cobrador1.cargasCapital.listarTodas();
    expect(cargas1.map((c) => c.monto), [10000]);

    final cargas2 = await cobrador2.cargasCapital.listarTodas();
    expect(cargas2.map((c) => c.monto), [777000]);
  });

  test('el dashboard de cada cobrador refleja solo sus propios números', () async {
    await sembrarDatosDeAmbosCobradores();

    final resumen1 = await cobrador1.dashboard.calcularResumen();
    // saldoDisponible = cargas(10000) + abonado(50000) - capitalActivo(100000)
    expect(resumen1.saldoDisponible, -40000);
    expect(resumen1.carteraPorCobrar, 50000);

    final resumen2 = await cobrador2.dashboard.calcularResumen();
    // saldoDisponible = cargas(777000) + abonado(333000) - capitalActivo(999000)
    expect(resumen2.saldoDisponible, 111000);
    expect(resumen2.carteraPorCobrar, 666000);
  });

  test('el CSV de reportes de cada cobrador no menciona nada del otro', () async {
    await sembrarDatosDeAmbosCobradores();

    final csv1 = await cobrador1.reportes.construirCsv();
    expect(csv1, contains('Juan Perez'));
    expect(csv1, isNot(contains('Maria Gomez')));
    expect(csv1, isNot(contains('999000')));

    final csv2 = await cobrador2.reportes.construirCsv();
    expect(csv2, contains('Maria Gomez'));
    expect(csv2, isNot(contains('Juan Perez')));
  });

  test('la cola de cambios_pendientes tampoco se cruza entre cobradores', () async {
    await sembrarDatosDeAmbosCobradores();

    final pendientes1 = await db.cambiosPendientesDao.obtenerPendientes(1);
    final pendientes2 = await db.cambiosPendientesDao.obtenerPendientes(2);

    expect(pendientes1, isNotEmpty);
    expect(pendientes2, isNotEmpty);
    expect(pendientes1.every((p) => p.usuarioId == 1), isTrue);
    expect(pendientes2.every((p) => p.usuarioId == 2), isTrue);
  });
}
