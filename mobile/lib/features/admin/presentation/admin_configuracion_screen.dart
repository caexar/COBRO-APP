import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

/// Configuración global: tasas de interés por defecto, política de mora por
/// defecto y PIN maestro global. El PIN nunca se muestra en texto plano —
/// solo se permite escribir uno nuevo (o quitar el actual).
class AdminConfiguracionScreen extends StatefulWidget {
  const AdminConfiguracionScreen({super.key});

  @override
  State<AdminConfiguracionScreen> createState() => _AdminConfiguracionScreenState();
}

class _AdminConfiguracionScreenState extends State<AdminConfiguracionScreen> {
  static const _politicas = {'mantener': 'Mantener', 'siguiente_pago': 'Siguiente pago', 'sumar_total': 'Sumar total'};

  final _repository = AdminRepository();
  final _tasasController = TextEditingController();
  final _pinMaestroController = TextEditingController();
  final _intentosController = TextEditingController();

  ConfiguracionAdmin? _configuracion;
  String? _politicaSeleccionada;
  bool _quitarPinMaestro = false;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tasasController.dispose();
    _pinMaestroController.dispose();
    _intentosController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final configuracion = await _repository.obtenerConfiguracion();
      if (!mounted) return;
      setState(() {
        _configuracion = configuracion;
        _tasasController.text = configuracion.tasasInteresDefault.map((t) => t.toStringAsFixed(0)).join(', ');
        _politicaSeleccionada = configuracion.politicaMoraDefault;
        _intentosController.text = configuracion.intentosPinAntesDeMaestro.toString();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  List<double>? _parsearTasas() {
    final partes = _tasasController.text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final tasas = <double>[];

    for (final parte in partes) {
      final valor = double.tryParse(parte);
      if (valor == null) return null;
      tasas.add(valor);
    }

    return tasas;
  }

  Future<void> _guardar() async {
    final tasas = _parsearTasas();
    if (tasas == null || tasas.isEmpty) {
      setState(() => _error = 'Las tasas deben ser números separados por comas, ej: 10, 20, 30, 40');
      return;
    }

    final pinMaestro = _pinMaestroController.text.trim();
    if (!_quitarPinMaestro && pinMaestro.isNotEmpty && (pinMaestro.length < 4 || pinMaestro.length > 10)) {
      setState(() => _error = 'El PIN maestro debe tener entre 4 y 10 caracteres.');
      return;
    }

    final intentos = int.tryParse(_intentosController.text.trim());
    if (intentos == null || intentos < 1 || intentos > 10) {
      setState(() => _error = 'Los intentos de PIN deben ser un número entero entre 1 y 10.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final cambios = <String, dynamic>{
        'tasas_interes_default': tasas,
        'politica_mora_default': _politicaSeleccionada,
        'intentos_pin_antes_de_maestro': intentos,
      };

      if (_quitarPinMaestro) {
        cambios['pin_maestro'] = null;
      } else if (pinMaestro.isNotEmpty) {
        cambios['pin_maestro'] = pinMaestro;
      }

      final actualizada = await _repository.actualizarConfiguracion(cambios);

      if (!mounted) return;
      setState(() {
        _configuracion = actualizada;
        _pinMaestroController.clear();
        _quitarPinMaestro = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada.')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Configuración')), body: SafeArea(child: _cuerpo()));
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_configuracion == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No se pudo cargar la configuración.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tasas de interés por defecto', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _tasasController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '10, 20, 30, 40',
              helperText: 'Porcentajes separados por comas. Solo son valores sugeridos para la app.',
            ),
          ),
          const SizedBox(height: 24),
          Text('Política de mora por defecto', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entrada in _politicas.entries)
                ChoiceChip(
                  label: Text(entrada.value, style: const TextStyle(fontSize: 16)),
                  selected: _politicaSeleccionada == entrada.key,
                  onSelected: (_) => setState(() => _politicaSeleccionada = entrada.key),
                ),
            ],
          ),
          const Text(
            'Se usa cuando un préstamo nuevo no indica su propia política de mora.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Text('PIN maestro global', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            _configuracion!.pinMaestroConfigurado ? 'Ya hay un PIN maestro configurado.' : 'No hay PIN maestro configurado.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinMaestroController,
            keyboardType: TextInputType.number,
            obscureText: true,
            enabled: !_quitarPinMaestro,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Nuevo PIN maestro (opcional)',
              helperText: 'Nunca se muestra el valor actual. Déjalo en blanco para no cambiarlo.',
            ),
          ),
          if (_configuracion!.pinMaestroConfigurado)
            CheckboxListTile(
              value: _quitarPinMaestro,
              onChanged: (valor) => setState(() => _quitarPinMaestro = valor ?? false),
              title: const Text('Quitar el PIN maestro actual'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 24),
          Text('Intentos de PIN antes de PIN maestro', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _intentosController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '3',
              helperText:
                  'Cuántos intentos fallidos del PIN personal se toleran, en cualquier '
                  'dispositivo, antes de ofrecer el PIN maestro de emergencia (1-10).',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            child: _guardando
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar configuración', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
