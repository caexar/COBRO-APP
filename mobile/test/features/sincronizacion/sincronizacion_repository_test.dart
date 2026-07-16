import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/data/app_database.dart';
import 'package:cobro_app/features/capital/data/cargas_capital_repository.dart';
import 'package:cobro_app/features/clientes/data/clientes_repository.dart';
import 'package:cobro_app/features/pagos/data/pagos_repository.dart';
import 'package:cobro_app/features/prestamos/data/prestamos_repository.dart';
import 'package:cobro_app/features/sincronizacion/data/sincronizacion_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SecureStorageFalso extends SecureStorageService {
  DateTime? ultimaSincronizacion;
  List<double>? tasasGuardadas;
  int? intentosGuardados;

  @override
  Future<int?> leerUsuarioId() async => 1;

  @override
  Future<String?> leerToken() async => 'token-de-prueba';

  @override
  Future<void> guardarUltimaSincronizacion(int usuarioId, DateTime fecha) async {
    ultimaSincronizacion = fecha;
  }

  @override
  Future<DateTime?> leerUltimaSincronizacion(int usuarioId) async => ultimaSincronizacion;

  @override
  Future<void> guardarTasasInteresDefault(List<double> tasas) async {
    tasasGuardadas = tasas;
  }

  @override
  Future<void> guardarIntentosMaximosPin(int intentos) async {
    intentosGuardados = intentos;
  }
}

http.Response _json(Object cuerpo, {int status = 200}) {
  return http.Response(jsonEncode(cuerpo), status, headers: {'content-type': 'application/json'});
}

/// Respuesta de `/sync` que confirma ('creado') cada registro presente en
/// [cuerpoEnviado], con un id de servidor incremental, más las extras que se
/// quieran agregar aparte ([cargasCapitalAdmin], [configuracion]).
Map<String, dynamic> _respuestaConfirmandoTodo(
  Map<String, dynamic> cuerpoEnviado, {
  List<Map<String, dynamic>> cargasCapitalAdmin = const [],
  Map<String, dynamic>? configuracion,
}) {
  var siguienteId = 100;
  final data = <String, dynamic>{};

  for (final tabla in ['clientes', 'prestamos', 'pagos', 'cargas_capital']) {
    final items = (cuerpoEnviado[tabla] as List?) ?? const [];
    data[tabla] = [
      for (final item in items) {'uuid_local': item['uuid_local'], 'estado': 'creado', 'id': siguienteId++},
    ];
  }

  return {
    'data': data,
    'cargas_capital_admin': cargasCapitalAdmin,
    'configuracion':
        configuracion ??
        {
          'tasas_interes_default': [10, 20, 30, 40],
          'politica_mora_default': 'mantener',
          'pin_maestro_configurado': false,
          'intentos_pin_antes_de_maestro': 3,
        },
  };
}

