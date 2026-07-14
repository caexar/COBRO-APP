import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de prueba: evita tocar flutter_secure_storage (usa platform
/// channels no disponibles en `flutter test`) y simula un cobrador logueado
/// con id fijo.
class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;
}

void main() {
  late AppDatabase db;
  late ClientesRepository repository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    repository = ClientesRepository(database: db, secureStorage: _SecureStorageFalso());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> crearClienteBase({String nombre = 'Juan Perez', String cedula = '123456'}) {
    return repository.crear(
      nombre: nombre,
      cedula: cedula,
      telefono: '3001234567',
      direccion: 'Calle 1 # 2-3',
    );
  }

  test('crea un cliente y lo encola en cambios_pendientes', () async {
    final id = await crearClienteBase();

    final clientes = await repository.listar();
    expect(clientes, hasLength(1));
    expect(clientes.first.nombre, 'Juan Perez');
    expect(clientes.first.sincronizado, isFalse);

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
    expect(pendientes, hasLength(1));
    expect(pendientes.first.tabla, 'clientes');
    expect(pendientes.first.registroId, id);
    expect(pendientes.first.tipoOperacion, 'crear');
    expect(pendientes.first.payload, contains('Juan Perez'));
  });

  test('rechaza crear un cliente con el mismo nombre', () async {
    await crearClienteBase(nombre: 'Juan Perez', cedula: '111111');

    expect(
      () => crearClienteBase(nombre: 'Juan Perez', cedula: '999999'),
      throwsA(
        isA<ClienteDuplicadoException>()
            .having((e) => e.campo, 'campo', 'nombre')
            .having((e) => e.mensaje, 'mensaje', contains('nombre')),
      ),
    );

    // No debe haber quedado ningún rastro del segundo intento fallido.
    expect(await repository.listar(), hasLength(1));
  });

  test('rechaza crear un cliente con la misma cédula', () async {
    await crearClienteBase(nombre: 'Juan Perez', cedula: '123456');

    expect(
      () => crearClienteBase(nombre: 'Maria Gomez', cedula: '123456'),
      throwsA(
        isA<ClienteDuplicadoException>()
            .having((e) => e.campo, 'campo', 'cedula')
            .having((e) => e.mensaje, 'mensaje', contains('cédula')),
      ),
    );

    expect(await repository.listar(), hasLength(1));
  });

  test('permite editar el propio cliente sin que choque consigo mismo', () async {
    final id = await crearClienteBase(nombre: 'Juan Perez', cedula: '123456');

    await repository.actualizar(
      id: id,
      nombre: 'Juan Perez', // mismo nombre y cédula: no debe considerarse duplicado de sí mismo
      cedula: '123456',
      telefono: '3009999999',
      direccion: 'Nueva direccion',
    );

    final clientes = await repository.listar();
    expect(clientes.single.telefono, '3009999999');

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes();
    expect(pendientes.map((p) => p.tipoOperacion), containsAll(['crear', 'actualizar']));
  });

  test('busca por nombre (sin dígitos: no busca por cédula)', () async {
    await crearClienteBase(nombre: 'Juan Perez', cedula: '123456');
    await crearClienteBase(nombre: 'Maria Gomez', cedula: '654321');

    final resultado = await repository.buscar('Juan');

    expect(resultado, hasLength(1));
    expect(resultado.first.nombre, 'Juan Perez');
  });

  test('busca por cédula cuando el término tiene dígitos', () async {
    await crearClienteBase(nombre: 'Juan Perez', cedula: '123456');
    await crearClienteBase(nombre: 'Maria Gomez', cedula: '654321');

    final resultado = await repository.buscar('654321');

    expect(resultado, hasLength(1));
    expect(resultado.first.nombre, 'Maria Gomez');
  });

  test('combina nombre y cédula sin duplicar filas', () async {
    await crearClienteBase(nombre: 'Cliente 2024', cedula: '555555');
    await crearClienteBase(nombre: 'Otro Cliente', cedula: '2024999');

    // "2024" aparece en el nombre del primero y en la cédula del segundo.
    final resultado = await repository.buscar('2024');

    expect(resultado.map((c) => c.nombre), containsAll(['Cliente 2024', 'Otro Cliente']));
    expect(resultado, hasLength(2));
  });

  test('buscar con texto vacío devuelve todos los clientes', () async {
    await crearClienteBase(nombre: 'Juan Perez', cedula: '123456');
    await crearClienteBase(nombre: 'Maria Gomez', cedula: '654321');

    final resultado = await repository.buscar('');

    expect(resultado, hasLength(2));
  });
}
