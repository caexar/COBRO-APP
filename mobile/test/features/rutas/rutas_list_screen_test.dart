import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/rutas/data/rutas_repository.dart';
import 'package:cobro_app/features/rutas/presentation/rutas_list_screen.dart';
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
  late RutasRepository rutasRepository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    rutasRepository = RutasRepository(database: db, secureStorage: _SecureStorageFalso());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('autogenerar ruta por día queda deshabilitado y con aviso claro sin conexión', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RutasListScreen(repository: rutasRepository, verificarConexion: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final opcionAutogenerar = tester.widget<ListTile>(
      find.ancestor(of: find.text('Autogenerar ruta por día'), matching: find.byType(ListTile)),
    );

    expect(opcionAutogenerar.enabled, isFalse);
    expect(find.textContaining('Requiere conexión'), findsOneWidget);

    // "Crear ruta manual" sí debe seguir disponible sin conexión.
    final opcionManual = tester.widget<ListTile>(
      find.ancestor(of: find.text('Crear ruta manual'), matching: find.byType(ListTile)),
    );
    expect(opcionManual.enabled, isTrue);
  });

  testWidgets('autogenerar ruta por día queda habilitado con conexión', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RutasListScreen(repository: rutasRepository, verificarConexion: () async => true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final opcionAutogenerar = tester.widget<ListTile>(
      find.ancestor(of: find.text('Autogenerar ruta por día'), matching: find.byType(ListTile)),
    );
    expect(opcionAutogenerar.enabled, isTrue);
  });
}
