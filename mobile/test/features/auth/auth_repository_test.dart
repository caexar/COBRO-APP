import 'dart:convert';
import 'dart:io';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Simula no tener conexión: cualquier request lanza una excepción de red
/// real (no `ApiException`), igual que le pasaría a un usuario cerrando
/// sesión sin internet o con el backend caído.
class _HttpClienteQueFalla extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Sin conexión (simulado para la prueba)');
  }
}

/// Doble de [SecureStorageService] en memoria, para no depender de
/// flutter_secure_storage (platform channels no disponibles en `flutter test`).
class _AlmacenamientoEnMemoria extends SecureStorageService {
  final Map<String, String> _valores = {};

  @override
  Future<void> guardarSesion({
    required String token,
    required int usuarioId,
    required String nombre,
    required String email,
    required String rol,
  }) async {
    _valores['token'] = token;
  }

  @override
  Future<String?> leerToken() async => _valores['token'];

  @override
  Future<void> cerrarSesion() async {
    _valores.remove('token');
  }

  @override
  Future<void> guardarPinMaestroHashes({String? individual, String? global}) async {
    if (individual != null) _valores['pinMaestroIndividual'] = individual;
    if (global != null) _valores['pinMaestroGlobal'] = global;
  }

  @override
  Future<PinMaestroHashesGuardados> leerPinMaestroHashes() async {
    return PinMaestroHashesGuardados(
      individual: _valores['pinMaestroIndividual'],
      global: _valores['pinMaestroGlobal'],
    );
  }

  @override
  Future<void> guardarIntentosMaximosPin(int intentos) async {
    _valores['intentosMaximosPin'] = intentos.toString();
  }

  @override
  Future<int> leerIntentosMaximosPin() async {
    return int.tryParse(_valores['intentosMaximosPin'] ?? '') ?? 3;
  }
}

void main() {
  test('cerrarSesion limpia el token localmente aunque falle la revocación remota (sin red)', () async {
    final almacenamiento = _AlmacenamientoEnMemoria();
    await almacenamiento.guardarSesion(
      token: 'token-de-prueba',
      usuarioId: 1,
      nombre: 'Test',
      email: 't@t.com',
      rol: 'cobrador',
    );
    await almacenamiento.guardarPinMaestroHashes(individual: 'hash-individual', global: 'hash-global');

    final apiClient = ApiClient(httpClient: _HttpClienteQueFalla());
    final repository = AuthRepository(apiClient: apiClient, secureStorage: almacenamiento);

    // Antes del fix: ApiClient.logout() no pasa por _procesar(), así que un
    // fallo de red lanza SocketException (no ApiException); el catch de
    // cerrarSesion() solo atrapaba ApiException, así que esta excepción se
    // propagaba sin capturar y el token nunca se borraba localmente.
    await repository.cerrarSesion();

    expect(await almacenamiento.leerToken(), isNull);
    expect(await repository.haySesionActiva(), isFalse);

    // El PIN maestro debe seguir disponible para el próximo usuario del dispositivo.
    final pinMaestro = await almacenamiento.leerPinMaestroHashes();
    expect(pinMaestro.individual, 'hash-individual');
    expect(pinMaestro.global, 'hash-global');
  });

  test('sincronizarPinMaestro guarda también intentos_pin_antes_de_maestro', () async {
    final almacenamiento = _AlmacenamientoEnMemoria();
    await almacenamiento.guardarSesion(
      token: 'token-de-prueba',
      usuarioId: 1,
      nombre: 'Test',
      email: 't@t.com',
      rol: 'cobrador',
    );

    final cliente = MockClient((request) async {
      expect(request.url.path, '/api/pin-maestro');
      return http.Response(
        jsonEncode({
          'data': {
            'pin_maestro_individual_hash': null,
            'pin_maestro_global_hash': 'hash-global',
            'intentos_pin_antes_de_maestro': 5,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repository = AuthRepository(apiClient: ApiClient(httpClient: cliente), secureStorage: almacenamiento);

    await repository.sincronizarPinMaestro();

    expect(await almacenamiento.leerIntentosMaximosPin(), 5);
  });

  test('leerIntentosMaximosPin cae a 3 por defecto si nunca se ha sincronizado', () async {
    final almacenamiento = _AlmacenamientoEnMemoria();
    expect(await almacenamiento.leerIntentosMaximosPin(), 3);
  });
}
