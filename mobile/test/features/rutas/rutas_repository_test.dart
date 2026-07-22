import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
import 'package:cobro_app/features/rutas/data/rutas_repository.dart';
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

  Future<int> crearPrestamoDePrueba() async {
    final clienteId = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '123456',
      telefono: '3001234567',
      direccion: 'Calle 1',
    );

    return prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 10000,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 1,
      fechaInicio: DateTime(2026, 1, 1),
    );
  }

  test('crea una ruta manual, le asigna el siguiente orden y la encola para sincronizar', () async {
    final primeraId = await rutasRepository.crear(nombre: 'Ruta A');
    final segundaId = await rutasRepository.crear(nombre: 'Ruta B', descripcion: 'Cobros de los lunes');

    final rutas = await rutasRepository.listar();
    expect(rutas, hasLength(2));

    final primera = rutas.firstWhere((r) => r.id == primeraId);
    final segunda = rutas.firstWhere((r) => r.id == segundaId);
    expect(primera.orden, 0);
    expect(segunda.orden, 1);
    expect(segunda.descripcion, 'Cobros de los lunes');
    expect(primera.uuidLocal, isNotNull);

    final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
    expect(pendientes.where((p) => p.tabla == 'rutas'), hasLength(2));
  });

  test('reordena la lista de rutas actualizando el orden local y re-encolando cada una', () async {
    final idA = await rutasRepository.crear(nombre: 'Ruta A');
    final idB = await rutasRepository.crear(nombre: 'Ruta B');
    final idC = await rutasRepository.crear(nombre: 'Ruta C');

    await rutasRepository.reordenar([idC, idA, idB]);

    final rutas = await rutasRepository.listar();
    expect(rutas.map((r) => r.id).toList(), [idC, idA, idB]);
    expect(rutas.map((r) => r.orden).toList(), [0, 1, 2]);
  });

  group('marcarCobradoSiPertenece', () {
    test('marca cobrado el ítem pendiente de esa ruta y ese préstamo, con cobradoEn', () async {
      final prestamoId = await crearPrestamoDePrueba();
      final rutaId = await rutasRepository.crear(nombre: 'Ruta del día');
      final itemId = await rutasRepository.agregarPrestamo(rutaId: rutaId, prestamoId: prestamoId);

      await rutasRepository.marcarCobradoSiPertenece(rutaId: rutaId, prestamoId: prestamoId);

      final items = await rutasRepository.listarItems(rutaId);
      final item = items.firstWhere((i) => i.id == itemId);
      expect(item.estado, 'cobrado');
      expect(item.cobradoEn, isNotNull);

      final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
      // 1 de la ruta + 1 de agregar el ítem + 1 de marcarlo cobrado.
      expect(pendientes.where((p) => p.tabla == 'ruta_items'), hasLength(2));
    });

    test('no hace nada si el préstamo no pertenece a esa ruta', () async {
      final prestamoId = await crearPrestamoDePrueba();
      final rutaConItem = await rutasRepository.crear(nombre: 'Ruta con el préstamo');
      final otraRuta = await rutasRepository.crear(nombre: 'Otra ruta');
      final itemId = await rutasRepository.agregarPrestamo(rutaId: rutaConItem, prestamoId: prestamoId);

      // El préstamo no está en "otraRuta": no debe afectar nada.
      await rutasRepository.marcarCobradoSiPertenece(rutaId: otraRuta, prestamoId: prestamoId);

      final items = await rutasRepository.listarItems(rutaConItem);
      expect(items.firstWhere((i) => i.id == itemId).estado, 'pendiente');
    });

    test('es idempotente: llamarlo de nuevo sobre un ítem ya cobrado no falla ni lo reescribe', () async {
      final prestamoId = await crearPrestamoDePrueba();
      final rutaId = await rutasRepository.crear(nombre: 'Ruta del día');
      await rutasRepository.agregarPrestamo(rutaId: rutaId, prestamoId: prestamoId);

      await rutasRepository.marcarCobradoSiPertenece(rutaId: rutaId, prestamoId: prestamoId);
      final items = await rutasRepository.listarItems(rutaId);
      final cobradoEnPrimeraVez = items.first.cobradoEn;

      // Simula que se registró un segundo pago (abono parcial adicional) para el mismo préstamo.
      await rutasRepository.marcarCobradoSiPertenece(rutaId: rutaId, prestamoId: prestamoId);

      final itemsTrasSegundaLlamada = await rutasRepository.listarItems(rutaId);
      expect(itemsTrasSegundaLlamada.first.estado, 'cobrado');
      expect(itemsTrasSegundaLlamada.first.cobradoEn, cobradoEnPrimeraVez);
    });
  });

  group('autogenerarHoy', () {
    /// Bug real: la URL se armaba con un espacio de más ("…/api/ rutas/autogenerar-hoy"),
    /// así que el backend respondía 404 "route not found" — ver `ApiClient._uri`. Este test
    /// verifica la ruta HTTP exacta a la que pega `autogenerarHoy()`, no solo que "algo" pase.
    test('llama a POST /rutas/autogenerar-hoy sin espacios en la URL y guarda la ruta con sus items', () async {
      final prestamoId = await crearPrestamoDePrueba();
      await db.prestamosDao.marcarSincronizado(prestamoId, 55);

      Uri? urlPedida;
      final mock = MockClient((request) async {
        urlPedida = request.url;
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 9,
              'nombre': 'Ruta de hoy 2026-07-23',
              'descripcion': null,
              'fecha': '2026-07-23T00:00:00.000000Z',
              'incluye_vencidas': false,
              'orden': 0,
              'items': [
                {'id': 30, 'prestamo_id': 55, 'orden': 0, 'estado': 'pendiente'},
              ],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repositorioConMock = RutasRepository(
        database: db,
        secureStorage: _SecureStorageFalso(),
        apiClient: ApiClient(httpClient: mock, baseUrl: 'http://test/api'),
      );

      final rutaId = await repositorioConMock.autogenerarHoy();

      expect(urlPedida.toString(), 'http://test/api/rutas/autogenerar-hoy');
      expect(urlPedida.toString(), isNot(contains(' ')));

      final ruta = await repositorioConMock.obtenerPorId(rutaId);
      expect(ruta?.nombre, 'Ruta de hoy 2026-07-23');
      expect(ruta?.sincronizado, isTrue);
      expect(ruta?.incluyeVencidas, isFalse);
      // Bug real: el backend serializa `fecha` como "2026-07-23T00:00:00.000000Z" (con hora y
      // Z de UTC) aunque sea una fecha de calendario sin hora real — parsearlo con
      // `DateTime.parse` directo y guardarlo en Drift corría el día un día hacia atrás en
      // cualquier huso detrás de UTC (ver `comoFecha` en core/utils/json_fecha.dart).
      expect(ruta?.fecha, DateTime(2026, 7, 23));

      final items = await repositorioConMock.listarItems(rutaId);
      expect(items, hasLength(1));
      expect(items.first.prestamoId, prestamoId);
      expect(items.first.sincronizado, isTrue);
    });

    test('manda incluir_vencidas en el body y lo guarda en la ruta creada', () async {
      Map<String, dynamic>? cuerpoEnviado;
      final mock = MockClient((request) async {
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'id': 9,
              'nombre': 'Ruta de hoy 2026-07-22',
              'descripcion': null,
              'fecha': '2026-07-22T00:00:00.000000Z',
              'incluye_vencidas': true,
              'orden': 0,
              'items': <Map<String, dynamic>>[],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repositorioConMock = RutasRepository(
        database: db,
        secureStorage: _SecureStorageFalso(),
        apiClient: ApiClient(httpClient: mock, baseUrl: 'http://test/api'),
      );

      final rutaId = await repositorioConMock.autogenerarHoy(
        fecha: DateTime(2026, 7, 22),
        incluirVencidas: true,
      );

      expect(cuerpoEnviado, {'fecha': '2026-07-22', 'incluir_vencidas': true});

      final ruta = await repositorioConMock.obtenerPorId(rutaId);
      expect(ruta?.incluyeVencidas, isTrue);
    });
  });
}
