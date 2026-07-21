import '../storage/secure_storage_service.dart';

/// Preferencia de "atajo de miles" para campos de monto (ver
/// `interpretarValorIngresado`/`textoAyudaAtajoMiles` en `formato_dinero.dart`):
/// activada por defecto. Es por cobrador/admin — resuelve internamente el
/// `usuarioId` de la sesión activa, así cualquier pantalla puede usarla sin
/// tener que pasarlo a mano.
class AtajoMilesRepository {
  AtajoMilesRepository({SecureStorageService? secureStorage}) : _secureStorage = secureStorage ?? SecureStorageService();

  final SecureStorageService _secureStorage;

  Future<bool> estaActivado() async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    if (usuarioId == null) return true;
    return _secureStorage.leerAtajoMilesActivado(usuarioId);
  }

  Future<void> configurar(bool activado) async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    if (usuarioId == null) return;
    await _secureStorage.guardarAtajoMilesActivado(usuarioId, activado);
  }
}
