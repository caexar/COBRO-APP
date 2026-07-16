import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/admin_repository.dart';

/// Totales de cartera: capital prestado, total cobrado y cartera en mora,
/// global y desglosado por cobrador.
class AdminResumenScreen extends StatefulWidget {
  const AdminResumenScreen({super.key});

  @override
  State<AdminResumenScreen> createState() => _AdminResumenScreenState();
}

class _AdminResumenScreenState extends State<AdminResumenScreen> {
  final _repository = AdminRepository();

  ResumenAdmin? _resumen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);

    try {
      final resumen = await _repository.obtenerResumen();
      if (!mounted) return;
      setState(() => _resumen = resumen);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Resumen')), body: SafeArea(child: _cuerpo()));
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final resumen = _resumen;
    if (resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Global', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TarjetaTotales(totales: resumen.global),
          const SizedBox(height: 24),
          Text('Por cobrador', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (resumen.porCobrador.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No hay cobradores registrados.'))
          else
            for (final cobrador in resumen.porCobrador) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cobrador.nombre,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            cobrador.activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 12,
                              color: cobrador.activo ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FilasTotales(totales: cobrador.totales),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _TarjetaTotales extends StatelessWidget {
  const _TarjetaTotales({required this.totales});

  final ResumenTotales totales;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(padding: const EdgeInsets.all(20), child: _FilasTotales(totales: totales)),
    );
  }
}

class _FilasTotales extends StatelessWidget {
  const _FilasTotales({required this.totales});

  final ResumenTotales totales;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _fila(context, 'Capital prestado', totales.capitalPrestado),
        _fila(context, 'Total cobrado', totales.totalCobrado),
        _fila(context, 'Cartera en mora', totales.carteraEnMora, resaltarSiPositivo: true),
        _fila(context, 'Saldo disponible', totales.saldoDisponible),
        const Divider(),
        _fila(context, 'Ganancia por interés', totales.gananciaInteres),
        _fila(context, 'Ganancia por extras', totales.gananciaExtra),
      ],
    );
  }

  Widget _fila(BuildContext context, String etiqueta, double valor, {bool resaltarSiPositivo = false}) {
    final resaltar = resaltarSiPositivo && valor > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta),
          Text(
            formatearMoneda(valor),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: resaltar ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
