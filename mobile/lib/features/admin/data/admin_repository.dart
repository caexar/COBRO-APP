import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'admin_models.dart';

export 'admin_models.dart';

/// Todos los endpoints de `/api/admin/*` (rol admin). A diferencia de
/// clientes/préstamos, el panel de administrador no trabaja offline: cada
/// pantalla llama directo a la API cada vez.
class AdminRepository {
  AdminRepository({ApiClient? apiClient, SecureStorageService? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  Future<String> _tokenActual() async {
    final token = await _secureStorage.leerToken();
    if (token == null) {
      throw StateError('No hay una sesión activa.');
    }
    return token;
  }

  Future<List<UsuarioAdmin>> listarUsuarios() async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.get('/admin/usuarios', token: token);
    return (respuesta['data'] as List).map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UsuarioAdmin> crearUsuario({
    required String nombre,
    required String email,
    required String password,
    String rol = 'cobrador',
    String? pin,
    String? pinMaestro,
  }) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.post(
      '/admin/usuarios',
      token: token,
      body: {
        'nombre': nombre,
        'email': email,
        'password': password,
        'rol': rol,
        'pin': ?pin,
        'pin_maestro': ?pinMaestro,
      },
    );
    return UsuarioAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// [cambios] solo debe incluir los campos que realmente cambiaron
  /// (nombre/email/password/rol/pin/pin_maestro); nunca incluir `activo`
  /// aquí, eso va por [desactivarUsuario]/[reactivarUsuario].
  Future<UsuarioAdmin> actualizarUsuario(int id, Map<String, dynamic> cambios) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.put('/admin/usuarios/$id', token: token, body: cambios);
    return UsuarioAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<UsuarioAdmin> desactivarUsuario(int id) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.put('/admin/usuarios/$id/desactivar', token: token);
    return UsuarioAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<UsuarioAdmin> reactivarUsuario(int id) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.put('/admin/usuarios/$id/reactivar', token: token);
    return UsuarioAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<DetalleCobrador> obtenerDetalleCobrador(int id) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.get('/admin/usuarios/$id/detalle', token: token);
    return DetalleCobrador.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<ResumenAdmin> obtenerResumen() async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.get('/admin/resumen', token: token);
    return ResumenAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Asigna (o retira, según [tipo]) saldo de capital a [usuarioId] — el
  /// cobrador destino, no necesariamente el admin autenticado. Este dinero
  /// no llega al dispositivo del cobrador hasta su próxima sincronización
  /// (`POST /api/sync` -> `cargas_capital_admin`).
  Future<void> asignarCapital({
    required int usuarioId,
    required String tipo,
    required double monto,
    String? descripcion,
  }) async {
    final token = await _tokenActual();
    await _apiClient.post(
      '/admin/cargas-capital',
      token: token,
      body: {'usuario_id': usuarioId, 'tipo': tipo, 'monto': monto, 'descripcion': ?descripcion},
    );
  }

  Future<ConfiguracionAdmin> obtenerConfiguracion() async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.get('/admin/configuracion', token: token);
    return ConfiguracionAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// [cambios] solo debe incluir lo que cambió: `tasas_interes_default`,
  /// `politica_mora_default`, `pin_maestro` (usar `null` para quitarlo).
  Future<ConfiguracionAdmin> actualizarConfiguracion(Map<String, dynamic> cambios) async {
    final token = await _tokenActual();
    final respuesta = await _apiClient.put('/admin/configuracion', token: token, body: cambios);
    return ConfiguracionAdmin.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}
