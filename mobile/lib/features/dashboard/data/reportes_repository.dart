import 'package:excel/excel.dart';

import '../../../core/utils/archivo_exportador.dart';
import '../../../core/utils/formato_dinero.dart';
import '../../capital/data/cierres_caja_repository.dart';
import '../../clientes/data/clientes_repository.dart';
import '../../pagos/data/pagos_repository.dart';
import '../../prestamos/data/prestamos_repository.dart';
import '../../rutas/data/rutas_repository.dart';
import 'dashboard_repository.dart';

/// Arma y comparte un reporte en `.xlsx`: resumen de cartera, listado de
/// préstamos, historial de pagos filtrable por rango de fechas y cliente
/// (con el total ingresado por cliente en ese rango), y cierre de caja
/// (diario + resumen agregado del rango) — una hoja por sección, mismo
/// contenido que antes armaba como CSV. Se genera enteramente en el
/// dispositivo con el paquete `excel` (sin pedirle nada al backend) para que
/// el cobrador pueda exportar su reporte sin conexión — a diferencia del
/// panel admin (`AdminReportesRepository`), que si descarga el `.xlsx` ya
/// armado del servidor, porque esa parte de la app nunca trabaja offline.
class ReportesRepository {
  ReportesRepository({
    PrestamosRepository? prestamosRepository,
    PagosRepository? pagosRepository,
    ClientesRepository? clientesRepository,
    DashboardRepository? dashboardRepository,
    CierresCajaRepository? cierresCajaRepository,
    RutasRepository? rutasRepository,
  }) : _prestamosRepository = prestamosRepository ?? PrestamosRepository(),
       _pagosRepository = pagosRepository ?? PagosRepository(),
       _clientesRepository = clientesRepository ?? ClientesRepository(),
       _dashboardRepository = dashboardRepository ?? DashboardRepository(),
       _cierresCajaRepository = cierresCajaRepository ?? CierresCajaRepository(),
       _rutasRepository = rutasRepository ?? RutasRepository();

  final PrestamosRepository _prestamosRepository;
  final PagosRepository _pagosRepository;
  final ClientesRepository _clientesRepository;
  final DashboardRepository _dashboardRepository;
  final CierresCajaRepository _cierresCajaRepository;
  final RutasRepository _rutasRepository;

  /// Arma el workbook, sin tocar el sistema de archivos ni ningún plugin
  /// (fácil de testear). [desde]/[hasta] filtran el historial de pagos por
  /// `fechaPago` (inclusive); [clienteId] lo acota a un solo cliente.
  Future<Excel> construirXlsx({DateTime? desde, DateTime? hasta, int? clienteId}) async {
    final excel = Excel.createExcel();
    final sheetPorDefecto = excel.getDefaultSheet();

    final clientes = await _clientesRepository.listar();
    final clientePorId = {for (final cliente in clientes) cliente.id: cliente};

    final prestamos = await _prestamosRepository.listarTodos();
    final prestamoPorId = {for (final prestamo in prestamos) prestamo.id: prestamo};

    final resumen = await _dashboardRepository.calcularResumen();

    final hojaResumen = excel['Resumen'];
    hojaResumen.appendRow([TextCellValue('Concepto'), TextCellValue('Valor')]);
    hojaResumen.appendRow([TextCellValue('Cartera por cobrar'), TextCellValue(formatearMoneda(resumen.carteraPorCobrar))]);
    hojaResumen.appendRow([TextCellValue('Saldo disponible'), TextCellValue(formatearMoneda(resumen.saldoDisponible))]);
    hojaResumen.appendRow([TextCellValue('Ganancia realizada'), TextCellValue(formatearMoneda(resumen.gananciaTotal))]);

    final hojaPrestamos = excel['Prestamos'];
    hojaPrestamos.appendRow(
      [TextCellValue('Cliente'), TextCellValue('Referencia'), TextCellValue('Saldo pendiente'), TextCellValue('Estado')],
    );
    for (final prestamo in prestamos) {
      final cliente = clientePorId[prestamo.clienteId];
      final saldoPendiente = await _saldoPendienteDe(prestamo);

      hojaPrestamos.appendRow([
        TextCellValue(cliente?.nombre ?? 'Cliente #${prestamo.clienteId}'),
        TextCellValue(prestamo.referencia ?? ''),
        TextCellValue(formatearMoneda(saldoPendiente)),
        TextCellValue(prestamo.estado),
      ]);
    }

    final hojaHistorial = excel['Historial de pagos'];
    hojaHistorial.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Cliente'),
      TextCellValue('Préstamo'),
      TextCellValue('Monto abonado'),
      TextCellValue('Saldo restante después'),
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
      hojaHistorial.appendRow([
        TextCellValue(_formatearFecha(pago.fechaPago)),
        TextCellValue(cliente?.nombre ?? 'Cliente #${prestamo.clienteId}'),
        TextCellValue(prestamo.referencia ?? 'Préstamo #${prestamo.id}'),
        TextCellValue(formatearMoneda(pago.montoAbonado)),
        TextCellValue(formatearMoneda(pago.saldoRestanteDespues)),
      ]);

      totalPorCliente.update(
        prestamo.clienteId,
        (valor) => valor + pago.montoAbonado,
        ifAbsent: () => pago.montoAbonado,
      );
    }

