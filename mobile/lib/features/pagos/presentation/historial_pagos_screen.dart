import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../prestamos/data/prestamos_repository.dart';
import '../data/pagos_repository.dart';

/// Todas las filas de `pagos` que comparten una misma `fecha_pago` (es decir,
/// que vinieron de una sola llamada a `PagosRepository.registrar()`, aunque
/// hayan generado varias filas por una cascada de `abono_deuda`).
class _GrupoPago {
  const _GrupoPago({
    required this.fecha,
    required this.filas,
    required this.resumenCorto,
    required this.montoTotalAbonado,
    required this.saldoRestanteDespues,
    required this.diasMora,
  });

  final DateTime fecha;
  final List<Pago> filas;
  final String resumenCorto;
  final double montoTotalAbonado;
  final double saldoRestanteDespues;
  final int diasMora;
}

/// Historial de pagos de un préstamo: cada pago registrado (que puede
/// abarcar varias filas de `pagos` por una cascada de excedente) se muestra
/// como una sola línea con un resumen corto; al tocarla se expande el
/// desglose completo por fila.
class HistorialPagosScreen extends StatefulWidget {
  const HistorialPagosScreen({super.key, required this.prestamoId, this.repository, this.prestamosRepository});

  final int prestamoId;

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final PagosRepository? repository;
  final PrestamosRepository? prestamosRepository;

  @override
  State<HistorialPagosScreen> createState() => _HistorialPagosScreenState();
}

