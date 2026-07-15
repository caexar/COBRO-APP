import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hashes de PIN maestro tal como quedaron guardados localmente (ninguno de
/// los dos existe hasta la primera sincronización exitosa tras el login).
class PinMaestroHashesGuardados {
  const PinMaestroHashesGuardados({this.individual, this.global});

  final String? individual;
  final String? global;
}

/// Envoltorio sobre [FlutterSecureStorage] (cifrado en disco, nunca
/// SharedPreferences) con todas las claves que usa el módulo de
/// autenticación: token de sesión, hash del PIN personal, hashes del PIN
/// maestro descargados del servidor, preferencia de biometría e intentos
/// fallidos del PIN.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _claveToken = 'auth_token';
  static const _claveUsuarioId = 'auth_usuario_id';
  static const _claveUsuarioNombre = 'auth_usuario_nombre';
  static const _claveUsuarioEmail = 'auth_usuario_email';
  static const _claveUsuarioRol = 'auth_usuario_rol';
  static const _clavePinPersonalHash = 'bloqueo_pin_personal_hash';
  static const _claveBiometriaHabilitada = 'bloqueo_biometria_habilitada';
  static const _clavePinMaestroIndividual = 'pin_maestro_individual_hash';
  static const _clavePinMaestroGlobal = 'pin_maestro_global_hash';
  static const _claveIntentosMaximosPin = 'bloqueo_intentos_maximos_pin';
  static const _claveIntentosFallidos = 'bloqueo_intentos_fallidos';
  static const _prefijoVistaDashboard = 'dashboard_vista_';

  // --- Sesión ---

  Future<void> guardarSesion({
    required String token,
    required int usuarioId,
    required String nombre,
    required String email,
    required String rol,
  }) async {
    await _storage.write(key: _claveToken, value: token);
    await _storage.write(key: _claveUsuarioId, value: usuarioId.toString());
    await _storage.write(key: _claveUsuarioNombre, value: nombre);
    await _storage.write(key: _claveUsuarioEmail, value: email);
    await _storage.write(key: _claveUsuarioRol, value: rol);
  }

  Future<String?> leerToken() => _storage.read(key: _claveToken);

  Future<int?> leerUsuarioId() async {
    final valor = await _storage.read(key: _claveUsuarioId);
    return valor != null ? int.tryParse(valor) : null;
  }

  Future<String?> leerNombre() => _storage.read(key: _claveUsuarioNombre);

  Future<String?> leerRol() => _storage.read(key: _claveUsuarioRol);

  /// Cierra la sesión pero conserva a propósito la configuración de bloqueo
  /// (PIN personal, biometría, PIN maestro): si el mismo usuario vuelve a
  /// entrar en este dispositivo no debería tener que reconfigurarla.
  Future<void> cerrarSesion() async {
    await _storage.delete(key: _claveToken);
    await _storage.delete(key: _claveUsuarioId);
    await _storage.delete(key: _claveUsuarioNombre);
    await _storage.delete(key: _claveUsuarioEmail);
    await _storage.delete(key: _claveUsuarioRol);
  }

  // --- Bloqueo: PIN personal ---

  Future<void> guardarPinPersonalHash(String hash) => _storage.write(key: _clavePinPersonalHash, value: hash);

  Future<String?> leerPinPersonalHash() => _storage.read(key: _clavePinPersonalHash);

  Future<bool> tienePinPersonalConfigurado() async {
    final hash = await leerPinPersonalHash();
    return hash != null && hash.isNotEmpty;
  }

  // --- Bloqueo: biometría ---

  Future<void> guardarBiometriaHabilitada(bool habilitada) =>
      _storage.write(key: _claveBiometriaHabilitada, value: habilitada.toString());

  Future<bool> biometriaHabilitada() async {
    final valor = await _storage.read(key: _claveBiometriaHabilitada);
    return valor == 'true';
  }

  // --- PIN maestro (descargado del servidor en cada sincronización) ---

  Future<void> guardarPinMaestroHashes({String? individual, String? global}) async {
    if (individual != null) {
      await _storage.write(key: _clavePinMaestroIndividual, value: individual);
    } else {
      await _storage.delete(key: _clavePinMaestroIndividual);
    }

    if (global != null) {
      await _storage.write(key: _clavePinMaestroGlobal, value: global);
    } else {
      await _storage.delete(key: _clavePinMaestroGlobal);
    }
  }

  Future<PinMaestroHashesGuardados> leerPinMaestroHashes() async {
    final individual = await _storage.read(key: _clavePinMaestroIndividual);
    final global = await _storage.read(key: _clavePinMaestroGlobal);
    return PinMaestroHashesGuardados(individual: individual, global: global);
  }

  /// Cuántos intentos fallidos del PIN personal se toleran antes de ofrecer
  /// el PIN maestro (configurable por el admin, descargado en cada
  /// sincronización). 3 por defecto si todavía no se ha sincronizado nunca.
  Future<void> guardarIntentosMaximosPin(int intentos) =>
      _storage.write(key: _claveIntentosMaximosPin, value: intentos.toString());

  Future<int> leerIntentosMaximosPin() async {
    final valor = await _storage.read(key: _claveIntentosMaximosPin);
    return int.tryParse(valor ?? '') ?? 3;
  }

  // --- Intentos fallidos del PIN personal ---

  Future<int> leerIntentosFallidos() async {
    final valor = await _storage.read(key: _claveIntentosFallidos);
    return int.tryParse(valor ?? '0') ?? 0;
  }

  Future<int> incrementarIntentosFallidos() async {
    final nuevo = await leerIntentosFallidos() + 1;
    await _storage.write(key: _claveIntentosFallidos, value: nuevo.toString());
    return nuevo;
  }

  Future<void> reiniciarIntentosFallidos() => _storage.write(key: _claveIntentosFallidos, value: '0');

  // --- Dashboard: vista configurable por cobrador ---

  /// Qué tarjetas mostrar en el dashboard del cobrador: `'todo'` (default,
  /// interés y extras), `'capital'` (solo saldo/cartera/entradas, sin
  /// tarjeta de ganancia), `'capital_interes'` o `'capital_extra'` (tarjeta
  /// de ganancia con un solo balde). Clave por [usuarioId] porque el
  /// dispositivo puede ser compartido por varios cobradores.
  Future<void> guardarVistaDashboard(int usuarioId, String vista) =>
      _storage.write(key: '$_prefijoVistaDashboard$usuarioId', value: vista);

  Future<String> leerVistaDashboard(int usuarioId) async {
    final valor = await _storage.read(key: '$_prefijoVistaDashboard$usuarioId');
    return valor ?? 'todo';
  }
}
