import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/admin_repository.dart';

/// Vista de solo lectura de un cobrador: sus clientes y préstamos. El admin
/// no edita nada desde aquí (el CRUD de clientes/préstamos sigue siendo
/// exclusivo del cobrador dueño, desde la app de cobrador).
class AdminCobradorDetalleScreen extends StatefulWidget {
  const AdminCobradorDetalleScreen({super.key, required this.usuarioId});

  final int usuarioId;

  @override
  State<AdminCobradorDetalleScreen> createState() => _AdminCobradorDetalleScreenState();
}

class _AdminCobradorDetalleScreenState extends State<AdminCobradorDetalleScreen> {
  final _repository = AdminRepository();

  DetalleCobrador? _detalle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);

    try {
      final detalle = await _repository.obtenerDetalleCobrador(widget.usuarioId);
      if (!mounted) return;
      setState(() => _detalle = detalle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle;

    return Scaffold(
      appBar: AppBar(title: Text(detalle?.usuario.nombre ?? 'Detalle del cobrador')),
      body: SafeArea(child: _cuerpo(detalle)),
    );
  }

  Widget _cuerpo(DetalleCobrador? detalle) {
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

    if (detalle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detalle.usuario.email, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  detalle.usuario.activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: detalle.usuario.activo ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Clientes (${detalle.clientes.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detalle.clientes.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Sin clientes registrados.'))
        else
          Card(
            child: Column(
              children: [
                for (final cliente in detalle.clientes)
                  ListTile(title: Text(cliente.nombre), subtitle: Text('CC ${cliente.cedula} · ${cliente.telefono}')),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('Préstamos (${detalle.prestamos.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detalle.prestamos.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Sin préstamos registrados.'))
        else
          Card(
            child: Column(
              children: [
                for (final prestamo in detalle.prestamos)
                  ListTile(
                    title: Text(formatearMoneda(prestamo.montoCapital)),
                    subtitle: Text('${prestamo.porcentajeInteres.toStringAsFixed(0)}% · ${prestamo.plazoCuotas} cuotas'),
                    trailing: _EtiquetaEstado(estado: prestamo.estado),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (estado) {
      'pagado' => (Colors.green, 'Pagado'),
      'en_mora' => (Colors.red, 'En mora'),
      'anulado' => (Colors.grey, 'Anulado'),
      _ => (Colors.blue, 'Activo'),
    };

    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
