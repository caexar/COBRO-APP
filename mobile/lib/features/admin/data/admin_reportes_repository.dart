import 'package:csv/csv.dart';

import '../../../core/utils/csv_exportador.dart';
import '../../../core/utils/formato_dinero.dart';
import 'admin_repository.dart';

/// Arma y comparte, para uno o varios cobradores elegidos por el admin, un
/// CSV con sus préstamos y su historial de pagos filtrable por rango de
/// `fecha_pago` — mismo patrón de generación que `ReportesRepository` del
/// lado cobrador (préstamos siempre completos, pagos sí filtrados), pero
/// trayendo los datos vía `GET /admin/usuarios/{id}/detalle` en vez de Drift
/// local. Reutiliza `exportarCsvYCompartir` (BOM de UTF-8 + share_plus) para
/// no repetir el fix de encoding en un segundo lugar.
class AdminReportesRepository {
  AdminReportesRepository({AdminRepository? adminRepository}) : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  /// Arma el texto CSV, sin tocar el sistema de archivos ni ningún plugin
  /// (fácil de testear). [usuarioIds] son los cobradores a incluir;
  /// [desde]/[hasta] filtran el historial de pagos de cada uno por
  /// `fechaPago` (inclusive) — el listado de préstamos siempre sale completo.
  Future<String> construirCsv({required List<int> usuarioIds, DateTime? desde, DateTime? hasta}) async {
    final usuarios = await _adminRepository.listarUsuarios();
    final cobradores = usuarios.where((usuario) => usuarioIds.contains(usuario.id));

    final filas = <List<dynamic>>[
      ['Reporte de cobradores'],
    ];

    for (final cobrador in cobradores) {
      final detalle = await _adminRepository.obtenerDetalleCobrador(cobrador.id);
      final clientePorId = {for (final cliente in detalle.clientes) cliente.id: cliente};

      filas.addAll([
        [],
        ['Cobrador', cobrador.nombre],
        ['Préstamos'],
        ['Cliente', 'Referencia', 'Saldo pendiente', 'Estado'],
      ]);

      for (final prestamo in detalle.prestamos) {
        final cliente = clientePorId[prestamo.clienteId];
        final saldoPendiente = prestamo.montoTotal - prestamo.totalPagado;

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

      for (final prestamo in detalle.prestamos) {
        final cliente = clientePorId[prestamo.clienteId];

        for (final pago in prestamo.pagos) {
          if (desde != null && pago.fechaPago.isBefore(desde)) continue;
          if (hasta != null && pago.fechaPago.isAfter(hasta)) continue;

          filas.add([
            _formatearFecha(pago.fechaPago),
            cliente?.nombre ?? 'Cliente #${prestamo.clienteId}',
            prestamo.referencia ?? 'Préstamo #${prestamo.id}',
            formatearMoneda(pago.montoAbonado),
            formatearMoneda(pago.saldoRestanteDespues),
          ]);
        }
      }
    }

    return Csv().encode(filas);
  }

  /// Arma el CSV y lo comparte como archivo vía `share_plus`.
  Future<void> exportarYCompartir({required List<int> usuarioIds, DateTime? desde, DateTime? hasta}) async {
    final contenidoCsv = await construirCsv(usuarioIds: usuarioIds, desde: desde, hasta: hasta);

    await exportarCsvYCompartir(
      contenidoCsv: contenidoCsv,
      nombreArchivo: 'cobro_app_reporte_admin_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }
}

String _formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
