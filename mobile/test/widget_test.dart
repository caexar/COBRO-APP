import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cobro_app/app.dart';

void main() {
  testWidgets('CobroApp muestra un indicador de carga mientras revisa la sesión guardada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CobroApp());

    // No se usa pumpAndSettle: la app decide qué pantalla mostrar (login,
    // configurar bloqueo, bloqueo o dashboard) tras leer flutter_secure_storage
    // de forma asíncrona, que depende de un platform channel no disponible en
    // este entorno de pruebas. Solo verificamos el estado de carga inicial.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
