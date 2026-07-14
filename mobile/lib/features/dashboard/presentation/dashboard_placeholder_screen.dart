import 'package:flutter/material.dart';

/// Marcador de posición mínimo para poder probar el flujo de autenticación
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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sesión iniciada y app desbloqueada.\nEl dashboard se construye en una fase futura.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
