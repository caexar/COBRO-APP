import 'package:flutter/material.dart';

import '../data/prestamo_calculator.dart';

/// Datos válidos y ya calculados que expone [PrestamoCalculadoraFormulario]
/// cada vez que el usuario completa lo suficiente para calcular un resultado.
class DatosPrestamoFormulario {
  const DatosPrestamoFormulario({
    required this.montoCapital,
    required this.porcentajeInteres,
    required this.extras,
    required this.frecuenciaPago,
    required this.diasPersonalizado,
    required this.plazoCuotas,
    required this.fechaInicio,
    required this.resultado,
  });

  final double montoCapital;
  final double porcentajeInteres;
  final List<ExtraPrestamo> extras;
  final String frecuenciaPago;
  final int? diasPersonalizado;
  final int plazoCuotas;
  final DateTime fechaInicio;
  final ResultadoCalculoPrestamo resultado;
}

class _ExtraControllers {
  final concepto = TextEditingController();
  final valor = TextEditingController();

  void dispose() {
    concepto.dispose();
    valor.dispose();
  }
}

/// Formulario de cálculo de préstamo (capital, interés, extras, frecuencia,
/// plazo, fecha) reutilizado tanto por "Nuevo préstamo" como por "Simular
/// préstamo", para no duplicar la lógica de cálculo ni la UI entre ambos.
/// Recalcula en tiempo real con [PrestamoCalculator] y avisa al padre vía
/// [onDatosValidosCambiados] (con `null` mientras falten datos).
class PrestamoCalculadoraFormulario extends StatefulWidget {
  const PrestamoCalculadoraFormulario({super.key, this.onDatosValidosCambiados});

  final ValueChanged<DatosPrestamoFormulario?>? onDatosValidosCambiados;

  @override
  State<PrestamoCalculadoraFormulario> createState() => _PrestamoCalculadoraFormularioState();
}

class _PrestamoCalculadoraFormularioState extends State<PrestamoCalculadoraFormulario> {
  static const _porcentajesRapidos = [10.0, 20.0, 30.0, 40.0];
  static const _frecuencias = {
    'diario': 'Diario',
    'semanal': 'Semanal',
    'mensual': 'Mensual',
    'personalizado': 'Personalizado',
  };
  static const _calculadora = PrestamoCalculator();

  final _capitalController = TextEditingController();
  final _porcentajePersonalizadoController = TextEditingController();
  final _plazoController = TextEditingController();
  final _diasPersonalizadoController = TextEditingController();
  final _extras = <_ExtraControllers>[];

  double? _porcentajeSeleccionado;
  bool _porcentajePersonalizado = false;
  String _frecuenciaPago = 'diario';
  DateTime _fechaInicio = DateTime.now();
  ResultadoCalculoPrestamo? _resultado;

  @override
  void initState() {
    super.initState();
    _capitalController.addListener(_recalcular);
    _porcentajePersonalizadoController.addListener(_recalcular);
    _plazoController.addListener(_recalcular);
    _diasPersonalizadoController.addListener(_recalcular);
  }

  @override
  void dispose() {
    _capitalController.dispose();
    _porcentajePersonalizadoController.dispose();
    _plazoController.dispose();
    _diasPersonalizadoController.dispose();
    for (final extra in _extras) {
      extra.dispose();
    }
    super.dispose();
  }

  double? get _porcentajeActual {
    if (_porcentajePersonalizado) {
      return double.tryParse(_porcentajePersonalizadoController.text.replaceAll(',', '.'));
    }
    return _porcentajeSeleccionado;
  }

  void _agregarExtra() {
    setState(() {
      final controles = _ExtraControllers();
      controles.concepto.addListener(_recalcular);
      controles.valor.addListener(_recalcular);
      _extras.add(controles);
    });
  }

