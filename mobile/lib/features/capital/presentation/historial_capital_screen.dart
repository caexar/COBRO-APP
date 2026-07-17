import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/cargas_capital_repository.dart';

/// Historial de movimientos de capital del cobrador: entradas (aportes) y
/// salidas (retiros), del más reciente al más antiguo. De solo lectura: el
/// cobrador puede ver su historial pero no eliminarlo desde acá (
/// `CargasCapitalRepository.eliminar` sigue existiendo, por si otra pantalla
/// lo necesita a futuro, pero esta ya no lo expone).
class HistorialCapitalScreen extends StatefulWidget {
  const HistorialCapitalScreen({super.key, this.repository});

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final CargasCapitalRepository? repository;

  @override
  State<HistorialCapitalScreen> createState() => _HistorialCapitalScreenState();
}

class _HistorialCapitalScreenState extends State<HistorialCapitalScreen> {
  late final _repository = widget.repository ?? CargasCapitalRepository();
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
                    final asignadoPorAdmin = movimiento.origen == 'admin';

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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                _formatearFecha(movimiento.creadoEn),
                                if (movimiento.descripcion != null && movimiento.descripcion!.isNotEmpty)
                                  movimiento.descripcion!,
                              ].join(' · '),
                            ),
                            if (asignadoPorAdmin) ...[
                              const SizedBox(height: 4),
                              const Chip(
                                label: Text('Asignado por administrador', style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
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
