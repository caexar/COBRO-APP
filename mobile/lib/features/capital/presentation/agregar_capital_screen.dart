import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/cargas_capital_repository.dart';

/// Formulario para registrar un movimiento de capital: monto + descripción
/// opcional, con un selector para elegir si es una entrada (aporte) o una
/// salida (retiro). La fecha es siempre "ahora" (no se pide, no es editable).
class AgregarCapitalScreen extends StatefulWidget {
  const AgregarCapitalScreen({super.key, this.repository, this.dashboardRepository});

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final CargasCapitalRepository? repository;
  final DashboardRepository? dashboardRepository;

  @override
  State<AgregarCapitalScreen> createState() => _AgregarCapitalScreenState();
}

class _AgregarCapitalScreenState extends State<AgregarCapitalScreen> {
  late final _repository = widget.repository ?? CargasCapitalRepository();
  late final _dashboardRepository = widget.dashboardRepository ?? DashboardRepository();
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  String _tipo = 'carga';
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
      if (_tipo == 'retiro') {
        final resumen = await _dashboardRepository.calcularResumen();
        if (monto > resumen.saldoDisponible) {
          setState(() {
            _error = 'El monto del retiro excede el saldo disponible (${formatearMoneda(resumen.saldoDisponible)}).';
          });
          return;
        }
      }

      final descripcion = _descripcionController.text.trim();
      await _repository.crear(monto: monto, descripcion: descripcion.isEmpty ? null : descripcion, tipo: _tipo);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo registrar el movimiento de capital: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = FormateadorDinero.valorNumerico(_montoController.text);
    final puedeGuardar = monto != null && monto > 0 && !_guardando;

    return Scaffold(
      appBar: AppBar(title: Text(_tipo == 'retiro' ? 'Registrar retiro' : 'Agregar capital')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'carga', label: Text('Entrada'), icon: Icon(Icons.add)),
                  ButtonSegment(value: 'retiro', label: Text('Retiro'), icon: Icon(Icons.remove)),
                ],
                selected: {_tipo},
                onSelectionChanged: (seleccion) => setState(() => _tipo = seleccion.first),
              ),
              const SizedBox(height: 20),
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
                    : Text(_tipo == 'retiro' ? 'Registrar retiro' : 'Guardar', style: const TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
