import 'package:flutter/material.dart';

import '../data/admin_reportes_repository.dart';
import '../data/admin_repository.dart';

/// Formulario para que el admin exporte un CSV con préstamos e historial de
/// pagos de uno, varios o todos los cobradores, filtrable por rango de
/// fechas — mismo patrón visual que `ExportarReporteScreen` del lado
/// cobrador, pero con selector múltiple de cobrador en vez de uno solo.
class AdminExportarReporteScreen extends StatefulWidget {
  const AdminExportarReporteScreen({super.key, this.repository, this.reportesRepository});

  /// Inyectables solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final AdminRepository? repository;
  final AdminReportesRepository? reportesRepository;

  @override
  State<AdminExportarReporteScreen> createState() => _AdminExportarReporteScreenState();
}

class _AdminExportarReporteScreenState extends State<AdminExportarReporteScreen> {
  late final _repository = widget.repository ?? AdminRepository();
  late final _reportesRepository = widget.reportesRepository ?? AdminReportesRepository();

  List<UsuarioAdmin>? _cobradores;
  final Set<int> _seleccionados = {};
  DateTime? _desde;
  DateTime? _hasta;
  bool _exportando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCobradores();
  }

  Future<void> _cargarCobradores() async {
    setState(() => _error = null);
    try {
      final usuarios = await _repository.listarUsuarios();
      final cobradores = usuarios.where((usuario) => usuario.rol == 'cobrador').toList();
      if (!mounted) return;
      setState(() {
        _cobradores = cobradores;
        _seleccionados.addAll(cobradores.map((c) => c.id));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _elegirDesde() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _desde = fecha);
  }

  Future<void> _elegirHasta() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _hasta = fecha);
  }

  void _alternarTodos(bool? marcar) {
    final cobradores = _cobradores;
    if (cobradores == null) return;
    setState(() {
      if (marcar == true) {
        _seleccionados.addAll(cobradores.map((c) => c.id));
      } else {
        _seleccionados.clear();
      }
    });
  }

  Future<void> _exportar() async {
    if (_exportando || _seleccionados.isEmpty) return;

    setState(() {
      _exportando = true;
      _error = null;
    });

    try {
      await _reportesRepository.exportarYCompartir(
        usuarioIds: _seleccionados.toList(),
        desde: _desde,
        // "hasta" debe incluir todo ese día, no solo su medianoche.
        hasta: _hasta?.add(const Duration(days: 1, seconds: -1)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo exportar el reporte: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cobradores = _cobradores;

    return Scaffold(
      appBar: AppBar(title: const Text('Exportar reporte')),
      body: SafeArea(
        child: cobradores == null
            ? Center(child: _error != null ? Text(_error!, textAlign: TextAlign.center) : const CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'El rango de fechas solo filtra el historial de pagos del CSV; el listado '
                    'de préstamos siempre sale completo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _elegirDesde,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Desde (opcional)', border: OutlineInputBorder()),
                      child: Text(_desde == null ? 'Sin límite inferior' : _formatearFecha(_desde!)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _elegirHasta,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Hasta (opcional)', border: OutlineInputBorder()),
                      child: Text(_hasta == null ? 'Sin límite superior' : _formatearFecha(_hasta!)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Cobradores', style: Theme.of(context).textTheme.titleMedium),
                  CheckboxListTile(
                    title: const Text('Todos'),
                    value: cobradores.isNotEmpty && _seleccionados.length == cobradores.length,
                    onChanged: _alternarTodos,
                  ),
                  const Divider(height: 1),
                  for (final cobrador in cobradores)
                    CheckboxListTile(
                      title: Text(cobrador.nombre),
                      value: _seleccionados.contains(cobrador.id),
                      onChanged: (marcado) => setState(() {
                        if (marcado == true) {
                          _seleccionados.add(cobrador.id);
                        } else {
                          _seleccionados.remove(cobrador.id);
                        }
                      }),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: (_exportando || _seleccionados.isEmpty) ? null : _exportar,
                    icon: const Icon(Icons.ios_share),
                    label: _exportando
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Exportar CSV', style: TextStyle(fontSize: 17)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                  ),
                ],
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
