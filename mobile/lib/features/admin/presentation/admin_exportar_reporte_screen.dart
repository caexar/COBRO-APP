import 'package:flutter/material.dart';

import '../data/admin_reportes_repository.dart';
import '../data/admin_repository.dart';

/// Opciones válidas de `cargas_capital.categoria` (solo aplica a un retiro,
/// ver CLAUDE.md) — mismas 4 opciones que ya usa el `<select>` del panel web.
const Map<String, String> _categoriasCapital = {
  'gasto_operativo': 'Gasto operativo',
  'decision_jefe': 'Decisión del jefe',
  'salario': 'Salario',
  'otro': 'Otro',
};

/// Formulario para que el admin descargue el mismo `.xlsx` de 5 hojas
/// (préstamos, resumen por cobrador, movimientos de capital, cierre de caja
/// y su resumen agregado) que ya arma el panel web, de uno, varios o todos
/// los cobradores — pedido tal cual a `GET /admin/reporte`, sin generar
/// nada en el móvil, filtrable por rango de fechas y categoria de
/// movimiento de capital.
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
  String? _categoria;
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
        categoria: _categoria,
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
                    'El Excel trae 5 hojas: detalle de préstamos, resumen por cobrador, '
                    'movimientos de capital, cierre de caja y su resumen agregado. El rango de '
                    'fechas solo acota el resumen por cobrador y los movimientos de capital — '
                    'la hoja de préstamos siempre sale completa.',
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
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    initialValue: _categoria,
                    decoration: const InputDecoration(
                      labelText: 'Categoría de movimientos de capital (opcional)',
                      border: OutlineInputBorder(),
                      helperText: 'Solo filtra la sección de movimientos de capital.',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      for (final entrada in _categoriasCapital.entries)
                        DropdownMenuItem(value: entrada.key, child: Text(entrada.value)),
                    ],
                    onChanged: (valor) => setState(() => _categoria = valor),
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
                        : const Text('Exportar Excel', style: TextStyle(fontSize: 17)),
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
