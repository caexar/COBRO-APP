import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import 'admin_cobrador_detalle_screen.dart';
import 'admin_usuario_form_screen.dart';

/// Listado de cobradores (activos e inactivos, diferenciados visualmente),
/// con acciones para crear, editar, desactivar/reactivar y ver el detalle
/// de solo lectura de cada uno.
class AdminUsuariosListScreen extends StatefulWidget {
  const AdminUsuariosListScreen({super.key});

  @override
  State<AdminUsuariosListScreen> createState() => _AdminUsuariosListScreenState();
}

class _AdminUsuariosListScreenState extends State<AdminUsuariosListScreen> {
  final _repository = AdminRepository();

  List<UsuarioAdmin>? _usuarios;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);

    try {
      final usuarios = await _repository.listarUsuarios();
      if (!mounted) return;
      setState(() => _usuarios = usuarios);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmarDesactivar(UsuarioAdmin usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('¿Desactivar a "${usuario.nombre}"? No podrá iniciar sesión hasta que lo reactives.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Desactivar')),
        ],
      ),
    );

    if (confirmar != true) return;
    await _ejecutarAccion(() => _repository.desactivarUsuario(usuario.id));
  }

  Future<void> _reactivar(UsuarioAdmin usuario) async {
    await _ejecutarAccion(() => _repository.reactivarUsuario(usuario.id));
  }

  Future<void> _ejecutarAccion(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _abrirFormulario({UsuarioAdmin? usuario}) async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => AdminUsuarioFormScreen(usuarioExistente: usuario)));

    if (guardado == true) _cargar();
  }

  void _abrirDetalle(UsuarioAdmin usuario) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminCobradorDetalleScreen(usuarioId: usuario.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios cobradores')),
      body: SafeArea(child: _cuerpo()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cobrador'),
      ),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final usuarios = _usuarios;
    if (usuarios == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (usuarios.isEmpty) {
      return const Center(child: Text('Todavía no hay cobradores registrados.'));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: usuarios.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, indice) {
          final usuario = usuarios[indice];
          return _UsuarioTile(
            usuario: usuario,
            onVerDetalle: () => _abrirDetalle(usuario),
            onEditar: () => _abrirFormulario(usuario: usuario),
            onDesactivar: () => _confirmarDesactivar(usuario),
            onReactivar: () => _reactivar(usuario),
          );
        },
      ),
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({
    required this.usuario,
    required this.onVerDetalle,
    required this.onEditar,
    required this.onDesactivar,
    required this.onReactivar,
  });

  final UsuarioAdmin usuario;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;
  final VoidCallback onReactivar;

  @override
  Widget build(BuildContext context) {
    final activo = usuario.activo;

    return ListTile(
      onTap: onVerDetalle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: activo
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: activo ? null : Theme.of(context).colorScheme.outline),
      ),
      title: Text(
        usuario.nombre,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: activo ? null : Theme.of(context).colorScheme.outline,
          decoration: activo ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(usuario.email, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activo ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              activo ? 'Activo' : 'Inactivo',
              style: TextStyle(
                color: activo ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (opcion) {
              switch (opcion) {
                case 'editar':
                  onEditar();
                case 'desactivar':
                  onDesactivar();
                case 'reactivar':
                  onReactivar();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              if (activo)
                const PopupMenuItem(value: 'desactivar', child: Text('Desactivar'))
              else
                const PopupMenuItem(value: 'reactivar', child: Text('Reactivar')),
            ],
          ),
        ],
      ),
    );
  }
}
