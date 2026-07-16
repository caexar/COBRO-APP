import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/admin_repository.dart';
import 'admin_asignar_capital_screen.dart';

/// Vista de solo lectura de un cobrador: sus clientes y préstamos. El admin
/// no edita nada desde aquí (el CRUD de clientes/préstamos sigue siendo
/// exclusivo del cobrador dueño, desde la app de cobrador) — la única
/// acción disponible es asignarle saldo de capital.
class AdminCobradorDetalleScreen extends StatefulWidget {
  const AdminCobradorDetalleScreen({super.key, required this.usuarioId, this.repository});

  final int usuarioId;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final AdminRepository? repository;

  @override
  State<AdminCobradorDetalleScreen> createState() => _AdminCobradorDetalleScreenState();
}

class _AdminCobradorDetalleScreenState extends State<AdminCobradorDetalleScreen> {
  late final _repository = widget.repository ?? AdminRepository();

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

  /// Cuenta de préstamos por `clienteId`: `(activos, totales)`. "Activos"
  /// cuenta solo `activo`/`en_mora`; "totales" cuenta cualquier estado. Se
  /// arma en memoria a partir de lo que ya trajo `obtenerDetalleCobrador`,
  /// sin pedir nada nuevo al backend.
  Map<int, (int activos, int totales)> _conteoPrestamosPorCliente(DetalleCobrador detalle) {
    final conteo = <int, (int, int)>{};

    for (final prestamo in detalle.prestamos) {
      final actual = conteo[prestamo.clienteId] ?? (0, 0);
      final esActivo = prestamo.estado == 'activo' || prestamo.estado == 'en_mora';
      conteo[prestamo.clienteId] = (actual.$1 + (esActivo ? 1 : 0), actual.$2 + 1);
    }

    return conteo;
  }

  Map<int, String> _nombresPorCliente(DetalleCobrador detalle) {
    return {for (final cliente in detalle.clientes) cliente.id: cliente.nombre};
  }

  Future<void> _asignarSaldo() async {
    final detalle = _detalle;
    if (detalle == null) return;

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAsignarCapitalScreen(usuarioId: widget.usuarioId, nombreCobrador: detalle.usuario.nombre),
      ),
    );

    if (guardado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo asignado correctamente. Se reflejará cuando el cobrador sincronice.')),
      );
    }
  }

  void _mostrarDetallePrestamo(PrestamoResumen prestamo, String nombreCliente) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _DetallePrestamoModal(
          prestamo: prestamo,
          nombreCliente: nombreCliente,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle;

    return Scaffold(
      appBar: AppBar(title: Text(detalle?.usuario.nombre ?? 'Detalle del cobrador')),
      floatingActionButton: detalle == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _asignarSaldo,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Asignar saldo'),
            ),
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

    final conteoPorCliente = _conteoPrestamosPorCliente(detalle);
    final nombresPorCliente = _nombresPorCliente(detalle);

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
                  ListTile(
                    title: Text(cliente.nombre),
                    subtitle: Text('CC ${cliente.cedula} · ${cliente.telefono}'),
                    trailing: _BadgeConteoPrestamos(conteo: conteoPorCliente[cliente.id] ?? (0, 0)),
                  ),
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
                    onTap: () => _mostrarDetallePrestamo(
                      prestamo,
                      nombresPorCliente[prestamo.clienteId] ?? 'Cliente',
                    ),
                    title: Text(_tituloPrestamo(prestamo, nombresPorCliente[prestamo.clienteId] ?? 'Cliente')),
                    subtitle: Text(
                      '${formatearMoneda(prestamo.montoTotal)} · '
                      '${prestamo.porcentajeInteres.toStringAsFixed(0)}% · '
                      '${prestamo.plazoCuotas} cuotas · ${_formatearFecha(prestamo.fechaInicio)}',
                    ),
                    trailing: _EtiquetaEstado(estado: prestamo.estado),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Título de un préstamo: su `referencia` si tiene una, o el nombre del
/// cliente como respaldo para no dejarlo en blanco.
String _tituloPrestamo(PrestamoResumen prestamo, String nombreCliente) {
  final referencia = prestamo.referencia;
  return (referencia != null && referencia.isNotEmpty) ? referencia : nombreCliente;
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

class _BadgeConteoPrestamos extends StatelessWidget {
  const _BadgeConteoPrestamos({required this.conteo});

  final (int activos, int totales) conteo;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('${conteo.$1}/${conteo.$2}', style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Detalle de un préstamo dentro de un modal/bottom sheet: capital, interés,
/// extras, monto total, total pagado y el listado completo de cuotas — todo
/// con datos que ya venían en el detalle del cobrador, sin ninguna llamada
/// de red nueva (mismo patrón visual que `PrestamoDetalleScreen` del lado
/// cobrador).
class _DetallePrestamoModal extends StatelessWidget {
  const _DetallePrestamoModal({
    required this.prestamo,
    required this.nombreCliente,
    required this.scrollController,
  });

  final PrestamoResumen prestamo;
  final String nombreCliente;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final saldoPendiente = prestamo.montoTotal - prestamo.totalPagado;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tituloPrestamo(prestamo, nombreCliente),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _FilaResumen(etiqueta: 'Capital', valor: formatearMoneda(prestamo.montoCapital)),
                _FilaResumen(
                  etiqueta: 'Interés (${prestamo.porcentajeInteres.toStringAsFixed(0)}%)',
                  valor: formatearMoneda(prestamo.montoInteres),
                ),
                if (prestamo.extras.isNotEmpty)
                  _FilaResumen(etiqueta: 'Extras', valor: formatearMoneda(prestamo.montoExtras)),
                const Divider(),
                _FilaResumen(etiqueta: 'Total original de la deuda', valor: formatearMoneda(prestamo.montoTotal)),
                _FilaResumen(etiqueta: 'Total pagado', valor: formatearMoneda(prestamo.totalPagado)),
                _FilaResumen(
                  etiqueta: 'Saldo pendiente',
                  valor: formatearMoneda(saldoPendiente < 0 ? 0 : saldoPendiente),
                  destacado: true,
                ),
                const SizedBox(height: 4),
                Text('Estado: ${prestamo.estado}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        if (prestamo.extras.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Montos extra', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final extra in prestamo.extras)
                  ListTile(title: Text(extra.concepto), trailing: Text(formatearMoneda(extra.valor))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Cuotas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final cuota in prestamo.cuotas)
                ListTile(
                  leading: CircleAvatar(child: Text('${cuota.numeroCuota}')),
                  title: Text(formatearMoneda(cuota.montoEsperado)),
                  subtitle: Text(_formatearFecha(cuota.fechaEsperada)),
                  trailing: _EtiquetaEstadoCuota(estado: cuota.estado),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.etiqueta, required this.valor, this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _EtiquetaEstadoCuota extends StatelessWidget {
  const _EtiquetaEstadoCuota({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (estado) {
      'pagada' => (Colors.green, 'Pagada'),
      'en_mora' => (Colors.red, 'En mora'),
      _ => (Colors.grey, 'Pendiente'),
    };

    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
