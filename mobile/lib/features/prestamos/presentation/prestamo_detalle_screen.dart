import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../pagos/data/pagos_repository.dart';
import '../../pagos/presentation/historial_pagos_screen.dart';
import '../../pagos/presentation/registrar_pago_screen.dart';
import '../data/prestamos_repository.dart';

/// Detalle de un préstamo ya guardado: capital, interés, extras y cuotas
/// generadas con su estado (pendiente/pagada/en_mora).
class PrestamoDetalleScreen extends StatefulWidget {
  const PrestamoDetalleScreen({
    super.key,
    required this.prestamoId,
    this.repository,
    this.pagosRepository,
    this.onPagoRegistrado,
  });

  final int prestamoId;

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final PrestamosRepository? repository;
  final PagosRepository? pagosRepository;

  /// Se llama justo después de que un pago se registra con éxito (antes de
  /// que el usuario navegue de vuelta) — pensado para que `RutaDetalleScreen`
  /// marque el ruta_item correspondiente como cobrado sin tener que
  /// duplicar esta pantalla ni la de `RegistrarPagoScreen`. `null` (default)
  /// para el resto de quienes navegan acá (`CobrosPendientesScreen`,
  /// `HistorialPrestamosScreen`), que no necesitan enterarse.
  final VoidCallback? onPagoRegistrado;

  @override
  State<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends State<PrestamoDetalleScreen> {
  late final _repository = widget.repository ?? PrestamosRepository();
  late final _pagosRepository = widget.pagosRepository ?? PagosRepository();
  PrestamoDetalle? _detalle;
  double _totalPagado = 0;
  double _extraCobrado = 0;
  Map<int, DateTime> _fechaPagoPorCuota = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final detalle = await _repository.obtenerDetalle(widget.prestamoId);
    final pagos = await _pagosRepository.listarPorPrestamo(widget.prestamoId);
    final totalPagado = pagos.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
    // Excedente de pagos `cobro_extra` (monto_abonado - monto_aplicado): no reduce la deuda
    // (por eso no se suma a _totalPagado/saldo pendiente), pero sí es dinero real cobrado —
    // el dashboard ya lo contabiliza en "Ganancia realizada", este detalle no lo mostraba.
    final extraCobrado = pagos.fold<double>(0, (acumulado, pago) => acumulado + (pago.montoAbonado - pago.montoAplicado));

    // Fecha de pago real por cuota (la más reciente, si una cuota recibió más de un pago).
    final fechaPagoPorCuota = <int, DateTime>{};
    for (final pago in pagos) {
      final cuotaId = pago.cuotaId;
      if (cuotaId == null) continue;
      final actual = fechaPagoPorCuota[cuotaId];
      if (actual == null || pago.fechaPago.isAfter(actual)) {
        fechaPagoPorCuota[cuotaId] = pago.fechaPago;
      }
    }

    if (!mounted) return;
    setState(() {
      _detalle = detalle;
      _totalPagado = totalPagado;
      _extraCobrado = extraCobrado;
      _fechaPagoPorCuota = fechaPagoPorCuota;
    });
  }

  Future<void> _registrarPago() async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => RegistrarPagoScreen(prestamoId: widget.prestamoId)));
    if (guardado == true) {
      _cargar();
      widget.onPagoRegistrado?.call();
    }
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
                          if (detalle.prestamo.referencia != null && detalle.prestamo.referencia!.isNotEmpty) ...[
                            Text(
                              detalle.prestamo.referencia!,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _FilaResumen(etiqueta: 'Capital', valor: formatearMoneda(detalle.prestamo.montoCapital)),
                          _FilaResumen(
                            etiqueta: 'Interés (${detalle.prestamo.porcentajeInteres.toStringAsFixed(0)}%)',
                            valor: formatearMoneda(detalle.montoInteres),
                          ),
                          if (detalle.extras.isNotEmpty)
                            _FilaResumen(etiqueta: 'Extras', valor: formatearMoneda(detalle.montoExtras)),
                          const Divider(),
                          _FilaResumen(
                            etiqueta: 'Total original de la deuda',
                            valor: formatearMoneda(detalle.montoTotal),
                          ),
                          _FilaResumen(etiqueta: 'Total pagado', valor: formatearMoneda(_totalPagado)),
                          if (_extraCobrado > 0)
                            _FilaResumen(etiqueta: 'Extra cobrado (no aplica a la deuda)', valor: formatearMoneda(_extraCobrado)),
                          _FilaResumen(
                            etiqueta: 'Saldo pendiente',
                            valor: formatearMoneda(
                              (detalle.montoTotal - _totalPagado) < 0 ? 0 : detalle.montoTotal - _totalPagado,
                            ),
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
                            subtitle: _SubtituloFechasCuota(
                              fechaEsperada: cuota.fechaEsperada,
                              fechaPago: _fechaPagoPorCuota[cuota.id],
                            ),
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

/// Fecha esperada de una cuota y, si ya está pagada, la fecha real en que se
/// pagó (en un color distinto para diferenciarla de la esperada).
class _SubtituloFechasCuota extends StatelessWidget {
  const _SubtituloFechasCuota({required this.fechaEsperada, this.fechaPago});

  final DateTime fechaEsperada;
  final DateTime? fechaPago;

  @override
  Widget build(BuildContext context) {
    final fechaPago = this.fechaPago;
    if (fechaPago == null) {
      return Text('Esperada: ${_formatearFecha(fechaEsperada)}');
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Esperada: ${_formatearFecha(fechaEsperada)} · '),
          TextSpan(
            text: 'Pagada: ${_formatearFecha(fechaPago)}',
            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
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
          Flexible(child: Text(etiqueta, style: estilo, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
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
