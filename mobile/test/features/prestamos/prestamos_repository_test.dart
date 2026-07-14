import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
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

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> crearClientePrueba() {
    return clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '123456',
      telefono: '3001234567',
      direccion: 'Calle 1 # 2-3',
    );
  }

  test('crea el préstamo, sus extras, sus cuotas y lo encola en cambios_pendientes', () async {
    final clienteId = await crearClientePrueba();

    final prestamoId = await prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 100000,
      porcentajeInteres: 20,
      extras: const [ExtraPrestamo(concepto: 'papeleria', valor: 5000)],
      frecuenciaPago: 'diario',
      plazoCuotas: 10,
      fechaInicio: DateTime(2026, 7, 10),
    );

    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    expect(detalle.prestamo.clienteId, clienteId);
    expect(detalle.prestamo.montoCapital, 100000);
    expect(detalle.prestamo.estado, 'activo');
    expect(detalle.prestamo.sincronizado, isFalse);

    expect(detalle.montoInteres, 20000);
    expect(detalle.montoExtras, 5000);
    expect(detalle.montoTotal, 125000);

    expect(detalle.extras, hasLength(1));
    expect(detalle.extras.first.concepto, 'papeleria');

    expect(detalle.cuotas, hasLength(10));
    expect(detalle.cuotas.every((c) => c.montoEsperado == 12500), isTrue);
    expect(detalle.cuotas.every((c) => c.estado == 'pendiente'), isTrue);
    expect(detalle.cuotas.first.fechaEsperada, DateTime(2026, 7, 11));

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
    // 1 del cliente creado + 1 del préstamo creado.
    expect(pendientes.where((p) => p.tabla == 'prestamos' && p.tipoOperacion == 'crear'), hasLength(1));
    expect(pendientes.firstWhere((p) => p.tabla == 'prestamos').registroId, prestamoId);
  });

  test('el resultado guardado coincide con PrestamoCalculator usado directamente', () async {
    final clienteId = await crearClientePrueba();

    const calculadora = PrestamoCalculator();
    final esperado = calculadora.calcular(
      montoCapital: 50000,
      porcentajeInteres: 10,
      frecuenciaPago: 'semanal',
      plazoCuotas: 4,
      fechaInicio: DateTime(2026, 1, 1),
    );

    final prestamoId = await prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 50000,
      porcentajeInteres: 10,
      frecuenciaPago: 'semanal',
      plazoCuotas: 4,
      fechaInicio: DateTime(2026, 1, 1),
    );

    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    expect(detalle.montoTotal, esperado.montoTotal);
    for (var i = 0; i < esperado.cuotas.length; i++) {
      expect(detalle.cuotas[i].montoEsperado, esperado.cuotas[i].montoEsperado);
      expect(detalle.cuotas[i].fechaEsperada, esperado.cuotas[i].fechaEsperada);
    }
  });

  test('listarPorCliente devuelve solo los préstamos de ese cliente', () async {
    final cliente1 = await crearClientePrueba();
    final cliente2 = await clientesRepository.crear(
      nombre: 'Maria Gomez',
      cedula: '654321',
      telefono: '3009999999',
      direccion: 'Otra direccion',
    );

    await prestamosRepository.crear(
      clienteId: cliente1,
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );
    await prestamosRepository.crear(
      clienteId: cliente2,
      montoCapital: 20000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );

    final prestamosCliente1 = await prestamosRepository.listarPorCliente(cliente1);

    expect(prestamosCliente1, hasLength(1));
    expect(prestamosCliente1.first.montoCapital, 10000);
  });
}
