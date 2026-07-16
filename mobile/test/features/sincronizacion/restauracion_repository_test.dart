import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/sincronizacion/data/restauracion_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<int?> leerUsuarioId() async => 1;

  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

Map<String, dynamic> _payloadRestaurar() {
  return {
    'data': {
      'clientes': [
        {
          'id': 900,
          'nombre': 'Juan Perez',
          'cedula': '123456',
          'telefono': '3001234567',
          'direccion': 'Calle 1',
          'referencia': null,
          'foto_url': null,
          'uuid_local': 'c-1',
          'created_at': '2026-01-01T00:00:00.000000Z',
          'updated_at': '2026-01-01T00:00:00.000000Z',
        },
      ],
      'prestamos': [
        {
          'id': 800,
          'cliente_id': 900,
          'referencia': 'Préstamo moto',
          // Los decimales llegan como string desde el backend (cast
          // `decimal:N` de Eloquent), no como número — el fixture lo refleja
          // así a propósito para cubrir ese caso.
          'monto_capital': '100000.00',
          'porcentaje_interes': '20.00',
          'frecuencia_pago': 'diario',
          'dias_personalizado': null,
          'plazo_cuotas': 2,
          'fecha_inicio': '2026-01-01',
          'estado': 'activo',
          'politica_mora': 'mantener',
          'uuid_local': 'p-1',
          'created_at': '2026-01-01T00:00:00.000000Z',
          'updated_at': '2026-01-01T00:00:00.000000Z',
          'extras': [
            {'id': 700, 'concepto': 'papeleria', 'valor': '5000.00'},
          ],
          'cuotas': [
            {'id': 600, 'numero_cuota': 1, 'fecha_esperada': '2026-01-02', 'monto_esperado': '62500.00', 'estado': 'pagada'},
            {'id': 601, 'numero_cuota': 2, 'fecha_esperada': '2026-01-03', 'monto_esperado': '62500.00', 'estado': 'pendiente'},
          ],
        },
      ],
      'pagos': [
        {
          'id': 500,
          'prestamo_id': 800,
          'cuota_id': 600,
          'monto_abonado': '62500.00',
          'monto_aplicado': '62500.00',
          'fecha_pago': '2026-01-02',
          'dias_mora': 0,
          'saldo_restante_despues': '62500.00',
          'uuid_local': 'pg-1',
          'created_at': '2026-01-02T00:00:00.000000Z',
          'updated_at': '2026-01-02T00:00:00.000000Z',
        },
      ],
      'cargas_capital': [
        {
          'id': 400,
          'tipo': 'carga',
          'monto': '200000.00',
          'descripcion': 'Aporte inicial',
          'origen': 'cobrador',
          'creado_por_usuario_id': null,
          'uuid_local': 'cc-1',
          'created_at': '2026-01-01T00:00:00.000000Z',
        },
        {
          'id': 401,
          'tipo': 'carga',
          'monto': '50000.00',
          'descripcion': null,
          'origen': 'admin',
          'creado_por_usuario_id': 1,
          'uuid_local': null,
          'created_at': '2026-01-03T00:00:00.000000Z',
        },
      ],
    },
  };
}

void main() {
  late AppDatabase db;
  late RestauracionRepository repository;
  var llamadas = 0;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    llamadas = 0;

    final mock = MockClient((request) async {
      llamadas++;
      expect(request.url.path, '/api/restaurar');
      return http.Response(jsonEncode(_payloadRestaurar()), 200, headers: {'content-type': 'application/json'});
    });

    repository = RestauracionRepository(
      database: db,
      secureStorage: _SecureStorageFalso(),
      apiClient: ApiClient(httpClient: mock),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('hayDatosLocales es false antes de restaurar y true después', () async {
    expect(await repository.hayDatosLocales(), isFalse);

    await repository.restaurar();

    expect(await repository.hayDatosLocales(), isTrue);
  });

  test('restaurar inserta todo ya sincronizado, sin encolar cambios_pendientes', () async {
    final resultado = await repository.restaurar();

    expect(resultado.exitosa, isTrue);
    expect(resultado.clientes, 1);
    expect(resultado.prestamos, 1);
    expect(resultado.pagos, 1);
    expect(resultado.cargasCapital, 2);

    final clientes = await db.clientesDao.obtenerTodos(1);
    expect(clientes, hasLength(1));
    expect(clientes.first.uuidLocal, 'c-1');
    expect(clientes.first.servidorId, 900);
    expect(clientes.first.sincronizado, isTrue);

    final prestamos = await db.prestamosDao.obtenerTodos(1);
    expect(prestamos, hasLength(1));
    expect(prestamos.first.sincronizado, isTrue);
    expect(prestamos.first.clienteId, clientes.first.id);

    final cuotas = await db.cuotasDao.obtenerPorPrestamo(prestamos.first.id);
    expect(cuotas, hasLength(2));
    expect(cuotas.first.estado, 'pagada');

    final extras = await db.prestamosExtrasDao.obtenerPorPrestamo(prestamos.first.id);
    expect(extras, hasLength(1));

    final pagos = await db.pagosDao.obtenerPorPrestamo(prestamos.first.id);
    expect(pagos, hasLength(1));
    expect(pagos.first.sincronizado, isTrue);
    expect(pagos.first.cuotaId, cuotas.first.id);

    final cargas = await db.cargasCapitalDao.obtenerTodas(1);
    expect(cargas, hasLength(2));
    expect(cargas.every((c) => c.sincronizado), isTrue);

    // Nada de lo restaurado debe quedar encolado para subir: ya está
    // sincronizado en el servidor, no es un cambio local pendiente.
    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientes, isEmpty);
  });

  test('reintentar restaurar tras un corte a mitad de camino no duplica nada', () async {
    await repository.restaurar();
    // Segundo intento (ej. el usuario reintentó tras perder la conexión a mitad de camino):
    // el mismo payload no debe volver a insertar los mismos registros.
    final resultado = await repository.restaurar();

    expect(llamadas, 2);
    expect(resultado.clientes, 0);
    expect(resultado.prestamos, 0);
    expect(resultado.pagos, 0);
    expect(resultado.cargasCapital, 0);

    expect(await db.clientesDao.obtenerTodos(1), hasLength(1));
    expect(await db.prestamosDao.obtenerTodos(1), hasLength(1));
    expect(await db.cargasCapitalDao.obtenerTodas(1), hasLength(2));

    final prestamos = await db.prestamosDao.obtenerTodos(1);
    expect(await db.cuotasDao.obtenerPorPrestamo(prestamos.first.id), hasLength(2));
    expect(await db.prestamosExtrasDao.obtenerPorPrestamo(prestamos.first.id), hasLength(1));
    expect(await db.pagosDao.obtenerPorPrestamo(prestamos.first.id), hasLength(1));
  });
}
