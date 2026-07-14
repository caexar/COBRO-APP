import 'package:flutter/material.dart';

import '../../clientes/data/clientes_repository.dart';

/// Bottom sheet para elegir un cliente existente al crear un préstamo.
/// Devuelve el [Cliente] elegido, o `null` si se cierra sin elegir.
Future<Cliente?> mostrarSeleccionarClienteSheet(BuildContext context) {
  return showModalBottomSheet<Cliente>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _SeleccionarClienteSheet(),
  );
}

class _SeleccionarClienteSheet extends StatefulWidget {
  const _SeleccionarClienteSheet();

  @override
  State<_SeleccionarClienteSheet> createState() => _SeleccionarClienteSheetState();
}

class _SeleccionarClienteSheetState extends State<_SeleccionarClienteSheet> {
  final _repository = ClientesRepository();
  final _busquedaController = TextEditingController();
  List<Cliente> _clientes = [];
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
    final resultado = await _repository.buscar(_busquedaController.text);
    if (!mounted) return;
    setState(() {
      _clientes = resultado;
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
                Text('Selecciona un cliente', style: Theme.of(context).textTheme.titleLarge),
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
                      : _clientes.isEmpty
                      ? const Center(child: Text('No se encontraron clientes.'))
                      : ListView.separated(
                          controller: controlador,
                          itemCount: _clientes.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, indice) {
                            final cliente = _clientes[indice];
                            return ListTile(
                              title: Text(cliente.nombre, style: const TextStyle(fontSize: 17)),
                              subtitle: Text('CC ${cliente.cedula}'),
                              onTap: () => Navigator.of(context).pop(cliente),
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
