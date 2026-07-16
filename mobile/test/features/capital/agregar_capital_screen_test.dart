import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:cobro_app/features/capital/presentation/agregar_capital_screen.dart';
import 'package:cobro_app/features/dashboard/data/dashboard_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
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
  late CargasCapitalRepository cargasCapitalRepository;
  late DashboardRepository dashboardRepository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    final secureStorage = _SecureStorageFalso();
    cargasCapitalRepository = CargasCapitalRepository(database: db, secureStorage: secureStorage);
    dashboardRepository = DashboardRepository(
      prestamosRepository: PrestamosRepository(database: db, secureStorage: secureStorage),
      pagosRepository: PagosRepository(database: db, secureStorage: secureStorage),
      cargasCapitalRepository: cargasCapitalRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('un retiro que excede el saldo disponible muestra error y no se guarda', (tester) async {
    await cargasCapitalRepository.crear(monto: 50000, tipo: 'carga');

    await tester.pumpWidget(
      MaterialApp(
        home: AgregarCapitalScreen(repository: cargasCapitalRepository, dashboardRepository: dashboardRepository),
      ),
    );

    await tester.tap(find.text('Retiro'));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar retiro'));
    await tester.pumpAndSettle();

    expect(find.textContaining('excede el saldo disponible'), findsOneWidget);

    final movimientos = await cargasCapitalRepository.listarTodas();
    expect(movimientos, hasLength(1));
    expect(movimientos.first.tipo, 'carga');
  });
}
