import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/cargas_capital_repository.dart';

/// Historial de movimientos de capital del cobrador: entradas (aportes) y
/// salidas (retiros), del más reciente al más antiguo. Permite deshacer un
/// movimiento registrado por error (soft-delete, ver
/// `CargasCapitalRepository.eliminar`).
class HistorialCapitalScreen extends StatefulWidget {
  const HistorialCapitalScreen({super.key});

  @override
  State<HistorialCapitalScreen> createState() => _HistorialCapitalScreenState();
}

class _HistorialCapitalScreenState extends State<HistorialCapitalScreen> {
  final _repository = CargasCapitalRepository();
  List<CargaCapital>? _movimientos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final movimientos = await _repository.listarTodas();
    if (!mounted) return;
    setState(() => _movimientos = movimientos.reversed.toList());
  }

  Future<void> _confirmarEliminar(CargaCapital movimiento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(
          '¿Eliminar ${movimiento.tipo == 'retiro' ? 'el retiro' : 'la entrada'} de '
          '${formatearMoneda(movimiento.monto)}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmado != true) return;

    await _repository.eliminar(movimiento.id);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = _movimientos;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de capital')),
      body: movimientos == null
          ? const Center(child: CircularProgressIndicator())
          : movimientos.isEmpty
          ? const Center(child: Text('Todavía no hay movimientos de capital registrados.'))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: movimientos.length,
                  separatorBuilder: (context, indice) => const SizedBox(height: 8),
                  itemBuilder: (context, indice) {
                    final movimiento = movimientos[indice];
                    final esRetiro = movimiento.tipo == 'retiro';

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          esRetiro ? Icons.arrow_downward : Icons.arrow_upward,
                          color: esRetiro ? Colors.red : Colors.green,
                        ),
                        title: Text(
                          '${esRetiro ? '-' : '+'} ${formatearMoneda(movimiento.monto)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            _formatearFecha(movimiento.creadoEn),
                            if (movimiento.descripcion != null && movimiento.descripcion!.isNotEmpty)
                              movimiento.descripcion!,
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmarEliminar(movimiento),
                        ),
                      ),
                    );
                  },
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
