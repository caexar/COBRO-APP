import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../data/app_database.dart';
export '../../../data/app_database.dart' show CambiosPendiente;
import '../../../data/daos/cambios_pendientes_dao.dart';
import '../../../data/daos/cargas_capital_dao.dart';
import '../../../data/daos/cierre_caja_gastos_dao.dart';
import '../../../data/daos/cierres_caja_dao.dart';
import '../../../data/daos/clientes_dao.dart';
import '../../../data/daos/cuotas_dao.dart';
import '../../../data/daos/pagos_dao.dart';
import '../../../data/daos/prestamos_dao.dart';
import '../../../data/daos/prestamos_extras_dao.dart';
import '../../capital/data/cargas_capital_repository.dart';

/// Resultado de un intento de sincronización, pensado para mostrarse
/// directamente en un `SnackBar`.
class ResultadoSincronizacion {
  const ResultadoSincronizacion({
    required this.exitosa,
    required this.mensaje,
    this.confirmados = 0,
    this.conflictos = 0,
    this.errores = 0,
  });

  final bool exitosa;
  final String mensaje;

  /// Registros que el servidor confirmó (creados, actualizados o ya
  /// existentes) y por lo tanto ya se limpiaron de `cambios_pendientes`.
  final int confirmados;

  /// Registros que quedaron en conflicto (ganó una versión más reciente ya
  /// guardada en el servidor) — siguen pendientes, se reintentan solos.
  final int conflictos;

  /// Registros que no se pudieron procesar (ej. referencian un registro que
  /// todavía no llegó al servidor) — siguen pendientes, se reintentan solos.
  final int errores;
}

/// Sincroniza la cola local (`cambios_pendientes`) contra `POST /api/sync`:
/// sube clientes/prestamos/pagos/cargas_capital pendientes del cobrador con
/// sesión activa (nunca de otro usuario que haya usado este dispositivo), y
/// de paso descarga la configuración vigente y los movimientos de capital
/// que un admin le haya asignado.
///
/// Nunca reimplementa `PrestamoCalculator`/`PagoProcessor`: solo lee lo que
/// ya está calculado y guardado localmente y arma el JSON tal como lo espera
/// el servidor. Si la subida falla (sin red, timeout, error del servidor),
/// no se toca nada local — `cambios_pendientes` sigue intacto para el
/// próximo intento, así que nunca se pierden ni se duplican datos.
class SincronizacionRepository {
  SincronizacionRepository({
    AppDatabase? database,
    SecureStorageService? secureStorage,
    ApiClient? apiClient,
    CargasCapitalRepository? cargasCapitalRepository,
  }) : _database = database ?? AppDatabase.instance,
       _secureStorage = secureStorage ?? SecureStorageService(),
       _apiClient = apiClient ?? ApiClient(),
       _cargasCapitalRepository =
           cargasCapitalRepository ?? CargasCapitalRepository(database: database, secureStorage: secureStorage);

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final ApiClient _apiClient;
  final CargasCapitalRepository _cargasCapitalRepository;

  ClientesDao get _clientesDao => _database.clientesDao;
  PrestamosDao get _prestamosDao => _database.prestamosDao;
  PrestamosExtrasDao get _extrasDao => _database.prestamosExtrasDao;
  CuotasDao get _cuotasDao => _database.cuotasDao;
  PagosDao get _pagosDao => _database.pagosDao;
  CargasCapitalDao get _cargasCapitalDao => _database.cargasCapitalDao;
  CierresCajaDao get _cierresCajaDao => _database.cierresCajaDao;
  CierreCajaGastosDao get _cierreCajaGastosDao => _database.cierreCajaGastosDao;
  CambiosPendientesDao get _cambiosPendientesDao => _database.cambiosPendientesDao;

