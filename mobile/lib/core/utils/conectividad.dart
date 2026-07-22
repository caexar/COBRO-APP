import 'dart:io';

/// Prueba liviana de conexión a internet (sin agregar el paquete
/// `connectivity_plus`): intenta resolver un dominio conocido con un
/// timeout corto. Un `false` acá no distingue "sin wifi/datos" de "hay red
/// pero el DNS falló" — para esta app basta con saber si vale la pena
/// intentar una llamada al servidor antes de mostrarla como disponible
/// (ej. "Autogenerar ruta de hoy" en `RutasListScreen`, que necesita
/// evaluar los préstamos del lado servidor y no puede hacerlo offline).
Future<bool> hayConexion() async {
  try {
    final resultado = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
    return resultado.isNotEmpty && resultado.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } catch (_) {
    return false;
  }
}
