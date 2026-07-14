import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/pagos_repository.dart';

/// Historial de pagos de un préstamo: fecha, monto abonado y saldo restante
/// después de cada pago, del más reciente al más antiguo.
class HistorialPagosScreen extends StatefulWidget {
  const HistorialPagosScreen({super.key, required this.prestamoId});

  final int prestamoId;

  @override
  State<HistorialPagosScreen> createState() => _HistorialPagosScreenState();
}

class _HistorialPagosScreenState extends State<HistorialPagosScreen> {
  final _repository = PagosRepository();
  List<Pago>? _pagos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final pagos = await _repository.listarPorPrestamo(widget.prestamoId);
    if (!mounted) return;
    setState(() => _pagos = pagos.reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    final pagos = _pagos;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: pagos == null
          ? const Center(child: CircularProgressIndicator())
          : pagos.isEmpty
          ? const Center(child: Text('Todavía no hay pagos registrados.'))
          : SafeArea(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: pagos.length,
                separatorBuilder: (context, indice) => const SizedBox(height: 8),
                itemBuilder: (context, indice) {
                  final pago = pagos[indice];
                  return Card(
                    child: ListTile(
                      title: Text(formatearMoneda(pago.montoAbonado)),
                      subtitle: Text(_formatearFecha(pago.fechaPago) + (pago.diasMora > 0 ? ' · ${pago.diasMora} días de mora' : '')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Saldo restante', style: TextStyle(fontSize: 11)),
                          Text(formatearMoneda(pago.saldoRestanteDespues), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
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