  /// Última vez que `sincronizar()` terminó con éxito para el cobrador con
  /// sesión activa (`null` si nunca sincronizó en este dispositivo).
  Future<DateTime?> ultimaSincronizacionExitosa() async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    if (usuarioId == null) return null;
    return _secureStorage.leerUltimaSincronizacion(usuarioId);
  }

  Future<ResultadoSincronizacion> sincronizar() async {
    final usuarioId = await _secureStorage.leerUsuarioId();
    final token = await _secureStorage.leerToken();

    if (usuarioId == null || token == null) {
      return const ResultadoSincronizacion(exitosa: false, mensaje: 'No hay una sesión activa.');
    }

    final pendientes = await _cambiosPendientesDao.obtenerPendientes(usuarioId);

    final porTabla = <String, Map<int, List<CambiosPendiente>>>{
      'clientes': {},
      'prestamos': {},
      'pagos': {},
      'cargas_capital': {},
      'cierres_caja': {},
    };
    for (final cambio in pendientes) {
      porTabla[cambio.tabla]?.putIfAbsent(cambio.registroId, () => []).add(cambio);
    }

    final clientesUuidARegistroId = <String, int>{};
    final clientesItems = <Map<String, dynamic>>[];
    for (final registroId in porTabla['clientes']!.keys) {
      final cliente = await _clientesDao.obtenerPorId(registroId, usuarioId);
      // uuidLocal nulo solo puede pasar en un registro creado antes de esta
      // función existir: se deja pendiente (no se pierde, simplemente
      // todavía no se puede deduplicar en el servidor) hasta que se le
      // pueda asignar uno.
      if (cliente == null || cliente.uuidLocal == null) continue;

      clientesUuidARegistroId[cliente.uuidLocal!] = registroId;
      clientesItems.add({
        'uuid_local': cliente.uuidLocal,
        'actualizado_en': cliente.actualizadoEn.toIso8601String(),
        'nombre': cliente.nombre,
        'cedula': cliente.cedula,
        'telefono': cliente.telefono,
        'direccion': cliente.direccion,
        'referencia': cliente.referencia,
        'foto_url': cliente.fotoUrl,
      });
    }

    final prestamosUuidARegistroId = <String, int>{};
    final prestamosItems = <Map<String, dynamic>>[];
    for (final registroId in porTabla['prestamos']!.keys) {
      final prestamo = await _prestamosDao.obtenerPorId(registroId, usuarioId);
      if (prestamo == null || prestamo.uuidLocal == null) continue;

      final cliente = await _clientesDao.obtenerPorId(prestamo.clienteId, usuarioId);
      // Sin el uuid_local del cliente dueño no hay forma de que el servidor
      // resuelva a qué cliente pertenece: se deja pendiente, se reintenta
      // solo apenas el cliente tenga uuid_local (ver caso de arriba).
      if (cliente == null || cliente.uuidLocal == null) continue;

      final extras = await _extrasDao.obtenerPorPrestamo(prestamo.id);

      prestamosUuidARegistroId[prestamo.uuidLocal!] = registroId;
      prestamosItems.add({
        'uuid_local': prestamo.uuidLocal,
        'actualizado_en': prestamo.actualizadoEn.toIso8601String(),
        'cliente_uuid_local': cliente.uuidLocal,
        'referencia': prestamo.referencia,
        'monto_capital': prestamo.montoCapital,
        'porcentaje_interes': prestamo.porcentajeInteres,
        'extras': extras.map((extra) => {'concepto': extra.concepto, 'valor': extra.valor}).toList(),
        'frecuencia_pago': prestamo.frecuenciaPago,
        'dias_personalizado': prestamo.diasPersonalizado,
        'plazo_cuotas': prestamo.plazoCuotas,
        'fecha_inicio': _soloFecha(prestamo.fechaInicio),
        'politica_mora': prestamo.politicaMora,
      });
    }

    final pagosUuidARegistroId = <String, int>{};
    final pagosItems = <Map<String, dynamic>>[];
    for (final registroId in porTabla['pagos']!.keys) {
      final pago = await _pagosDao.obtenerPorId(registroId);
      if (pago == null || pago.uuidLocal == null) continue;

      final prestamo = await _prestamosDao.obtenerPorId(pago.prestamoId, usuarioId);
      if (prestamo == null || prestamo.uuidLocal == null) continue;

      final cuotaId = pago.cuotaId;
      final cuotaPrincipal = cuotaId != null ? await _cuotasDao.obtenerPorId(cuotaId) : null;
      if (cuotaPrincipal == null) continue;

      // El estado actual de TODAS las cuotas del préstamo (no solo la que
      // este pago tocó directamente): es idempotente reenviarlas todas en
      // cada pago del mismo préstamo dentro del batch, y evita tener que
      // reconstruir un historial de "qué cuota cambió por cuál pago" que
      // Drift no guarda en ningún lado una vez aplicado.
      final todasLasCuotas = await _cuotasDao.obtenerPorPrestamo(prestamo.id);

      pagosUuidARegistroId[pago.uuidLocal!] = registroId;
      pagosItems.add({
        'uuid_local': pago.uuidLocal,
        'prestamo_uuid_local': prestamo.uuidLocal,
        'numero_cuota': cuotaPrincipal.numeroCuota,
        'monto_abonado': pago.montoAbonado,
        'monto_aplicado': pago.montoAplicado,
        'fecha_pago': _soloFecha(pago.fechaPago),
        'dias_mora': pago.diasMora,
        'saldo_restante_despues': pago.saldoRestanteDespues,
        'estado_prestamo': prestamo.estado,
        'cuotas_afectadas': todasLasCuotas
            .map((cuota) => {'numero_cuota': cuota.numeroCuota, 'estado': cuota.estado, 'monto_esperado': cuota.montoEsperado})
            .toList(),
      });
    }

    final cargasUuidARegistroId = <String, int>{};
    final cargasItems = <Map<String, dynamic>>[];
    for (final registroId in porTabla['cargas_capital']!.keys) {
      final carga = await _cargasCapitalDao.obtenerPorId(registroId, usuarioId);
      if (carga == null || carga.uuidLocal == null) continue;
      // Se creó y se eliminó localmente (soft-delete) antes de llegar a
      // sincronizarse: el backend todavía no soporta borrar por sync, así
      // que se deja pendiente sin enviarlo (no se pierde el registro local,
      // simplemente no se resucita en el servidor).
      if (carga.eliminadoEn != null) continue;
      // Defensivo: un movimiento de origen admin nunca debería tener un
      // cambio pendiente propio (se guarda ya sincronizado), pero si algo
      // saliera mal no hay que intentar "crearlo" en el servidor.
      if (carga.origen != 'cobrador') continue;

      cargasUuidARegistroId[carga.uuidLocal!] = registroId;
      cargasItems.add({
        'uuid_local': carga.uuidLocal,
        'tipo': carga.tipo,
        'monto': carga.monto,
        'descripcion': carga.descripcion,
      });
    }

    final cierresUuidARegistroId = <String, int>{};
    final cierresItems = <Map<String, dynamic>>[];
    for (final registroId in porTabla['cierres_caja']!.keys) {
      final cierre = await _cierresCajaDao.obtenerPorId(registroId, usuarioId);
      if (cierre == null || cierre.uuidLocal == null) continue;

      final gastos = await _cierreCajaGastosDao.obtenerPorCierre(cierre.id);

      cierresUuidARegistroId[cierre.uuidLocal!] = registroId;
      cierresItems.add({
        'uuid_local': cierre.uuidLocal,
        'fecha': _soloFecha(cierre.fecha),
        'capital_inicio': cierre.capitalInicio,
        'capital_cierre': cierre.capitalCierre,
        'justificacion_diferencia': cierre.justificacionDiferencia,
        'gastos': gastos.map((gasto) => {'monto': gasto.monto, 'detalle': gasto.detalle}).toList(),
      });
    }

    final batch = <String, dynamic>{
      if (clientesItems.isNotEmpty) 'clientes': clientesItems,
      if (prestamosItems.isNotEmpty) 'prestamos': prestamosItems,
      if (pagosItems.isNotEmpty) 'pagos': pagosItems,
      if (cargasItems.isNotEmpty) 'cargas_capital': cargasItems,
      if (cierresItems.isNotEmpty) 'cierres_caja': cierresItems,
    };

    Map<String, dynamic> respuesta;
    try {
      respuesta = await _apiClient.post('/sync', body: batch, token: token).timeout(const Duration(seconds: 30));
    } on ApiException catch (e) {
      return ResultadoSincronizacion(
        exitosa: false,
        mensaje: 'El servidor rechazó la sincronización: ${e.message}. Tus datos siguen guardados '
            'localmente, se reintentará en la próxima sincronización.',
      );
    } catch (_) {
      return const ResultadoSincronizacion(
        exitosa: false,
        mensaje: 'No se pudo conectar para sincronizar. Verifica tu conexión e intenta de nuevo; '
            'tus datos siguen guardados localmente.',
      );
    }

    final datos = (respuesta['data'] as Map?)?.cast<String, dynamic>() ?? const {};

    var confirmados = 0;
    var conflictos = 0;
    var errores = 0;

    Future<void> procesarResultados(
      String tabla,
      Map<String, int> uuidARegistroId,
      Map<int, List<CambiosPendiente>> grupo,
      Future<void> Function(int registroId, int servidorId) marcarSincronizado,
    ) async {
      final items = (datos[tabla] as List?) ?? const [];

      for (final crudo in items) {
        final item = (crudo as Map).cast<String, dynamic>();
        final registroId = uuidARegistroId[item['uuid_local'] as String];
        if (registroId == null) continue;

        final estado = item['estado'] as String;
        if (estado == 'conflicto') {
          conflictos++;
          continue;
        }
        if (estado == 'error') {
          errores++;
          continue;
        }

        // 'creado' | 'actualizado' | 'ya_existia': el servidor ya tiene este
        // registro tal como está localmente, se puede limpiar la cola.
        confirmados++;
        await marcarSincronizado(registroId, item['id'] as int);
        for (final cambio in grupo[registroId] ?? const <CambiosPendiente>[]) {
          await _cambiosPendientesDao.eliminar(cambio.id);
        }
      }
    }

    await procesarResultados(
      'clientes',
      clientesUuidARegistroId,
      porTabla['clientes']!,
      _clientesDao.marcarSincronizado,
    );
    await procesarResultados(
      'prestamos',
      prestamosUuidARegistroId,
      porTabla['prestamos']!,
      _prestamosDao.marcarSincronizado,
    );
    await procesarResultados('pagos', pagosUuidARegistroId, porTabla['pagos']!, _pagosDao.marcarSincronizado);
    await procesarResultados(
      'cargas_capital',
      cargasUuidARegistroId,
      porTabla['cargas_capital']!,
      _cargasCapitalDao.marcarSincronizado,
    );
    await procesarResultados(
      'cierres_caja',
      cierresUuidARegistroId,
      porTabla['cierres_caja']!,
      _cierresCajaDao.marcarSincronizado,
    );

    await _descargarConfiguracion(respuesta);
    await _descargarCargasCapitalDeAdmin(respuesta);

    await _secureStorage.guardarUltimaSincronizacion(usuarioId, DateTime.now());

    return ResultadoSincronizacion(
      exitosa: true,
      mensaje: _mensajeExito(confirmados: confirmados, conflictos: conflictos, errores: errores),
      confirmados: confirmados,
      conflictos: conflictos,
      errores: errores,
    );
  }

  /// `tasas_interes_default` e `intentos_pin_antes_de_maestro` de la
  /// configuración vigente. NO descarga el PIN maestro en sí — eso lo sigue
  /// haciendo únicamente `AuthRepository.sincronizarPinMaestro()` (llamado
  /// aparte, justo después del login); esta función solo reutiliza el mismo
  /// método de guardado (`SecureStorageService.guardarIntentosMaximosPin`)
  /// para no tener dos fuentes de verdad para ese número.
  Future<void> _descargarConfiguracion(Map<String, dynamic> respuesta) async {
    final configuracion = (respuesta['configuracion'] as Map?)?.cast<String, dynamic>();
    if (configuracion == null) return;

    final tasas = configuracion['tasas_interes_default'] as List?;
    if (tasas != null) {
      await _secureStorage.guardarTasasInteresDefault(tasas.map((tasa) => (tasa as num).toDouble()).toList());
    }

    final intentos = configuracion['intentos_pin_antes_de_maestro'] as int?;
    if (intentos != null) {
      await _secureStorage.guardarIntentosMaximosPin(intentos);
    }
  }

  Future<void> _descargarCargasCapitalDeAdmin(Map<String, dynamic> respuesta) async {
    final cargas = (respuesta['cargas_capital_admin'] as List?) ?? const [];

    for (final crudo in cargas) {
      final carga = (crudo as Map).cast<String, dynamic>();
      await _cargasCapitalRepository.guardarDescargadaDeAdmin(
        servidorId: carga['id'] as int,
        tipo: carga['tipo'] as String,
        monto: (carga['monto'] as num).toDouble(),
        descripcion: carga['descripcion'] as String?,
      );
    }
  }

  String _mensajeExito({required int confirmados, required int conflictos, required int errores}) {
    if (confirmados == 0 && conflictos == 0 && errores == 0) {
      return 'Todo al día, no había nada pendiente por sincronizar.';
    }

    final partes = <String>['$confirmados sincronizado${confirmados == 1 ? '' : 's'}'];
    if (conflictos > 0) partes.add('$conflictos con conflicto (se reintentará)');
    if (errores > 0) partes.add('$errores pendiente${errores == 1 ? '' : 's'} por un dato que falta');

    return 'Sincronización completa: ${partes.join(', ')}.';
  }

  String _soloFecha(DateTime fecha) => fecha.toIso8601String().split('T').first;
}
