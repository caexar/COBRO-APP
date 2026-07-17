import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:cobro_app/features/capital/presentation/historial_capital_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

void main() {
  late AppDatabase db;
  late CargasCapitalRepository repository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    repository = CargasCapitalRepository(database: db, secureStorage: _SecureStorageFalso());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('no muestra ningún botón de eliminar, ni para movimientos propios ni de origen admin', (tester) async {
    await repository.crear(monto: 50000, tipo: 'carga', descripcion: 'Aporte propio');
    await repository.guardarDescargadaDeAdmin(servidorId: 1, tipo: 'carga', monto: 20000, descripcion: 'Asignado');

    await tester.pumpWidget(MaterialApp(home: HistorialCapitalScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    // Confirma que sí se cargaron ambos movimientos (no es una lista vacía).
    expect(find.text('Asignado por administrador'), findsOneWidget);
  });
}
