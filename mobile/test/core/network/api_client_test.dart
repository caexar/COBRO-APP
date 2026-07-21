import 'package:cobro_app/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient.getBytes', () {
    test('devuelve los bytes tal cual, incluidos bytes que no son UTF-8 válido', () async {
      // Firma ZIP (PK\x03\x04, como cualquier .xlsx real) seguida de bytes que NO forman una
      // secuencia UTF-8 válida (0xFF/0xFE sueltos) — si algún punto del camino decodificara la
      // respuesta como texto (`response.body`) y la re-codificara, estos bytes se romperían
      // silenciosamente (reemplazados por el carácter de reemplazo U+FFFD), a diferencia de
      // `response.bodyBytes`, que nunca pasa por esa decodificación.
      final bytesOriginales = [0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFE, 0x80, 0x81, 0x00, 0x10, 0x20];

      Map<String, String>? headersEnviados;
      final mock = MockClient((request) async {
        headersEnviados = request.headers;
        return http.Response.bytes(
          bytesOriginales,
          200,
          headers: {'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
        );
      });

      final apiClient = ApiClient(httpClient: mock, baseUrl: 'http://test');
      final bytes = await apiClient.getBytes('/admin/reporte', token: 'token-de-prueba');

      expect(bytes, bytesOriginales);
      // No debe pedir Accept: application/json en una descarga binaria (sería engañoso —
      // ver ApiClient._headersBinario).
      expect(headersEnviados!['accept'], isNot('application/json'));
      expect(headersEnviados!['authorization'], 'Bearer token-de-prueba');
    });

    test('un error 4xx se decodifica como JSON y lanza ApiException, sin tocar bodyBytes', () async {
      final mock = MockClient((request) async {
        return http.Response('{"message":"El cobrador indicado no existe."}', 422, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(httpClient: mock, baseUrl: 'http://test');

      await expectLater(
        () => apiClient.getBytes('/admin/reporte', token: 'token-de-prueba'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'El cobrador indicado no existe.')),
      );
    });
  });
}
