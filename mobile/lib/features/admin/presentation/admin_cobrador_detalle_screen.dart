import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../data/admin_repository.dart';
import 'admin_asignar_capital_screen.dart';

/// Vista de solo lectura de un cobrador, en 5 pestañas: Préstamos, Clientes,
/// Movimientos de capital, Historial de pagos y Gastos (cierres de caja). El
/// admin no edita nada de esto desde aquí (el CRUD de clientes/préstamos
/// sigue siendo exclusivo del cobrador dueño, desde la app de cobrador) — la
/// única acción disponible es asignarle saldo de capital.
class AdminCobradorDetalleScreen extends StatefulWidget {
  const AdminCobradorDetalleScreen({super.key, required this.usuarioId, this.repository});

  final int usuarioId;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final AdminRepository? repository;

  @override
  State<AdminCobradorDetalleScreen> createState() => _AdminCobradorDetalleScreenState();
}

class _AdminCobradorDetalleScreenState extends State<AdminCobradorDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final _repository = widget.repository ?? AdminRepository();
  late final _tabController = TabController(length: 5, vsync: this);

  DetalleCobrador? _detalle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  /// Cuenta de préstamos por `clienteId`: `(pagados, totales)`. "Pagados"
  /// cuenta solo `estado == 'pagado'`; "totales" cuenta cualquier estado. Se
  /// arma en memoria a partir de lo que ya trajo `obtenerDetalleCobrador`,
  /// sin pedir nada nuevo al backend.
  Map<int, (int pagados, int totales)> _conteoPrestamosPorCliente(DetalleCobrador detalle) {
    final conteo = <int, (int, int)>{};

    for (final prestamo in detalle.prestamos) {
      final actual = conteo[prestamo.clienteId] ?? (0, 0);
      final esPagado = prestamo.estado == 'pagado';
      conteo[prestamo.clienteId] = (actual.$1 + (esPagado ? 1 : 0), actual.$2 + 1);
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(detalle.usuario.email, style: Theme.of(context).textTheme.bodyLarge)),
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
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Préstamos'),
            Tab(text: 'Clientes'),
            Tab(text: 'Movimientos'),
            Tab(text: 'Historial de pagos'),
            Tab(text: 'Gastos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _tabPrestamos(detalle, nombresPorCliente),
              _tabClientes(detalle, conteoPorCliente),
              _tabMovimientos(detalle),
              _tabHistorialPagos(detalle, nombresPorCliente),
              _tabGastos(detalle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabPrestamos(DetalleCobrador detalle, Map<int, String> nombresPorCliente) {
    if (detalle.prestamos.isEmpty) {
      return const Center(child: Text('Sin préstamos registrados.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Préstamos (${detalle.prestamos.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final prestamo in detalle.prestamos)
          Card(
            child: ListTile(
              onTap: () => _mostrarDetallePrestamo(prestamo, nombresPorCliente[prestamo.clienteId] ?? 'Cliente'),
              title: Text(
                _tituloPrestamo(prestamo, nombresPorCliente[prestamo.clienteId] ?? 'Cliente'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${formatearMoneda(prestamo.montoTotal)} · '
                '${prestamo.porcentajeInteres.toStringAsFixed(0)}% · '
                '${prestamo.plazoCuotas} cuotas · ${_formatearFecha(prestamo.fechaInicio)}',
              ),
              trailing: _EtiquetaEstado(estado: prestamo.estado),
            ),
          ),
      ],
    );
  }

  Widget _tabClientes(DetalleCobrador detalle, Map<int, (int pagados, int totales)> conteoPorCliente) {
    if (detalle.clientes.isEmpty) {
      return const Center(child: Text('Sin clientes registrados.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Clientes (${detalle.clientes.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _tabMovimientos(DetalleCobrador detalle) {
    if (detalle.cargasCapital.isEmpty) {
      return const Center(child: Text('Sin movimientos de capital registrados.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Movimientos de capital (${detalle.cargasCapital.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [for (final carga in detalle.cargasCapital) _FilaCargaCapital(carga: carga)],
          ),
        ),
      ],
    );
  }

  Widget _tabHistorialPagos(DetalleCobrador detalle, Map<int, String> nombresPorCliente) {
    final grupos = _agruparHistorialPagos(detalle, nombresPorCliente);

    if (grupos.isEmpty) {
      return const Center(child: Text('Todavía no hay pagos registrados.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: grupos.length,
      separatorBuilder: (context, indice) => const SizedBox(height: 8),
      itemBuilder: (context, indice) => _TarjetaGrupoPagoAdmin(grupo: grupos[indice]),
    );
  }

  Widget _tabGastos(DetalleCobrador detalle) {
    if (detalle.cierresCaja.isEmpty) {
      return const Center(child: Text('Sin cierres de caja registrados.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: detalle.cierresCaja.length,
      separatorBuilder: (context, indice) => const SizedBox(height: 8),
      itemBuilder: (context, indice) => _TarjetaCierreCaja(cierre: detalle.cierresCaja[indice]),
    );
  }
}

/// Todas las filas de `pagos` (de cualquier préstamo del cobrador) que
/// comparten un mismo préstamo y una misma `fecha_pago` — mismo criterio de
/// agrupamiento que `HistorialPagosScreen` del lado cobrador, agregando
/// `prestamoId` a la clave porque esta vista abarca todos los préstamos a
/// la vez (igual que `ResumenAdminService::historialPagosAgrupado()` del
/// panel web, ver CLAUDE.md).
class _GrupoPagoAdmin {
  const _GrupoPagoAdmin({
    required this.tituloPrestamo,
    required this.fecha,
    required this.filasConEtiqueta,
    required this.resumenCorto,
    required this.montoTotalAbonado,
    required this.saldoRestanteDespues,
    required this.diasMora,
  });

  final String tituloPrestamo;
  final DateTime fecha;
  final List<(PagoResumen pago, String etiqueta)> filasConEtiqueta;
  final String resumenCorto;
  final double montoTotalAbonado;
  final double saldoRestanteDespues;
  final int diasMora;
}

List<_GrupoPagoAdmin> _agruparHistorialPagos(DetalleCobrador detalle, Map<int, String> nombresPorCliente) {
  final grupos = <_GrupoPagoAdmin>[];

  for (final prestamo in detalle.prestamos) {
    final numeroCuotaPorCuotaId = {for (final cuota in prestamo.cuotas) cuota.id: cuota.numeroCuota};
    final titulo = _tituloPrestamo(prestamo, nombresPorCliente[prestamo.clienteId] ?? 'Cliente');

    final porFecha = <int, List<PagoResumen>>{};
    for (final pago in prestamo.pagos) {
      porFecha.putIfAbsent(pago.fechaPago.millisecondsSinceEpoch, () => []).add(pago);
    }

    for (final filas in porFecha.values) {
      final ordenado = [...filas]
        ..sort((a, b) => (numeroCuotaPorCuotaId[a.cuotaId] ?? 0).compareTo(numeroCuotaPorCuotaId[b.cuotaId] ?? 0));

      final numerosCuota = <int>{};
      var extraTotal = 0.0;
      var montoTotalAbonado = 0.0;
      var saldoRestanteDespues = double.infinity;
      var diasMora = 0;
      final filasConEtiqueta = <(PagoResumen, String)>[];

      for (var indice = 0; indice < ordenado.length; indice++) {
        final pago = ordenado[indice];
        final numero = numeroCuotaPorCuotaId[pago.cuotaId];
        if (numero != null) numerosCuota.add(numero);

        final etiqueta = pago.montoAbonado != pago.montoAplicado
            ? 'Extra'
            : (indice == 0
                  ? (numero != null ? 'Pago cuota $numero' : 'Pago')
                  : (numero != null ? 'Abono cuota $numero' : 'Abono'));
        filasConEtiqueta.add((pago, etiqueta));

        extraTotal += pago.montoAbonado - pago.montoAplicado;
        montoTotalAbonado += pago.montoAbonado;
        if (pago.saldoRestanteDespues < saldoRestanteDespues) saldoRestanteDespues = pago.saldoRestanteDespues;
        if (pago.diasMora > diasMora) diasMora = pago.diasMora;
      }

      final numerosOrdenados = numerosCuota.toList()..sort();
      final segmentos = <String>[
        if (numerosOrdenados.isNotEmpty) 'Cuota ${numerosOrdenados.join(', ')}',
        if (extraTotal > 0) 'Extra ${formatearMoneda(extraTotal)}',
      ];

      grupos.add(
        _GrupoPagoAdmin(
          tituloPrestamo: titulo,
          fecha: filas.first.fechaPago,
          filasConEtiqueta: filasConEtiqueta,
          resumenCorto: segmentos.isEmpty ? 'Pago' : segmentos.join(' + '),
          montoTotalAbonado: montoTotalAbonado,
          saldoRestanteDespues: saldoRestanteDespues.isFinite ? saldoRestanteDespues : 0,
          diasMora: diasMora,
        ),
      );
    }
  }

  grupos.sort((a, b) => b.fecha.compareTo(a.fecha));
  return grupos;
}

class _TarjetaGrupoPagoAdmin extends StatelessWidget {
  const _TarjetaGrupoPagoAdmin({required this.grupo});

  final _GrupoPagoAdmin grupo;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('${grupo.tituloPrestamo} · ${grupo.resumenCorto}'),
        subtitle: Text(
          '${_formatearFecha(grupo.fecha)}'
          '${grupo.diasMora > 0 ? ' · ${grupo.diasMora} días de mora' : ''}'
          ' · ${formatearMoneda(grupo.montoTotalAbonado)}'
          ' · Saldo restante: ${formatearMoneda(grupo.saldoRestanteDespues)}',
        ),
        children: [
          for (final (pago, etiqueta) in grupo.filasConEtiqueta)
            ListTile(
              title: Text(etiqueta),
              trailing: Text(formatearMoneda(pago.montoAbonado), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaCierreCaja extends StatelessWidget {
  const _TarjetaCierreCaja({required this.cierre});

  final CierreCajaResumen cierre;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(_formatearFecha(cierre.fecha)),
        subtitle: Text(
          'Inicio: ${formatearMoneda(cierre.capitalInicio)} · '
          'Cierre: ${formatearMoneda(cierre.capitalCierre)} · '
          'Gastos: ${formatearMoneda(cierre.gastosTotal)}',
        ),
        children: [
          if (cierre.justificacionDiferencia != null && cierre.justificacionDiferencia!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Justificación'),
              subtitle: Text(cierre.justificacionDiferencia!),
            ),
          if (cierre.gastos.isEmpty)
            const ListTile(title: Text('Sin gastos registrados ese día.'))
          else
            for (final gasto in cierre.gastos)
              ListTile(title: Text(gasto.detalle), trailing: Text(formatearMoneda(gasto.monto))),
        ],
      ),
    );
  }
}

class _FilaCargaCapital extends StatelessWidget {
  const _FilaCargaCapital({required this.carga});

  final CargaCapitalResumen carga;

  @override
  Widget build(BuildContext context) {
    final esRetiro = carga.tipo == 'retiro';
    final asignadoPorAdmin = carga.origen == 'admin';

    return ListTile(
      leading: Icon(
        esRetiro ? Icons.arrow_downward : Icons.arrow_upward,
        color: esRetiro ? Colors.red : Colors.green,
      ),
      title: Text(
        '${esRetiro ? '-' : '+'} ${formatearMoneda(carga.monto)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [_formatearFecha(carga.creadoEn), if (carga.descripcion != null && carga.descripcion!.isNotEmpty) carga.descripcion!]
                .join(' · '),
          ),
          if (asignadoPorAdmin) ...[
            const SizedBox(height: 4),
            const Chip(
              label: Text('Asignado por administrador', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Título de un préstamo: "Nombre del cliente - Referencia", o solo el
/// nombre del cliente si no tiene referencia.
String _tituloPrestamo(PrestamoResumen prestamo, String nombreCliente) {
  final referencia = prestamo.referencia;
  return (referencia != null && referencia.isNotEmpty) ? '$nombreCliente - $referencia' : nombreCliente;
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Fecha esperada de una cuota y, si ya está pagada, la fecha real en que se
/// pagó (en un color distinto para diferenciarla de la esperada).
Widget _subtituloFechasCuota(CuotaResumen cuota) {
  final fechaPago = cuota.fechaPago;
  if (fechaPago == null) {
    return Text('Esperada: ${_formatearFecha(cuota.fechaEsperada)}');
  }

  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'Esperada: ${_formatearFecha(cuota.fechaEsperada)} · '),
        TextSpan(
          text: 'Pagada: ${_formatearFecha(fechaPago)}',
          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _BadgeConteoPrestamos extends StatelessWidget {
  const _BadgeConteoPrestamos({required this.conteo});

  final (int pagados, int totales) conteo;

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                if (prestamo.extraCobrado > 0)
                  _FilaResumen(
                    etiqueta: 'Extra cobrado (no aplica a la deuda)',
                    valor: formatearMoneda(prestamo.extraCobrado),
                  ),
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
                  subtitle: _subtituloFechasCuota(cuota),
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
          Flexible(child: Text(etiqueta, style: estilo, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
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
