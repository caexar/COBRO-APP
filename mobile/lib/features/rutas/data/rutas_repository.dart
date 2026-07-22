import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/prestamos_dao.dart';
import '../../../data/daos/ruta_items_dao.dart';
import '../../../data/daos/rutas_dao.dart';

export '../../../data/app_database.dart' show Ruta, RutaItem;

/// CRUD local de rutas de cobro y sus ítems (préstamos dentro de cada
/// ruta), con encolado en `cambios_pendientes` para `POST /api/sync` —
/// mismo patrón que el resto de la app (offline-first). La única operación
/// que sí requiere conexión es [autogenerarHoy] (evalúa del lado servidor
/// qué préstamos vencen hoy, ver `App\Services\RutaService` en el backend).
///
/// **Eliminar una ruta o un ítem es solo local** (a diferencia de
/// crear/editar/reordenar): el contrato de `POST /api/sync` no tiene un
/// flujo de borrado para estas entidades (mismo criterio que
/// `cargas_capital`/`cierres_caja`, que tampoco lo tienen). Si la ruta ya se
/// había sincronizado, el registro sigue existiendo en el servidor.
class RutasRepository {
  RutasRepository({AppDatabase? database, SecureStorageService? secureStorage, ApiClient? apiClient})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService(),
        _apiClient = apiClient ?? ApiClient();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final ApiClient _apiClient;
  final _uuid = const Uuid();

  RutasDao get _rutasDao => _database.rutasDao;
  RutaItemsDao get _itemsDao => _database.rutaItemsDao;
  PrestamosDao get _prestamosDao => _database.prestamosDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<String> _tokenActual() async {
    final token = await _secureStorage.leerToken();
    if (token == null) {
      throw StateError('No hay una sesión activa.');
    }
    return token;
  }

  Future<List<Ruta>> listar() async {
    final usuarioId = await _usuarioIdActual();
    return _rutasDao.obtenerTodas(usuarioId);
  }

  Future<Ruta?> obtenerPorId(int id) async {
    final usuarioId = await _usuarioIdActual();
    return _rutasDao.obtenerPorId(id, usuarioId);
  }

  Future<List<RutaItem>> listarItems(int rutaId) => _itemsDao.obtenerPorRuta(rutaId);

  /// Crea una ruta manual (nombre + descripción/fecha opcionales) y la
  /// encola para sincronizar. A diferencia de [autogenerarHoy], funciona
  /// sin conexión.
  Future<int> crear({required String nombre, String? descripcion, DateTime? fecha}) async {
    final usuarioId = await _usuarioIdActual();
    final siguienteOrden = await _rutasDao.contarPorUsuario(usuarioId);

    final rutaId = await _rutasDao.insertar(
      RutasCompanion.insert(
        usuarioId: usuarioId,
        nombre: nombre,
        descripcion: Value(descripcion),
        fecha: Value(fecha),
        orden: Value(siguienteOrden),
        uuidLocal: Value(_uuid.v4()),
      ),
    );

    await _encolarRuta(usuarioId, rutaId);
    return rutaId;
  }

  Future<void> actualizar({required int id, required String nombre, String? descripcion, DateTime? fecha}) async {
    final usuarioId = await _usuarioIdActual();

    await _rutasDao.actualizar(
      RutasCompanion(
        id: Value(id),
        nombre: Value(nombre),
        descripcion: Value(descripcion),
        fecha: Value(fecha),
        actualizadoEn: Value(DateTime.now()),
        sincronizado: const Value(false),
      ),
      usuarioId,
    );

    await _encolarRuta(usuarioId, id);
  }

  /// Solo local — ver nota de la clase sobre por qué no hay borrado por sync.
  Future<void> eliminar(int id) async {
    final usuarioId = await _usuarioIdActual();
    await _itemsDao.eliminarPorRuta(id);
    await _rutasDao.eliminar(id, usuarioId);
  }

  /// [idsEnOrden] son los ids de TODAS las rutas del cobrador en el nuevo
  /// orden deseado (posición en la lista = nuevo `orden`) — mismo contrato
  /// simple que el backend (`PUT /api/rutas/reordenar`).
  Future<void> reordenar(List<int> idsEnOrden) async {
    final usuarioId = await _usuarioIdActual();
    for (var i = 0; i < idsEnOrden.length; i++) {
      await _rutasDao.actualizarOrden(idsEnOrden[i], i);
      await _encolarRuta(usuarioId, idsEnOrden[i]);
    }
  }

  Future<int> agregarPrestamo({required int rutaId, required int prestamoId}) async {
    final usuarioId = await _usuarioIdActual();
    final siguienteOrden = await _itemsDao.contarPorRuta(rutaId);

    final itemId = await _itemsDao.insertar(
      RutaItemsCompanion.insert(
        rutaId: rutaId,
        prestamoId: prestamoId,
        orden: Value(siguienteOrden),
        uuidLocal: Value(_uuid.v4()),
      ),
    );

    await _encolarItem(usuarioId, itemId);
    return itemId;
  }

