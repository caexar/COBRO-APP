import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/clientes_dao.dart';

export '../../../data/app_database.dart' show Cliente;

/// Se lanza cuando ya existe un cliente local con el mismo nombre o cédula
/// para el cobrador autenticado. [campo] es 'nombre' o 'cedula', para que la
/// pantalla marque el campo correcto.
class ClienteDuplicadoException implements Exception {
  ClienteDuplicadoException(this.campo, this.mensaje);

  final String campo;
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// CRUD local de clientes (SQLite/Drift) con búsqueda por nombre/cédula,
/// validación de duplicados y registro en la cola de sincronización
/// ([CambiosPendientes]).
class ClientesRepository {
  ClientesRepository({AppDatabase? database, SecureStorageService? secureStorage})
      : _database = database ?? AppDatabase.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final _uuid = const Uuid();

  ClientesDao get _clientesDao => _database.clientesDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  Future<List<Cliente>> listar() async {
    final usuarioId = await _usuarioIdActual();
    return _clientesDao.obtenerTodos(usuarioId);
  }

  Future<Cliente?> obtenerPorId(int id) async {
    final usuarioId = await _usuarioIdActual();
    return _clientesDao.obtenerPorId(id, usuarioId);
  }

  /// Busca siempre por nombre; si [termino] contiene dígitos, también busca
  /// por cédula y agrega esos resultados al final (sin duplicar filas).
  /// Nunca cruza datos entre cobradores, aunque compartan dispositivo.
  Future<List<Cliente>> buscar(String termino) async {
    final consulta = termino.trim();
    if (consulta.isEmpty) return listar();

    final usuarioId = await _usuarioIdActual();
    final porNombre = await _clientesDao.buscarPorNombre(consulta, usuarioId);

    if (!_contieneDigitos(consulta)) {
      return porNombre;
    }

    final porCedula = await _clientesDao.buscarPorCedula(consulta, usuarioId);
    final idsYaIncluidos = porNombre.map((cliente) => cliente.id).toSet();
    final adicionalesPorCedula = porCedula.where((cliente) => !idsYaIncluidos.contains(cliente.id));

    return [...porNombre, ...adicionalesPorCedula];
  }

  bool _contieneDigitos(String texto) => RegExp(r'\d').hasMatch(texto);

  Future<int> _usuarioIdActual() async {
    final id = await _secureStorage.leerUsuarioId();
    if (id == null) {
      throw StateError('No hay una sesión activa.');
    }
    return id;
  }

  Future<void> _validarDuplicados({
    required String nombre,
    required String cedula,
    required int usuarioId,
    int? excluirId,
  }) async {
    if (await _clientesDao.existeNombre(nombre, usuarioId, excluirId: excluirId)) {
      throw ClienteDuplicadoException('nombre', 'Ya tienes un cliente registrado con este nombre.');
    }

    if (await _clientesDao.existeCedula(cedula, usuarioId, excluirId: excluirId)) {
      throw ClienteDuplicadoException('cedula', 'Ya tienes un cliente registrado con esta cédula.');
    }
  }

  /// Crea el cliente localmente y encola el alta para la próxima sincronización.
  Future<int> crear({
    required String nombre,
    required String cedula,
    required String telefono,
    required String direccion,
    String? referencia,
    String? fotoUrl,
  }) async {
    final usuarioId = await _usuarioIdActual();

    await _validarDuplicados(nombre: nombre, cedula: cedula, usuarioId: usuarioId);

    final id = await _clientesDao.insertar(
      ClientesCompanion.insert(
        usuarioId: usuarioId,
        nombre: nombre,
        cedula: cedula,
        telefono: telefono,
        direccion: direccion,
        referencia: Value(referencia),
        fotoUrl: Value(fotoUrl),
        uuidLocal: Value(_uuid.v4()),
      ),
    );

    await _encolarCambio(usuarioId: usuarioId, id: id, tipoOperacion: 'crear', datos: {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'direccion': direccion,
      'referencia': referencia,
      'foto_url': fotoUrl,
    });

    return id;
  }

  /// Actualiza el cliente localmente y encola la edición para la próxima sincronización.
  Future<void> actualizar({
    required int id,
    required String nombre,
    required String cedula,
    required String telefono,
    required String direccion,
    String? referencia,
    String? fotoUrl,
  }) async {
    final usuarioId = await _usuarioIdActual();

    await _validarDuplicados(nombre: nombre, cedula: cedula, usuarioId: usuarioId, excluirId: id);

    await _clientesDao.actualizar(
      ClientesCompanion(
        id: Value(id),
        nombre: Value(nombre),
        cedula: Value(cedula),
        telefono: Value(telefono),
        direccion: Value(direccion),
        referencia: Value(referencia),
        fotoUrl: Value(fotoUrl),
        actualizadoEn: Value(DateTime.now()),
        sincronizado: const Value(false),
      ),
      usuarioId,
    );

    await _encolarCambio(usuarioId: usuarioId, id: id, tipoOperacion: 'actualizar', datos: {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'direccion': direccion,
      'referencia': referencia,
      'foto_url': fotoUrl,
    });
  }

  Future<void> _encolarCambio({
    required int usuarioId,
    required int id,
    required String tipoOperacion,
    required Map<String, dynamic> datos,
  }) {
    return _cambiosPendientesDao.encolar(
      usuarioId: usuarioId,
      tabla: 'clientes',
      registroId: id,
      tipoOperacion: tipoOperacion,
      payload: jsonEncode(datos),
    );
  }
}
