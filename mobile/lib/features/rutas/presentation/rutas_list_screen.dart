import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/conectividad.dart';
import '../data/rutas_repository.dart';
import 'ruta_detalle_screen.dart';
import 'ruta_form_screen.dart';

/// Una [Ruta] junto con cuántos de sus ítems ya están `cobrado` vs. el total
/// (ej. "3/8 cobrados"), para no repetir la consulta en cada rebuild.
class _RutaConConteo {
  const _RutaConConteo({required this.ruta, required this.cobrados, required this.total});

  final Ruta ruta;
  final int cobrados;
  final int total;
}

/// Listado de rutas del cobrador, reordenable por drag-and-drop. Cada ruta
/// muestra nombre, fecha (si tiene) y cuántos de sus ítems ya se cobraron.
/// El botón de crear ofrece dos caminos: una ruta manual (funciona sin
/// conexión, como el resto de la app) o autogenerar la ruta del día
/// (requiere conexión: el servidor evalúa todos los préstamos del
/// cobrador — ver `RutaService::autogenerarHoy` en el backend).
class RutasListScreen extends StatefulWidget {
  const RutasListScreen({super.key, this.repository, this.verificarConexion});

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final RutasRepository? repository;

  /// Inyectable solo para pruebas (ver `hayConexion` en
  /// `core/utils/conectividad.dart`), para poder simular sin/con conexión
  /// sin depender de una resolución DNS real.
  final Future<bool> Function()? verificarConexion;

  @override
  State<RutasListScreen> createState() => _RutasListScreenState();
}

class _RutasListScreenState extends State<RutasListScreen> {
  late final _repository = widget.repository ?? RutasRepository();
  late final _verificarConexion = widget.verificarConexion ?? hayConexion;

  List<_RutaConConteo> _rutas = [];
  bool _cargando = true;
  bool _hayConexion = true;
  bool _generandoRuta = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _actualizarConectividad();
  }

  Future<void> _actualizarConectividad() async {
    final ok = await _verificarConexion();
    if (!mounted) return;
    setState(() => _hayConexion = ok);
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);

    final rutas = await _repository.listar();
    final conConteo = <_RutaConConteo>[];
    for (final ruta in rutas) {
      final items = await _repository.listarItems(ruta.id);
      final cobrados = items.where((item) => item.estado == 'cobrado').length;
      conConteo.add(_RutaConConteo(ruta: ruta, cobrados: cobrados, total: items.length));
    }

    if (!mounted) return;
    setState(() {
      _rutas = conConteo;
      _cargando = false;
    });
  }

  Future<void> _abrirDetalle(Ruta ruta) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RutaDetalleScreen(rutaId: ruta.id)));
    _cargar();
  }

  Future<void> _crearManual() async {
    Navigator.of(context).pop();
    final creada = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => RutaFormScreen(repository: _repository)));
    if (creada == true) _cargar();
  }

  /// Pide el día a generar (hoy por defecto, pero cambiable — no asume
  /// "hoy" a ciegas) y luego si se deben incluir también las deudas
  /// vencidas de días anteriores, antes de llamar a
  /// `POST /rutas/autogenerar-hoy`. Si el cobrador cancela cualquiera de
  /// los dos pasos, no pasa nada (ni siquiera se intenta la llamada).
  Future<void> _elegirFechaYAutogenerar() async {
    Navigator.of(context).pop();

    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Genera la ruta para este día',
    );
    if (fecha == null || !mounted) return;

    final incluirVencidas = await _preguntarIncluirVencidas();
    if (incluirVencidas == null || !mounted) return;

    setState(() => _generandoRuta = true);

    try {
      await _repository.autogenerarHoy(fecha: fecha, incluirVencidas: incluirVencidas);
      if (!mounted) return;
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar la ruta: ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar la ruta. Verifica tu conexión e intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _generandoRuta = false);
    }
  }

  /// Un préstamo que deba de varios días atrás aparece una sola vez en la
  /// ruta (por su cuota pendiente más antigua) sin importar la respuesta —
  /// ver `RutasRepository.autogenerarHoy`.
  Future<bool?> _preguntarIncluirVencidas() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Incluir deudas vencidas?'),
        content: const Text(
          'Además de los préstamos cuya próxima cuota vence ese día, ¿también quieres incluir '
          'los que ya estén atrasados de días anteriores?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Solo ese día')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Incluir vencidas')),
        ],
      ),
    );
  }

  Future<void> _mostrarOpcionesCrear() async {
    await _actualizarConectividad();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Crear ruta manual'),
              subtitle: const Text('Nombre, descripción y fecha opcionales. Funciona sin conexión.'),
              onTap: _crearManual,
            ),
            ListTile(
              enabled: _hayConexion && !_generandoRuta,
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Autogenerar ruta por día'),
              subtitle: Text(
                _hayConexion
                    ? 'Elige un día (hoy por defecto) y arma la ruta con los préstamos que vencen ese día.'
                    : 'Requiere conexión a internet (evalúa los préstamos en el servidor).',
              ),
              onTap: _elegirFechaYAutogenerar,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editar(Ruta ruta) async {
    final editada = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => RutaFormScreen(ruta: ruta, repository: _repository)));
    if (editada == true) _cargar();
  }

  Future<void> _eliminar(Ruta ruta) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ruta'),
        content: Text('¿Eliminar "${ruta.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado != true) return;

    await _repository.eliminar(ruta.id);
    _cargar();
  }

  void _onReorder(int oldIndex, int newIndex) {
    final nueva = List<_RutaConConteo>.from(_rutas);
    final movida = nueva.removeAt(oldIndex);
    nueva.insert(newIndex, movida);
    setState(() => _rutas = nueva);

    _repository.reordenar(nueva.map((rc) => rc.ruta.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _generandoRuta ? null : _mostrarOpcionesCrear,
        child: _generandoRuta
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _rutas.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía no tienes rutas. Usa el botón "+" para crear una.', textAlign: TextAlign.center),
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _rutas.length,
                onReorderItem: _onReorder,
                itemBuilder: (context, indice) {
                  final rutaConConteo = _rutas[indice];
                  return _RutaTile(
                    key: ValueKey(rutaConConteo.ruta.id),
                    rutaConConteo: rutaConConteo,
                    onTap: () => _abrirDetalle(rutaConConteo.ruta),
                    onEditar: () => _editar(rutaConConteo.ruta),
                    onEliminar: () => _eliminar(rutaConConteo.ruta),
                  );
                },
              ),
      ),
    );
  }
}

class _RutaTile extends StatelessWidget {
  const _RutaTile({
    required super.key,
    required this.rutaConConteo,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  final _RutaConConteo rutaConConteo;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ruta = rutaConConteo.ruta;
    final partesSubtitulo = [
      if (ruta.fecha != null) _formatearFecha(ruta.fecha!),
      '${rutaConConteo.cobrados}/${rutaConConteo.total} cobrados',
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(ruta.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: Text(partesSubtitulo.join(' · ')),
        trailing: PopupMenuButton<String>(
          onSelected: (accion) {
            if (accion == 'editar') onEditar();
            if (accion == 'eliminar') onEliminar();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}
