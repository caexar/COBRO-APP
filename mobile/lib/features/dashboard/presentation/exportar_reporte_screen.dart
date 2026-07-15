import 'package:flutter/material.dart';

import '../../clientes/data/clientes_repository.dart';
import '../../prestamos/presentation/seleccionar_cliente_sheet.dart';
import '../data/reportes_repository.dart';

/// Formulario para exportar el reporte en CSV: rango de fechas opcional
/// (aplica solo al historial de pagos) y cliente opcional.
class ExportarReporteScreen extends StatefulWidget {
  const ExportarReporteScreen({super.key});

  @override
  State<ExportarReporteScreen> createState() => _ExportarReporteScreenState();
}

class _ExportarReporteScreenState extends State<ExportarReporteScreen> {
  final _repository = ReportesRepository();

  DateTime? _desde;
  DateTime? _hasta;
  Cliente? _cliente;
  bool _exportando = false;
  String? _error;

  Future<void> _elegirDesde() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _desde = fecha);
  }

  Future<void> _elegirHasta() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _hasta = fecha);
  }

  Future<void> _elegirCliente() async {
    final cliente = await mostrarSeleccionarClienteSheet(context);
    if (cliente != null) setState(() => _cliente = cliente);
  }

  Future<void> _exportar() async {
    if (_exportando) return;

    setState(() {
      _exportando = true;
      _error = null;
    });

    try {
      await _repository.exportarYCompartir(
        desde: _desde,
        // "hasta" debe incluir todo ese día, no solo su medianoche.
        hasta: _hasta?.add(const Duration(days: 1, seconds: -1)),
        clienteId: _cliente?.id,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo exportar el reporte: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar reporte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'El rango de fechas y el cliente solo filtran el historial de pagos del CSV; '
                'el resumen y el listado de préstamos siempre salen completos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _elegirDesde,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Desde (opcional)', border: OutlineInputBorder()),
                  child: Text(_desde == null ? 'Sin límite inferior' : _formatearFecha(_desde!)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _elegirHasta,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hasta (opcional)', border: OutlineInputBorder()),
                  child: Text(_hasta == null ? 'Sin límite superior' : _formatearFecha(_hasta!)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _elegirCliente,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Cliente (opcional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _cliente == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _cliente = null),
                          ),
                  ),
                  child: Text(_cliente?.nombre ?? 'Todos los clientes'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _exportando ? null : _exportar,
                icon: const Icon(Icons.ios_share),
                label: _exportando
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Exportar CSV', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