  void _eliminarExtra(int indice) {
    setState(() => _extras.removeAt(indice).dispose());
    _recalcular();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha == null) return;
    setState(() => _fechaInicio = fecha);
    _recalcular();
  }

  void _recalcular() {
    final capital = double.tryParse(_capitalController.text.replaceAll(',', '.'));
    final porcentaje = _porcentajeActual;
    final plazo = int.tryParse(_plazoController.text);
    final diasPersonalizado = _frecuenciaPago == 'personalizado'
        ? int.tryParse(_diasPersonalizadoController.text)
        : null;

    final extras = <ExtraPrestamo>[];
    for (final controles in _extras) {
      final concepto = controles.concepto.text.trim();
      final valor = double.tryParse(controles.valor.text.replaceAll(',', '.'));
      if (concepto.isNotEmpty && valor != null && valor > 0) {
        extras.add(ExtraPrestamo(concepto: concepto, valor: valor));
      }
    }

    final datosCompletos =
        capital != null &&
        capital > 0 &&
        porcentaje != null &&
        porcentaje >= 0 &&
        plazo != null &&
        plazo > 0 &&
        (_frecuenciaPago != 'personalizado' || (diasPersonalizado != null && diasPersonalizado > 0));

    if (!datosCompletos) {
      setState(() => _resultado = null);
      widget.onDatosValidosCambiados?.call(null);
      return;
    }

    final resultado = _calculadora.calcular(
      montoCapital: capital,
      porcentajeInteres: porcentaje,
      extras: extras,
      frecuenciaPago: _frecuenciaPago,
      diasPersonalizado: diasPersonalizado,
      plazoCuotas: plazo,
      fechaInicio: _fechaInicio,
    );

    setState(() => _resultado = resultado);
    widget.onDatosValidosCambiados?.call(
      DatosPrestamoFormulario(
        montoCapital: capital,
        porcentajeInteres: porcentaje,
        extras: extras,
        frecuenciaPago: _frecuenciaPago,
        diasPersonalizado: diasPersonalizado,
        plazoCuotas: plazo,
        fechaInicio: _fechaInicio,
        resultado: resultado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _capitalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto de capital',
            border: OutlineInputBorder(),
            prefixText: r'$ ',
          ),
        ),
        const SizedBox(height: 20),
        Text('Porcentaje de interés', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final porcentaje in _porcentajesRapidos)
              ChoiceChip(
                label: Text('${porcentaje.toInt()}%', style: const TextStyle(fontSize: 16)),
                selected: !_porcentajePersonalizado && _porcentajeSeleccionado == porcentaje,
                onSelected: (_) {
                  setState(() {
                    _porcentajePersonalizado = false;
                    _porcentajeSeleccionado = porcentaje;
                  });
                  _recalcular();
                },
              ),
            ChoiceChip(
              label: const Text('Personalizado', style: TextStyle(fontSize: 16)),
              selected: _porcentajePersonalizado,
              onSelected: (_) {
                setState(() => _porcentajePersonalizado = true);
                _recalcular();
              },
            ),
          ],
        ),
        if (_porcentajePersonalizado) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _porcentajePersonalizadoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '% de interés', border: OutlineInputBorder(), suffixText: '%'),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Montos extra', style: Theme.of(context).textTheme.labelLarge),
            TextButton.icon(onPressed: _agregarExtra, icon: const Icon(Icons.add), label: const Text('Agregar otro')),
          ],
        ),
        for (var i = 0; i < _extras.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _extras[i].concepto,
                    decoration: const InputDecoration(labelText: 'Concepto', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _extras[i].valor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor', border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar',
                  onPressed: () => _eliminarExtra(i),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text('Frecuencia de pago', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entrada in _frecuencias.entries)
              ChoiceChip(
                label: Text(entrada.value, style: const TextStyle(fontSize: 16)),
                selected: _frecuenciaPago == entrada.key,
                onSelected: (_) {
                  setState(() => _frecuenciaPago = entrada.key);
                  _recalcular();
                },
              ),
          ],
        ),
        if (_frecuenciaPago == 'personalizado') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _diasPersonalizadoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cada cuántos días', border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _plazoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Plazo (número de cuotas)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _elegirFecha,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fecha de inicio', border: OutlineInputBorder()),
            child: Text(_formatearFecha(_fechaInicio), style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 28),
        _TarjetaResultado(resultado: _resultado),
      ],
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

String formatearMoneda(double valor) {
  final parteEntera = valor.truncate().toString();
  final conSeparadorDeMiles = parteEntera.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  return '\$ $conSeparadorDeMiles';
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({required this.resultado});

  final ResultadoCalculoPrestamo? resultado;

  @override
  Widget build(BuildContext context) {
    final resultado = this.resultado;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: resultado == null
            ? const Text(
                'Completa capital, interés y plazo para ver el total a pagar.',
                textAlign: TextAlign.center,
              )
            : Column(
                children: [
                  Text('Total a pagar', style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    formatearMoneda(resultado.montoTotal),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Valor de cada cuota: ${formatearMoneda(resultado.cuotas.first.montoEsperado)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${resultado.cuotas.length} cuotas', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
      ),
    );
  }
}
