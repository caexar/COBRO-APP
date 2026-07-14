import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/almacenamiento_fotos.dart';
import '../data/clientes_repository.dart';

/// Alta o edición de un cliente. Si [clienteExistente] viene nulo es un
/// cliente nuevo; si no, se precargan sus datos para editar.
class ClienteFormScreen extends StatefulWidget {
  const ClienteFormScreen({super.key, this.clienteExistente});

  final Cliente? clienteExistente;

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ClientesRepository();

  late final _nombreController = TextEditingController(text: widget.clienteExistente?.nombre);
  late final _cedulaController = TextEditingController(text: widget.clienteExistente?.cedula);
  late final _telefonoController = TextEditingController(text: widget.clienteExistente?.telefono);
  late final _direccionController = TextEditingController(text: widget.clienteExistente?.direccion);
  late final _referenciaController = TextEditingController(
    text: widget.clienteExistente?.referencia,
  );

  String? _fotoUrl;
  bool _guardando = false;
  String? _errorNombre;
  String? _errorCedula;

  bool get _esEdicion => widget.clienteExistente != null;

  @override
  void initState() {
    super.initState();
    _fotoUrl = widget.clienteExistente?.fotoUrl;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, size: 28),
              title: const Text('Tomar foto', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('Elegir de galería', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (origen == null || !mounted) return;

    final archivo = await ImagePicker().pickImage(source: origen, maxWidth: 1280, imageQuality: 80);
    if (archivo == null || !mounted) return;

    final rutaGuardada = await guardarFotoCliente(archivo);
    if (!mounted) return;
    setState(() => _fotoUrl = rutaGuardada);
  }

  Future<void> _guardar() async {
    setState(() {
      _errorNombre = null;
      _errorCedula = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      if (_esEdicion) {
        await _repository.actualizar(
          id: widget.clienteExistente!.id,
          nombre: _nombreController.text.trim(),
          cedula: _cedulaController.text.trim(),
          telefono: _telefonoController.text.trim(),
          direccion: _direccionController.text.trim(),
          referencia: _vacioANulo(_referenciaController.text),
          fotoUrl: _fotoUrl,
        );
      } else {
        await _repository.crear(
          nombre: _nombreController.text.trim(),
          cedula: _cedulaController.text.trim(),
          telefono: _telefonoController.text.trim(),
          direccion: _direccionController.text.trim(),
          referencia: _vacioANulo(_referenciaController.text),
          fotoUrl: _fotoUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ClienteDuplicadoException catch (e) {
      setState(() {
        if (e.campo == 'nombre') {
          _errorNombre = e.mensaje;
        } else {
          _errorCedula = e.mensaje;
        }
      });
      _formKey.currentState!.validate();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _vacioANulo(String texto) => texto.trim().isEmpty ? null : texto.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar cliente' : 'Nuevo cliente')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _elegirFoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: (_fotoUrl != null && File(_fotoUrl!).existsSync())
                              ? FileImage(File(_fotoUrl!))
                              : null,
                          child: (_fotoUrl == null || !File(_fotoUrl!).existsSync())
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: const OutlineInputBorder(),
                    errorText: _errorNombre,
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) return 'Ingresa el nombre';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorNombre != null) setState(() => _errorNombre = null);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cedulaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cédula',
                    border: const OutlineInputBorder(),
                    errorText: _errorCedula,
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) return 'Ingresa la cédula';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorCedula != null) setState(() => _errorCedula = null);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) return 'Ingresa el teléfono';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _direccionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) return 'Ingresa la dirección';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referenciaController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                  child: _guardando
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_esEdicion ? 'Guardar cambios' : 'Guardar cliente', style: const TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
