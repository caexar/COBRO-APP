import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bloqueo_repository.dart';

/// Se muestra una sola vez, justo después del primer login en el
/// dispositivo, para que el cobrador defina cómo se protegerá la app.
class BloqueoConfigScreen extends StatefulWidget {
  const BloqueoConfigScreen({super.key, required this.onConfigurado, this.bloqueoRepository});

  final VoidCallback onConfigurado;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final BloqueoRepository? bloqueoRepository;

  @override
  State<BloqueoConfigScreen> createState() => _BloqueoConfigScreenState();
}

class _BloqueoConfigScreenState extends State<BloqueoConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmarPinController = TextEditingController();
  late final _bloqueoRepository = widget.bloqueoRepository ?? BloqueoRepository();

  bool _biometriaDisponible = false;
  bool _biometriaActivada = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verificarBiometriaDisponible();
  }

  Future<void> _verificarBiometriaDisponible() async {
    final disponible = await _bloqueoRepository.biometriaDisponibleEnDispositivo();
    if (mounted) setState(() => _biometriaDisponible = disponible);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmarPinController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinController.text != _confirmarPinController.text) {
      setState(() => _error = 'Los PIN no coinciden.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    await _bloqueoRepository.configurarPinPersonal(_pinController.text);
    await _bloqueoRepository.configurarBiometria(_biometriaActivada && _biometriaDisponible);

    if (!mounted) return;
    widget.onConfigurado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configura el bloqueo de la app')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Define un PIN personal de 4 a 6 dígitos para proteger la app cuando la abras o vuelvas de segundo plano.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder(), counterText: ''),
                  validator: (valor) {
                    if (valor == null || valor.length < 4 || valor.length > 6) {
                      return 'El PIN debe tener entre 4 y 6 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirmar PIN',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (valor) => (valor == null || valor.isEmpty) ? 'Confirma tu PIN' : null,
                ),
                if (_biometriaDisponible) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar huella / Face ID'),
                    subtitle: const Text('Además del PIN, para desbloquear más rápido'),
                    value: _biometriaActivada,
                    onChanged: (valor) => setState(() => _biometriaActivada = valor),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar y continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
