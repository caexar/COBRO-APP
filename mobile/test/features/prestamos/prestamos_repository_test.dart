import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
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
    expect(detalle.prestamo.referencia, isNull);

    expect(detalle.montoInteres, 20000);
    expect(detalle.montoExtras, 5000);
    expect(detalle.montoTotal, 125000);

    expect(detalle.extras, hasLength(1));
    expect(detalle.extras.first.concepto, 'papeleria');

    expect(detalle.cuotas, hasLength(10));
    expect(detalle.cuotas.every((c) => c.montoEsperado == 12500), isTrue);
    expect(detalle.cuotas.every((c) => c.estado == 'pendiente'), isTrue);
    expect(detalle.cuotas.first.fechaEsperada, DateTime(2026, 7, 11));

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    // 1 del cliente creado + 1 del préstamo creado.
    expect(pendientes.where((p) => p.tabla == 'prestamos' && p.tipoOperacion == 'crear'), hasLength(1));
    expect(pendientes.firstWhere((p) => p.tabla == 'prestamos').registroId, prestamoId);
  });

  test('guarda la referencia opcional y la incluye en el payload encolado', () async {
    final clienteId = await crearClientePrueba();

    final prestamoId = await prestamosRepository.crear(
      clienteId: clienteId,
      referencia: 'Préstamo moto',
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );

    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);
    expect(detalle.prestamo.referencia, 'Préstamo moto');

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    final cambioPrestamo = pendientes.firstWhere((p) => p.tabla == 'prestamos' && p.registroId == prestamoId);
    expect(cambioPrestamo.payload, contains('Préstamo moto'));
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

  group('listarPendientes', () {
    test('incluye préstamos activos y en mora, excluye los ya pagados', () async {
      final cliente1 = await crearClientePrueba();
      final cliente2 = await clientesRepository.crear(
        nombre: 'Maria Gomez',
        cedula: '654321',
        telefono: '3009999999',
        direccion: 'Otra direccion',
      );

      // Préstamo activo (queda pendiente).
      await prestamosRepository.crear(
        clienteId: cliente1,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 2,
        fechaInicio: DateTime(2026, 1, 1),
      );

      // Préstamo que se paga por completo: no debe aparecer en la lista.
      final prestamoPagadoId = await prestamosRepository.crear(
        clienteId: cliente2,
        montoCapital: 5000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 1,
        fechaInicio: DateTime(2026, 1, 1),
      );
      await pagosRepository.registrar(
        prestamoId: prestamoPagadoId,
        montoAbonado: 5000,
        fechaPago: DateTime(2026, 1, 2),
      );

      final pendientes = await prestamosRepository.listarPendientes();

      expect(pendientes, hasLength(1));
      expect(pendientes.first.cliente.nombre, 'Juan Perez');
      expect(pendientes.first.saldoPendiente, 10000);
      expect(pendientes.first.enMora, isFalse);
    });

    test('marca enMora cuando el préstamo quedó en mora tras un pago incompleto', () async {
      final clienteId = await crearClientePrueba();
      final prestamoId = await prestamosRepository.crear(
        clienteId: clienteId,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 1,
        fechaInicio: DateTime(2026, 1, 1),
        politicaMora: 'mantener',
      );

      // Pago tardío e incompleto: con política "mantener" la cuota queda en_mora.
      await pagosRepository.registrar(
        prestamoId: prestamoId,
        montoAbonado: 4000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'mantener',
      );

      final pendientes = await prestamosRepository.listarPendientes();

      expect(pendientes, hasLength(1));
      expect(pendientes.first.enMora, isTrue);
      expect(pendientes.first.saldoPendiente, 6000);
    });

    test('busqueda filtra por nombre o cédula igual que ClientesRepository.buscar', () async {
      final cliente1 = await crearClientePrueba(); // Juan Perez, cédula 123456
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

      final porNombre = await prestamosRepository.listarPendientes(busqueda: 'Maria');
      expect(porNombre, hasLength(1));
      expect(porNombre.first.cliente.nombre, 'Maria Gomez');

      final porCedula = await prestamosRepository.listarPendientes(busqueda: '123456');
      expect(porCedula, hasLength(1));
      expect(porCedula.first.cliente.nombre, 'Juan Perez');
    });
  });

  group('listarPagados', () {
    test('incluye solo préstamos ya pagados por completo, con el total pagado', () async {
      final cliente1 = await crearClientePrueba();
      final cliente2 = await clientesRepository.crear(
        nombre: 'Maria Gomez',
        cedula: '654321',
        telefono: '3009999999',
        direccion: 'Otra direccion',
      );

      // Préstamo activo: no debe aparecer en el historial de pagados.
      await prestamosRepository.crear(
        clienteId: cliente1,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 2,
        fechaInicio: DateTime(2026, 1, 1),
      );

      // Préstamo pagado por completo: sí debe aparecer.
      final prestamoPagadoId = await prestamosRepository.crear(
        clienteId: cliente2,
        montoCapital: 5000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 1,
        fechaInicio: DateTime(2026, 1, 1),
      );
      await pagosRepository.registrar(
        prestamoId: prestamoPagadoId,
        montoAbonado: 5000,
        fechaPago: DateTime(2026, 1, 2),
      );

      final pagados = await prestamosRepository.listarPagados();

      expect(pagados, hasLength(1));
      expect(pagados.first.cliente.nombre, 'Maria Gomez');
      expect(pagados.first.totalPagado, 5000);
      expect(pagados.first.saldoPendiente, 0);
    });

    test('busqueda filtra por nombre o cédula igual que listarPendientes', () async {
      final cliente1 = await crearClientePrueba(); // Juan Perez, cédula 123456
      final prestamoId = await prestamosRepository.crear(
        clienteId: cliente1,
        montoCapital: 5000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 1,
        fechaInicio: DateTime(2026, 1, 1),
      );
      await pagosRepository.registrar(prestamoId: prestamoId, montoAbonado: 5000, fechaPago: DateTime(2026, 1, 2));

      final porNombre = await prestamosRepository.listarPagados(busqueda: 'Maria');
      expect(porNombre, isEmpty);

      final porCedula = await prestamosRepository.listarPagados(busqueda: '123456');
      expect(porCedula, hasLength(1));
      expect(porCedula.first.cliente.nombre, 'Juan Perez');
    });
  });

  group('orden de listarPendientes', () {
    // Fechas de inicio y nombres deliberadamente "cruzados" (ninguno de los 3
    // criterios de orden coincide con otro por casualidad), para que cada
    // test distinga realmente el criterio que dice probar:
    // - Andres: alfabéticamente primero, pero el préstamo más antiguo.
    // - Carla: alfabéticamente último, préstamo con fecha intermedia.
    // - Beatriz: alfabéticamente en el medio, préstamo más reciente.
    Future<void> crearTresPrestamos() async {
      final andres = await clientesRepository.crear(
        nombre: 'Andres Lopez',
        cedula: '111111',
        telefono: '3001111111',
        direccion: 'Calle 1',
      );
      final beatriz = await clientesRepository.crear(
        nombre: 'Beatriz Ruiz',
        cedula: '222222',
        telefono: '3002222222',
        direccion: 'Calle 2',
      );
      final carla = await clientesRepository.crear(
        nombre: 'Carla Diaz',
        cedula: '333333',
        telefono: '3003333333',
        direccion: 'Calle 3',
      );

      await prestamosRepository.crear(
        clienteId: andres,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 2,
        fechaInicio: DateTime(2026, 1, 1),
      );
      await prestamosRepository.crear(
        clienteId: carla,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 2,
        fechaInicio: DateTime(2026, 1, 10),
      );
      await prestamosRepository.crear(
        clienteId: beatriz,
        montoCapital: 10000,
        porcentajeInteres: 0,
        frecuenciaPago: 'diario',
        plazoCuotas: 2,
        fechaInicio: DateTime(2026, 1, 20),
      );
    }

    test('alfabetico (default) ordena por nombre del cliente', () async {
      await crearTresPrestamos();

      final resultado = await prestamosRepository.listarPendientes();

      expect(resultado.map((r) => r.cliente.nombre).toList(), ['Andres Lopez', 'Beatriz Ruiz', 'Carla Diaz']);
    });

    test('masAntiguoPrimero ordena por fecha_inicio ascendente', () async {
      await crearTresPrestamos();

      final resultado = await prestamosRepository.listarPendientes(orden: OrdenPrestamos.masAntiguoPrimero);

      expect(resultado.map((r) => r.cliente.nombre).toList(), ['Andres Lopez', 'Carla Diaz', 'Beatriz Ruiz']);
    });

    test('masRecientePrimero ordena por fecha_inicio descendente', () async {
      await crearTresPrestamos();

      final resultado = await prestamosRepository.listarPendientes(orden: OrdenPrestamos.masRecientePrimero);

      expect(resultado.map((r) => r.cliente.nombre).toList(), ['Beatriz Ruiz', 'Carla Diaz', 'Andres Lopez']);
    });
  });
}
