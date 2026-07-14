import 'package:flutter/material.dart';

import '../../clientes/data/clientes_repository.dart';
import '../data/prestamos_repository.dart';
import 'prestamo_calculadora_formulario.dart';
import 'prestamo_detalle_screen.dart';
import 'seleccionar_cliente_sheet.dart';

/// Formulario de préstamo nuevo, asociado a un cliente existente. Reutiliza
/// [PrestamoCalculadoraFormulario] (misma calculadora que "Simular
/// préstamo") y, al guardar, genera las cuotas localmente y encola el alta.
class PrestamoFormScreen extends StatefulWidget {
  const PrestamoFormScreen({super.key, this.clienteInicial});

  final Cliente? clienteInicial;

  @override
  State<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends State<PrestamoFormScreen> {
  final _repository = PrestamosRepository();
  final _referenciaController = TextEditingController();

  Cliente? _cliente;
  DatosPrestamoFormulario? _datos;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cliente = widget.clienteInicial;
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente() async {
    final cliente = await mostrarSeleccionarClienteSheet(context);
    if (cliente != null) setState(() => _cliente = cliente);
  }

  Future<void> _guardar() async {
    final cliente = _cliente;
    final datos = _datos;
    if (cliente == null || datos == null || _guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final referencia = _referenciaController.text.trim();
      final prestamoId = await _repository.crear(
        clienteId: cliente.id,
        referencia: referencia.isEmpty ? null : referencia,
        montoCapital: datos.montoCapital,
        porcentajeInteres: datos.porcentajeInteres,
        extras: datos.extras,
        frecuenciaPago: datos.frecuenciaPago,
        diasPersonalizado: datos.diasPersonalizado,
        plazoCuotas: datos.plazoCuotas,
        fechaInicio: datos.fechaInicio,
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => PrestamoDetalleScreen(prestamoId: prestamoId)));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar el préstamo: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _cliente;
    final puedeGuardar = cliente != null && _datos != null && !_guardando;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo préstamo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _elegirCliente,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                  child: Text(
                    cliente?.nombre ?? 'Toca para elegir un cliente',
                    style: TextStyle(
                      fontSize: 17,
                      color: cliente == null ? Theme.of(context).colorScheme.outline : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenciaController,
                decoration: const InputDecoration(
                  labelText: 'Referencia (opcional)',
                  hintText: 'Ej. "Préstamo moto", "Segundo préstamo"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              PrestamoCalculadoraFormulario(onDatosValidosCambiados: (datos) => setState(() => _datos = datos)),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: puedeGuardar ? _guardar : null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: _guardando
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar préstamo', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
