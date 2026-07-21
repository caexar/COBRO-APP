import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Escribe [bytes] a un archivo temporal y lo comparte vía `share_plus`.
/// Usado tanto por el reporte del propio cobrador (`.xlsx` armado localmente
/// con el paquete `excel`, offline) como por el del admin (`.xlsx`
/// descargado tal cual de `GET /admin/reporte`) — ningún reporte de la app
/// se comparte ya como CSV, así que este es el único exportador de archivos.
Future<void> exportarArchivoYCompartir({
  required List<int> bytes,
  required String nombreArchivo,
  String textoCompartir = 'Reporte CobroApp',
}) async {
  final carpetaTemporal = await getTemporaryDirectory();
  final archivo = File('${carpetaTemporal.path}/$nombreArchivo');
  await archivo.writeAsBytes(Uint8List.fromList(bytes));

  await SharePlus.instance.share(ShareParams(files: [XFile(archivo.path)], text: textoCompartir));
}
