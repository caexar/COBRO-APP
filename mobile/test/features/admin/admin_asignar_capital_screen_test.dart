import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/core/utils/atajo_miles_repository.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/presentation/admin_asignar_capital_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

/// Desactivado en estas pruebas para que el monto escrito se interprete tal
/// cual — el comportamiento del atajo en sí ya está cubierto en
/// `formato_dinero_test.dart`.
class _AtajoMilesRepositoryFalso extends AtajoMilesRepository {
  @override
  Future<bool> estaActivado() async => false;
}

http.Response _json(Object cuerpo, {int status = 200}) {
  return http.Response(jsonEncode(cuerpo), status, headers: {'content-type': 'application/json'});
}

/// Envuelve la pantalla en una ruta empujada desde una "Home" de prueba, para
/// poder verificar que un guardado exitoso hace `pop` (volviendo a ver la
/// Home) en vez de solo revisar el estado interno del formulario.
Widget _appConHomeYFormulario(AdminRepository repository) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            child: const Text('Ir a asignar saldo'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminAsignarCapitalScreen(
                usuarioId: 9,
                nombreCobrador: 'Luis',
                repository: repository,
                atajoMilesRepository: _AtajoMilesRepositoryFalso(),
              ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('guarda una carga, manda el body correcto a POST /admin/cargas-capital y vuelve atrás', (tester) async {
    Map<String, dynamic>? cuerpoEnviado;

    final mock = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/admin/cargas-capital');
      cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;

      return _json({
        'data': {'id': 1, 'usuario_id': 9, 'tipo': 'carga', 'monto': 300000, 'descripcion': 'Fondeo'},
      }, status: 201);
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(_appConHomeYFormulario(repository));

    await tester.tap(find.text('Ir a asignar saldo'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAsignarCapitalScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '300000');
    await tester.enterText(find.widgetWithText(TextField, 'Descripción (opcional)'), 'Fondeo');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Asignar saldo'));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado, {'usuario_id': 9, 'tipo': 'carga', 'monto': 300000.0, 'descripcion': 'Fondeo'});

    // Guardó con éxito: hizo pop, ya no está la pantalla del formulario.
    expect(find.byType(AdminAsignarCapitalScreen), findsNothing);
    expect(find.text('Ir a asignar saldo'), findsOneWidget);
  });

  testWidgets('seleccionar "Retiro" manda tipo=retiro en el body', (tester) async {
    Map<String, dynamic>? cuerpoEnviado;

    final mock = MockClient((request) async {
      cuerpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'data': {'id': 2, 'usuario_id': 9, 'tipo': 'retiro', 'monto': 50000, 'descripcion': null},
      }, status: 201);
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(_appConHomeYFormulario(repository));
    await tester.tap(find.text('Ir a asignar saldo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retiro'));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '50000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar retiro'));
    await tester.pumpAndSettle();

    expect(cuerpoEnviado!['tipo'], 'retiro');
    expect(cuerpoEnviado!.containsKey('descripcion'), isFalse);
  });

  testWidgets('un error del servidor se muestra en pantalla y no hace pop', (tester) async {
    final mock = MockClient((request) async {
      return _json({'message': 'El cobrador indicado no existe.'}, status: 422);
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(_appConHomeYFormulario(repository));
    await tester.tap(find.text('Ir a asignar saldo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Asignar saldo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('El cobrador indicado no existe.'), findsOneWidget);
    // Sigue en el formulario: no hizo pop.
    expect(find.byType(AdminAsignarCapitalScreen), findsOneWidget);
  });
}
