import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/cargas_capital_repository.dart';

/// Formulario para registrar una carga de capital: monto + descripción
/// opcional. La fecha es siempre "ahora" (no se pide, no es editable).
class AgregarCapitalScreen extends StatefulWidget {
  const AgregarCapitalScreen({super.key});

  @override
  State<AgregarCapitalScreen> createState() => _AgregarCapitalScreenState();
}

class _AgregarCapitalScreenState extends State<AgregarCapitalScreen> {
  final _repository = CargasCapitalRepository();
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(_alCambiarMonto);
  }

  @override
  void dispose() {
    _montoController.removeListener(_alCambiarMonto);
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _alCambiarMonto() => setState(() {});

  Future<void> _guardar() async {
    final monto = FormateadorDinero.valorNumerico(_montoController.text);
    if (monto == null || monto <= 0 || _guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final descripcion = _descripcionController.text.trim();
      await _repository.crear(monto: monto, descripcion: descripcion.isEmpty ? null : descripcion);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo registrar la carga de capital: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = FormateadorDinero.valorNumerico(_montoController.text);
    final puedeGuardar = monto != null && monto > 0 && !_guardando;

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar capital')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormateadorDinero()],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej. "Aporte inicial"',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: puedeGuardar ? _guardar : null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: _guardando
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
