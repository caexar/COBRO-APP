import 'package:flutter/material.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/formato_dinero.dart';
import '../data/prestamos_repository.dart';
import 'prestamo_detalle_screen.dart';

const _nombresOrden = {
  OrdenPrestamos.alfabetico: 'Alfabético (nombre del cliente)',
  OrdenPrestamos.masAntiguoPrimero: 'Más antiguo primero',
  OrdenPrestamos.masRecientePrimero: 'Más reciente primero',
};

/// Préstamos activos/en mora del cobrador, con buscador por nombre o cédula
/// del cliente (mismo criterio flexible que el buscador de clientes). Tocar
/// un préstamo lleva al detalle del préstamo (mismo flujo que al crear uno
/// nuevo), desde donde el cobrador puede registrar el pago.
class CobrosPendientesScreen extends StatefulWidget {
  const CobrosPendientesScreen({super.key});

  @override
  State<CobrosPendientesScreen> createState() => _CobrosPendientesScreenState();
}

class _CobrosPendientesScreenState extends State<CobrosPendientesScreen> {
  final _repository = PrestamosRepository();
  final _secureStorage = SecureStorageService();
  final _busquedaController = TextEditingController();

  List<PrestamoResumen> _prestamos = [];
  bool _cargando = true;
  OrdenPrestamos _orden = OrdenPrestamos.alfabetico;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _cargarOrden();
    await _cargar();
  }

  Future<void> _cargarOrden() async {
    try {
      final usuarioId = await _secureStorage.leerUsuarioId();
      if (usuarioId == null) return;
      final guardado = await _secureStorage.leerOrdenPrestamos(usuarioId);
      if (!mounted) return;
      setState(() => _orden = OrdenPrestamos.values.byName(guardado));
    } catch (_) {
      // Sin preferencia guardada (o sin sesión todavía) se queda alfabético.
    }
  }

  Future<void> _cambiarOrden(OrdenPrestamos nuevo) async {
    setState(() => _orden = nuevo);
    _cargar();
    try {
      final usuarioId = await _secureStorage.leerUsuarioId();
      if (usuarioId != null) {
        await _secureStorage.guardarOrdenPrestamos(usuarioId, nuevo.name);
      }
    } catch (_) {
      // Si no se pudo guardar, la preferencia queda solo para esta sesión.
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final resultado = await _repository.listarPendientes(busqueda: _busquedaController.text, orden: _orden);
    if (!mounted) return;
    setState(() {
      _prestamos = resultado;
      _cargando = false;
    });
  }

  Future<void> _irADetalle(PrestamoResumen resumen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PrestamoDetalleScreen(prestamoId: resumen.prestamo.id)));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobros pendientes'),
        actions: [
          PopupMenuButton<OrdenPrestamos>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _orden,
            onSelected: _cambiarOrden,
            itemBuilder: (context) => [
              for (final entrada in _nombresOrden.entries)
                PopupMenuItem(
                  value: entrada.key,
                  child: Row(
                    children: [
                      Icon(
                        entrada.key == _orden ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(entrada.value),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _busquedaController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o cédula',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busquedaController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _busquedaController.clear();
                            _cargar();
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) {
                  setState(() {}); // refresca el ícono de limpiar
                  _cargar();
                },
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _prestamos.isEmpty
                  ? _EstadoVacio(hayBusqueda: _busquedaController.text.trim().isNotEmpty)
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _prestamos.length,
                        separatorBuilder: (context, indice) => const Divider(height: 1),
                        itemBuilder: (context, indice) {
                          final resumen = _prestamos[indice];
                          return _PrestamoTile(resumen: resumen, onTap: () => _irADetalle(resumen));
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrestamoTile extends StatelessWidget {
  const _PrestamoTile({required this.resumen, required this.onTap});

  final PrestamoResumen resumen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final referencia = resumen.prestamo.referencia;
    final titulo = (referencia != null && referencia.isNotEmpty)
        ? '${resumen.cliente.nombre} — $referencia'
        : resumen.cliente.nombre;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Saldo pendiente: ${formatearMoneda(resumen.saldoPendiente)}', style: const TextStyle(fontSize: 15)),
      trailing: resumen.enMora
          ? const Chip(
              label: Text('En mora', style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: Colors.red,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.hayBusqueda});

  final bool hayBusqueda;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              hayBusqueda
                  ? 'No hay préstamos pendientes con ese nombre o cédula.'
                  : 'No tienes préstamos activos o en mora por cobrar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
