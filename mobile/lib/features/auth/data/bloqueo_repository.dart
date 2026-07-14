import 'package:bcrypt/bcrypt.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/storage/secure_storage_service.dart';

class ResultadoVerificacionPin {
  const ResultadoVerificacionPin({required this.correcto, required this.intentosFallidos});

  final bool correcto;
  final int intentosFallidos;
}

/// Configuración y verificación del bloqueo de la app: PIN personal
/// (hasheado con bcrypt, nunca en texto plano), biometría (`local_auth`) y
/// el PIN maestro de emergencia descargado por [AuthRepository].
class BloqueoRepository {
  BloqueoRepository({SecureStorageService? secureStorage, LocalAuthentication? localAuth})
      : _secureStorage = secureStorage ?? SecureStorageService(),
        _localAuth = localAuth ?? LocalAuthentication();

  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth;

  /// Después de este número de intentos fallidos del PIN personal se ofrece
  /// automáticamente el campo de PIN maestro. Configurable por el admin
  /// (`GET /api/pin-maestro`, sincronizado por `AuthRepository`); 3 por
  /// defecto si el dispositivo todavía no ha sincronizado nunca.
  Future<int> obtenerIntentosMaximosPin() => _secureStorage.leerIntentosMaximosPin();

  Future<bool> tieneBloqueoConfigurado() => _secureStorage.tienePinPersonalConfigurado();

  Future<void> configurarPinPersonal(String pin) async {
    final hash = BCrypt.hashpw(pin, BCrypt.gensalt());
    await _secureStorage.guardarPinPersonalHash(hash);
    await _secureStorage.reiniciarIntentosFallidos();
  }

  Future<void> configurarBiometria(bool habilitada) => _secureStorage.guardarBiometriaHabilitada(habilitada);

  Future<bool> biometriaHabilitada() => _secureStorage.biometriaHabilitada();

  Future<bool> biometriaDisponibleEnDispositivo() async {
    try {
      final soportado = await _localAuth.isDeviceSupported();
      final puedeChequear = await _localAuth.canCheckBiometrics;
      return soportado && puedeChequear;
    } catch (_) {
      return false;
    }
  }

  Future<bool> autenticarConBiometria() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para abrir CobroApp',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<ResultadoVerificacionPin> verificarPinPersonal(String pin) async {
    final hash = await _secureStorage.leerPinPersonalHash();

    if (hash != null && _coincide(pin, hash)) {
      await _secureStorage.reiniciarIntentosFallidos();
      return const ResultadoVerificacionPin(correcto: true, intentosFallidos: 0);
    }

    final intentos = await _secureStorage.incrementarIntentosFallidos();
    return ResultadoVerificacionPin(correcto: false, intentosFallidos: intentos);
  }

  Future<int> intentosFallidosActuales() => _secureStorage.leerIntentosFallidos();

  /// Verifica el PIN maestro: primero contra el hash individual del
  /// cobrador (si tiene uno propio) y, si no coincide o no existe, contra
  /// el hash global de respaldo (ver CLAUDE.md, sección "PIN maestro").
  Future<bool> verificarPinMaestro(String pin) async {
    final hashes = await _secureStorage.leerPinMaestroHashes();

    final coincideIndividual = hashes.individual != null && _coincide(pin, hashes.individual!);
    final coincideGlobal = hashes.global != null && _coincide(pin, hashes.global!);

    if (coincideIndividual || coincideGlobal) {
      await _secureStorage.reiniciarIntentosFallidos();
      return true;
    }

    return false;
  }

  Future<bool> hayPinMaestroDisponible() async {
    final hashes = await _secureStorage.leerPinMaestroHashes();
    return hashes.individual != null || hashes.global != null;
  }

  bool _coincide(String pin, String hash) {
    try {
      return BCrypt.checkpw(pin, hash);
    } catch (_) {
      return false;
    }
  }
}
