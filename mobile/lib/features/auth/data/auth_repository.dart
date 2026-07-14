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

  /// Descarga los hashes de PIN maestro (individual y global) y cuántos
  /// intentos de PIN personal se toleran antes de ofrecerlo, y los guarda
  /// cifrados localmente. Debe llamarse tras cada sincronización exitosa;
  /// si falla por falta de conexión, se conserva lo guardado en la última
  /// sincronización exitosa y todo sigue funcionando offline.
  Future<void> sincronizarPinMaestro() async {
    final token = await _secureStorage.leerToken();
    if (token == null) return;

    try {
      final hashes = await _apiClient.obtenerPinMaestro(token);
      await _secureStorage.guardarPinMaestroHashes(individual: hashes.individual, global: hashes.global);
      await _secureStorage.guardarIntentosMaximosPin(hashes.intentosPinAntesDeMaestro);
    } on ApiException {
      // Sin conexión o error del servidor: se mantiene lo guardado de la
      // última sincronización exitosa.
    }
  }

  Future<void> cerrarSesion() async {
    final token = await _secureStorage.leerToken();

    if (token != null) {
      try {
        await _apiClient.logout(token).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Cualquier fallo -- de red (sin conexión, backend caído), de
        // tiempo de espera, o de la API -- no debe impedir cerrar la
        // sesión localmente. Antes solo se atrapaba ApiException, así que
        // un error de conexión (muy común: `logout()` no pasa por
        // `_procesar()`, así que nunca lanza ApiException) se propagaba
        // sin capturar y el botón "Cerrar sesión" parecía no hacer nada.
        // Si falla la revocación remota, el token queda huérfano en el
        // servidor hasta que expire por sí solo.
      }
    }

    await _secureStorage.cerrarSesion();
  }

  Future<bool> haySesionActiva() async {
    final token = await _secureStorage.leerToken();
    return token != null;
  }

  Future<String?> nombreUsuarioActual() => _secureStorage.leerNombre();

  /// 'admin' | 'cobrador' del usuario actualmente logueado (o `null` si no
  /// hay sesión). Se usa para bloquear el acceso a pantallas exclusivas de
  /// cobrador cuando el usuario logueado es admin.
  Future<String?> rolUsuarioActual() => _secureStorage.leerRol();
}
