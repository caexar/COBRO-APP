import 'package:flutter/material.dart';

import '../../../core/utils/formato_dinero.dart';
import '../../prestamos/data/prestamos_repository.dart';
import '../../prestamos/presentation/prestamo_detalle_screen.dart';
import '../data/rutas_repository.dart';
import 'agregar_prestamo_a_ruta_sheet.dart';

/// Un [RutaItem] junto con el resumen (cliente, referencia, saldo pendiente)
/// de su préstamo, para no repetir la consulta en cada rebuild.
class _ItemConResumen {
  const _ItemConResumen({required this.item, required this.resumen});

  final RutaItem item;
  final PrestamoResumen resumen;
}

/// Detalle de una ruta: sus préstamos en el orden manual guardado,
/// reordenables por drag-and-drop (o "Mover arriba"/"Mover abajo" desde el
/// menú de tres puntos, para accesibilidad). Tocar un ítem pendiente abre
/// **la misma pantalla de siempre** para ver/cobrar ese préstamo
/// (`PrestamoDetalleScreen`, la que ya usa `CobrosPendientesScreen`) — si
/// desde ahí se registra un pago, el ítem se marca `cobrado` localmente al
/// volver (ver `onPagoRegistrado`).
class RutaDetalleScreen extends StatefulWidget {
  const RutaDetalleScreen({super.key, required this.rutaId, this.repository, this.prestamosRepository});

  final int rutaId;

  /// Inyectables solo para pruebas; en la app real siempre se usan las
  /// instancias por defecto.
  final RutasRepository? repository;
  final PrestamosRepository? prestamosRepository;

  @override
  State<RutaDetalleScreen> createState() => _RutaDetalleScreenState();
}

class _RutaDetalleScreenState extends State<RutaDetalleScreen> {
  late final _repository = widget.repository ?? RutasRepository();
  late final _prestamosRepository = widget.prestamosRepository ?? PrestamosRepository();