void main() {
  late AppDatabase db;
  late _SecureStorageFalso secureStorage;
  late ClientesRepository clientesRepository;
  late PrestamosRepository prestamosRepository;
  late PagosRepository pagosRepository;
  late CargasCapitalRepository cargasCapitalRepository;

  setUp(() {
    db = AppDatabase.paraPruebas(NativeDatabase.memory());
    secureStorage = _SecureStorageFalso();
    clientesRepository = ClientesRepository(database: db, secureStorage: secureStorage);
    prestamosRepository = PrestamosRepository(database: db, secureStorage: secureStorage);
    pagosRepository = PagosRepository(database: db, secureStorage: secureStorage, prestamosRepository: prestamosRepository);
    cargasCapitalRepository = CargasCapitalRepository(database: db, secureStorage: secureStorage);
  });

  tearDown(() async {
    await db.close();
  });

  SincronizacionRepository construirRepositorio(http.Client httpClient) {
    return SincronizacionRepository(
      database: db,
      secureStorage: secureStorage,
      apiClient: ApiClient(httpClient: httpClient),
      cargasCapitalRepository: cargasCapitalRepository,
    );
  }

  /// Siembra un cliente, un préstamo (de ese cliente), un pago (de ese
  /// préstamo) y una carga de capital, todos pendientes de sincronizar.
  Future<void> sembrarPendientes() async {
    final clienteId = await clientesRepository.crear(
      nombre: 'Juan Perez',
      cedula: '111',
      telefono: '3000000001',
      direccion: 'Calle 1',
    );
    final prestamoId = await prestamosRepository.crear(
      clienteId: clienteId,
      montoCapital: 100000,
      porcentajeInteres: 20,
      frecuenciaPago: 'diario',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 7, 10),
    );
    final cuotas = (await prestamosRepository.obtenerDetalle(prestamoId)).cuotas;
    await pagosRepository.registrar(prestamoId: prestamoId, montoAbonado: 60000, fechaPago: cuotas[0].fechaEsperada);
    await cargasCapitalRepository.crear(monto: 500000, descripcion: 'Aporte inicial');
  }

  group('subida', () {
    test('sube clientes -> prestamos -> pagos y cargas_capital, y limpia cambios_pendientes al confirmarse', () async {
      await sembrarPendientes();

      Map<String, dynamic>? cuerpoEnviado;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/sync');
        expect(request.headers['Authorization'], 'Bearer token-de-prueba');
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_respuestaConfirmandoTodo(cuerpoEnviado!));
      });

      final resultado = await construirRepositorio(mock).sincronizar();

      expect(resultado.exitosa, isTrue);
      expect(resultado.confirmados, 4);

      // El préstamo referencia al cliente por uuid_local, no por id local.
      final clienteUuid = cuerpoEnviado!['clientes'][0]['uuid_local'];
      expect(cuerpoEnviado!['prestamos'][0]['cliente_uuid_local'], clienteUuid);
      final prestamoUuid = cuerpoEnviado!['prestamos'][0]['uuid_local'];
      expect(cuerpoEnviado!['pagos'][0]['prestamo_uuid_local'], prestamoUuid);
      expect(cuerpoEnviado!['pagos'][0]['numero_cuota'], 1);
      expect(cuerpoEnviado!['pagos'][0]['cuotas_afectadas'], isNotEmpty);
      expect(cuerpoEnviado!['cargas_capital'][0]['tipo'], 'carga');

      // cambios_pendientes queda vacío: todo se confirmó.
      final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
      expect(pendientes, isEmpty);

      // Los registros locales quedan marcados con el id del servidor.
      final cliente = (await clientesRepository.listar()).single;
      expect(cliente.sincronizado, isTrue);
      expect(cliente.servidorId, isNotNull);

      expect(secureStorage.ultimaSincronizacion, isNotNull);
    });

    test('no envía cambios pendientes de otro usuario que haya usado el dispositivo', () async {
      await sembrarPendientes();
      // Cambio pendiente de otro cobrador que compartió el dispositivo.
      await db.cambiosPendientesDao.encolar(usuarioId: 2, tabla: 'clientes', registroId: 999, tipoOperacion: 'crear');

      Map<String, dynamic>? cuerpoEnviado;
      final mock = MockClient((request) async {
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_respuestaConfirmandoTodo(cuerpoEnviado!));
      });

      await construirRepositorio(mock).sincronizar();

      expect(cuerpoEnviado!['clientes'], hasLength(1));

      // El cambio del otro cobrador nunca se tocó.
      final pendientesUsuario2 = await db.cambiosPendientesDao.obtenerPendientes(2);
      expect(pendientesUsuario2, hasLength(1));
    });

    test('un fallo de red no pierde ni duplica nada, y el reintento posterior sí sincroniza', () async {
      await sembrarPendientes();

      final mockFallido = MockClient((request) async => throw Exception('sin conexión'));
      final primerIntento = await construirRepositorio(mockFallido).sincronizar();

      expect(primerIntento.exitosa, isFalse);
      expect(primerIntento.mensaje, isNotEmpty);

      // Nada se perdió ni se marcó como sincronizado.
      final pendientesTrasFallo = await db.cambiosPendientesDao.obtenerPendientes(1);
      expect(pendientesTrasFallo, hasLength(4));
      final clienteTrasFallo = (await clientesRepository.listar()).single;
      expect(clienteTrasFallo.sincronizado, isFalse);

      // Reintento: mismo estado local, ahora contra un servidor que sí responde.
      final mockExitoso = MockClient((request) async {
        final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_respuestaConfirmandoTodo(cuerpo));
      });
      final segundoIntento = await construirRepositorio(mockExitoso).sincronizar();

      expect(segundoIntento.exitosa, isTrue);
      expect(segundoIntento.confirmados, 4);
      expect(await db.cambiosPendientesDao.obtenerPendientes(1), isEmpty);
    });

    test('un registro en conflicto se queda pendiente, no se pierde ni se marca como sincronizado', () async {
      final clienteId = await clientesRepository.crear(
        nombre: 'Juan Perez',
        cedula: '111',
        telefono: '3000000001',
        direccion: 'Calle 1',
      );

      final mock = MockClient((request) async {
        final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
        final uuidLocal = cuerpo['clientes'][0]['uuid_local'];
        return _json({
          'data': {
            'clientes': [
              {'uuid_local': uuidLocal, 'estado': 'conflicto', 'id': 55},
            ],
            'prestamos': [],
            'pagos': [],
            'cargas_capital': [],
          },
          'cargas_capital_admin': [],
          'configuracion': {
            'tasas_interes_default': [10, 20, 30, 40],
            'politica_mora_default': 'mantener',
            'pin_maestro_configurado': false,
            'intentos_pin_antes_de_maestro': 3,
          },
        });
      });

      final resultado = await construirRepositorio(mock).sincronizar();

      expect(resultado.exitosa, isTrue);
      expect(resultado.confirmados, 0);
      expect(resultado.conflictos, 1);

      final pendientes = await db.cambiosPendientesDao.obtenerPendientes(1);
      expect(pendientes, hasLength(1));

      final cliente = await clientesRepository.listar();
      expect(cliente.single.sincronizado, isFalse);
      expect(cliente.single.id, clienteId);
    });
  });

  group('descarga', () {
    test('guarda la configuración y los intentos_pin_antes_de_maestro descargados', () async {
      final mock = MockClient((request) async {
        return _json(
          _respuestaConfirmandoTodo(
            {},
            configuracion: {
              'tasas_interes_default': [15, 25, 35],
              'politica_mora_default': 'siguiente_pago',
              'pin_maestro_configurado': true,
              'intentos_pin_antes_de_maestro': 5,
            },
          ),
        );
      });

      await construirRepositorio(mock).sincronizar();

      expect(secureStorage.tasasGuardadas, [15.0, 25.0, 35.0]);
      expect(secureStorage.intentosGuardados, 5);
    });

    test('guarda las cargas de capital asignadas por un admin, marcadas con origen admin', () async {
      final mock = MockClient((request) async {
        return _json(
          _respuestaConfirmandoTodo(
            {},
            cargasCapitalAdmin: [
              {'id': 42, 'tipo': 'carga', 'monto': 300000, 'descripcion': 'Fondeo', 'creado_en': '2026-07-15T10:00:00Z'},
            ],
          ),
        );
      });

      await construirRepositorio(mock).sincronizar();

      final cargas = await cargasCapitalRepository.listarTodas();
      expect(cargas, hasLength(1));
      expect(cargas.first.origen, 'admin');
      expect(cargas.first.servidorId, 42);
      expect(cargas.first.sincronizado, isTrue);
      expect(cargas.first.monto, 300000);
    });

    test('una carga de admin ya descargada antes no se duplica en un sync posterior', () async {
      MockClient respuestaConCarga() {
        return MockClient((request) async {
          return _json(
            _respuestaConfirmandoTodo(
              {},
              cargasCapitalAdmin: [
                {'id': 42, 'tipo': 'carga', 'monto': 300000, 'descripcion': null, 'creado_en': '2026-07-15T10:00:00Z'},
              ],
            ),
          );
        });
      }

      await construirRepositorio(respuestaConCarga()).sincronizar();
      await construirRepositorio(respuestaConCarga()).sincronizar();

      final cargas = await cargasCapitalRepository.listarTodas();
      expect(cargas, hasLength(1));
    });
  });
}
