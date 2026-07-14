import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../pagos/presentation/historial_pagos_screen.dart';
import '../../pagos/presentation/registrar_pago_screen.dart';
import '../data/prestamos_repository.dart';

/// Detalle de un préstamo ya guardado: capital, interés, extras y cuotas
/// generadas con su estado (pendiente/pagada/en_mora).
class PrestamoDetalleScreen extends StatefulWidget {
  const PrestamoDetalleScreen({super.key, required this.prestamoId});

  final int prestamoId;

  @override
  State<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends State<PrestamoDetalleScreen> {
  final _repository = PrestamosRepository();
  PrestamoDetalle? _detalle;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final detalle = await _repository.obtenerDetalle(widget.prestamoId);
    if (!mounted) return;
    setState(() => _detalle = detalle);
  }

  Future<void> _registrarPago() async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => RegistrarPagoScreen(prestamoId: widget.prestamoId)));
    if (guardado == true) _cargar();
  }

  void _verHistorialPagos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => HistorialPagosScreen(prestamoId: widget.prestamoId)));
  }

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle;
    final puedeRegistrarPago = detalle != null && detalle.prestamo.estado != 'anulado' && detalle.prestamo.estado != 'pagado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del préstamo'),
        actions: [
          IconButton(
            onPressed: detalle == null ? null : _verHistorialPagos,
            icon: const Icon(Icons.history),
            tooltip: 'Historial de pagos',
          ),
        ],
      ),
      floatingActionButton: puedeRegistrarPago
          ? FloatingActionButton.extended(
              onPressed: _registrarPago,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registrar pago'),
            )
          : null,
      body: detalle == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FilaResumen(etiqueta: 'Capital', valor: formatearMoneda(detalle.prestamo.montoCapital)),
                          _FilaResumen(
                            etiqueta: 'Interés (${detalle.prestamo.porcentajeInteres.toStringAsFixed(0)}%)',
                            valor: formatearMoneda(detalle.montoInteres),
                          ),
                          if (detalle.extras.isNotEmpty)
                            _FilaResumen(etiqueta: 'Extras', valor: formatearMoneda(detalle.montoExtras)),
                          const Divider(),
                          _FilaResumen(
                            etiqueta: 'Total a pagar',
                            valor: formatearMoneda(detalle.montoTotal),
                            destacado: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estado: ${detalle.prestamo.estado}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (detalle.extras.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Montos extra', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          for (final extra in detalle.extras)
                            ListTile(title: Text(extra.concepto), trailing: Text(formatearMoneda(extra.valor))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Cuotas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final cuota in detalle.cuotas)
                          ListTile(
                            leading: CircleAvatar(child: Text('${cuota.numeroCuota}')),
                            title: Text(formatearMoneda(cuota.montoEsperado)),
                            subtitle: Text(_formatearFecha(cuota.fechaEsperada)),
                            trailing: _EtiquetaEstado(estado: cuota.estado),
                          ),
                      ],
                    ),
                  ),
                ],
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

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.etiqueta, required this.valor, this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (estado) {
      'pagada' => (Colors.green, 'Pagada'),
      'en_mora' => (Colors.red, 'En mora'),
      _ => (Colors.grey, 'Pendiente'),
    };

    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
