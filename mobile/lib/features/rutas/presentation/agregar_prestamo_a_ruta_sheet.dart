import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../prestamos/data/prestamos_repository.dart';

/// Bottom sheet para elegir, entre los "cobros pendientes" del cobrador, un
/// préstamo que todavía no esté en la ruta actual ([idsExcluidos]). Devuelve
/// el [PrestamoResumen] elegido, o `null` si se cierra sin elegir.
Future<PrestamoResumen?> mostrarAgregarPrestamoARutaSheet(
  BuildContext context, {
  required List<int> idsExcluidos,
  PrestamosRepository? prestamosRepository,
}) {
  return showModalBottomSheet<PrestamoResumen>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AgregarPrestamoARutaSheet(idsExcluidos: idsExcluidos, prestamosRepository: prestamosRepository),
  );
}

class _AgregarPrestamoARutaSheet extends StatefulWidget {
  const _AgregarPrestamoARutaSheet({required this.idsExcluidos, this.prestamosRepository});

  final List<int> idsExcluidos;
  final PrestamosRepository? prestamosRepository;

  @override
  State<_AgregarPrestamoARutaSheet> createState() => _AgregarPrestamoARutaSheetState();
}

class _AgregarPrestamoARutaSheetState extends State<_AgregarPrestamoARutaSheet> {
  late final _repository = widget.prestamosRepository ?? PrestamosRepository();
  final _busquedaController = TextEditingController();
  List<PrestamoResumen> _prestamos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final resultado = await _repository.listarPendientes(busqueda: _busquedaController.text);
    final disponibles = resultado.where((resumen) => !widget.idsExcluidos.contains(resumen.prestamo.id)).toList();
    if (!mounted) return;
    setState(() {
      _prestamos = disponibles;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controlador) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Agregar préstamo a la ruta', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _busquedaController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre o cédula',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _cargar(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : _prestamos.isEmpty
                      ? const Center(child: Text('No hay más cobros pendientes para agregar.'))
                      : ListView.separated(
                          controller: controlador,
                          itemCount: _prestamos.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, indice) {
                            final resumen = _prestamos[indice];
                            final referencia = resumen.prestamo.referencia;
                            final titulo = (referencia != null && referencia.isNotEmpty)
                                ? '${resumen.cliente.nombre} — $referencia'
                                : resumen.cliente.nombre;

                            return ListTile(
                              title: Text(titulo, style: const TextStyle(fontSize: 17)),
                              subtitle: Text('Saldo pendiente: ${formatearMoneda(resumen.saldoPendiente)}'),
                              onTap: () => Navigator.of(context).pop(resumen),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
