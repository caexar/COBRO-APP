import 'dart:io';

import 'package:cobro_app/core/utils/csv_exportador.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/platform_interface/share_plus_platform.dart';

class _PathProviderFalso extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _PathProviderFalso(this.directorio);

  final Directory directorio;

  @override
  Future<String?> getTemporaryPath() async => directorio.path;
}

class _ShareFalso extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? ultimaLlamada;

  @override
  Future<ShareResult> share(ShareParams params) async {
    ultimaLlamada = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  test('antepone el BOM de UTF-8 al contenido antes de escribir el archivo', () async {
    final directorioTemporal = await Directory.systemTemp.createTemp('csv_exportador_test');
    addTearDown(() => directorioTemporal.delete(recursive: true));

    PathProviderPlatform.instance = _PathProviderFalso(directorioTemporal);
    final shareFalso = _ShareFalso();
    SharePlatform.instance = shareFalso;

    await exportarCsvYCompartir(contenidoCsv: 'Cliente,Ciudad\r\nJosé Peña,Bogotá\r\n', nombreArchivo: 'reporte.csv');

    final archivo = File('${directorioTemporal.path}/reporte.csv');
    final bytes = await archivo.readAsBytes();

    // BOM de UTF-8 (EF BB BF) como prefijo, sin el cual Excel no detecta la
    // codificación y muestra tildes/ñ como símbolos raros.
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);

    final contenidoSinBom = await archivo.readAsString();
    expect(contenidoSinBom, contains('José Peña,Bogotá'));

    expect(shareFalso.ultimaLlamada, isNotNull);
    expect(shareFalso.ultimaLlamada!.files!.single.path, archivo.path);
  });
}
