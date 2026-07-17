import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/presentation/admin_cobrador_detalle_screen.dart';
import 'package:cobro_app/features/admin/presentation/admin_resumen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

http.Response _json(Object cuerpo) {
  return http.Response(jsonEncode(cuerpo), 200, headers: {'content-type': 'application/json'});
}

Map<String, dynamic> _totales() => {
  'capital_prestado': 100000,
  'total_cobrado': 20000,
  'cartera_en_mora': 0,
  'ganancia_interes': 5000,
  'ganancia_extra': 0,
  'saldo_disponible': 10000,
};

void main() {
  testWidgets('tocar un cobrador en el resumen abre AdminCobradorDetalleScreen', (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/detalle')) {
        return _json({
          'data': {
            'id': 2,
            'nombre': 'Cobrador Uno',
            'email': 'cobrador1@cobroapp.test',
            'rol': 'cobrador',
            'activo': true,
            'clientes': [],
            'prestamos': [],
            'cargas_capital': [],
          },
        });
      }

      return _json({
        'data': {
          'global': _totales(),
          'por_cobrador': [
            {'usuario_id': 2, 'nombre': 'Cobrador Uno', 'activo': true, ..._totales()},
          ],
        },
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(MaterialApp(home: AdminResumenScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byType(AdminCobradorDetalleScreen), findsNothing);

    await tester.tap(find.text('Cobrador Uno'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminCobradorDetalleScreen), findsOneWidget);
  });
}
