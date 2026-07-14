import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bloqueo_repository.dart';

/// Pantalla de bloqueo mostrada al abrir la app o volver de segundo plano.
/// Intenta biometría primero (si está activada); si falla o no está
/// activada, pide el PIN personal. Tras varios intentos fallidos (o si el
/// usuario toca "Olvidé mi PIN"), ofrece el PIN maestro de emergencia.
class BloqueoScreen extends StatefulWidget {
  const BloqueoScreen({super.key, required this.onDesbloqueado});

  final VoidCallback onDesbloqueado;

  @override
  State<BloqueoScreen> createState() => _BloqueoScreenState();
}

class _BloqueoScreenState extends State<BloqueoScreen> {
  final _bloqueoRepository = BloqueoRepository();
  final _pinController = TextEditingController();
  final _pinMaestroController = TextEditingController();

  bool _mostrandoPinMaestro = false;
  bool _hayPinMaestroDisponible = false;
  bool _intentandoBiometria = false;
  bool _verificando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _hayPinMaestroDisponible = await _bloqueoRepository.hayPinMaestroDisponible();
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
      if (resultado.intentosFallidos >= BloqueoRepository.intentosMaximosPinPersonal) {
        _error = 'Demasiados intentos fallidos.';
        if (_hayPinMaestroDisponible) _mostrandoPinMaestro = true;
      } else {
        _error =
            'PIN incorrecto (intento ${resultado.intentosFallidos} de ${BloqueoRepository.intentosMaximosPinPersonal}).';
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
