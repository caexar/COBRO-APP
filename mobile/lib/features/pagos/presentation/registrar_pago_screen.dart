import 'package:flutter/material.dart';

import '../../../core/utils/atajo_miles_repository.dart';
import '../../../core/utils/formato_dinero.dart';
import '../../prestamos/data/prestamos_repository.dart';
import '../data/pagos_repository.dart';

/// Formulario para registrar un pago sobre un préstamo: monto abonado y
/// fecha (hoy por defecto, editable a cualquier fecha). Si el abono no
/// alcanza a cubrir la cuota pendiente más antigua o la supera, le pregunta
/// al cobrador cómo proceder antes de guardar (ver [PagosRepository.registrar]).
class RegistrarPagoScreen extends StatefulWidget {
  const RegistrarPagoScreen({super.key, required this.prestamoId, this.atajoMilesRepository});

  final int prestamoId;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final AtajoMilesRepository? atajoMilesRepository;

  @override
  State<RegistrarPagoScreen> createState() => _RegistrarPagoScreenState();
}

class _RegistrarPagoScreenState extends State<RegistrarPagoScreen> {
  final _repository = PagosRepository();
  final _prestamosRepository = PrestamosRepository();
  late final _atajoMilesRepository = widget.atajoMilesRepository ?? AtajoMilesRepository();
  final _montoController = TextEditingController();

