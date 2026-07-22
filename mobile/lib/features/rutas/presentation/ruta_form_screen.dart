import 'package:flutter/material.dart';

import '../data/rutas_repository.dart';

/// Formulario simple de crear/editar una ruta manual (nombre, descripción y
/// fecha opcionales) — mismo componente para ambos casos, según si [ruta]
/// llega en el constructor (igual que el patrón ya usado en
/// `AdminUsuarioFormScreen`/`ClienteFormScreen`). Funciona sin conexión, a
/// diferencia de "Autogenerar ruta de hoy".
class RutaFormScreen extends StatefulWidget {
  const RutaFormScreen({super.key, this.ruta, this.repository});

  final Ruta? ruta;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final RutasRepository? repository;

  @override
  State<RutaFormScreen> createState() => _RutaFormScreenState();
}

class _RutaFormScreenState extends State<RutaFormScreen> {
  late final _repository = widget.repository ?? RutasRepository();
  final _formKey = GlobalKey<FormState>();
  late final _nombreController = TextEditingController(text: widget.ruta?.nombre ?? '');
  late final _descripcionController = TextEditingController(text: widget.ruta?.descripcion ?? '');
  DateTime? _fecha;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.ruta != null;

  @override
  void initState() {
    super.initState();
    _fecha = widget.ruta?.fecha;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final nombre = _nombreController.text.trim();
      final descripcion = _descripcionController.text.trim();

      if (_esEdicion) {
        await _repository.actualizar(
          id: widget.ruta!.id,
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
          fecha: _fecha,
        );
      } else {
        await _repository.crear(
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
          fecha: _fecha,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo guardar la ruta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar ruta' : 'Nueva ruta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (valor) => (valor == null || valor.trim().isEmpty) ? 'Ingresa un nombre.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fecha == null ? 'Sin fecha (ruta general, reutilizable)' : 'Fecha: ${_formatearFecha(_fecha!)}',
                    ),
                  ),
                  TextButton(onPressed: _elegirFecha, child: const Text('Elegir fecha')),
                  if (_fecha != null)
                    IconButton(
                      onPressed: () => setState(() => _fecha = null),
                      icon: const Icon(Icons.clear),
                      tooltip: 'Quitar fecha',
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
