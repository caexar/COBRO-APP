import 'dart:io';

import 'package:flutter/material.dart';

import '../data/clientes_repository.dart';
import 'cliente_form_screen.dart';

/// Listado de clientes con buscador (nombre siempre, cédula además si el
/// texto tiene números). Pensada para uso rápido en campo: botones grandes,
/// poco texto.
class ClientesListScreen extends StatefulWidget {
  const ClientesListScreen({super.key});

  @override
  State<ClientesListScreen> createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> {
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

  Future<void> _abrirFormulario({Cliente? cliente}) async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ClienteFormScreen(clienteExistente: cliente)));

    if (guardado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _busquedaController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o cédula',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busquedaController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _busquedaController.clear();
                            _cargar();
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) {
                  setState(() {}); // refresca el ícono de limpiar
                  _cargar();
                },
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _clientes.isEmpty
                  ? _EstadoVacio(hayBusqueda: _busquedaController.text.trim().isNotEmpty)
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _clientes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, indice) {
                          final cliente = _clientes[indice];
                          return _ClienteTile(
                            cliente: cliente,
                            onTap: () => _abrirFormulario(cliente: cliente),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cliente'),
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  const _ClienteTile({required this.cliente, required this.onTap});

  final Cliente cliente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foto = cliente.fotoUrl;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: (foto != null && File(foto).existsSync()) ? FileImage(File(foto)) : null,
        child: (foto == null || !File(foto).existsSync())
            ? const Icon(Icons.person, size: 28)
            : null,
      ),
      title: Text(
        cliente.nombre,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('CC ${cliente.cedula} · ${cliente.telefono}', style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.hayBusqueda});

  final bool hayBusqueda;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              hayBusqueda ? 'No hay clientes con ese nombre o cédula.' : 'Todavía no tienes clientes.\nToca "Nuevo cliente" para agregar el primero.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
