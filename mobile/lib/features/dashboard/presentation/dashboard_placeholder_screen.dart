import 'package:flutter/material.dart';

import '../../clientes/presentation/clientes_list_screen.dart';

/// Marcador de posición mínimo para poder probar los módulos ya construidos
/// de punta a punta. El dashboard real se construye en una fase futura.
class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key, required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CobroApp'),
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
              const SizedBox(height: 16),
              const Text(
                'Sesión iniciada y app desbloqueada.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ClientesListScreen())),
                icon: const Icon(Icons.people),
                label: const Text('Clientes', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