    final hojaTotalPorCliente = excel['Total por cliente'];
    hojaTotalPorCliente.appendRow([TextCellValue('Cliente'), TextCellValue('Total')]);
    for (final entrada in totalPorCliente.entries) {
      final cliente = clientePorId[entrada.key];
      hojaTotalPorCliente.appendRow([
        TextCellValue(cliente?.nombre ?? 'Cliente #${entrada.key}'),
        TextCellValue(formatearMoneda(entrada.value)),
      ]);
    }

    await _agregarSeccionCierreCaja(excel, desde: desde, hasta: hasta);
    await _agregarSeccionRutas(excel, clientePorId: clientePorId, prestamoPorId: prestamoPorId, desde: desde, hasta: hasta);

    if (sheetPorDefecto != null && sheetPorDefecto != 'Resumen') {
      excel.delete(sheetPorDefecto);
    }

    return excel;
  }

  Future<double> _saldoPendienteDe(Prestamo prestamo) async {
    final detalle = await _prestamosRepository.obtenerDetalle(prestamo.id);
    final pagosPrestamo = await _pagosRepository.listarPorPrestamo(prestamo.id);
    final totalAplicado = pagosPrestamo.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
    final saldo = detalle.montoTotal - totalAplicado;
    return saldo < 0 ? 0 : saldo;
  }

  /// Cierre de caja: una fila por día (fecha operativa, no filtra por
  /// préstamo/cliente) dentro de [desde]/[hasta] en la hoja "Cierre de
  /// caja", más un resumen agregado del rango (capital inicio del primer
  /// día, capital cierre del último, suma de gastos) en la hoja "Resumen
  /// cierre de caja" — misma lógica que
  /// `ExportarReporteService::filasCierreCaja()`/`filasCierreCajaResumen()`
  /// del backend, replicada acá porque este reporte se arma offline.
  Future<void> _agregarSeccionCierreCaja(Excel excel, {DateTime? desde, DateTime? hasta}) async {
    final cierres = await _cierresCajaRepository.listarTodos();
    final enRango =
        cierres.where((cierre) {
          if (desde != null && cierre.fecha.isBefore(desde)) return false;
          if (hasta != null && cierre.fecha.isAfter(hasta)) return false;
          return true;
        }).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final hojaCierre = excel['Cierre de caja'];
    hojaCierre.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Capital inicio'),
      TextCellValue('Capital cierre'),
      TextCellValue('Total gastos'),
      TextCellValue('Detalle de gastos'),
      TextCellValue('Justificación'),
    ]);

    for (final cierre in enRango) {
      final gastos = await _cierresCajaRepository.obtenerGastos(cierre.id);
      final detalleGastos = gastos.map((gasto) => '${gasto.detalle} (${formatearMoneda(gasto.monto)})').join('; ');

      hojaCierre.appendRow([
        TextCellValue(_formatearFecha(cierre.fecha)),
        TextCellValue(formatearMoneda(cierre.capitalInicio)),
        TextCellValue(formatearMoneda(cierre.capitalCierre)),
        TextCellValue(formatearMoneda(cierre.gastosTotal)),
        TextCellValue(detalleGastos),
        TextCellValue(cierre.justificacionDiferencia ?? ''),
      ]);
    }

    final hojaResumenCierre = excel['Resumen cierre de caja'];
    hojaResumenCierre.appendRow([
      TextCellValue('Capital inicio (primer día)'),
      TextCellValue('Capital cierre (último día)'),
      TextCellValue('Total gastos (rango)'),
    ]);

    if (enRango.isNotEmpty) {
      final totalGastosRango = enRango.fold<double>(0, (acumulado, cierre) => acumulado + cierre.gastosTotal);
      hojaResumenCierre.appendRow([
        TextCellValue(formatearMoneda(enRango.first.capitalInicio)),
        TextCellValue(formatearMoneda(enRango.last.capitalCierre)),
        TextCellValue(formatearMoneda(totalGastosRango)),
      ]);
    }
  }

  /// Rutas de cobro: una fila por ítem (préstamo dentro de una ruta), en el
  /// orden en que quedaron, dentro de [desde]/[hasta] (por `creadoEn` de la
  /// ruta, igual que `cargas_capital` en el reporte del admin — mismo
  /// criterio replicado en `App\Services\ExportarReporteService::filasRutas()`
  /// del backend). "Monto pendiente" es el saldo del préstamo al momento de
  /// exportar, no un histórico congelado a la fecha del ítem.
  Future<void> _agregarSeccionRutas(
    Excel excel, {
    required Map<int, Cliente> clientePorId,
    required Map<int, Prestamo> prestamoPorId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final rutas = await _rutasRepository.listar();
    final enRango = rutas.where((ruta) {
      if (desde != null && ruta.creadoEn.isBefore(desde)) return false;
      if (hasta != null && ruta.creadoEn.isAfter(hasta)) return false;
      return true;
    }).toList();

    final hojaRutas = excel['Rutas'];
    hojaRutas.appendRow([
      TextCellValue('Ruta'),
      TextCellValue('Fecha de la ruta'),
      TextCellValue('Orden'),
      TextCellValue('Cliente'),
      TextCellValue('Préstamo'),
      TextCellValue('Estado'),
      TextCellValue('Cobrado en'),
      TextCellValue('Monto pendiente'),
    ]);

    for (final ruta in enRango) {
      final items = await _rutasRepository.listarItems(ruta.id);

      for (final item in items) {
        final prestamo = prestamoPorId[item.prestamoId];
        final cliente = prestamo != null ? clientePorId[prestamo.clienteId] : null;
        final saldoPendiente = prestamo != null ? await _saldoPendienteDe(prestamo) : 0.0;

        hojaRutas.appendRow([
          TextCellValue(ruta.nombre),
          TextCellValue(ruta.fecha != null ? _formatearFecha(ruta.fecha!) : ''),
          TextCellValue('${item.orden}'),
          TextCellValue(cliente?.nombre ?? (prestamo != null ? 'Cliente #${prestamo.clienteId}' : '—')),
          TextCellValue(prestamo?.referencia ?? (prestamo != null ? 'Préstamo #${prestamo.id}' : '—')),
          TextCellValue(item.estado),
          TextCellValue(item.cobradoEn != null ? '${_formatearFecha(item.cobradoEn!)} ${_formatearHora(item.cobradoEn!)}' : ''),
          TextCellValue(formatearMoneda(saldoPendiente)),
        ]);
      }
    }
  }

  /// Arma el `.xlsx` y lo comparte vía `share_plus`, escrito en un
  /// directorio temporal.
  Future<void> exportarYCompartir({DateTime? desde, DateTime? hasta, int? clienteId}) async {
    final excel = await construirXlsx(desde: desde, hasta: hasta, clienteId: clienteId);
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo del reporte.');
    }

    await exportarArchivoYCompartir(
      bytes: bytes,
      nombreArchivo: 'cobro_app_reporte_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

String _formatearHora(DateTime fecha) {
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}
