import 'package:cobro_app/app.dart';
import 'package:cobro_app/features/admin/presentation/admin_panel_screen.dart';
import 'package:cobro_app/features/auth/data/auth_repository.dart';
import 'package:cobro_app/features/auth/data/bloqueo_repository.dart';
import 'package:cobro_app/features/dashboard/data/dashboard_repository.dart';
import 'package:cobro_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula una sesión ya iniciada (con el rol indicado) sin tocar la red ni
/// flutter_secure_storage.
class _AuthRepositoryFalso extends AuthRepository {
  _AuthRepositoryFalso({required this.rol});

  final String rol;

  @override
  Future<bool> haySesionActiva() async => true;

  @override
  Future<String?> rolUsuarioActual() async => rol;

  @override
  Future<String?> nombreUsuarioActual() async => 'Ana Cobradora';

  @override
  Future<void> sincronizarPinMaestro() async {}

  @override
  Future<void> cerrarSesion() async {}
}

/// Simula el bloqueo ya configurado, sin biometría ni PIN maestro, y
/// acepta cualquier PIN como correcto (no nos interesa probar el PIN en sí
/// en este test, solo qué pantalla aparece después de desbloquear).
class _BloqueoRepositoryFalso extends BloqueoRepository {
  @override
  Future<bool> tieneBloqueoConfigurado() async => true;

  @override
  Future<bool> biometriaHabilitada() async => false;

  @override
  Future<bool> hayPinMaestroDisponible() async => false;

  @override
  Future<ResultadoVerificacionPin> verificarPinPersonal(String pin) async {
    return const ResultadoVerificacionPin(correcto: true, intentosFallidos: 0);
  }
}

/// Evita que el dashboard de cobrador toque la base de datos real (que no
/// está disponible en este entorno de pruebas) al calcular su resumen.
class _DashboardRepositoryFalso extends DashboardRepository {
  @override
  Future<ResumenDashboard> calcularResumen({DateTime? ahora}) async {
    return const ResumenDashboard(
      saldoDisponible: 0,
      carteraPorCobrar: 0,
      entradasHoy: 0,
      entradasUltimos7Dias: 0,
      gananciaInteres: 0,
      gananciaExtras: 0,
    );
  }
}

Future<void> _desbloquear(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, '1234');
  await tester.tap(find.text('Desbloquear'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un usuario admin ve su propio panel, no el dashboard de cobrador', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppEntryPoint(
          authRepository: _AuthRepositoryFalso(rol: 'admin'),
          bloqueoRepository: _BloqueoRepositoryFalso(),
        ),
      ),
    );

    await _desbloquear(tester);

    expect(find.byType(AdminPanelScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.text('Clientes'), findsNothing);
    expect(find.text('Usuarios cobradores'), findsOneWidget);
    expect(find.text('Ana Cobradora · Administrador'), findsOneWidget);
  });

  testWidgets('un usuario cobrador sí ve el dashboard con Clientes/Préstamos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppEntryPoint(
          authRepository: _AuthRepositoryFalso(rol: 'cobrador'),
          bloqueoRepository: _BloqueoRepositoryFalso(),
          dashboardRepository: _DashboardRepositoryFalso(),
        ),
      ),
    );

    await _desbloquear(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(AdminPanelScreen), findsNothing);
    expect(find.text('Ana Cobradora · Cobrador'), findsOneWidget);

    // Las tarjetas financieras arriba del dashboard ocupan más que el
    // viewport de la prueba: hay que bajar para que "Clientes" se construya.
    await tester.scrollUntilVisible(find.text('Clientes'), 300, scrollable: find.byType(Scrollable));
    expect(find.text('Clientes'), findsOneWidget);
  });
}
