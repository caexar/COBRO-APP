import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cierres_caja_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

void main() {
  late AppDatabase db;
  late CierresCajaRepository repository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    repository = CierresCajaRepository(database: db, secureStorage: _SecureStorageFalso());
  });

  tearDown(() async {
    await db.close();
  });

  test('crea un cierre con justificación y gastos, deriva gastos_total y encola un solo cambio pendiente', () async {
    final fecha = DateTime(2026, 7, 21);

    final id = await repository.crear(
      fecha: fecha,
      capitalInicio: 100000,
      capitalCierre: 150000,
      justificacionDiferencia: 'Se contó mal el efectivo inicial',
      gastos: const [
        GastoCierreCaja(monto: 10000, detalle: 'almuerzo'),
        GastoCierreCaja(monto: 25000, detalle: 'gasolina'),
      ],
    );

    final todos = await repository.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.first.id, id);
    expect(todos.first.capitalInicio, 100000);
    expect(todos.first.capitalCierre, 150000);
    expect(todos.first.justificacionDiferencia, 'Se contó mal el efectivo inicial');
    // gastos_total se deriva de la suma de los gastos, no es un valor aparte.
    expect(todos.first.gastosTotal, 35000);
    expect(todos.first.sincronizado, isFalse);
    expect(todos.first.uuidLocal, isNotNull);

    final gastos = await repository.obtenerGastos(id);
    expect(gastos, hasLength(2));
    expect(gastos.map((g) => g.detalle), containsAll(['almuerzo', 'gasolina']));

    // Un solo cambio pendiente para el cierre, no uno por gasto (mismo patrón que
    // PrestamosRepository.crear() con sus extras).
    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    final pendientesCierre = pendientes.where((p) => p.tabla == 'cierres_caja');
    expect(pendientesCierre, hasLength(1));
    expect(pendientesCierre.first.registroId, id);
    expect(pendientesCierre.first.payload, contains('almuerzo'));
  });

  test('permite crear un cierre sin gastos ni justificación, gastos_total queda en 0', () async {
    final id = await repository.crear(
      fecha: DateTime(2026, 7, 21),
      capitalInicio: 100000,
      capitalCierre: 100000,
    );

    final todos = await repository.listarTodos();
    expect(todos.first.id, id);
    expect(todos.first.gastosTotal, 0);
    expect(todos.first.justificacionDiferencia, isNull);

    final gastos = await repository.obtenerGastos(id);
    expect(gastos, isEmpty);
  });

  test('listarTodos ordena del más reciente al más antiguo por fecha', () async {
    await repository.crear(fecha: DateTime(2026, 7, 1), capitalInicio: 1000, capitalCierre: 1000);
    await repository.crear(fecha: DateTime(2026, 7, 10), capitalInicio: 2000, capitalCierre: 2000);

    final todos = await repository.listarTodos();
    expect(todos.map((c) => c.fecha), [DateTime(2026, 7, 10), DateTime(2026, 7, 1)]);
  });
}
