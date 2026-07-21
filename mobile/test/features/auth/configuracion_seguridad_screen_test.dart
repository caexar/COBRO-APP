import 'package:cobro_app/core/utils/atajo_miles_repository.dart';
import 'package:cobro_app/features/auth/data/bloqueo_repository.dart';
import 'package:cobro_app/features/auth/presentation/configuracion_seguridad_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evita tocar `flutter_secure_storage` real: solo interesa que la pantalla
/// llame a los métodos correctos según lo que el cobrador haga con el switch.
class _AtajoMilesRepositoryFalso extends AtajoMilesRepository {
  bool activado = true;

  @override
  Future<bool> estaActivado() async => activado;

  @override
  Future<void> configurar(bool valor) async => activado = valor;
}

/// Simula `BloqueoRepository` sin tocar `local_auth` ni
/// `flutter_secure_storage` real — la lógica de biometría/PIN en sí ya está
/// cubierta donde vive (`BloqueoRepository`); acá solo interesa que la
/// pantalla llame a los métodos correctos según lo que el cobrador haga.
class _BloqueoRepositoryFalso extends BloqueoRepository {
  _BloqueoRepositoryFalso({this.biometriaDisponible = true});

  final bool biometriaDisponible;
  bool biometriaActivada = false;

  /// Último valor con el que se llamó a `configurarBiometria`, o `null` si
  /// nunca se llamó.
  bool? biometriaConfiguradaCon;

  /// Último PIN con el que se llamó a `configurarPinPersonal`, o `null` si
  /// nunca se llamó (ej. porque el PIN actual no era correcto).
  String? pinConfigurado;

  @override
  Future<bool> biometriaDisponibleEnDispositivo() async => biometriaDisponible;

  @override
  Future<bool> biometriaHabilitada() async => biometriaActivada;

  @override
  Future<void> configurarBiometria(bool habilitada) async {
    biometriaConfiguradaCon = habilitada;
    biometriaActivada = habilitada;
  }

  @override
  Future<ResultadoVerificacionPin> verificarPinPersonal(String pin) async {
    final correcto = pin == '1234';
    return ResultadoVerificacionPin(correcto: correcto, intentosFallidos: correcto ? 0 : 1);
  }

  @override
  Future<void> configurarPinPersonal(String pin) async {
    pinConfigurado = pin;
  }
}

Future<void> _abrirDialogoCambiarPin(WidgetTester tester) async {
  await tester.tap(find.text('Cambiar PIN personal'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('activa la biometría cuando está disponible en el dispositivo', (tester) async {
    final repository = _BloqueoRepositoryFalso();

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionSeguridadScreen(
          bloqueoRepository: repository,
          atajoMilesRepository: _AtajoMilesRepositoryFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final biometriaFinder = find.widgetWithText(SwitchListTile, 'Usar huella / Face ID');
    final switchTile = tester.widget<SwitchListTile>(biometriaFinder);
    expect(switchTile.value, isFalse);
    expect(switchTile.onChanged, isNotNull);

    await tester.tap(biometriaFinder);
    await tester.pumpAndSettle();

    expect(repository.biometriaConfiguradaCon, isTrue);
    expect(tester.widget<SwitchListTile>(biometriaFinder).value, isTrue);
  });

  testWidgets('sin biometría configurada en el dispositivo, el switch queda deshabilitado con un mensaje', (
    tester,
  ) async {
    final repository = _BloqueoRepositoryFalso(biometriaDisponible: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionSeguridadScreen(
          bloqueoRepository: repository,
          atajoMilesRepository: _AtajoMilesRepositoryFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final biometriaFinder = find.widgetWithText(SwitchListTile, 'Usar huella / Face ID');
    final switchTile = tester.widget<SwitchListTile>(biometriaFinder);
    expect(switchTile.value, isFalse);
    expect(switchTile.onChanged, isNull);
    expect(find.textContaining('Actívala primero en los ajustes de tu teléfono'), findsOneWidget);

    // Tocar un switch deshabilitado no hace nada (ni crashea).
    await tester.tap(biometriaFinder);
    await tester.pumpAndSettle();
    expect(repository.biometriaConfiguradaCon, isNull);
  });

  testWidgets('cambiar PIN: el PIN actual incorrecto rechaza y no guarda', (tester) async {
    final repository = _BloqueoRepositoryFalso();

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionSeguridadScreen(
          bloqueoRepository: repository,
          atajoMilesRepository: _AtajoMilesRepositoryFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _abrirDialogoCambiarPin(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'PIN actual'), '0000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nuevo PIN'), '5678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nuevo PIN'), '5678');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El PIN actual no es correcto.'), findsOneWidget);
    expect(repository.pinConfigurado, isNull);
    // El diálogo sigue abierto: no se guardó ni se cerró.
    expect(find.text('Cambiar PIN personal'), findsWidgets);
  });

  testWidgets('cambiar PIN: PIN actual correcto y nuevo PIN válido guarda y avisa', (tester) async {
    final repository = _BloqueoRepositoryFalso();

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionSeguridadScreen(
          bloqueoRepository: repository,
          atajoMilesRepository: _AtajoMilesRepositoryFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _abrirDialogoCambiarPin(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'PIN actual'), '1234');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nuevo PIN'), '5678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nuevo PIN'), '5678');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.pinConfigurado, '5678');
    expect(find.text('PIN actualizado correctamente.'), findsOneWidget);
  });

  testWidgets('el switch de atajo de miles refleja la preferencia guardada y la actualiza al tocarlo', (
    tester,
  ) async {
    final atajoMilesRepository = _AtajoMilesRepositoryFalso();

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionSeguridadScreen(
          bloqueoRepository: _BloqueoRepositoryFalso(),
          atajoMilesRepository: atajoMilesRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final atajoFinder = find.widgetWithText(SwitchListTile, 'Atajo de miles al ingresar montos');
    expect(tester.widget<SwitchListTile>(atajoFinder).value, isTrue);

    await tester.tap(atajoFinder);
    await tester.pumpAndSettle();

    expect(atajoMilesRepository.activado, isFalse);
    expect(tester.widget<SwitchListTile>(atajoFinder).value, isFalse);
  });
}
