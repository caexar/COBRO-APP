import 'package:flutter/material.dart';

import '../../../core/utils/atajo_miles_repository.dart';
import '../../../core/utils/formato_dinero.dart';
import '../data/admin_repository.dart';

/// Formulario para que el admin asigne (o retire) saldo de capital a un
/// cobrador puntual (`POST /admin/cargas-capital`) — mismo patrón visual que
/// `AgregarCapitalScreen` del lado cobrador.
class AdminAsignarCapitalScreen extends StatefulWidget {
  const AdminAsignarCapitalScreen({
    super.key,
    required this.usuarioId,
    required this.nombreCobrador,
    this.repository,
    this.atajoMilesRepository,
  });

  final int usuarioId;
  final String nombreCobrador;

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final AdminRepository? repository;
  final AtajoMilesRepository? atajoMilesRepository;

  @override
  State<AdminAsignarCapitalScreen> createState() => _AdminAsignarCapitalScreenState();
}

class _AdminAsignarCapitalScreenState extends State<AdminAsignarCapitalScreen> {
  late final _repository = widget.repository ?? AdminRepository();
  late final _atajoMilesRepository = widget.atajoMilesRepository ?? AtajoMilesRepository();
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  String _tipo = 'carga';
  bool _guardando = false;
  bool _atajoMilesActivado = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(_alCambiarMonto);
    _cargarAtajoMiles();
  }

  @override
  void dispose() {
    _montoController.removeListener(_alCambiarMonto);
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _alCambiarMonto() => setState(() {});

  Future<void> _cargarAtajoMiles() async {
    final activado = await _atajoMilesRepository.estaActivado();
    if (!mounted) return;
    setState(() => _atajoMilesActivado = activado);
  }

  Future<void> _guardar() async {
    final monto = interpretarValorIngresado(_montoController.text, atajoMilesActivado: _atajoMilesActivado);
    if (monto == null || monto <= 0 || _guardando) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final descripcion = _descripcionController.text.trim();
      await _repository.asignarCapital(
        usuarioId: widget.usuarioId,
        tipo: _tipo,
        monto: monto,
        descripcion: descripcion.isEmpty ? null : descripcion,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo asignar el saldo: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = interpretarValorIngresado(_montoController.text, atajoMilesActivado: _atajoMilesActivado);
    final puedeGuardar = monto != null && monto > 0 && !_guardando;
    final textoAyuda = textoAyudaAtajoMiles(_montoController.text, atajoMilesActivado: _atajoMilesActivado);

    return Scaffold(
      appBar: AppBar(title: Text(_tipo == 'retiro' ? 'Registrar retiro' : 'Asignar saldo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cobrador: ${widget.nombreCobrador}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'carga', label: Text('Carga'), icon: Icon(Icons.add)),
                  ButtonSegment(value: 'retiro', label: Text('Retiro'), icon: Icon(Icons.remove)),
                ],
                selected: {_tipo},
                onSelectionChanged: (seleccion) => setState(() => _tipo = seleccion.first),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormateadorDinero()],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                ),
              ),
              if (textoAyuda != null) ...[
                const SizedBox(height: 6),
                Text(
                  textoAyuda,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej. "Fondeo semanal"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Este saldo se reflejará en el dispositivo del cobrador en su próxima sincronización.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                    : Text(
                        _tipo == 'retiro' ? 'Registrar retiro' : 'Asignar saldo',
                        style: const TextStyle(fontSize: 17),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
