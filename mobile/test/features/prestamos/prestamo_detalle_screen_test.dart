import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
import 'package:cobro_app/features/prestamos/presentation/prestamo_detalle_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

void main() {
  late AppDatabase db;
  late PrestamosRepository prestamosRepository;
  late PagosRepository pagosRepository;

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    final clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
    pagosRepository = PagosRepository(
      database: db,
      secureStorage: secureStorage,
      prestamosRepository: prestamosRepository,
    );

    final clienteId = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '123456',
      telefono: '3001234567',
      direccion: 'Calle 1 # 2-3',
    );

    await prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 30000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 3,
      fechaInicio: DateTime(2026, 1, 1),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('muestra la fecha de pago real de una cuota pagada y el excedente cobro_extra', (tester) async {
    final prestamos = await prestamosRepository.listarTodos();
    final prestamoId = prestamos.first.id;
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);
    final cuota1 = detalle.cuotas.firstWhere((c) => c.numeroCuota == 1);
    final cuota2 = detalle.cuotas.firstWhere((c) => c.numeroCuota == 2);

    // Cuota 1: pago exacto, pagada en su fecha esperada.
    await pagosRepository.registrar(prestamoId: prestamoId, montoAbonado: 10000, fechaPago: cuota1.fechaEsperada);

    // Cuota 2: excedente de 5000 registrado como cobro_extra (no reduce deuda).
    await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 15000,
      fechaPago: cuota2.fechaEsperada,
      manejoExcedente: 'cobro_extra',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrestamoDetalleScreen(prestamoId: prestamoId, repository: prestamosRepository, pagosRepository: pagosRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pagada: 02/01/2026'), findsOneWidget);
    expect(find.textContaining('Extra cobrado'), findsOneWidget);
    expect(find.textContaining('\$ 5.000'), findsOneWidget);
  });
}
