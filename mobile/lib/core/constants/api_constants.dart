/// URL base de la API del backend.
///
/// - Emulador Android: `10.0.2.2` apunta al `localhost` de la máquina host.
/// - Simulador iOS: `127.0.0.1` funciona directo (comparte la red del host).
/// - Celular físico (Android o iOS): reemplaza por la IP LAN de tu máquina,
///   ej. `http://192.168.1.50:8000/api` (debe estar en la misma red Wi-Fi
///   y el firewall debe permitir conexiones entrantes al puerto 8000).
///
/// Cambia este valor según dónde vayas a probar la app.
const String kApiBaseUrl = 'http://127.0.0.1:8000/api';
//'http://10.0.2.2:8000/api';
