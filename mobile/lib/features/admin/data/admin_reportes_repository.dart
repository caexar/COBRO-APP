import 'package:csv/csv.dart';

import '../../../core/utils/csv_exportador.dart';
import 'admin_repository.dart';

/// Arma y comparte, para uno o varios cobradores elegidos por el admin, un
/// CSV con el mismo reporte financiero de 3 secciones que ya arma el panel
/// web como .xlsx (préstamos, resumen por cobrador, movimientos de capital)
/// — trayendo los datos ya calculados vía `GET /admin/reporte` en vez de
/// recalcularlos en el móvil. Se eligió CSV (no .xlsx) para mobile a
/// propósito: acá el archivo se comparte por WhatsApp/correo con
/// `share_plus`, donde un CSV es más liviano y compatible que un .xlsx.
/// Reutiliza `exportarCsvYCompartir` (BOM de UTF-8 + share_plus) para no
/// repetir el fix de encoding en un segundo lugar.
class AdminReportesRepository {
  AdminReportesRepository({AdminRepository? adminRepository}) : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  /// Arma el texto CSV, sin tocar el sistema de archivos ni ningún plugin
  /// (fácil de testear). [usuarioIds] son los cobradores a incluir;
  /// [desde]/[hasta] acotan la sección de resumen por cobrador y la de
  /// movimientos de capital (la de préstamos siempre sale completa, mismo
  /// criterio que la web); [categoria] filtra solo la sección de
  /// movimientos de capital.
  Future<String> construirCsv({
    required List<int> usuarioIds,
    DateTime? desde,
    DateTime? hasta,
    String? categoria,
  }) async {
    final reporte = await _adminRepository.obtenerReporte(
      usuarioIds: usuarioIds,
      desde: desde,
      hasta: hasta,
      categoria: categoria,
    );

    final filas = <List<dynamic>>[
      ['Reporte financiero de cobradores'],
      [],
      [reporte.prestamos.titulo],
      reporte.prestamos.columnas,
      ...reporte.prestamos.filas,
      [],
      [reporte.resumenPorCobrador.titulo],
      reporte.resumenPorCobrador.columnas,
      ...reporte.resumenPorCobrador.filas,
      [],
      [reporte.movimientosCapital.titulo],
      reporte.movimientosCapital.columnas,
      ...reporte.movimientosCapital.filas,
    ];

    return Csv().encode(filas);
  }

  /// Arma el CSV y lo comparte como un solo archivo vía `share_plus`.
  Future<void> exportarYCompartir({
    required List<int> usuarioIds,
    DateTime? desde,
    DateTime? hasta,
    String? categoria,
  }) async {
    final contenidoCsv = await construirCsv(
      usuarioIds: usuarioIds,
      desde: desde,
      hasta: hasta,
      categoria: categoria,
    );

    await exportarCsvYCompartir(
      contenidoCsv: contenidoCsv,
      nombreArchivo: 'cobro_app_reporte_admin_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }
}
