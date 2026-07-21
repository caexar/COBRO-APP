import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/cierres_caja_repository.dart';

class _GastoControllers {
  final monto = TextEditingController();
  final detalle = TextEditingController();

  void dispose() {
    monto.dispose();
    detalle.dispose();
  }
}

/// Registro de cierre de caja diario: capital de inicio/cierre (prellenados
/// con el saldo disponible actual — mismo cálculo que
/// `DashboardRepository.calcularResumen`, editables), gastos del día y, si
/// el cobrador edita alguno de los dos capitales prellenados, una
/// justificación obligatoria de la diferencia. Guarda todo localmente en
/// Drift y lo encola para la próxima sincronización, mismo patrón
/// offline-first que `AgregarCapitalScreen`.
class CierreCajaScreen extends StatefulWidget {
  const CierreCajaScreen({super.key, this.repository, this.dashboardRepository});

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final CierresCajaRepository? repository;
  final DashboardRepository? dashboardRepository;

  @override
  State<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  late final _repository = widget.repository ?? CierresCajaRepository();
  late final _dashboardRepository = widget.dashboardRepository ?? DashboardRepository();

  final _capitalInicioController = TextEditingController();
  final _capitalCierreController = TextEditingController();
  final _justificacionController = TextEditingController();
  final _gastos = <_GastoControllers>[];

  DateTime _fecha = DateTime.now();
  double? _capitalInicioPrellenado;
  double? _capitalCierrePrellenado;
  bool _cargandoSaldo = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _capitalInicioController.addListener(_alCambiarCapital);
    _capitalCierreController.addListener(_alCambiarCapital);
    _cargarSaldoDisponible();
  }

  @override
  void dispose() {
    _capitalInicioController.removeListener(_alCambiarCapital);
    _capitalCierreController.removeListener(_alCambiarCapital);
    _capitalInicioController.dispose();
    _capitalCierreController.dispose();
    _justificacionController.dispose();
    for (final gasto in _gastos) {
      gasto.dispose();
    }
    super.dispose();
  }

  void _alCambiarCapital() => setState(() {});

  Future<void> _cargarSaldoDisponible() async {
    try {
      final resumen = await _dashboardRepository.calcularResumen();
      if (!mounted) return;
      setState(() {
        _capitalInicioPrellenado = resumen.saldoDisponible;
        _capitalCierrePrellenado = resumen.saldoDisponible;
        _capitalInicioController.text = _formatearSinPrefijo(resumen.saldoDisponible);
        _capitalCierreController.text = _formatearSinPrefijo(resumen.saldoDisponible);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo calcular el saldo disponible: $e');
    } finally {
      if (mounted) setState(() => _cargandoSaldo = false);
    }
  }

  String _formatearSinPrefijo(double valor) => formatearMoneda(valor).replaceFirst(r'$ ', '');

  bool _difiereDelPrellenado(TextEditingController controller, double? prellenado) {
    if (prellenado == null) return false;
    final actual = FormateadorDinero.valorNumerico(controller.text);
    if (actual == null) return false;
    return actual.round() != prellenado.round();
  }

  bool get _requiereJustificacion =>
      _difiereDelPrellenado(_capitalInicioController, _capitalInicioPrellenado) ||
      _difiereDelPrellenado(_capitalCierreController, _capitalCierrePrellenado);

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  void _agregarGasto() => setState(() => _gastos.add(_GastoControllers()));

  void _eliminarGasto(int indice) => setState(() => _gastos.removeAt(indice).dispose());

  double get _totalGastos {
    var total = 0.0;
    for (final controles in _gastos) {
      total += FormateadorDinero.valorNumerico(controles.monto.text) ?? 0;
    }
    return total;
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final capitalInicio = FormateadorDinero.valorNumerico(_capitalInicioController.text);
    final capitalCierre = FormateadorDinero.valorNumerico(_capitalCierreController.text);
    if (capitalInicio == null || capitalCierre == null) return;

    final justificacion = _justificacionController.text.trim();
    if (_requiereJustificacion && justificacion.isEmpty) {
      setState(() => _error = 'Debes justificar el cambio en el capital de inicio o de cierre.');
      return;
    }

    final gastos = <GastoCierreCaja>[];
    for (final controles in _gastos) {
      final monto = FormateadorDinero.valorNumerico(controles.monto.text);
      final detalle = controles.detalle.text.trim();
      if (monto != null && monto > 0 && detalle.isNotEmpty) {
        gastos.add(GastoCierreCaja(monto: monto, detalle: detalle));
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _repository.crear(
        fecha: _fecha,
        capitalInicio: capitalInicio,
        capitalCierre: capitalCierre,
        justificacionDiferencia: justificacion.isEmpty ? null : justificacion,
        gastos: gastos,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo registrar el cierre de caja: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capitalInicio = FormateadorDinero.valorNumerico(_capitalInicioController.text);
    final capitalCierre = FormateadorDinero.valorNumerico(_capitalCierreController.text);
    final puedeGuardar = !_cargandoSaldo && !_guardando && capitalInicio != null && capitalCierre != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Cierre de caja')),
      body: SafeArea(
        child: _cargandoSaldo
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _elegirFecha,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha', border: OutlineInputBorder()),
                        child: Text(_formatearFecha(_fecha)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _capitalInicioController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FormateadorDinero()],
                      decoration: const InputDecoration(
                        labelText: 'Capital de inicio',
                        border: OutlineInputBorder(),
                        prefixText: r'$ ',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _capitalCierreController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FormateadorDinero()],
                      decoration: const InputDecoration(
                        labelText: 'Capital de cierre',
                        border: OutlineInputBorder(),
                        prefixText: r'$ ',
                      ),
                    ),
                    if (_requiereJustificacion) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: _justificacionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Justificación de la diferencia',
                          hintText: 'Explica por qué el capital cambió respecto al saldo calculado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gastos del día', style: Theme.of(context).textTheme.labelLarge),
                        TextButton.icon(onPressed: _agregarGasto, icon: const Icon(Icons.add), label: const Text('Agregar gasto')),
                      ],
                    ),
                    for (var i = 0; i < _gastos.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _gastos[i].monto,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FormateadorDinero()],
                                decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _gastos[i].detalle,
                                decoration: const InputDecoration(
                                  labelText: 'Detalle',
                                  hintText: 'Ej. "almuerzo"',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Quitar',
                              onPressed: () => _eliminarGasto(i),
                            ),
                          ],
                        ),
                      ),
                    if (_gastos.isNotEmpty)
                      Text(
                        'Total gastos: ${formatearMoneda(_totalGastos)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
                          : const Text('Guardar cierre', style: TextStyle(fontSize: 17)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
