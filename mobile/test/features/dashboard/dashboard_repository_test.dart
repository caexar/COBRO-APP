import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/dashboard/data/dashboard_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamo_calculator.dart';
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
  late CargasCapitalRepository cargasCapitalRepository;
  late DashboardRepository dashboardRepository;

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
    cargasCapitalRepository = CargasCapitalRepository(database: db, secureStorage: secureStorage);
    dashboardRepository = DashboardRepository(
      prestamosRepository: prestamosRepository,
      pagosRepository: pagosRepository,
      cargasCapitalRepository: cargasCapitalRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('calcula saldo disponible, cartera, proyección y ganancia realizada', () async {
    final hoy = DateTime(2026, 7, 15);

    // Cliente A: préstamo activo de 125000 (capital 100000, interés 20%,
    // extra 5000), 10 cuotas diarias de 12500 empezando 3 días atrás, así
    // la cuota 3 vence hoy.
    final clienteA = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '111',
      telefono: '3000000001',
      direccion: 'Calle 1',
    );
    final prestamo1 = await prestamosRepository.crear(
      clienteId: clienteA,
      montoCapital: 100000,
      porcentajeInteres: 20,
      extras: const [ExtraPrestamo(concepto: 'papeleria', valor: 5000)],
      frecuenciaPago: 'diario',
      plazoCuotas: 10,
      fechaInicio: hoy.subtract(const Duration(days: 3)),
      politicaMora: 'mantener',
    );

    final cuotas1 = (await prestamosRepository.obtenerDetalle(prestamo1)).cuotas;

    // Cuota 1 pagada exacta (12500, sin mora).
    await pagosRepository.registrar(
      prestamoId: prestamo1,
      montoAbonado: 12500,
      fechaPago: cuotas1[0].fechaEsperada,
    );
    // Cuota 2: paga 20000 contra un pendiente de 12500 -> excedente 7500
    // registrado como cobro_extra (no reduce la deuda).
    await pagosRepository.registrar(
      prestamoId: prestamo1,
      montoAbonado: 20000,
      fechaPago: cuotas1[1].fechaEsperada,
      manejoExcedente: 'cobro_extra',
    );

    // Cliente B: préstamo pequeño ya pagado por completo (no debe contar
    // para cartera/capital activo/proyección, pero sí para ganancia y saldo).
    final clienteB = await clientesRepository.crear(
      nombre: 'Maria Gomez',
      cedula: '222',
      telefono: '3000000002',
      direccion: 'Calle 2',
    );
    final prestamo2 = await prestamosRepository.crear(
      clienteId: clienteB,
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 1,
      fechaInicio: hoy.subtract(const Duration(days: 5)),
    );
    final cuotas2 = (await prestamosRepository.obtenerDetalle(prestamo2)).cuotas;
    await pagosRepository.registrar(
      prestamoId: prestamo2,
      montoAbonado: 10000,
      fechaPago: cuotas2[0].fechaEsperada,
    );

    await cargasCapitalRepository.crear(monto: 200000, descripcion: 'Aporte inicial');

    final resumen = await dashboardRepository.calcularResumen();

    // totalAbonadoGlobal = 32500 (prestamo1) + 10000 (prestamo2) = 42500
    // capitalEnPrestamosActivos = 100000 (solo prestamo1, el 2 ya está pagado)
    // saldoDisponible = 200000 + 42500 - 100000
    expect(resumen.saldoDisponible, 142500);

    // cartera = montoTotal(125000) - totalAplicado(25000) del préstamo 1 activo.
    expect(resumen.carteraPorCobrar, 100000);

    // interesProp = 20000/125000 = 0.16; extrasProp = 5000/125000 = 0.04
    // totalAplicado prestamo1 = 25000 -> interes 4000, extras propias 1000
    // + excedente cobro_extra 7500 = 8500. prestamo2 (0% interés) no aporta.
    expect(resumen.gananciaInteres, closeTo(4000, 0.01));
    expect(resumen.gananciaExtras, closeTo(8500, 0.01));
    expect(resumen.gananciaTotal, closeTo(12500, 0.01));

    // Cuota 3 (única con fecha_esperada == hoy) = 12500.
    expect(resumen.proyeccionHoy, 12500);
    // Cuotas 3..9 (7 cuotas, dentro de [hoy, hoy+7)) = 7 * 12500.
    expect(resumen.proyeccionSemana, 87500);
  });

  test('sin datos, todo queda en cero', () async {
    final resumen = await dashboardRepository.calcularResumen();

    expect(resumen.saldoDisponible, 0);
    expect(resumen.carteraPorCobrar, 0);
    expect(resumen.proyeccionHoy, 0);
    expect(resumen.proyeccionSemana, 0);
    expect(resumen.gananciaTotal, 0);
  });
}
