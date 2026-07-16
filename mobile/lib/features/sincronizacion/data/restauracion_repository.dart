import 'package:drift/drift.dart' show Value;

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/json_numero.dart';
import '../../../data/app_database.dart';

/// Resultado de un intento de restauración, pensado para mostrarse
/// directamente en pantalla (mismo patrón que `ResultadoSincronizacion`).
class ResultadoRestauracion {
  const ResultadoRestauracion({
    required this.exitosa,
    required this.mensaje,
    this.clientes = 0,
    this.prestamos = 0,
    this.pagos = 0,
    this.cargasCapital = 0,
  });

  final bool exitosa;
  final String mensaje;
  final int clientes;
  final int prestamos;
  final int pagos;
  final int cargasCapital;
}

/// Recupera todos los datos del cobrador con sesión activa desde
/// `GET /api/restaurar` y los inserta en Drift — pensado para un dispositivo
/// nuevo (o con la app reinstalada) cuya base de datos local está vacía.
///
/// A diferencia de `SincronizacionRepository` (incremental, sube la cola
/// local de `cambios_pendientes`), este flujo es de una sola vía: todo lo que
/// llega ya existe y está sincronizado en el servidor, así que se inserta
/// directamente con `sincronizado = true` y el mismo `servidorId`/`uuidLocal`
/// que trae cada registro — nunca se encola nada en `cambios_pendientes`.
/// Es idempotente: si el proceso se corta a mitad de camino y se reintenta,
/// cada registro se busca primero por `uuid_local` (o por `servidorId` para
/// los que no tienen uno propio, como cuotas/extras/cargas de admin) antes de
/// insertarlo, para no duplicar lo que ya haya quedado de un intento previo.
class RestauracionRepository {
  RestauracionRepository({AppDatabase? database, SecureStorageService? secureStorage, ApiClient? apiClient})
    : _database = database ?? AppDatabase.instance,
      _secureStorage = secureStorage ?? SecureStorageService(),
      _apiClient = apiClient ?? ApiClient();

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final ApiClient _apiClient;

  /// `true` si el cobrador con sesión activa ya tiene al menos un cliente en
  /// este dispositivo — señal de que no es la primera carga (o de que ya
  /// restauró/empezó a trabajar localmente). `true` también si no hay sesión,
  /// para no ofrecer restaurar cuando no hay nada que restaurar.
  Future<bool> hayDatosLocales() async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    if (usuarioId == null) return true;

