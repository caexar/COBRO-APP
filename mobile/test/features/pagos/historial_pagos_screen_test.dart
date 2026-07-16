import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
import 'package:cobro_app/features/pagos/presentation/historial_pagos_screen.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
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

  testWidgets('agrupa las filas de un mismo pago en un resumen corto expandible con el detalle por fila', (
    tester,
  ) async {
    final prestamos = await prestamosRepository.listarTodos();
    final prestamoId = prestamos.first.id;
    final detalle = await prestamosRepository.obtenerDetalle(prestamoId);
    final cuota1 = detalle.cuotas.firstWhere((c) => c.numeroCuota == 1);
    final cuota2 = detalle.cuotas.firstWhere((c) => c.numeroCuota == 2);
    final cuota3 = detalle.cuotas.firstWhere((c) => c.numeroCuota == 3);

    // Cuota 1: excedente registrado como cobro_extra -> un solo grupo "Cuota 1 + Extra".
    await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 15000,
      fechaPago: cuota1.fechaEsperada,
      manejoExcedente: 'cobro_extra',
    );

    // Cuota 2: excedente registrado como abono_deuda -> un grupo con 2 filas
    // ("Pago cuota 2" + cascada "Abono cuota 3"), resumen corto "Cuota 2, 3".
    await pagosRepository.registrar(
      prestamoId: prestamoId,
      montoAbonado: 13000,
      fechaPago: cuota2.fechaEsperada,
      manejoExcedente: 'abono_deuda',
    );

    // Cuota 3: le queda pendiente 10000 - 3000 = 7000 tras la cascada; se paga exacto,
    // en una fecha distinta -> grupo propio "Cuota 3".
    await pagosRepository.registrar(prestamoId: prestamoId, montoAbonado: 7000, fechaPago: cuota3.fechaEsperada);

    await tester.pumpWidget(
      MaterialApp(
        home: HistorialPagosScreen(prestamoId: prestamoId, repository: pagosRepository, prestamosRepository: prestamosRepository),
      ),
    );
    await tester.pumpAndSettle();

    // Resúmenes cortos colapsados, sin el detalle por fila todavía.
    expect(find.textContaining('Cuota 1 + Extra'), findsOneWidget);
    expect(find.textContaining('Cuota 2, 3'), findsOneWidget);
    expect(find.textContaining('Cuota 3 ·'), findsOneWidget);
    expect(find.text('Abono cuota 3'), findsNothing);

    // Expandir el grupo de la cascada revela el desglose por fila.
    await tester.tap(find.textContaining('Cuota 2, 3'));
    await tester.pumpAndSettle();

    expect(find.text('Pago cuota 2'), findsOneWidget);
    expect(find.text('Abono cuota 3'), findsOneWidget);
  });
}
