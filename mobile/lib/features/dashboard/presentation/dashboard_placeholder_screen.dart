import 'package:flutter/material.dart';

import '../../clientes/presentation/clientes_list_screen.dart';
import '../../prestamos/presentation/cobros_pendientes_screen.dart';
import '../../prestamos/presentation/prestamo_form_screen.dart';
import '../../prestamos/presentation/simular_prestamo_screen.dart';

/// Marcador de posición mínimo para poder probar los módulos ya construidos
/// de punta a punta. El dashboard real se construye en una fase futura.
class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key, required this.onCerrarSesion, required this.nombre});

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
            const Text('CobroApp'),
            if (nombre.isNotEmpty)
              Text('$nombre · Cobrador', style: Theme.of(context).textTheme.bodySmall),
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
              const SizedBox(height: 16),
              const Text('Sesión iniciada y app desbloqueada.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClientesListScreen())),
                icon: const Icon(Icons.people),
                label: const Text('Clientes', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CobrosPendientesScreen())),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Cobros pendientes', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrestamoFormScreen())),
                icon: const Icon(Icons.request_page),
                label: const Text('Nuevo préstamo', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimularPrestamoScreen())),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Simular préstamo', style: TextStyle(fontSize: 17)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
