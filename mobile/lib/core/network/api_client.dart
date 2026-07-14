import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Error de red o de la API (incluye validaciones 422, credenciales
/// incorrectas, etc.). El [message] ya viene listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({
    required this.token,
    required this.usuarioId,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final usuario = json['user'] as Map<String, dynamic>;
    return LoginResult(
      token: json['token'] as String,
      usuarioId: usuario['id'] as int,
      nombre: usuario['nombre'] as String,
      email: usuario['email'] as String,
      rol: usuario['rol'] as String,
    );
  }

  final String token;
  final int usuarioId;
  final String nombre;
  final String email;
  final String rol;
}

/// Hashes de PIN maestro tal como los guarda el backend (bcrypt), listos
/// para verificarse localmente con el paquete `bcrypt`. Cualquiera de los
/// dos puede venir nulo si no está configurado.
class PinMaestroHashes {
  const PinMaestroHashes({this.individual, this.global});

  factory PinMaestroHashes.fromJson(Map<String, dynamic> json) {
    return PinMaestroHashes(
      individual: json['pin_maestro_individual_hash'] as String?,
      global: json['pin_maestro_global_hash'] as String?,
    );
  }

  final String? individual;
  final String? global;
}

/// Cliente HTTP delgado para los endpoints que necesita el módulo de
/// autenticación. El resto de la API (clientes, préstamos, pagos) se
/// integrará aquí en fases futuras.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? kApiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  Future<LoginResult> login({required String email, required String password}) async {
    final respuesta = await _post('/login', body: {'email': email, 'password': password});
    return LoginResult.fromJson(respuesta);
  }

  Future<void> logout(String token) async {
    await _http.post(Uri.parse('$_baseUrl/logout'), headers: _headers(token: token));
  }

  Future<PinMaestroHashes> obtenerPinMaestro(String token) async {
    final respuesta = await _get('/pin-maestro', token: token);
    return PinMaestroHashes.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _post(String ruta, {Map<String, dynamic>? body, String? token}) async {
    final respuesta = await _http.post(
      Uri.parse('$_baseUrl$ruta'),
      headers: _headers(token: token),
      body: jsonEncode(body ?? {}),
    );
    return _procesar(respuesta);
  }

  Future<Map<String, dynamic>> _get(String ruta, {String? token}) async {
    final respuesta = await _http.get(Uri.parse('$_baseUrl$ruta'), headers: _headers(token: token));
    return _procesar(respuesta);
  }

  Map<String, dynamic> _procesar(http.Response respuesta) {
    final cuerpo = respuesta.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(respuesta.body) as Map<String, dynamic>;

    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw ApiException(_mensajeDeError(cuerpo), statusCode: respuesta.statusCode);
    }

    return cuerpo;
  }

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _mensajeDeError(Map<String, dynamic> cuerpo) {
    final errores = cuerpo['errors'];
    if (errores is Map) {
      final primerCampo = errores.values.whereType<List>().firstOrNull;
      if (primerCampo != null && primerCampo.isNotEmpty) {
        return primerCampo.first.toString();
      }
    }
    return cuerpo['message'] as String? ?? 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