  DateTime _fechaPago = DateTime.now();
  bool _guardando = false;
  bool _atajoMilesActivado = true;
  String? _error;
  Cuota? _cuotaReferencia;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(_alCambiarMonto);
    _cargarCuotaReferencia();
    _cargarAtajoMiles();
  }

  Future<void> _cargarAtajoMiles() async {
    final activado = await _atajoMilesRepository.estaActivado();
    if (!mounted) return;
    setState(() => _atajoMilesActivado = activado);
  }

  @override
  void dispose() {
    _montoController.removeListener(_alCambiarMonto);
    _montoController.dispose();
    super.dispose();
  }

  // El botón "Registrar pago" depende del monto ingresado; sin este listener
  // la pantalla solo se redibuja cuando algo más llama a setState (ej. elegir
  // fecha), así que el botón parecía quedar bloqueado hasta tocar la fecha
  // aunque el monto ya fuera válido.
  void _alCambiarMonto() => setState(() {});

  Future<void> _cargarCuotaReferencia() async {
    final detalle = await _prestamosRepository.obtenerDetalle(widget.prestamoId);
    final pendiente = detalle.cuotas.where((c) => c.estado != 'pagada').toList()
      ..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));
    if (!mounted || pendiente.isEmpty) return;
    setState(() => _cuotaReferencia = pendiente.first);
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha == null) return;
    setState(() => _fechaPago = fecha);
  }

  Future<void> _guardar() async {
    final monto = interpretarValorIngresado(_montoController.text, atajoMilesActivado: _atajoMilesActivado);
    if (monto == null || monto <= 0 || _guardando) return;

    final saldoPendiente = await _calcularSaldoPendiente();
    if (!mounted) return;

    if (monto > saldoPendiente) {
      final confirmar = await _confirmarMontoMayorASaldo(monto, saldoPendiente);
      if (confirmar != true) return;
      if (!mounted) return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _intentarRegistrar(montoAbonado: monto, fechaPago: _fechaPago);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Suma total del préstamo menos lo ya aplicado en pagos anteriores, para
  /// poder avisarle al cobrador si el abono que está por registrar supera lo
  /// que realmente falta (puede ser legítimo: un cliente que paga de más).
  Future<double> _calcularSaldoPendiente() async {
    final detalle = await _prestamosRepository.obtenerDetalle(widget.prestamoId);
    final pagos = await _repository.listarPorPrestamo(widget.prestamoId);
    final totalAplicado = pagos.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
    final saldo = detalle.montoTotal - totalAplicado;
    return saldo < 0 ? 0 : saldo;
  }

  Future<bool?> _confirmarMontoMayorASaldo(double monto, double saldoPendiente) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('El monto supera la deuda restante'),
        content: Text(
          'El monto ingresado es mayor a la deuda restante (${formatearMoneda(saldoPendiente)}). '
          '¿Confirmas que quieres registrarlo así?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
  }

  /// Intenta guardar el pago; si el repositorio pide una decisión sobre mora
  /// o excedente, muestra el diálogo correspondiente y reintenta con la
  /// elección del cobrador. Si el cobrador cancela un diálogo, no se guarda
  /// nada (el repositorio no escribe hasta calcular el plan completo).
  Future<void> _intentarRegistrar({
    required double montoAbonado,
    required DateTime fechaPago,
    String? politicaMora,
    String? manejoExcedente,
  }) async {
    try {
      await _repository.registrar(
        prestamoId: widget.prestamoId,
        montoAbonado: montoAbonado,
        fechaPago: fechaPago,
        politicaMora: politicaMora,
        manejoExcedente: manejoExcedente,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PoliticaMoraRequeridaException catch (e) {
      final eleccion = await _mostrarDialogoPoliticaMora(e.faltante);
      if (eleccion == null) return;
      await _intentarRegistrar(montoAbonado: montoAbonado, fechaPago: fechaPago, politicaMora: eleccion);
    } on ManejoExcedenteRequeridoException catch (e) {
      final eleccion = await _mostrarDialogoManejoExcedente(e.excedente);
      if (eleccion == null) return;
      await _intentarRegistrar(montoAbonado: montoAbonado, fechaPago: fechaPago, manejoExcedente: eleccion);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<String?> _mostrarDialogoPoliticaMora(double faltante) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleDialog(
        title: const Text('Este pago no cubre la cuota'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Falta ${formatearMoneda(faltante)} para completar la cuota. ¿Cómo lo manejamos?'),
          ),
          const SizedBox(height: 12),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('mantener'),
            child: const _OpcionDialogo(
              titulo: 'Mantener la cuota igual',
              subtitulo: 'El atraso corre y se extiende el plazo.',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('siguiente_pago'),
            child: const _OpcionDialogo(
              titulo: 'Cobrar el faltante en el siguiente pago',
              subtitulo: 'Se suma a la siguiente cuota pendiente.',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('sumar_total'),
            child: const _OpcionDialogo(
              titulo: 'Sumar el faltante al total de la deuda',
              subtitulo: 'Se reparte entre las demás cuotas pendientes.',
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _mostrarDialogoManejoExcedente(double excedente) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleDialog(
        title: const Text('Este pago supera lo pendiente de la cuota'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Hay un excedente de ${formatearMoneda(excedente)}. ¿Qué hacemos con él?'),
          ),
          const SizedBox(height: 12),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('abono_deuda'),
            child: const _OpcionDialogo(
              titulo: 'Abonar a la deuda',
              subtitulo: 'Reduce las siguientes cuotas pendientes.',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('cobro_extra'),
            child: const _OpcionDialogo(
              titulo: 'Registrar como cobro extra',
              subtitulo: 'No reduce la deuda del préstamo.',
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monto = interpretarValorIngresado(_montoController.text, atajoMilesActivado: _atajoMilesActivado);
    final puedeGuardar = monto != null && monto > 0 && !_guardando;
    final textoAyuda = textoAyudaAtajoMiles(_montoController.text, atajoMilesActivado: _atajoMilesActivado);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pago')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormateadorDinero()],
                decoration: const InputDecoration(
                  labelText: 'Monto abonado',
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
              if (_cuotaReferencia != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Cuota ${_cuotaReferencia!.numeroCuota}: ${formatearMoneda(_cuotaReferencia!.montoEsperado)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
              const SizedBox(height: 20),
              InkWell(
                onTap: _elegirFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha de pago', border: OutlineInputBorder()),
                  child: Text(_formatearFecha(_fechaPago), style: const TextStyle(fontSize: 16)),
                ),
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
                    : const Text('Registrar pago', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionDialogo extends StatelessWidget {
  const _OpcionDialogo({required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
