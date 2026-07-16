import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Marca de orden de bytes (BOM) de UTF-8 (U+FEFF), como carácter Unicode:
/// al codificarse a bytes queda como el prefijo EF BB BF. Sin este prefijo,
/// Excel no detecta que el archivo está en UTF-8 y muestra tildes/ñ como
/// símbolos raros — el texto en sí ya se codifica bien en UTF-8 porque
/// `File.writeAsString` usa esa codificación por defecto; el problema real
/// era la falta del BOM, no el encoding en sí.
const String _bomUtf8 = '\uFEFF';

/// Escribe [contenidoCsv] a un archivo temporal (con el BOM de UTF-8
/// antepuesto) y lo comparte vía `share_plus`. Cualquier exportador de CSV
/// nuevo debe usar esta función en vez de escribir el archivo directamente,
/// para no repetir el bug de encoding en cada exportador nuevo.
Future<void> exportarCsvYCompartir({
  required String contenidoCsv,
  required String nombreArchivo,
  String textoCompartir = 'Reporte CobroApp',
}) async {
  final carpetaTemporal = await getTemporaryDirectory();
  final archivo = File('${carpetaTemporal.path}/$nombreArchivo');
  await archivo.writeAsString('$_bomUtf8$contenidoCsv');

  await SharePlus.instance.share(ShareParams(files: [XFile(archivo.path)], text: textoCompartir));
}
