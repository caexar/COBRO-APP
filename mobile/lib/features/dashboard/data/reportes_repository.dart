import 'package:csv/csv.dart';

import '../../../core/utils/csv_exportador.dart';
import '../../../core/utils/formato_dinero.dart';
import '../../capital/data/cierres_caja_repository.dart';
import '../../clientes/data/clientes_repository.dart';
import '../../pagos/data/pagos_repository.dart';
import '../../prestamos/data/prestamos_repository.dart';
import 'dashboard_repository.dart';

/// Arma y comparte un reporte en CSV: resumen de cartera, listado de
/// préstamos, historial de pagos filtrable por rango de fechas y cliente
/// (con el total ingresado por cliente en ese rango), y cierre de caja
/// (diario + resumen agregado del rango) — mismas 5 secciones que arma el
/// panel admin (`AdminReportesRepository`) a partir del backend, acá
/// calculadas localmente desde Drift (offline-first).
class ReportesRepository {
  ReportesRepository({
    PrestamosRepository? prestamosRepository,
    PagosRepository? pagosRepository,
    ClientesRepository? clientesRepository,
    DashboardRepository? dashboardRepository,
    CierresCajaRepository? cierresCajaRepository,
  }) : _prestamosRepository = prestamosRepository ?? PrestamosRepository(),
       _pagosRepository = pagosRepository ?? PagosRepository(),
       _clientesRepository = clientesRepository ?? ClientesRepository(),
       _dashboardRepository = dashboardRepository ?? DashboardRepository(),
       _cierresCajaRepository = cierresCajaRepository ?? CierresCajaRepository();

  final PrestamosRepository _prestamosRepository;
  final PagosRepository _pagosRepository;
  final ClientesRepository _clientesRepository;
  final DashboardRepository _dashboardRepository;
  final CierresCajaRepository _cierresCajaRepository;

  /// Arma el texto CSV, sin tocar el sistema de archivos ni ningún plugin
  /// (fácil de testear). [desde]/[hasta] filtran el historial de pagos por
  /// `fechaPago` (inclusive); [clienteId] lo acota a un solo cliente.
  Future<String> construirCsv({DateTime? desde, DateTime? hasta, int? clienteId}) async {
    final clientes = await _clientesRepository.listar();
    final clientePorId = {for (final cliente in clientes) cliente.id: cliente};

    final prestamos = await _prestamosRepository.listarTodos();
    final prestamoPorId = {for (final prestamo in prestamos) prestamo.id: prestamo};

    final resumen = await _dashboardRepository.calcularResumen();

    final filas = <List<dynamic>>[
      ['Resumen de cartera'],
      ['Cartera por cobrar', formatearMoneda(resumen.carteraPorCobrar)],
      ['Saldo disponible', formatearMoneda(resumen.saldoDisponible)],
      ['Ganancia realizada', formatearMoneda(resumen.gananciaTotal)],
      [],
      ['Préstamos'],
      ['Cliente', 'Referencia', 'Saldo pendiente', 'Estado'],
    ];

    for (final prestamo in prestamos) {
      final cliente = clientePorId[prestamo.clienteId];
      final detalle = await _prestamosRepository.obtenerDetalle(prestamo.id);
      final pagosPrestamo = await _pagosRepository.listarPorPrestamo(prestamo.id);
      final totalAplicado = pagosPrestamo.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
      final saldoPendiente = detalle.montoTotal - totalAplicado;

      filas.add([
        cliente?.nombre ?? 'Cliente #${prestamo.clienteId}',
        prestamo.referencia ?? '',
        formatearMoneda(saldoPendiente < 0 ? 0 : saldoPendiente),
        prestamo.estado,
      ]);
    }

    filas.addAll([
      [],
      ['Historial de pagos'],
      ['Fecha', 'Cliente', 'Préstamo', 'Monto abonado', 'Saldo restante después'],
    ]);

    final pagos = await _pagosRepository.listarTodos();
    final totalPorCliente = <int, double>{};

    for (final pago in pagos) {
      if (desde != null && pago.fechaPago.isBefore(desde)) continue;
      if (hasta != null && pago.fechaPago.isAfter(hasta)) continue;

      final prestamo = prestamoPorId[pago.prestamoId];
      if (prestamo == null) continue;
      if (clienteId != null && prestamo.clienteId != clienteId) continue;

      final cliente = clientePorId[prestamo.clienteId];
      filas.add([
        _formatearFecha(pago.fechaPago),
        cliente?.nombre ?? 'Cliente #${prestamo.clienteId}',
        prestamo.referencia ?? 'Préstamo #${prestamo.id}',
        formatearMoneda(pago.montoAbonado),
        formatearMoneda(pago.saldoRestanteDespues),
      ]);

      totalPorCliente.update(
        prestamo.clienteId,
        (valor) => valor + pago.montoAbonado,
        ifAbsent: () => pago.montoAbonado,
      );
    }

    filas.addAll([
      [],
      ['Total ingresado por cliente en el rango'],
      ['Cliente', 'Total'],
    ]);
    for (final entrada in totalPorCliente.entries) {
      final cliente = clientePorId[entrada.key];
      filas.add([cliente?.nombre ?? 'Cliente #${entrada.key}', formatearMoneda(entrada.value)]);
    }

    await _agregarSeccionCierreCaja(filas, desde: desde, hasta: hasta);

    return Csv().encode(filas);
  }

