/// URL base de la API del backend.
///
/// Se resuelve en tiempo de compilación vía `--dart-define=API_BASE_URL=...`. Sin ese flag,
/// el valor por defecto es **producción** (Laravel Cloud) — así un build normal (`flutter
/// run`/`flutter build apk` sin flags, en debug o release) nunca queda apuntando a local por
/// descuido. El flag aplica igual en debug y release, no es específico de ningún modo de
/// build.
///
/// Para desarrollo local, pasa el flag explícito según dónde vayas a probar (emulador Android
/// → `10.0.2.2` apunta al `localhost` de la máquina host; simulador iOS → `127.0.0.1` funciona
/// directo, comparte la red del host; celular físico → la IP LAN de tu máquina, debe estar en
/// la misma red Wi-Fi y el firewall debe permitir conexiones entrantes al puerto 8000):
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://cobro-app-production-36jqgb.laravel.cloud/api',
);