  Ruta? _ruta;
  List<_ItemConResumen> _pendientes = [];
  List<_ItemConResumen> _cobrados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);

    final ruta = await _repository.obtenerPorId(widget.rutaId);
    final items = await _repository.listarItems(widget.rutaId);

    final conResumen = <_ItemConResumen>[];
    for (final item in items) {
      try {
        final resumen = await _prestamosRepository.obtenerResumen(item.prestamoId);
        conResumen.add(_ItemConResumen(item: item, resumen: resumen));
      } catch (_) {
        // El préstamo referenciado ya no existe (caso extremo, no debería
        // pasar en uso normal): se omite en vez de romper toda la pantalla.
      }
    }

    final pendientes = conResumen.where((ic) => ic.item.estado != 'cobrado').toList()
      ..sort((a, b) => a.item.orden.compareTo(b.item.orden));
    final cobrados = conResumen.where((ic) => ic.item.estado == 'cobrado').toList()
      ..sort((a, b) => (b.item.cobradoEn ?? b.item.actualizadoEn).compareTo(a.item.cobradoEn ?? a.item.actualizadoEn));

    if (!mounted) return;
    setState(() {
      _ruta = ruta;
      _pendientes = pendientes;
      _cobrados = cobrados;
      _cargando = false;
    });
  }

  Future<void> _abrirPrestamo(_ItemConResumen itemConResumen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrestamoDetalleScreen(
          prestamoId: itemConResumen.item.prestamoId,
          onPagoRegistrado: () => _repository.marcarCobradoSiPertenece(
            rutaId: widget.rutaId,
            prestamoId: itemConResumen.item.prestamoId,
          ),
        ),
      ),
    );
    _cargar();
  }

  Future<void> _agregarPrestamo() async {
    final idsEnRuta = [..._pendientes, ..._cobrados].map((ic) => ic.item.prestamoId).toList();
    final elegido = await mostrarAgregarPrestamoARutaSheet(context, idsExcluidos: idsEnRuta);
    if (elegido == null) return;

    await _repository.agregarPrestamo(rutaId: widget.rutaId, prestamoId: elegido.prestamo.id);
    _cargar();
  }

  Future<void> _aplicarNuevoOrden(List<_ItemConResumen> nuevaListaPendientes) async {
    setState(() => _pendientes = nuevaListaPendientes);
    final ids = nuevaListaPendientes.map((ic) => ic.item.id).toList();
    await _repository.reordenarItems(widget.rutaId, ids);
    _cargar();
  }

  void _onReorderPendientes(int oldIndex, int newIndex) {
    final nueva = List<_ItemConResumen>.from(_pendientes);
    final movido = nueva.removeAt(oldIndex);
    nueva.insert(newIndex, movido);
    _aplicarNuevoOrden(nueva);
  }

  void _mover(int indice, int nuevoIndice) {
    if (nuevoIndice < 0 || nuevoIndice >= _pendientes.length) return;
    final nueva = List<_ItemConResumen>.from(_pendientes);
    final item = nueva.removeAt(indice);
    nueva.insert(nuevoIndice, item);
    _aplicarNuevoOrden(nueva);
  }

  Future<void> _quitarPrestamo(_ItemConResumen itemConResumen) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar de la ruta'),
        content: Text('¿Quitar a ${itemConResumen.resumen.cliente.nombre} de esta ruta?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmado != true) return;

    await _repository.quitarPrestamo(itemConResumen.item.id);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;

    return Scaffold(
      appBar: AppBar(title: Text(ruta?.nombre ?? 'Ruta')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarPrestamo,
        icon: const Icon(Icons.add),
        label: const Text('Agregar préstamo'),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : (_pendientes.isEmpty && _cobrados.isEmpty)
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Esta ruta todavía no tiene préstamos. Usa "Agregar préstamo" para empezar.'),
                ),
              )
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_pendientes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Pendientes (${_pendientes.length})', style: Theme.of(context).textTheme.titleSmall),
                      ),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorderItem: _onReorderPendientes,
                        children: [
                          for (var indice = 0; indice < _pendientes.length; indice++)
                            _ItemPendienteTile(
                              key: ValueKey(_pendientes[indice].item.id),
                              itemConResumen: _pendientes[indice],
                              onTap: () => _abrirPrestamo(_pendientes[indice]),
                              onMoverArriba: indice > 0 ? () => _mover(indice, indice - 1) : null,
                              onMoverAbajo: indice < _pendientes.length - 1 ? () => _mover(indice, indice + 1) : null,
                              onQuitar: () => _quitarPrestamo(_pendientes[indice]),
                            ),
                        ],
                      ),
                    ],
                    if (_cobrados.isNotEmpty) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text('Cobrados (${_cobrados.length})', style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final itemConResumen in _cobrados) _ItemCobradoTile(itemConResumen: itemConResumen),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ItemPendienteTile extends StatelessWidget {
  const _ItemPendienteTile({
    required super.key,
    required this.itemConResumen,
    required this.onTap,
    required this.onQuitar,
    this.onMoverArriba,
    this.onMoverAbajo,
  });

  final _ItemConResumen itemConResumen;
  final VoidCallback onTap;
  final VoidCallback onQuitar;
  final VoidCallback? onMoverArriba;
  final VoidCallback? onMoverAbajo;

  @override
  Widget build(BuildContext context) {
    final resumen = itemConResumen.resumen;
    final referencia = resumen.prestamo.referencia;
    final titulo = (referencia != null && referencia.isNotEmpty) ? '${resumen.cliente.nombre} — $referencia' : resumen.cliente.nombre;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: Text('Saldo pendiente: ${formatearMoneda(resumen.saldoPendiente)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resumen.enMora)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('En mora', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.red,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (accion) {
              if (accion == 'arriba') onMoverArriba?.call();
              if (accion == 'abajo') onMoverAbajo?.call();
              if (accion == 'quitar') onQuitar();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'arriba', enabled: onMoverArriba != null, child: const Text('Mover arriba')),
              PopupMenuItem(value: 'abajo', enabled: onMoverAbajo != null, child: const Text('Mover abajo')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'quitar', child: Text('Quitar de la ruta')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemCobradoTile extends StatelessWidget {
  const _ItemCobradoTile({required this.itemConResumen});

  final _ItemConResumen itemConResumen;

  @override
  Widget build(BuildContext context) {
    final resumen = itemConResumen.resumen;
    final referencia = resumen.prestamo.referencia;
    final titulo = (referencia != null && referencia.isNotEmpty) ? '${resumen.cliente.nombre} — $referencia' : resumen.cliente.nombre;
    final colorGris = Theme.of(context).colorScheme.outline;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        titulo,
        style: TextStyle(fontSize: 17, decoration: TextDecoration.lineThrough, color: colorGris),
      ),
      subtitle: Text('Cobrado', style: TextStyle(color: colorGris)),
      trailing: const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
