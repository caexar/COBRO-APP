import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/presentation/admin_cobrador_detalle_screen.dart';
import 'package:cobro_app/features/admin/presentation/admin_usuario_form_screen.dart';
import 'package:cobro_app/features/admin/presentation/admin_usuarios_list_screen.dart';
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

void main() {
  testWidgets('tocar un cobrador abre el formulario de edición, nunca el detalle financiero', (tester) async {
    final mock = MockClient((request) async {
      return _json({
        'data': [
          {'id': 2, 'nombre': 'Cobrador Uno', 'email': 'cobrador1@cobroapp.test', 'rol': 'cobrador', 'activo': true},
        ],
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(MaterialApp(home: AdminUsuariosListScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Sin acción explícita (popup "Editar"/etc.), tocar la fila entera no debe
    // navegar al detalle financiero del cobrador.
    expect(find.byType(AdminCobradorDetalleScreen), findsNothing);

    await tester.tap(find.text('Cobrador Uno'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminUsuarioFormScreen), findsOneWidget);
    expect(find.byType(AdminCobradorDetalleScreen), findsNothing);
  });
}
