import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Token fijo en memoria, sin tocar flutter_secure_storage real.
class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

http.Response _json(Object cuerpo, {int status = 200}) {
  return http.Response(jsonEncode(cuerpo), status, headers: {'content-type': 'application/json'});
}

void main() {
  group('AdminRepository', () {
    test('listarUsuarios parsea el listado tal como lo documenta API.md', () async {
      final cliente = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/admin/usuarios');
        expect(request.headers['Authorization'], 'Bearer token-de-prueba');

        return _json({
          'data': [
            {
              'id': 2,
              'nombre': 'Cobrador Uno',
              'email': 'cobrador1@cobroapp.test',
              'rol': 'cobrador',
              'activo': true,
              'created_at': '2026-01-01T00:00:00.000000Z',
              'updated_at': '2026-01-01T00:00:00.000000Z',
              'deleted_at': null,
            },
          ],
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final usuarios = await repository.listarUsuarios();

      expect(usuarios, hasLength(1));
      expect(usuarios.first.id, 2);
      expect(usuarios.first.nombre, 'Cobrador Uno');
      expect(usuarios.first.activo, isTrue);
    });

    test('crearUsuario manda rol=cobrador por defecto y solo incluye pin/pin_maestro si se dan', () async {
      Map<String, dynamic>? cuerpoEnviado;

      final cliente = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/admin/usuarios');
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {
            'id': 5,
            'nombre': cuerpoEnviado!['nombre'],
            'email': cuerpoEnviado!['email'],
            'rol': cuerpoEnviado!['rol'],
            'activo': true,
          },
        }, status: 201);
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final usuario = await repository.crearUsuario(
        nombre: 'Nuevo Cobrador',
        email: 'nuevo@cobroapp.test',
        password: 'password123',
      );

      expect(cuerpoEnviado!['rol'], 'cobrador');
      expect(cuerpoEnviado!.containsKey('pin'), isFalse);
      expect(cuerpoEnviado!.containsKey('pin_maestro'), isFalse);
      expect(usuario.nombre, 'Nuevo Cobrador');
      expect(usuario.rol, 'cobrador');
    });

    test('actualizarUsuario envía PUT con solo los cambios dados', () async {
      Map<String, dynamic>? cuerpoEnviado;

      final cliente = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/admin/usuarios/7');
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {'id': 7, 'nombre': 'Editado', 'email': 'editado@cobroapp.test', 'rol': 'cobrador', 'activo': true},
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final usuario = await repository.actualizarUsuario(7, {'nombre': 'Editado'});

      expect(cuerpoEnviado, {'nombre': 'Editado'});
      expect(usuario.nombre, 'Editado');
    });

    test('desactivarUsuario y reactivarUsuario llaman a las rutas correctas', () async {
      final rutasLlamadas = <String>[];

      final cliente = MockClient((request) async {
        rutasLlamadas.add('${request.method} ${request.url.path}');

        return _json({
          'data': {
            'id': 3,
            'nombre': 'Cobrador',
            'email': 'c@cobroapp.test',
            'rol': 'cobrador',
            'activo': request.url.path.contains('reactivar'),
          },
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final desactivado = await repository.desactivarUsuario(3);
      final reactivado = await repository.reactivarUsuario(3);

      expect(rutasLlamadas, ['PUT /api/admin/usuarios/3/desactivar', 'PUT /api/admin/usuarios/3/reactivar']);
      expect(desactivado.activo, isFalse);
      expect(reactivado.activo, isTrue);
    });

    test('obtenerDetalleCobrador parsea usuario + clientes + prestamos anidados', () async {
      final cliente = MockClient((request) async {
        expect(request.url.path, '/api/admin/usuarios/2/detalle');

        return _json({
          'data': {
            'id': 2,
            'nombre': 'Cobrador Uno',
            'email': 'cobrador1@cobroapp.test',
            'rol': 'cobrador',
            'activo': true,
            'clientes': [
              {'id': 1, 'nombre': 'Juan Perez', 'cedula': '123456', 'telefono': '3001234567'},
            ],
            'prestamos': [
              {
                'id': 10,
                'cliente_id': 1,
                'referencia': null,
                'monto_capital': '100000.00',
                'porcentaje_interes': '20.00',
                'monto_total': '120000.00',
                'estado': 'activo',
                'plazo_cuotas': 10,
                'fecha_inicio': '2026-07-10',
                // Campos extra que el backend incluye pero que este modelo no necesita.
                'cliente': {'id': 1, 'nombre': 'Juan Perez'},
                'extras': [],
                'cuotas': [],
                'pagos': [],
              },
            ],
          },
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final detalle = await repository.obtenerDetalleCobrador(2);

      expect(detalle.usuario.nombre, 'Cobrador Uno');
      expect(detalle.clientes, hasLength(1));
      expect(detalle.clientes.first.nombre, 'Juan Perez');
      expect(detalle.prestamos, hasLength(1));
      expect(detalle.prestamos.first.montoCapital, 100000.0);
      expect(detalle.prestamos.first.porcentajeInteres, 20.0);
      expect(detalle.prestamos.first.montoTotal, 120000.0);
      expect(detalle.prestamos.first.referencia, isNull);
      expect(detalle.prestamos.first.estado, 'activo');
      expect(detalle.prestamos.first.totalPagado, 0.0);
    });

    test('obtenerResumen parsea global y por_cobrador', () async {
      final cliente = MockClient((request) async {
        expect(request.url.path, '/api/admin/resumen');

        return _json({
          'data': {
            'global': {
              'capital_prestado': 50000,
              'total_cobrado': 5000,
              'cartera_en_mora': 6000,
              'ganancia_interes': 1000,
              'ganancia_extra': 500,
            },
            'por_cobrador': [
              {
                'usuario_id': 2,
                'nombre': 'Cobrador Uno',
                'activo': true,
                'capital_prestado': 50000,
                'total_cobrado': 5000,
                'cartera_en_mora': 6000,
                'ganancia_interes': 1000,
                'ganancia_extra': 500,
              },
            ],
          },
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final resumen = await repository.obtenerResumen();

      expect(resumen.global.capitalPrestado, 50000.0);
      expect(resumen.global.carteraEnMora, 6000.0);
      expect(resumen.global.gananciaInteres, 1000.0);
      expect(resumen.global.gananciaExtra, 500.0);
      expect(resumen.porCobrador, hasLength(1));
      expect(resumen.porCobrador.first.nombre, 'Cobrador Uno');
      expect(resumen.porCobrador.first.totales.totalCobrado, 5000.0);
      expect(resumen.porCobrador.first.totales.gananciaInteres, 1000.0);
      expect(resumen.porCobrador.first.totales.gananciaExtra, 500.0);
    });

    test('obtenerConfiguracion nunca expone el pin, solo si está configurado', () async {
      final cliente = MockClient((request) async {
        return _json({
          'data': {
            'tasas_interes_default': [10, 20, 30, 40],
            'politica_mora_default': 'mantener',
            'pin_maestro_configurado': false,
            'intentos_pin_antes_de_maestro': 3,
          },
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final configuracion = await repository.obtenerConfiguracion();

      expect(configuracion.tasasInteresDefault, [10.0, 20.0, 30.0, 40.0]);
      expect(configuracion.politicaMoraDefault, 'mantener');
      expect(configuracion.pinMaestroConfigurado, isFalse);
      expect(configuracion.intentosPinAntesDeMaestro, 3);
    });

    test('actualizarConfiguracion envía intentos_pin_antes_de_maestro y pin_maestro: null para quitarlo', () async {
      Map<String, dynamic>? cuerpoEnviado;

      final cliente = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/admin/configuracion');
        cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;

        return _json({
          'data': {
            'tasas_interes_default': [15, 25],
            'politica_mora_default': 'siguiente_pago',
            'pin_maestro_configurado': false,
            'intentos_pin_antes_de_maestro': 5,
          },
        });
      });

      final repository = AdminRepository(
        apiClient: ApiClient(httpClient: cliente),
        secureStorage: _SecureStorageFalso(),
      );

      final actualizada = await repository.actualizarConfiguracion({
        'tasas_interes_default': [15, 25],
        'politica_mora_default': 'siguiente_pago',
        'pin_maestro': null,
        'intentos_pin_antes_de_maestro': 5,
      });

      expect(cuerpoEnviado!.containsKey('pin_maestro'), isTrue);
      expect(cuerpoEnviado!['pin_maestro'], isNull);
      expect(cuerpoEnviado!['intentos_pin_antes_de_maestro'], 5);
      expect(actualizada.pinMaestroConfigurado, isFalse);
      expect(actualizada.politicaMoraDefault, 'siguiente_pago');
      expect(actualizada.intentosPinAntesDeMaestro, 5);
    });
  });
}
