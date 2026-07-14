import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

/// Alta o edición de un cobrador. El rol queda fijo en "cobrador" desde
/// esta pantalla (crear otros admins no es prioridad ahora). La contraseña
/// es obligatoria al crear; al editar, se deja en blanco para no cambiarla.
class AdminUsuarioFormScreen extends StatefulWidget {
  const AdminUsuarioFormScreen({super.key, this.usuarioExistente});

  final UsuarioAdmin? usuarioExistente;

  @override
  State<AdminUsuarioFormScreen> createState() => _AdminUsuarioFormScreenState();
}

class _AdminUsuarioFormScreenState extends State<AdminUsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = AdminRepository();

  late final _nombreController = TextEditingController(text: widget.usuarioExistente?.nombre);
  late final _emailController = TextEditingController(text: widget.usuarioExistente?.email);
  final _passwordController = TextEditingController();

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.usuarioExistente != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        final cambios = <String, dynamic>{
          'nombre': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
        };
        if (_passwordController.text.isNotEmpty) {
          cambios['password'] = _passwordController.text;
        }
        await _repository.actualizarUsuario(widget.usuarioExistente!.id, cambios);
      } else {
        await _repository.crearUsuario(
          nombre: _nombreController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar cobrador' : 'Nuevo cobrador')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                  validator: (valor) => (valor == null || valor.trim().isEmpty) ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
                  validator: (valor) => (valor == null || valor.trim().isEmpty) ? 'Ingresa el correo' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _esEdicion ? 'Nueva contraseña (opcional)' : 'Contraseña',
                    border: const OutlineInputBorder(),
                    helperText: _esEdicion ? 'Déjalo en blanco para no cambiarla' : 'Mínimo 8 caracteres',
                  ),
                  validator: (valor) {
                    if (_esEdicion) return null;
                    if (valor == null || valor.isEmpty) return 'Ingresa una contraseña';
                    if (valor.length < 8) return 'Debe tener al menos 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                  child: const Text('Cobrador', style: TextStyle(fontSize: 16)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                  child: _guardando
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_esEdicion ? 'Guardar cambios' : 'Crear cobrador', style: const TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
