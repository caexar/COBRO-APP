import 'dart:async';

import 'package:flutter/material.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/bloqueo_repository.dart';
import 'features/auth/presentation/bloqueo_config_screen.dart';
import 'features/auth/presentation/bloqueo_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_placeholder_screen.dart';

class CobroApp extends StatelessWidget {
  const CobroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CobroApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const AppEntryPoint(),
    );
  }
}

/// Decide qué pantalla mostrar (login → configurar bloqueo → bloqueo →
/// dashboard) y vuelve a exigir el bloqueo cada vez que la app se abre o
/// vuelve de segundo plano.
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> with WidgetsBindingObserver {
  final _authRepository = AuthRepository();
  final _bloqueoRepository = BloqueoRepository();

  bool _cargandoInicial = true;
  bool _haySesion = false;
  bool _bloqueoConfigurado = false;
  bool _desbloqueada = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluarEstadoInicial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_haySesion || !_bloqueoConfigurado) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      setState(() => _desbloqueada = false);
    } else if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _evaluarEstadoInicial() async {
    final haySesion = await _authRepository.haySesionActiva();
    final bloqueoConfigurado = await _bloqueoRepository.tieneBloqueoConfigurado();

    if (!mounted) return;
    setState(() {
      _haySesion = haySesion;
      _bloqueoConfigurado = bloqueoConfigurado;
      _cargandoInicial = false;
    });

    if (haySesion) {
      unawaited(_authRepository.sincronizarPinMaestro());
    }
  }

  Future<void> _alIniciarSesionExitoso() async {
    final bloqueoConfigurado = await _bloqueoRepository.tieneBloqueoConfigurado();
    if (!mounted) return;

    setState(() {
      _haySesion = true;
      _bloqueoConfigurado = bloqueoConfigurado;
      // Si ya tenía el bloqueo configurado de una sesión anterior en este
      // mismo dispositivo, igual debe pasar por la pantalla de bloqueo.
      _desbloqueada = false;
    });
  }

  void _alConfigurarBloqueoExitoso() {
    setState(() {
      _bloqueoConfigurado = true;
      _desbloqueada = true;
    });
  }

  void _alDesbloquear() {
    setState(() => _desbloqueada = true);
  }

  Future<void> _cerrarSesion() async {
    await _authRepository.cerrarSesion();
    if (!mounted) return;
    setState(() {
      _haySesion = false;
      _desbloqueada = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_haySesion) {
      return LoginScreen(onLoginExitoso: _alIniciarSesionExitoso);
    }

    if (!_bloqueoConfigurado) {
      return BloqueoConfigScreen(onConfigurado: _alConfigurarBloqueoExitoso);
    }

    if (!_desbloqueada) {
      return BloqueoScreen(onDesbloqueado: _alDesbloquear);
    }

    return DashboardPlaceholderScreen(onCerrarSesion: _cerrarSesion);
  }
}
