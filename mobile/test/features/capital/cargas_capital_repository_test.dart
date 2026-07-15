import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

void main() {
  late AppDatabase db;
  late CargasCapitalRepository repository;

  setUp(() async {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    repository = CargasCapitalRepository(database: db, secureStorage: _SecureStorageFalso());
  });

  tearDown(() async {
    await db.close();
  });

  test('crea una carga de capital y la encola en cambios_pendientes', () async {
    final id = await repository.crear(monto: 500000, descripcion: 'Aporte inicial');

    final todas = await repository.listarTodas();
    expect(todas, hasLength(1));
    expect(todas.first.id, id);
    expect(todas.first.monto, 500000);
    expect(todas.first.descripcion, 'Aporte inicial');
    expect(todas.first.usuarioId, 1);
    expect(todas.first.sincronizado, isFalse);

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientes.where((p) => p.tabla == 'cargas_capital'), hasLength(1));
    expect(pendientes.first.registroId, id);
    expect(pendientes.first.payload, contains('Aporte inicial'));
  });

  test('permite registrar varias cargas de capital y las lista ordenadas', () async {
    await repository.crear(monto: 100000);
    await repository.crear(monto: 200000, descripcion: 'Segundo aporte');

    final todas = await repository.listarTodas();
    expect(todas, hasLength(2));
    expect(todas.map((c) => c.monto), [100000, 200000]);
  });

  test('descripcion es opcional', () async {
    await repository.crear(monto: 50000);

    final todas = await repository.listarTodas();
    expect(todas.first.descripcion, isNull);
  });

  test('tipo por defecto es carga', () async {
    await repository.crear(monto: 50000);

    final todas = await repository.listarTodas();
    expect(todas.first.tipo, 'carga');
  });

  test('permite registrar un retiro y lo encola en cambios_pendientes', () async {
    await repository.crear(monto: 30000, descripcion: 'Retiro para gastos', tipo: 'retiro');

    final todas = await repository.listarTodas();
    expect(todas, hasLength(1));
    expect(todas.first.tipo, 'retiro');
    expect(todas.first.monto, 30000);

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientes.first.payload, contains('retiro'));
  });

  test('eliminar hace soft-delete y no aparece más en listarTodas', () async {
    final id = await repository.crear(monto: 100000);

    await repository.eliminar(id);

    final todas = await repository.listarTodas();
    expect(todas, isEmpty);

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientes.where((p) => p.tipoOperacion == 'eliminar'), hasLength(1));
  });

  test('eliminar un movimiento no afecta a los demás', () async {
    final id1 = await repository.crear(monto: 100000, descripcion: 'Primero');
    await repository.crear(monto: 200000, descripcion: 'Segundo');

    await repository.eliminar(id1);

    final todas = await repository.listarTodas();
    expect(todas, hasLength(1));
    expect(todas.first.descripcion, 'Segundo');
  });
}
