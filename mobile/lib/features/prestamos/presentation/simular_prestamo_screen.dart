import 'package:flutter/material.dart';

import 'prestamo_calculadora_formulario.dart';

/// Calculadora de préstamo sin cliente ni guardado: mismo widget compartido
/// que "Nuevo préstamo", solo que aquí no hay nada que persistir.
class SimularPrestamoScreen extends StatelessWidget {
  const SimularPrestamoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simular préstamo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: const PrestamoCalculadoraFormulario(),
        ),
      ),
    );
  }
}
