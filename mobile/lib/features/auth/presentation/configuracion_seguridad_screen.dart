import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bloqueo_repository.dart';

/// Configuración de seguridad accesible en cualquier momento después del
/// login (a diferencia de `BloqueoConfigScreen`, que solo se ve una vez,
/// justo tras el primer login en el dispositivo). Reutiliza exactamente la
/// misma lógica de `BloqueoRepository` para biometría y PIN personal — esta
/// pantalla es solo una segunda puerta de entrada a esos mismos controles,
/// no una implementación nueva.
class ConfiguracionSeguridadScreen extends StatefulWidget {
  const ConfiguracionSeguridadScreen({super.key, this.bloqueoRepository});

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final BloqueoRepository? bloqueoRepository;

  @override
  State<ConfiguracionSeguridadScreen> createState() => _ConfiguracionSeguridadScreenState();
}

class _ConfiguracionSeguridadScreenState extends State<ConfiguracionSeguridadScreen> {
  late final _bloqueoRepository = widget.bloqueoRepository ?? BloqueoRepository();

  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _biometriaActivada = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final disponible = await _bloqueoRepository.biometriaDisponibleEnDispositivo();
    final activada = await _bloqueoRepository.biometriaHabilitada();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      // Si el dispositivo dejó de tener biometría configurada a nivel de
      // sistema (o nunca la tuvo) el toggle no debe mostrarse activado,
      // aunque la preferencia guardada localmente todavía diga que sí.
      _biometriaActivada = activada && disponible;
      _cargando = false;
    });
  }

  Future<void> _cambiarBiometria(bool valor) async {
    setState(() => _biometriaActivada = valor);
    // Al desactivarla, `BloqueoScreen` la vuelve a leer (`false`) la próxima
    // vez que se bloquee la app y cae directo al flujo de PIN personal, sin
    // intentar biometría — ver `BloqueoScreen._inicializar`.
    await _bloqueoRepository.configurarBiometria(valor);
  }

  Future<void> _abrirCambiarPin() async {
    final cambiado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCambiarPin(bloqueoRepository: _bloqueoRepository),
    );

    if (cambiado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN actualizado correctamente.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de seguridad')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Usar huella / Face ID'),
                      subtitle: Text(
                        _biometriaDisponible
                            ? 'Además del PIN, para desbloquear más rápido.'
                            : 'Este dispositivo no tiene huella ni Face ID configurados. '
                                  'Actívala primero en los ajustes de tu teléfono para poder usarla aquí.',
                      ),
                      value: _biometriaActivada,
                      onChanged: _biometriaDisponible ? _cambiarBiometria : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.pin_outlined),
                      title: const Text('Cambiar PIN personal'),
                      subtitle: const Text('El PIN que usas para desbloquear la app.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _abrirCambiarPin,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Pide el PIN actual (verificado con la misma lógica que desbloquea la
/// app), luego el nuevo PIN con las mismas reglas de validación que ya usa
/// `BloqueoConfigScreen` (4 a 6 dígitos), y lo guarda reemplazando el hash
/// anterior. No toca el PIN maestro (individual ni global) para nada.
class _DialogoCambiarPin extends StatefulWidget {
  const _DialogoCambiarPin({required this.bloqueoRepository});

  final BloqueoRepository bloqueoRepository;

  @override
  State<_DialogoCambiarPin> createState() => _DialogoCambiarPinState();
}

class _DialogoCambiarPinState extends State<_DialogoCambiarPin> {
  final _formKey = GlobalKey<FormState>();
  final _pinActualController = TextEditingController();
  final _pinNuevoController = TextEditingController();
  final _pinConfirmarController = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _pinActualController.dispose();
    _pinNuevoController.dispose();
    _pinConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinNuevoController.text != _pinConfirmarController.text) {
      setState(() => _error = 'Los PIN no coinciden.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await widget.bloqueoRepository.verificarPinPersonal(_pinActualController.text);

    if (!resultado.correcto) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'El PIN actual no es correcto.';
      });
      return;
    }

    await widget.bloqueoRepository.configurarPinPersonal(_pinNuevoController.text);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar PIN personal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _pinActualController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                enabled: !_guardando,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'PIN actual', counterText: ''),
                validator: (valor) => (valor == null || valor.isEmpty) ? 'Ingresa tu PIN actual' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinNuevoController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                enabled: !_guardando,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nuevo PIN', counterText: ''),
                validator: (valor) {
                  if (valor == null || valor.length < 4 || valor.length > 6) {
                    return 'El PIN debe tener entre 4 y 6 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinConfirmarController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                enabled: !_guardando,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Confirmar nuevo PIN', counterText: ''),
                validator: (valor) => (valor == null || valor.isEmpty) ? 'Confirma el nuevo PIN' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
