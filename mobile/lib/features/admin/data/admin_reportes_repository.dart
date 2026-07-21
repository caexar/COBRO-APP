import '../../../core/utils/archivo_exportador.dart';
import 'admin_repository.dart';

/// Descarga y comparte, para uno o varios cobradores elegidos por el admin,
/// el mismo `.xlsx` de 5 hojas (préstamos, resumen por cobrador, movimientos
/// de capital, cierre de caja y su resumen agregado) que ya arma el panel
/// web — el panel admin nunca trabaja offline (ver CLAUDE.md), así que no
/// hay ninguna razón para generar el archivo en el dispositivo: se pide tal
/// cual a `GET /admin/reporte` y solo se comparte con `share_plus`.
class AdminReportesRepository {
  AdminReportesRepository({AdminRepository? adminRepository}) : _adminRepository = adminRepository ?? AdminRepository();

  final AdminRepository _adminRepository;

  /// Descarga el `.xlsx` y lo comparte como un solo archivo vía
  /// `share_plus`. [usuarioIds] son los cobradores a incluir; [desde]/
  /// [hasta] acotan la hoja de resumen por cobrador y la de movimientos de
  /// capital (la de préstamos siempre sale completa, mismo criterio que la
  /// web); [categoria] filtra solo la hoja de movimientos de capital.
  Future<void> exportarYCompartir({
    required List<int> usuarioIds,
    DateTime? desde,
    DateTime? hasta,
    String? categoria,
  }) async {
    final bytes = await _adminRepository.descargarReporteXlsx(
      usuarioIds: usuarioIds,
      desde: desde,
      hasta: hasta,
      categoria: categoria,
    );

    await exportarArchivoYCompartir(
      bytes: bytes,
      nombreArchivo: 'cobro_app_reporte_admin_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
  }
}