class _HistorialPagosScreenState extends State<HistorialPagosScreen> {
  late final _repository = widget.repository ?? PagosRepository();
  late final _prestamosRepository = widget.prestamosRepository ?? PrestamosRepository();
  List<_GrupoPago>? _grupos;
  Map<int, String> _descripcionesPorPago = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final pagos = await _repository.listarPorPrestamo(widget.prestamoId);
    final detalle = await _prestamosRepository.obtenerDetalle(widget.prestamoId);
    final numeroCuotaPorCuotaId = {for (final cuota in detalle.cuotas) cuota.id: cuota.numeroCuota};
    final descripciones = _describirPagos(pagos, numeroCuotaPorCuotaId);
    final grupos = _agruparPagos(pagos, numeroCuotaPorCuotaId);
    if (!mounted) return;
    setState(() {
      _grupos = grupos;
      _descripcionesPorPago = descripciones;
    });
  }

  /// Etiqueta cada fila de pago según cómo la generó `PagoProcessor`: el pago
  /// exacto/faltante de una cuota ("Pago cuota N"), una fila de cascada de
  /// `abono_deuda` sobre una cuota siguiente ("Abono cuota N") o el registro
  /// de un excedente `cobro_extra` ("Extra"). Se agrupan por `fecha_pago`
  /// (todas las filas de una misma llamada a `registrar()` comparten la
  /// misma fecha): dentro de un grupo con más de una fila, la de menor
  /// `numero_cuota` es la principal y el resto son cascada.
  Map<int, String> _describirPagos(List<Pago> pagos, Map<int, int> numeroCuotaPorCuotaId) {
    final descripciones = <int, String>{};
    for (final grupo in _agruparPorFecha(pagos).values) {
      final ordenado = _ordenarPorNumeroCuota(grupo, numeroCuotaPorCuotaId);

      for (var indice = 0; indice < ordenado.length; indice++) {
        final pago = ordenado[indice];
        final numero = numeroCuotaPorCuotaId[pago.cuotaId];

        if (pago.montoAbonado != pago.montoAplicado) {
          descripciones[pago.id] = 'Extra';
        } else if (indice == 0) {
          descripciones[pago.id] = numero != null ? 'Pago cuota $numero' : 'Pago';
        } else {
          descripciones[pago.id] = numero != null ? 'Abono cuota $numero' : 'Abono';
        }
      }
    }

    return descripciones;
  }

  /// Arma un `_GrupoPago` por cada `fecha_pago` distinta, del más reciente al
  /// más antiguo, con un resumen corto (ej. "Cuota 2 + Extra $ 50.000" o
  /// "Cuota 1, 2" si la cascada cubrió varias cuotas completas).
  List<_GrupoPago> _agruparPagos(List<Pago> pagos, Map<int, int> numeroCuotaPorCuotaId) {
    final grupos = <_GrupoPago>[];

    for (final filas in _agruparPorFecha(pagos).values) {
      final numerosCuota = <int>{};
      var extraTotal = 0.0;
      var montoTotalAbonado = 0.0;
      var saldoRestanteDespues = double.infinity;
      var diasMora = 0;

      for (final fila in filas) {
        final numero = numeroCuotaPorCuotaId[fila.cuotaId];
        if (numero != null) numerosCuota.add(numero);

        extraTotal += fila.montoAbonado - fila.montoAplicado;
        montoTotalAbonado += fila.montoAbonado;
        if (fila.saldoRestanteDespues < saldoRestanteDespues) saldoRestanteDespues = fila.saldoRestanteDespues;
        if (fila.diasMora > diasMora) diasMora = fila.diasMora;
      }

      final numerosOrdenados = numerosCuota.toList()..sort();
      final segmentos = <String>[
        if (numerosOrdenados.isNotEmpty) 'Cuota ${numerosOrdenados.join(', ')}',
        if (extraTotal > 0) 'Extra ${formatearMoneda(extraTotal)}',
      ];

      grupos.add(
        _GrupoPago(
          fecha: filas.first.fechaPago,
          filas: _ordenarPorNumeroCuota(filas, numeroCuotaPorCuotaId),
          resumenCorto: segmentos.isEmpty ? 'Pago' : segmentos.join(' + '),
          montoTotalAbonado: montoTotalAbonado,
          saldoRestanteDespues: saldoRestanteDespues.isFinite ? saldoRestanteDespues : 0,
          diasMora: diasMora,
        ),
      );
    }

    grupos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return grupos;
  }

  Map<int, List<Pago>> _agruparPorFecha(List<Pago> pagos) {
    final grupos = <int, List<Pago>>{};
    for (final pago in pagos) {
      grupos.putIfAbsent(pago.fechaPago.millisecondsSinceEpoch, () => []).add(pago);
    }
    return grupos;
  }

  List<Pago> _ordenarPorNumeroCuota(List<Pago> filas, Map<int, int> numeroCuotaPorCuotaId) {
    return [...filas]..sort((a, b) {
      final numeroA = numeroCuotaPorCuotaId[a.cuotaId] ?? 0;
      final numeroB = numeroCuotaPorCuotaId[b.cuotaId] ?? 0;
      return numeroA.compareTo(numeroB);
    });
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _grupos;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: grupos == null
          ? const Center(child: CircularProgressIndicator())
          : grupos.isEmpty
          ? const Center(child: Text('Todavía no hay pagos registrados.'))
          : SafeArea(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: grupos.length,
                separatorBuilder: (context, indice) => const SizedBox(height: 8),
                itemBuilder: (context, indice) => _TarjetaGrupoPago(
                  grupo: grupos[indice],
                  descripcionesPorPago: _descripcionesPorPago,
                ),
              ),
            ),
    );
  }
}

class _TarjetaGrupoPago extends StatelessWidget {
  const _TarjetaGrupoPago({required this.grupo, required this.descripcionesPorPago});

  final _GrupoPago grupo;
  final Map<int, String> descripcionesPorPago;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('${grupo.resumenCorto} · ${formatearMoneda(grupo.montoTotalAbonado)}'),
        subtitle: Text(
          '${_formatearFecha(grupo.fecha)}'
          '${grupo.diasMora > 0 ? ' · ${grupo.diasMora} días de mora' : ''}'
          ' · Saldo restante: ${formatearMoneda(grupo.saldoRestanteDespues)}',
        ),
        children: [
          for (final fila in grupo.filas)
            ListTile(
              title: Text(descripcionesPorPago[fila.id] ?? 'Pago'),
              trailing: Text(formatearMoneda(fila.montoAbonado), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
