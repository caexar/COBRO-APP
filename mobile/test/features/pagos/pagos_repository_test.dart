import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
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

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
    pagosRepository = PagosRepository(database: db, prestamosRepository: prestamosRepository);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> crearPrestamoPrueba({String politicaMora = 'mantener'}) async {
    final clienteId = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '123456',
      telefono: '3001234567',
      direccion: 'Calle 1 # 2-3',
    );

    return prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 30000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 3,
      fechaInicio: DateTime(2026, 1, 1),
      politicaMora: politicaMora,
    );
  }

  test('pago exacto marca la cuota pagada, guarda el pago y lo encola', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);
    final primeraCuota = detalle.cuotas.first;

    final pagos = await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 10000,
      fechaPago: primeraCuota.fechaEsperada,
    );

    expect(pagos, hasLength(1));
    expect(pagos.first.montoAplicado, 10000);
    expect(pagos.first.saldoRestanteDespues, 20000);

    final detalleActualizado = await prestamosRepository.obtenerDetalle(prestamoId);
    expect(detalleActualizado.cuotas.first.estado, 'pagada');
    expect(detalleActualizado.prestamo.estado, 'activo');

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
    final cambioPago = pendientes.where((p) => p.tabla == 'pagos');
    expect(cambioPago, hasLength(1));
    expect(cambioPago.first.tipoOperacion, 'crear');
  });

  test('sin política ante un faltante, lanza PoliticaMoraRequeridaException y no escribe nada', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    await expectLater(
      pagosRepository.registrar(
        prestamoId: prestamoId,
        montoAbonado: 6000,
        fechaPago: detalle.cuotas.first.fechaEsperada,
      ),
      throwsA(isA<PoliticaMoraRequeridaException>()),
    );

    final pagos = await pagosRepository.listarPorPrestamo(prestamoId);
    expect(pagos, isEmpty);
  });

  test('sin manejo ante un excedente, lanza ManejoExcedenteRequeridoException y no escribe nada', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    await expectLater(
      pagosRepository.registrar(
        prestamoId: prestamoId,
        montoAbonado: 15000,
        fechaPago: detalle.cuotas.first.fechaEsperada,
      ),
      throwsA(isA<ManejoExcedenteRequeridoException>()),
    );

    final pagos = await pagosRepository.listarPorPrestamo(prestamoId);
    expect(pagos, isEmpty);
  });

  test(
    'al elegir una política distinta a la del préstamo para un faltante, actualiza el préstamo y lo re-encola',
    () async {
      final prestamoId = await crearPrestamoPrueba(politicaMora: 'mantener');
      final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

      await pagosRepository.registrar(
        prestamoId: prestamoId,
        montoAbonado: 6000,
        fechaPago: detalle.cuotas.first.fechaEsperada,
        politicaMora: 'siguiente_pago',
      );

      final detalleActualizado = await prestamosRepository.obtenerDetalle(prestamoId);
      expect(detalleActualizado.prestamo.politicaMora, 'siguiente_pago');
      expect(detalleActualizado.prestamo.sincronizado, isFalse);
      // Cuota 1 pagada (aunque incompleta, por siguiente_pago), cuota 2 con el faltante sumado.
      expect(detalleActualizado.cuotas[0].estado, 'pagada');
      expect(detalleActualizado.cuotas[1].montoEsperado, 14000);

      final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
      final cambioPrestamo = pendientes.where((p) => p.tabla == 'prestamos' && p.tipoOperacion == 'actualizar');
      expect(cambioPrestamo, hasLength(1));
      expect(cambioPrestamo.first.registroId, prestamoId);
    },
  );

  test('deja el préstamo en pagado cuando la última cuota queda cubierta', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    for (final cuota in detalle.cuotas) {
      await pagosRepository.registrar(prestamoId: prestamoId, montoAbonado: 10000, fechaPago: cuota.fechaEsperada);
    }

    final detalleFinal = await prestamosRepository.obtenerDetalle(prestamoId);
    expect(detalleFinal.prestamo.estado, 'pagado');
    expect(detalleFinal.cuotas.every((c) => c.estado == 'pagada'), isTrue);
  });

  test('un excedente con abono_deuda genera varios pagos locales pero un solo cambio pendiente', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    final pagos = await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 25000,
      fechaPago: detalle.cuotas.first.fechaEsperada,
      manejoExcedente: 'abono_deuda',
    );

    expect(pagos, hasLength(3));

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
    expect(pendientes.where((p) => p.tabla == 'pagos'), hasLength(1));
  });

  test('listarPorPrestamo devuelve los pagos ordenados por fecha', () async {
    final prestamoId = await crearPrestamoPrueba();
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);

    await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 10000,
      fechaPago: detalle.cuotas[0].fechaEsperada,
    );
    await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 10000,
      fechaPago: detalle.cuotas[1].fechaEsperada,
    );

    final pagos = await pagosRepository.listarPorPrestamo(prestamoId);
    expect(pagos, hasLength(2));
    expect(pagos[0].fechaPago.isBefore(pagos[1].fechaPago), isTrue);
  });
}
