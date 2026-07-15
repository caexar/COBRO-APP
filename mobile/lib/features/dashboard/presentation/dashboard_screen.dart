import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../capital/presentation/agregar_capital_screen.dart';
import '../../clientes/presentation/clientes_list_screen.dart';
import '../../prestamos/presentation/cobros_pendientes_screen.dart';
import '../../prestamos/presentation/prestamo_form_screen.dart';
import '../../prestamos/presentation/simular_prestamo_screen.dart';
import '../data/dashboard_repository.dart';
import 'exportar_reporte_screen.dart';

// Colores categóricos validados (slots 1 y 2 de la paleta de referencia,
// orden fijo interés->extras): ver skill de dataviz, CVD ΔE 73.6, ambos
// dentro de la banda de luminosidad. El aqua queda bajo 3:1 de contraste en
// superficie clara, por eso la leyenda siempre lleva etiqueta de texto
// visible (nunca solo el color) junto a cada monto.
const _colorInteres = Color(0xFF2A78D6);
const _colorExtras = Color(0xFF1BAF7A);

/// Dashboard del cobrador: saldo disponible, cartera por cobrar, proyección
/// de entradas y ganancia realizada, calculados localmente. Reemplaza al
/// antiguo `DashboardPlaceholderScreen`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onCerrarSesion,
    required this.nombre,
    this.dashboardRepository,
  });

  final VoidCallback onCerrarSesion;
  final String nombre;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto (mismo patrón que `AppEntryPoint`).
  final DashboardRepository? dashboardRepository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final _repository = widget.dashboardRepository ?? DashboardRepository();

  ResumenDashboard? _resumen;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final resumen = await _repository.calcularResumen();
      if (!mounted) return;
      setState(() => _resumen = resumen);
    } catch (_) {
      // Si el resumen financiero no se pudo calcular, el cobrador igual
      // debe poder navegar (clientes, cobros pendientes, etc.) — no se
      // bloquea el dashboard entero por esto.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => pantalla));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CobroApp'),
            if (widget.nombre.isNotEmpty)
              Text(
                '${widget.nombre} · Cobrador',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: widget.onCerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_cargando && resumen == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (resumen != null) ...[
                _TarjetaSaldoDisponible(
                  saldo: resumen.saldoDisponible,
                  onAgregarCapital: () => _ir(const AgregarCapitalScreen()),
                ),
                const SizedBox(height: 16),
                _StatTile(
                  etiqueta: 'Cartera por cobrar',
                  valor: resumen.carteraPorCobrar,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        etiqueta: 'Entradas hoy',
                        valor: resumen.proyeccionHoy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        etiqueta: 'Entradas en 7 días',
                        valor: resumen.proyeccionSemana,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _TarjetaGanancia(resumen: resumen),
                const SizedBox(height: 24),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No se pudo cargar el resumen financiero.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => _ir(const ClientesListScreen()),
                icon: const Icon(Icons.people),
                label: const Text('Clientes', style: TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _ir(const CobrosPendientesScreen()),
                icon: const Icon(Icons.payments_outlined),
                label: const Text(
                  'Cobros pendientes',
                  style: TextStyle(fontSize: 17),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _ir(const PrestamoFormScreen()),
                icon: const Icon(Icons.request_page),
                label: const Text(
                  'Nuevo préstamo',
                  style: TextStyle(fontSize: 17),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _ir(const SimularPrestamoScreen()),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text(
                  'Simular préstamo',
                  style: TextStyle(fontSize: 17),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _ir(const ExportarReporteScreen()),
                icon: const Icon(Icons.ios_share),
                label: const Text(
                  'Exportar reporte',
                  style: TextStyle(fontSize: 17),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaSaldoDisponible extends StatelessWidget {
  const _TarjetaSaldoDisponible({
    required this.saldo,
    required this.onAgregarCapital,
  });

  final double saldo;
  final VoidCallback onAgregarCapital;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saldo disponible',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              formatearMoneda(saldo),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAgregarCapital,
              icon: const Icon(Icons.add),
              label: const Text('Agregar capital'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.etiqueta, required this.valor});

  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              formatearMoneda(valor),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaGanancia extends StatelessWidget {
  const _TarjetaGanancia({required this.resumen});

  final ResumenDashboard resumen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ganancia realizada',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              formatearMoneda(resumen.gananciaTotal),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (resumen.gananciaTotal <= 0)
              const Text('Todavía no hay ganancia realizada.')
            else
              Row(
                children: [
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: resumen.gananciaInteres,
                            color: _colorInteres,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: resumen.gananciaExtras,
                            color: _colorExtras,
                            showTitle: false,
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FilaLeyenda(
                          color: _colorInteres,
                          etiqueta: 'Interés',
                          valor: resumen.gananciaInteres,
                        ),
                        const SizedBox(height: 8),
                        _FilaLeyenda(
                          color: _colorExtras,
                          etiqueta: 'Extras',
                          valor: resumen.gananciaExtras,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaLeyenda extends StatelessWidget {
  const _FilaLeyenda({
    required this.color,
    required this.etiqueta,
    required this.valor,
  });

  final Color color;
  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
              Text(
                formatearMoneda(valor),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
