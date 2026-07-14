import 'dart:async';

import 'package:flutter/material.dart';

import 'features/admin/presentation/admin_panel_screen.dart';
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
  const AppEntryPoint({super.key, this.authRepository, this.bloqueoRepository});

  /// Inyectables solo para pruebas; en la app real siempre se usan las
  /// instancias por defecto (ver `_AppEntryPointState`).
  final AuthRepository? authRepository;
  final BloqueoRepository? bloqueoRepository;

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> with WidgetsBindingObserver {
  late final _authRepository = widget.authRepository ?? AuthRepository();
  late final _bloqueoRepository = widget.bloqueoRepository ?? BloqueoRepository();

  bool _cargandoInicial = true;
  bool _haySesion = false;
  bool _bloqueoConfigurado = false;
  bool _desbloqueada = false;
  String? _rol;
  String? _nombre;

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
    final rol = haySesion ? await _authRepository.rolUsuarioActual() : null;
    final nombre = haySesion ? await _authRepository.nombreUsuarioActual() : null;

    if (!mounted) return;
    setState(() {
      _haySesion = haySesion;
      _bloqueoConfigurado = bloqueoConfigurado;
      _rol = rol;
      _nombre = nombre;
      _cargandoInicial = false;
    });

    if (haySesion) {
      unawaited(_authRepository.sincronizarPinMaestro());
    }
  }

  Future<void> _alIniciarSesionExitoso() async {
    final bloqueoConfigurado = await _bloqueoRepository.tieneBloqueoConfigurado();
    final rol = await _authRepository.rolUsuarioActual();
    final nombre = await _authRepository.nombreUsuarioActual();
    if (!mounted) return;

    setState(() {
      _haySesion = true;
      _bloqueoConfigurado = bloqueoConfigurado;
      _rol = rol;
      _nombre = nombre;
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
      _rol = null;
      _nombre = null;
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
      return BloqueoConfigScreen(
        onConfigurado: _alConfigurarBloqueoExitoso,
        bloqueoRepository: _bloqueoRepository,
      );
    }

    if (!_desbloqueada) {
      return BloqueoScreen(
        onDesbloqueado: _alDesbloquear,
        onCerrarSesion: _cerrarSesion,
        bloqueoRepository: _bloqueoRepository,
      );
    }

    // Las pantallas de cobrador (clientes, préstamos, pagos) son exclusivas
    // de ese rol; un admin ve su propio panel.
    if (_rol == 'admin') {
      return AdminPanelScreen(onCerrarSesion: _cerrarSesion, nombre: _nombre ?? '');
    }

    return DashboardPlaceholderScreen(onCerrarSesion: _cerrarSesion, nombre: _nombre ?? '');
  }
}
