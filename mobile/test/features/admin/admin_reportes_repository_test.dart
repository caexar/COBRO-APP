import 'dart:io';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/data/admin_reportes_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/platform_interface/share_plus_platform.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

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
  test('descarga el .xlsx de GET /admin/reporte con los filtros correctos y lo comparte', () async {
    final directorioTemporal = await Directory.systemTemp.createTemp('admin_reportes_repository_test');
    addTearDown(() => directorioTemporal.delete(recursive: true));
    PathProviderPlatform.instance = _PathProviderFalso(directorioTemporal);
    final shareFalso = _ShareFalso();
    SharePlatform.instance = shareFalso;

    Uri? urlLlamada;
    final bytesXlsx = [0x50, 0x4B, 0x03, 0x04]; // firma ZIP, como cualquier .xlsx real

    final mock = MockClient((request) async {
      urlLlamada = request.url;
      return http.Response.bytes(
        bytesXlsx,
        200,
        headers: {'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
      );
    });

    final adminRepository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());
    final reportesRepository = AdminReportesRepository(adminRepository: adminRepository);

    await reportesRepository.exportarYCompartir(
      usuarioIds: [2, 3],
      desde: DateTime(2026, 1, 1),
      hasta: DateTime(2026, 1, 31),
      categoria: 'gasto_operativo',
    );

    // Pide el reporte con los filtros correctos (Uri percent-codifica los corchetes de
    // "usuario_ids[]" al parsear, por eso se lee vía queryParametersAll ya decodificado).
    expect(urlLlamada!.path, '/api/admin/reporte');
    expect(urlLlamada!.queryParametersAll['usuario_ids[]'], ['2', '3']);
    expect(urlLlamada!.queryParameters['desde'], '2026-01-01');
    expect(urlLlamada!.queryParameters['hasta'], '2026-01-31');
    expect(urlLlamada!.queryParameters['categoria'], 'gasto_operativo');

    // Comparte el archivo descargado tal cual, sin tocar los bytes.
    expect(shareFalso.ultimaLlamada, isNotNull);
    final archivoCompartido = File(shareFalso.ultimaLlamada!.files!.single.path);
    expect(await archivoCompartido.readAsBytes(), bytesXlsx);
    expect(archivoCompartido.path, endsWith('.xlsx'));
  });

  test('un error del servidor se propaga como ApiException, sin compartir nada', () async {
    final mock = MockClient((request) async {
      return http.Response('{"message":"El cobrador indicado no existe."}', 422, headers: {'content-type': 'application/json'});
    });

    final adminRepository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());
    final reportesRepository = AdminReportesRepository(adminRepository: adminRepository);

    await expectLater(
      () => reportesRepository.exportarYCompartir(usuarioIds: [2]),
      throwsA(isA<ApiException>()),
    );
  });
}
