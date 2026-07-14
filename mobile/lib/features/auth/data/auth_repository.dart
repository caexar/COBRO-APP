import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Login/logout y sincronización del PIN maestro. La configuración de
/// bloqueo (PIN personal, biometría) vive en [BloqueoRepository].
class AuthRepository {
  AuthRepository({ApiClient? apiClient, SecureStorageService? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorageService();

  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  Future<void> iniciarSesion({required String email, required String password}) async {
    final resultado = await _apiClient.login(email: email, password: password);

    await _secureStorage.guardarSesion(
      token: resultado.token,
      usuarioId: resultado.usuarioId,
      nombre: resultado.nombre,
      email: resultado.email,
      rol: resultado.rol,
    );

    // No se espera un fallo aquí para no bloquear el login si no hay red
    // justo en este instante; sincronizarPinMaestro ya maneja sus propios
    // errores de conexión.
    await sincronizarPinMaestro();
  }

  /// Descarga los hashes de PIN maestro (individual y global) y los guarda
  /// cifrados localmente. Debe llamarse tras cada sincronización exitosa;
  /// si falla por falta de conexión, se conservan los últimos guardados y
  /// el PIN maestro sigue funcionando offline hasta la próxima sincronización.
  Future<void> sincronizarPinMaestro() async {
    final token = await _secureStorage.leerToken();
    if (token == null) return;

    try {
      final hashes = await _apiClient.obtenerPinMaestro(token);
      await _secureStorage.guardarPinMaestroHashes(individual: hashes.individual, global: hashes.global);
    } on ApiException {
      // Sin conexión o error del servidor: se mantiene el PIN maestro
      // guardado de la última sincronización exitosa.
    }
  }

  Future<void> cerrarSesion() async {
    final token = await _secureStorage.leerToken();

    if (token != null) {
      try {
        await _apiClient.logout(token);
      } on ApiException {
        // Si falla la revocación remota del token, igual cerramos la
        // sesión localmente; el token quedará huérfano en el servidor
        // hasta que expire por sí solo.
      }
    }

    await _secureStorage.cerrarSesion();
  }

  Future<bool> haySesionActiva() async {
    final token = await _secureStorage.leerToken();
    return token != null;
  }

  Future<String?> nombreUsuarioActual() => _secureStorage.leerNombre();
}
