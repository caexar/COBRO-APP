import 'dart:io';

import 'package:cobro_app/core/utils/archivo_exportador.dart';
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
  test('escribe los bytes tal cual en un archivo temporal y lo comparte', () async {
    final directorioTemporal = await Directory.systemTemp.createTemp('archivo_exportador_test');
    addTearDown(() => directorioTemporal.delete(recursive: true));

    PathProviderPlatform.instance = _PathProviderFalso(directorioTemporal);
    final shareFalso = _ShareFalso();
    SharePlatform.instance = shareFalso;

    // Firma ZIP (PK\x03\x04, como un .xlsx real) seguida de bytes que no forman una secuencia
    // UTF-8 válida — si `writeAsBytes` se cambiara por `writeAsString` (que fuerza un paso por
    // texto), estos bytes quedarían corrompidos en el archivo.
    final bytes = [0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFE, 0x80, 0x81];
    await exportarArchivoYCompartir(bytes: bytes, nombreArchivo: 'reporte.xlsx');

    final archivo = File('${directorioTemporal.path}/reporte.xlsx');
    expect(await archivo.readAsBytes(), bytes);

    expect(shareFalso.ultimaLlamada, isNotNull);
    expect(shareFalso.ultimaLlamada!.files!.single.path, archivo.path);
  });
}
