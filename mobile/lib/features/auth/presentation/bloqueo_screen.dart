import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bloqueo_repository.dart';

/// Pantalla de bloqueo mostrada al abrir la app o volver de segundo plano.
/// Intenta biometría primero (si está activada); si falla o no está
/// activada, pide el PIN personal. Tras varios intentos fallidos (o si el
/// usuario toca "Olvidé mi PIN"), ofrece el PIN maestro de emergencia.
class BloqueoScreen extends StatefulWidget {
  const BloqueoScreen({
    super.key,
    required this.onDesbloqueado,
    required this.onCerrarSesion,
    this.bloqueoRepository,
  });

  final VoidCallback onDesbloqueado;

  /// Cierra la sesión actual (revoca el token, limpia los datos locales de
  /// sesión) para permitir iniciar con otra cuenta. Es la misma lógica que
  /// el botón "Cerrar sesión" del menú principal.
  final Future<void> Function() onCerrarSesion;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final BloqueoRepository? bloqueoRepository;

  @override
  State<BloqueoScreen> createState() => _BloqueoScreenState();
}

class _BloqueoScreenState extends State<BloqueoScreen> {
  late final _bloqueoRepository = widget.bloqueoRepository ?? BloqueoRepository();
  final _pinController = TextEditingController();
  final _pinMaestroController = TextEditingController();

  bool _mostrandoPinMaestro = false;
  bool _hayPinMaestroDisponible = false;
  bool _intentandoBiometria = false;
  bool _verificando = false;
  bool _cerrandoSesion = false;
  int _intentosMaximos = 3;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _hayPinMaestroDisponible = await _bloqueoRepository.hayPinMaestroDisponible();
    _intentosMaximos = await _bloqueoRepository.obtenerIntentosMaximosPin();
    final biometriaActivada = await _bloqueoRepository.biometriaHabilitada();

    if (!mounted) return;
    setState(() {});

    if (biometriaActivada) {
      await _intentarBiometria();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinMaestroController.dispose();
    super.dispose();
  }

  Future<void> _intentarBiometria() async {
    setState(() => _intentandoBiometria = true);
    final exito = await _bloqueoRepository.autenticarConBiometria();
    if (!mounted) return;

    setState(() => _intentandoBiometria = false);
    if (exito) widget.onDesbloqueado();
  }

  Future<void> _verificarPin() async {
    if (_pinController.text.isEmpty) return;

    setState(() {
      _verificando = true;
      _error = null;
    });

    final resultado = await _bloqueoRepository.verificarPinPersonal(_pinController.text);
    if (!mounted) return;

    if (resultado.correcto) {
      widget.onDesbloqueado();
      return;
    }

    setState(() {
      _verificando = false;
      _pinController.clear();
      if (resultado.intentosFallidos >= _intentosMaximos) {
        _error = 'Demasiados intentos fallidos.';
        if (_hayPinMaestroDisponible) _mostrandoPinMaestro = true;
      } else {
        _error = 'PIN incorrecto (intento ${resultado.intentosFallidos} de $_intentosMaximos).';
      }
    });
  }

  Future<void> _verificarPinMaestro() async {
    if (_pinMaestroController.text.isEmpty) return;

    setState(() {
      _verificando = true;
      _error = null;
    });

    final correcto = await _bloqueoRepository.verificarPinMaestro(_pinMaestroController.text);
    if (!mounted) return;

    if (correcto) {
      widget.onDesbloqueado();
      return;
    }

    setState(() {
      _verificando = false;
      _pinMaestroController.clear();
      _error = 'PIN maestro incorrecto.';
    });
  }

  /// Salida alterna para quien no quiere seguir con la cuenta ya logueada
  /// en este dispositivo. Pide confirmación porque esta pantalla se ve muy
  /// seguido (cada vez que se abre o retoma la app) y un toque accidental
  /// no debería cerrar una sesión que sigue siendo válida.
  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar la sesión actual e iniciar con otra cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _cerrandoSesion = true);
    await widget.onCerrarSesion();
    // No hace falta más setState: en cuanto onCerrarSesion actualiza el
    // estado del padre (AppEntryPoint), esta pantalla deja de existir.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'CobroApp bloqueada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                if (_intentandoBiometria)
                  const Center(child: CircularProgressIndicator())
                else if (!_mostrandoPinMaestro) ...[
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    enabled: !_verificando,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder(), counterText: ''),
                    onSubmitted: (_) => _verificarPin(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _verificando ? null : _verificarPin,
                    child: const Text('Desbloquear'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final biometriaActivada = await _bloqueoRepository.biometriaHabilitada();
                      if (biometriaActivada) await _intentarBiometria();
                    },
                    child: const Text('Usar huella / Face ID'),
                  ),
                  if (_hayPinMaestroDisponible)
                    TextButton(
                      onPressed: () => setState(() {
                        _mostrandoPinMaestro = true;
                        _error = null;
                      }),
                      child: const Text('Olvidé mi PIN'),
                    ),
                ] else ...[
                  Text(
                    'Ingresa el PIN maestro de emergencia.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinMaestroController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    enabled: !_verificando,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN maestro',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _verificarPinMaestro(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _verificando ? null : _verificarPinMaestro,
                    child: const Text('Desbloquear con PIN maestro'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _mostrandoPinMaestro = false;
                      _error = null;
                    }),
                    child: const Text('Volver a mi PIN personal'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _cerrandoSesion ? null : _confirmarCerrarSesion,
                  child: _cerrandoSesion
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cerrar sesión e iniciar con otra cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