    final clientes = await _database.clientesDao.obtenerTodos(usuarioId);
    return clientes.isNotEmpty;
  }

  Future<ResultadoRestauracion> restaurar() async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    final token = await _secureStorage.leerToken();

    if (usuarioId == null || token == null) {
      return const ResultadoRestauracion(exitosa: false, mensaje: 'No hay una sesión activa.');
    }

    Map<String, dynamic> respuesta;
    try {
      respuesta = await _apiClient.get('/restaurar', token: token).timeout(const Duration(seconds: 30));
    } on ApiException catch (e) {
      return ResultadoRestauracion(exitosa: false, mensaje: 'El servidor rechazó la restauración: ${e.message}.');
    } catch (_) {
      return const ResultadoRestauracion(
        exitosa: false,
        mensaje: 'No se pudo conectar para restaurar. Verifica tu conexión e intenta de nuevo.',
      );
    }

    final datos = (respuesta['data'] as Map).cast<String, dynamic>();

    final clientesInsertados = await _restaurarClientes(datos, usuarioId);
    final resultadoPrestamos = await _restaurarPrestamos(datos, usuarioId, clientesInsertados.idsPorServidorId);
    final pagosInsertados = await _restaurarPagos(
      datos,
      resultadoPrestamos.idsPorServidorId,
      resultadoPrestamos.cuotaIdsPorServidorId,
    );
    final cargasInsertadas = await _restaurarCargasCapital(datos, usuarioId);

    return ResultadoRestauracion(
      exitosa: true,
      mensaje: 'Restauración completa: ${clientesInsertados.nuevos} clientes, '
          '${resultadoPrestamos.nuevos} préstamos, $pagosInsertados pagos y '
          '$cargasInsertadas movimientos de capital nuevos.',
      clientes: clientesInsertados.nuevos,
      prestamos: resultadoPrestamos.nuevos,
      pagos: pagosInsertados,
      cargasCapital: cargasInsertadas,
    );
  }

  Future<_ResultadoInsercion> _restaurarClientes(Map<String, dynamic> datos, int usuarioId) async {
    final idsPorServidorId = <int, int>{};
    var nuevos = 0;

    for (final crudo in (datos['clientes'] as List? ?? const [])) {
      final item = (crudo as Map).cast<String, dynamic>();
      final servidorId = item['id'] as int;
      final uuidLocal = item['uuid_local'] as String?;

      final existente = uuidLocal != null ? await _database.clientesDao.obtenerPorUuidLocal(uuidLocal, usuarioId) : null;
      if (existente != null) {
        idsPorServidorId[servidorId] = existente.id;
        continue;
      }

      final id = await _database.clientesDao.insertar(
        ClientesCompanion.insert(
          usuarioId: usuarioId,
          nombre: item['nombre'] as String,
          cedula: item['cedula'] as String,
          telefono: item['telefono'] as String,
          direccion: item['direccion'] as String,
          referencia: Value(item['referencia'] as String?),
          fotoUrl: Value(item['foto_url'] as String?),
          servidorId: Value(servidorId),
          uuidLocal: Value(uuidLocal),
          creadoEn: Value(DateTime.parse(item['created_at'] as String)),
          actualizadoEn: Value(DateTime.parse(item['updated_at'] as String)),
          sincronizado: const Value(true),
        ),
      );

      idsPorServidorId[servidorId] = id;
      nuevos++;
    }

    return _ResultadoInsercion(nuevos: nuevos, idsPorServidorId: idsPorServidorId);
  }

  Future<_ResultadoPrestamos> _restaurarPrestamos(
    Map<String, dynamic> datos,
    int usuarioId,
    Map<int, int> clienteIdsPorServidorId,
  ) async {
    final idsPorServidorId = <int, int>{};
    final cuotaIdsPorServidorId = <int, int>{};
    var nuevos = 0;

    for (final crudo in (datos['prestamos'] as List? ?? const [])) {
      final item = (crudo as Map).cast<String, dynamic>();
      final servidorId = item['id'] as int;
      final uuidLocal = item['uuid_local'] as String?;

      final existente = uuidLocal != null ? await _database.prestamosDao.obtenerPorUuidLocal(uuidLocal, usuarioId) : null;

      int prestamoLocalId;
      if (existente != null) {
        prestamoLocalId = existente.id;
      } else {
        prestamoLocalId = await _database.prestamosDao.insertar(
          PrestamosCompanion.insert(
            clienteId: clienteIdsPorServidorId[item['cliente_id'] as int]!,
            usuarioId: usuarioId,
            referencia: Value(item['referencia'] as String?),
            montoCapital: comoDouble(item['monto_capital']),
            porcentajeInteres: comoDouble(item['porcentaje_interes']),
            frecuenciaPago: item['frecuencia_pago'] as String,
            diasPersonalizado: Value(item['dias_personalizado'] as int?),
            plazoCuotas: item['plazo_cuotas'] as int,
            fechaInicio: DateTime.parse(item['fecha_inicio'] as String),
            estado: Value(item['estado'] as String),
            politicaMora: Value(item['politica_mora'] as String?),
            servidorId: Value(servidorId),
            uuidLocal: Value(uuidLocal),
            creadoEn: Value(DateTime.parse(item['created_at'] as String)),
            actualizadoEn: Value(DateTime.parse(item['updated_at'] as String)),
            sincronizado: const Value(true),
          ),
        );
        nuevos++;
      }

      idsPorServidorId[servidorId] = prestamoLocalId;

      for (final extraCrudo in (item['extras'] as List? ?? const [])) {
        final extra = (extraCrudo as Map).cast<String, dynamic>();
        final extraServidorId = extra['id'] as int;
        if (await _database.prestamosExtrasDao.existePorServidorId(extraServidorId)) continue;

        await _database.prestamosExtrasDao.insertar(
          PrestamosExtrasCompanion.insert(
            prestamoId: prestamoLocalId,
            concepto: extra['concepto'] as String,
            valor: comoDouble(extra['valor']),
            servidorId: Value(extraServidorId),
            sincronizado: const Value(true),
          ),
        );
      }

      for (final cuotaCrudo in (item['cuotas'] as List? ?? const [])) {
        final cuota = (cuotaCrudo as Map).cast<String, dynamic>();
        final cuotaServidorId = cuota['id'] as int;

        final cuotaExistente = await _database.cuotasDao.obtenerPorServidorId(cuotaServidorId);
        if (cuotaExistente != null) {
          cuotaIdsPorServidorId[cuotaServidorId] = cuotaExistente.id;
          continue;
        }

        final cuotaLocalId = await _database.cuotasDao.insertar(
          CuotasCompanion.insert(
            prestamoId: prestamoLocalId,
            numeroCuota: cuota['numero_cuota'] as int,
            fechaEsperada: DateTime.parse(cuota['fecha_esperada'] as String),
            montoEsperado: comoDouble(cuota['monto_esperado']),
            estado: Value(cuota['estado'] as String),
            servidorId: Value(cuotaServidorId),
            sincronizado: const Value(true),
          ),
        );
        cuotaIdsPorServidorId[cuotaServidorId] = cuotaLocalId;
      }
    }

    return _ResultadoPrestamos(nuevos: nuevos, idsPorServidorId: idsPorServidorId, cuotaIdsPorServidorId: cuotaIdsPorServidorId);
  }

  Future<int> _restaurarPagos(
    Map<String, dynamic> datos,
    Map<int, int> prestamoIdsPorServidorId,
    Map<int, int> cuotaIdsPorServidorId,
  ) async {
    var nuevos = 0;

    for (final crudo in (datos['pagos'] as List? ?? const [])) {
      final item = (crudo as Map).cast<String, dynamic>();
      final uuidLocal = item['uuid_local'] as String?;

      final existente = uuidLocal != null ? await _database.pagosDao.obtenerPorUuidLocal(uuidLocal) : null;
      if (existente != null) continue;

      final cuotaServidorId = item['cuota_id'] as int?;

      await _database.pagosDao.insertar(
        PagosCompanion.insert(
          prestamoId: prestamoIdsPorServidorId[item['prestamo_id'] as int]!,
          cuotaId: Value(cuotaServidorId != null ? cuotaIdsPorServidorId[cuotaServidorId] : null),
          montoAbonado: comoDouble(item['monto_abonado']),
          montoAplicado: comoDouble(item['monto_aplicado']),
          fechaPago: DateTime.parse(item['fecha_pago'] as String),
          diasMora: Value(item['dias_mora'] as int? ?? 0),
          saldoRestanteDespues: comoDouble(item['saldo_restante_despues']),
          servidorId: Value(item['id'] as int),
          uuidLocal: Value(uuidLocal),
          creadoEn: Value(DateTime.parse(item['created_at'] as String)),
          actualizadoEn: Value(DateTime.parse(item['updated_at'] as String)),
          sincronizado: const Value(true),
        ),
      );
      nuevos++;
    }

    return nuevos;
  }

  Future<int> _restaurarCargasCapital(Map<String, dynamic> datos, int usuarioId) async {
    var nuevas = 0;

    for (final crudo in (datos['cargas_capital'] as List? ?? const [])) {
      final item = (crudo as Map).cast<String, dynamic>();
      final origen = item['origen'] as String? ?? 'cobrador';
      final servidorId = item['id'] as int;
      final uuidLocal = origen == 'cobrador' ? item['uuid_local'] as String? : null;

      final yaExiste = uuidLocal != null
          ? await _database.cargasCapitalDao.obtenerPorUuidLocal(uuidLocal, usuarioId) != null
          : await _database.cargasCapitalDao.existePorServidorId(servidorId);
      if (yaExiste) continue;

      await _database.cargasCapitalDao.insertar(
        CargasCapitalCompanion.insert(
          usuarioId: usuarioId,
          monto: comoDouble(item['monto']),
          tipo: Value(item['tipo'] as String? ?? 'carga'),
          descripcion: Value(item['descripcion'] as String?),
          servidorId: Value(servidorId),
          uuidLocal: Value(uuidLocal),
          origen: Value(origen),
          creadoPorUsuarioId: Value(item['creado_por_usuario_id'] as int?),
          creadoEn: Value(DateTime.parse(item['created_at'] as String)),
          sincronizado: const Value(true),
        ),
      );
      nuevas++;
    }

    return nuevas;
  }
}

class _ResultadoInsercion {
  const _ResultadoInsercion({required this.nuevos, required this.idsPorServidorId});

  final int nuevos;
  final Map<int, int> idsPorServidorId;
}

class _ResultadoPrestamos {
  const _ResultadoPrestamos({required this.nuevos, required this.idsPorServidorId, required this.cuotaIdsPorServidorId});

  final int nuevos;
  final Map<int, int> idsPorServidorId;
  final Map<int, int> cuotaIdsPorServidorId;
}
