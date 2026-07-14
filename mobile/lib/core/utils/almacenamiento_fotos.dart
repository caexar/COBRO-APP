import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copia una foto elegida (cámara o galería) a la carpeta de documentos de la
/// app, para no depender del archivo temporal que entrega `image_picker`
/// (que el sistema operativo puede limpiar en cualquier momento).
///
/// Devuelve la ruta local absoluta guardada en `fotoUrl`; se reemplaza por la
/// URL real del servidor cuando el cliente se sincronice.
Future<String> guardarFotoCliente(XFile archivo) async {
  final carpetaDocumentos = await getApplicationDocumentsDirectory();
  final carpetaFotos = Directory(p.join(carpetaDocumentos.path, 'fotos_clientes'));

  if (!await carpetaFotos.exists()) {
    await carpetaFotos.create(recursive: true);
  }

  final extension = p.extension(archivo.path).isNotEmpty ? p.extension(archivo.path) : '.jpg';
  final nombreArchivo = 'cliente_${DateTime.now().millisecondsSinceEpoch}$extension';
  final destino = p.join(carpetaFotos.path, nombreArchivo);

  await File(archivo.path).copy(destino);

  return destino;
}
