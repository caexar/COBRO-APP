import 'package:flutter/material.dart';

import 'admin_configuracion_screen.dart';
import 'admin_resumen_screen.dart';
import 'admin_usuarios_list_screen.dart';

/// Home del panel de administrador: acceso a usuarios, resumen y
/// configuración. El admin no tiene acceso a las pantallas de cobrador
/// (clientes/préstamos/pagos) — ver `AppEntryPoint`.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key, required this.onCerrarSesion, required this.nombre});

  final VoidCallback onCerrarSesion;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CobroApp · Admin'),
            if (nombre.isNotEmpty)
              Text('$nombre · Administrador', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: onCerrarSesion),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsuariosListScreen())),
                icon: const Icon(Icons.people),
                label: const Text('Usuarios cobradores', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResumenScreen())),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Resumen', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminConfiguracionScreen())),
                icon: const Icon(Icons.settings),
                label: const Text('Configuración', style: TextStyle(fontSize: 17)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