  /// Solo local — ver nota de la clase.
  Future<void> quitarPrestamo(int itemId) => _itemsDao.eliminar(itemId);

  /// [idsEnOrden] son los ids de TODOS los ítems de [rutaId] en el nuevo
  /// orden deseado.
  Future<void> reordenarItems(int rutaId, List<int> idsEnOrden) async {
    final usuarioId = await _usuarioIdActual();
    for (var i = 0; i < idsEnOrden.length; i++) {
      await _itemsDao.actualizarOrden(idsEnOrden[i], i);
      await _encolarItem(usuarioId, idsEnOrden[i]);
    }
  }

  /// Si [rutaId] tiene un ítem pendiente para [prestamoId], lo marca
  /// `cobrado` con `cobradoEn = ahora` y lo encola. No hace nada si ese
  /// préstamo no está en la ruta (o ya estaba cobrado) — llamado desde
  /// `PrestamoDetalleScreen.onPagoRegistrado` sin importar si el pago fue
  /// parcial o cubrió la cuota completa, porque igual se registró un pago
  /// real para ese préstamo.
  Future<void> marcarCobradoSiPertenece({required int rutaId, required int prestamoId}) async {
    final item = await _itemsDao.obtenerPendientePorRutaYPrestamo(rutaId, prestamoId);
    if (item == null) return;

    final usuarioId = await _usuarioIdActual();
    await _itemsDao.marcarCobrado(item.id, DateTime.now());
    await _encolarItem(usuarioId, item.id);
  }

  /// Llama a `POST /api/rutas/autogenerar-hoy` (requiere conexión: el
  /// servidor evalúa todos los préstamos del cobrador) y guarda la ruta +
  /// items resultantes ya marcados `sincronizado = true` (nacieron en el
  /// servidor, nunca se suben) — mismo criterio que `RestauracionRepository`
  /// con datos descargados. Ítems cuyo préstamo todavía no existe en este
  /// dispositivo (ej. se creó desde otro) se omiten en silencio: no hay
  /// forma de apuntar un `RutaItem` local a un préstamo que no está en Drift.
  ///
  /// [fecha] es opcional (hoy por defecto, tanto acá como del lado del
  /// servidor si se omite) — permite generar la ruta de otro día, ej. para
  /// planificar con anticipación.
  Future<int> autogenerarHoy({DateTime? fecha}) async {
    final usuarioId = await _usuarioIdActual();
    final token = await _tokenActual();

    final respuesta = await _apiClient.post(
      '/rutas/autogenerar-hoy',
      token: token,
      body: fecha != null ? {'fecha': _soloFecha(fecha)} : null,
    );
    final data = (respuesta['data'] as Map).cast<String, dynamic>();

    final rutaId = await _rutasDao.insertar(
      RutasCompanion.insert(
        usuarioId: usuarioId,
        servidorId: Value(data['id'] as int),
        nombre: data['nombre'] as String,
        descripcion: Value(data['descripcion'] as String?),
        fecha: Value(data['fecha'] != null ? DateTime.parse(data['fecha'] as String) : null),
        orden: Value(data['orden'] as int),
        sincronizado: const Value(true),
      ),
    );

    final items = (data['items'] as List?) ?? const [];
    for (final crudo in items) {
      final item = (crudo as Map).cast<String, dynamic>();
      final prestamoServidorId = item['prestamo_id'] as int;
      final prestamoLocal = await _prestamosDao.obtenerPorServidorId(prestamoServidorId, usuarioId);
      if (prestamoLocal == null) continue;

      await _itemsDao.insertar(
        RutaItemsCompanion.insert(
          rutaId: rutaId,
          prestamoId: prestamoLocal.id,
          servidorId: Value(item['id'] as int),
          orden: Value(item['orden'] as int),
          estado: Value(item['estado'] as String? ?? 'pendiente'),
          sincronizado: const Value(true),
        ),
      );
    }

    return rutaId;
  }

  Future<void> _encolarRuta(int usuarioId, int rutaId) async {
    final ruta = await _rutasDao.obtenerPorId(rutaId, usuarioId);
    if (ruta == null || ruta.uuidLocal == null) return;

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'rutas',
      registroId: rutaId,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'nombre': ruta.nombre,
        'descripcion': ruta.descripcion,
        'fecha': ruta.fecha?.toIso8601String(),
        'orden': ruta.orden,
      }),
    );
  }

  Future<void> _encolarItem(int usuarioId, int itemId) async {
    final item = await _itemsDao.obtenerPorId(itemId);
    if (item == null || item.uuidLocal == null) return;

    await _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'ruta_items',
      registroId: itemId,
      tipoOperacion: 'crear',
      payload: jsonEncode({
        'ruta_id': item.rutaId,
        'prestamo_id': item.prestamoId,
        'orden': item.orden,
        'estado': item.estado,
        'cobrado_en': item.cobradoEn?.toIso8601String(),
      }),
    );
  }

  String _soloFecha(DateTime fecha) => fecha.toIso8601String().split('T').first;
}