  /// Cierre de caja: una fila por día (fecha operativa, no filtra por
  /// préstamo/cliente) dentro de [desde]/[hasta], más un resumen agregado
  /// del rango (capital inicio del primer día, capital cierre del último,
  /// suma de gastos) — misma lógica que
  /// `ExportarReporteService::filasCierreCaja()`/`filasCierreCajaResumen()`
  /// del backend, replicada acá porque este reporte se arma offline.
  Future<void> _agregarSeccionCierreCaja(List<List<dynamic>> filas, {DateTime? desde, DateTime? hasta}) async {
    final cierres = await _cierresCajaRepository.listarTodos();
    final enRango =
        cierres.where((cierre) {
          if (desde != null && cierre.fecha.isBefore(desde)) return false;
          if (hasta != null && cierre.fecha.isAfter(hasta)) return false;
          return true;
        }).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    filas.addAll([
      [],
      ['Cierre de caja'],
      ['Fecha', 'Capital inicio', 'Capital cierre', 'Total gastos', 'Detalle de gastos', 'Justificación'],
    ]);

    for (final cierre in enRango) {
      final gastos = await _cierresCajaRepository.obtenerGastos(cierre.id);
      final detalleGastos = gastos.map((gasto) => '${gasto.detalle} (${formatearMoneda(gasto.monto)})').join('; ');

      filas.add([
        _formatearFecha(cierre.fecha),
        formatearMoneda(cierre.capitalInicio),
        formatearMoneda(cierre.capitalCierre),
        formatearMoneda(cierre.gastosTotal),
        detalleGastos,
        cierre.justificacionDiferencia ?? '',
      ]);
    }

    filas.addAll([
      [],
      ['Resumen de cierre de caja (rango)'],
      ['Capital inicio (primer día)', 'Capital cierre (último día)', 'Total gastos (rango)'],
    ]);

    if (enRango.isNotEmpty) {
      final totalGastosRango = enRango.fold<double>(0, (acumulado, cierre) => acumulado + cierre.gastosTotal);
      filas.add([
        formatearMoneda(enRango.first.capitalInicio),
        formatearMoneda(enRango.last.capitalCierre),
        formatearMoneda(totalGastosRango),
      ]);
    }
  }

  /// Arma el CSV y lo comparte como archivo vía `share_plus`, escrito en un
  /// directorio temporal.
  Future<void> exportarYCompartir({DateTime? desde, DateTime? hasta, int? clienteId}) async {
    final contenidoCsv = await construirCsv(desde: desde, hasta: hasta, clienteId: clienteId);

    await exportarCsvYCompartir(
      contenidoCsv: contenidoCsv,
      nombreArchivo: 'cobro_app_reporte_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
