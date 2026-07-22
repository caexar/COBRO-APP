import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
import 'package:cobro_app/features/rutas/data/rutas_repository.dart';
import 'package:cobro_app/features/rutas/presentation/ruta_detalle_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;

  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

void main() {
  late AppDatabase db;
  late ClientesRepository clientesRepository;
  late PrestamosRepository prestamosRepository;
  late RutasRepository rutasRepository;

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
    rutasRepository = RutasRepository(database: db, secureStorage: secureStorage);
  });

  tearDown(() async {
    await db.close();
  });

  /// El pedido explícitamente decía "confirma que esto ya funciona" para agregar/quitar
  /// ítems sobre una ruta ya generada — al revisar el código, "quitar" NO estaba conectado:
  /// `RutasRepository.quitarPrestamo()` existía pero ningún botón lo llamaba. Este test cubre
  /// el arreglo (menú de tres puntos -> "Quitar de la ruta").
  testWidgets('quitar un préstamo desde el menú de tres puntos lo saca de la ruta', (tester) async {
    final clienteId = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '123456',
      telefono: '3001234567',
      direccion: 'Calle 1',
    );
    final prestamoId = await prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 1,
      fechaInicio: DateTime(2026, 1, 1),
    );
    final rutaId = await rutasRepository.crear(nombre: 'Ruta de prueba');
    await rutasRepository.agregarPrestamo(rutaId: rutaId, prestamoId: prestamoId);

    await tester.pumpWidget(
      MaterialApp(
        home: RutaDetalleScreen(rutaId: rutaId, repository: rutasRepository, prestamosRepository: prestamosRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Perez'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la ruta'));
    await tester.pumpAndSettle();

    // Diálogo de confirmación.
    expect(find.text('¿Quitar a Juan Perez de esta ruta?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Juan Perez'), findsNothing);
    expect(await rutasRepository.listarItems(rutaId), isEmpty);
  });
}
