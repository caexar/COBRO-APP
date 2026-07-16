import '../../../core/utils/json_numero.dart';

/// Usuario tal como lo devuelve la API de administración (`GET/POST/PUT
/// /admin/usuarios*`). Nunca incluye password/pin_hash/pin_maestro_hash —
/// el backend ya los oculta.
class UsuarioAdmin {
  const UsuarioAdmin({required this.id, required this.nombre, required this.email, required this.rol, required this.activo});

  final int id;
  final String nombre;
  final String email;
  final String rol;
  final bool activo;

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) {
    return UsuarioAdmin(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      activo: json['activo'] as bool,
    );
  }
}

/// Totales de cartera: capital prestado, total cobrado, cartera en mora y
/// ganancia realizada (repartida entre interés y extras, misma lógica que
/// `DashboardRepository` del lado cobrador).
class ResumenTotales {
  const ResumenTotales({
    required this.capitalPrestado,
    required this.totalCobrado,
    required this.carteraEnMora,
    required this.gananciaInteres,
    required this.gananciaExtra,
    required this.saldoDisponible,
  });

  final double capitalPrestado;
  final double totalCobrado;
  final double carteraEnMora;
  final double gananciaInteres;
  final double gananciaExtra;

  /// Mismo cálculo que `DashboardRepository.calcularResumen` del lado
  /// cobrador, replicado en el backend (`CapitalService::calcularSaldoDisponible`).
  final double saldoDisponible;

  factory ResumenTotales.fromJson(Map<String, dynamic> json) {
    return ResumenTotales(
      capitalPrestado: comoDouble(json['capital_prestado']),
      totalCobrado: comoDouble(json['total_cobrado']),
      carteraEnMora: comoDouble(json['cartera_en_mora']),
      gananciaInteres: comoDouble(json['ganancia_interes']),
      gananciaExtra: comoDouble(json['ganancia_extra']),
      saldoDisponible: comoDouble(json['saldo_disponible']),
    );
  }
}

class ResumenCobrador {
  const ResumenCobrador({required this.usuarioId, required this.nombre, required this.activo, required this.totales});

  final int usuarioId;
  final String nombre;
  final bool activo;
  final ResumenTotales totales;

  factory ResumenCobrador.fromJson(Map<String, dynamic> json) {
    return ResumenCobrador(
      usuarioId: json['usuario_id'] as int,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool,
      totales: ResumenTotales.fromJson(json),
    );
  }
}

class ResumenAdmin {
  const ResumenAdmin({required this.global, required this.porCobrador});

  final ResumenTotales global;
  final List<ResumenCobrador> porCobrador;

  factory ResumenAdmin.fromJson(Map<String, dynamic> json) {
    return ResumenAdmin(
      global: ResumenTotales.fromJson(json['global'] as Map<String, dynamic>),
      porCobrador: (json['por_cobrador'] as List)
          .map((e) => ResumenCobrador.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ConfiguracionAdmin {
  const ConfiguracionAdmin({
    required this.tasasInteresDefault,
    required this.politicaMoraDefault,
    required this.pinMaestroConfigurado,
    required this.intentosPinAntesDeMaestro,
  });

  final List<double> tasasInteresDefault;
  final String politicaMoraDefault;
  final bool pinMaestroConfigurado;

  /// Cuántos intentos fallidos del PIN personal tolera la app móvil antes de
  /// ofrecer el PIN maestro. La app lo descarga vía `GET /api/pin-maestro`
  /// en cada sincronización (no desde este endpoint, que es solo de admin).
  final int intentosPinAntesDeMaestro;

  factory ConfiguracionAdmin.fromJson(Map<String, dynamic> json) {
    return ConfiguracionAdmin(
      tasasInteresDefault: (json['tasas_interes_default'] as List).map(comoDouble).toList(),
      politicaMoraDefault: json['politica_mora_default'] as String,
      pinMaestroConfigurado: json['pin_maestro_configurado'] as bool,
      intentosPinAntesDeMaestro: json['intentos_pin_antes_de_maestro'] as int? ?? 3,
    );
  }
}

/// Cliente tal como aparece dentro del detalle de un cobrador (solo los
/// campos que se muestran; la vista es de solo lectura).
class ClienteResumen {
  const ClienteResumen({required this.id, required this.nombre, required this.cedula, required this.telefono});

  final int id;
  final String nombre;
  final String cedula;
  final String telefono;

  factory ClienteResumen.fromJson(Map<String, dynamic> json) {
    return ClienteResumen(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      cedula: json['cedula'] as String,
      telefono: json['telefono'] as String,
    );
  }
}

/// Monto extra de un préstamo (ej. "papelería"), tal como aparece dentro del
/// detalle de un cobrador.
class ExtraResumen {
  const ExtraResumen({required this.concepto, required this.valor});

  final String concepto;
  final double valor;

  factory ExtraResumen.fromJson(Map<String, dynamic> json) {
    return ExtraResumen(concepto: json['concepto'] as String, valor: comoDouble(json['valor']));
  }
}

/// Cuota de un préstamo, tal como aparece dentro del detalle de un cobrador.
class CuotaResumen {
  const CuotaResumen({
    required this.id,
    required this.numeroCuota,
    required this.fechaEsperada,
    required this.montoEsperado,
    required this.estado,
    this.fechaPago,
  });

  final int id;
  final int numeroCuota;
  final DateTime fechaEsperada;
  final double montoEsperado;
  final String estado;

  /// Fecha real del pago que dejó esta cuota `pagada` (la más reciente entre
  /// los pagos aplicados a esta cuota, si hubo más de uno); `null` si la
  /// cuota todavía no está pagada.
  final DateTime? fechaPago;

  factory CuotaResumen.fromJson(Map<String, dynamic> json, {DateTime? fechaPago}) {
    return CuotaResumen(
      id: json['id'] as int,
      numeroCuota: json['numero_cuota'] as int,
      fechaEsperada: DateTime.parse(json['fecha_esperada'] as String),
      montoEsperado: comoDouble(json['monto_esperado']),
      estado: json['estado'] as String,
      fechaPago: fechaPago,
    );
  }
}

/// Pago tal como aparece dentro del detalle de un cobrador (uno por fila de
/// `pagos`, ver reglas de negocio de pagos en CLAUDE.md — `cuota_id` puede
/// repetirse entre varias filas del mismo préstamo).
class PagoResumen {
  const PagoResumen({
    required this.fechaPago,
    required this.montoAbonado,
    required this.montoAplicado,
    required this.saldoRestanteDespues,
  });

  final DateTime fechaPago;
  final double montoAbonado;
  final double montoAplicado;
  final double saldoRestanteDespues;

  factory PagoResumen.fromJson(Map<String, dynamic> json) {
    return PagoResumen(
      fechaPago: DateTime.parse(json['fecha_pago'] as String),
      montoAbonado: comoDouble(json['monto_abonado']),
      montoAplicado: comoDouble(json['monto_aplicado']),
      saldoRestanteDespues: comoDouble(json['saldo_restante_despues']),
    );
  }
}

/// Préstamo tal como aparece dentro del detalle de un cobrador, con extras y
/// cuotas completas (la respuesta ya las trae, no hace falta pedirlas
/// aparte) y `montoTotal` calculado por el backend (`Prestamo::monto_total`,
/// nunca se recalcula acá).
class PrestamoResumen {
  const PrestamoResumen({
    required this.id,
    required this.clienteId,
    required this.referencia,
    required this.montoCapital,
    required this.porcentajeInteres,
    required this.montoTotal,
    required this.estado,
    required this.plazoCuotas,
    required this.fechaInicio,
    required this.extras,
    required this.cuotas,
    required this.pagos,
    required this.totalPagado,
    required this.totalAbonado,
  });

  final int id;
  final int clienteId;
  final String? referencia;
  final double montoCapital;
  final double porcentajeInteres;
  final double montoTotal;
  final String estado;
  final int plazoCuotas;
  final DateTime fechaInicio;
  final List<ExtraResumen> extras;
  final List<CuotaResumen> cuotas;

  /// Historial de pagos del préstamo, para reportes que necesiten filtrar
  /// por rango de `fecha_pago` (ej. el exportador de CSV del admin).
  final List<PagoResumen> pagos;

  /// Σ `pagos.monto_aplicado`, ya sumado de los pagos que trae la misma
  /// respuesta (no se pide nada aparte).
  final double totalPagado;

  /// Σ `pagos.monto_abonado`. Solo difiere de [totalPagado] cuando hubo un
  /// excedente `cobro_extra` (no reduce deuda, pero sí es dinero cobrado).
  final double totalAbonado;

  double get montoExtras => extras.fold<double>(0, (acumulado, extra) => acumulado + extra.valor);

  /// Excedente de pagos `cobro_extra`: dinero real cobrado que no redujo la
  /// deuda del préstamo — el dashboard ya lo contabiliza en "Ganancia
  /// realizada", este detalle no lo mostraba (bug corregido).
  double get extraCobrado => totalAbonado - totalPagado;

  /// Se obtiene restando de `montoTotal` (ya calculado por el backend) en
  /// vez de recalcular `capital * porcentaje / 100`, para no arriesgar un
  /// desajuste de redondeo entre este valor y el total que sí vino del
  /// servidor.
  double get montoInteres => montoTotal - montoCapital - montoExtras;

  factory PrestamoResumen.fromJson(Map<String, dynamic> json) {
    final pagos = ((json['pagos'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final totalPagado = pagos.fold<double>(0, (acumulado, pago) => acumulado + comoDouble(pago['monto_aplicado']));
    final totalAbonado = pagos.fold<double>(0, (acumulado, pago) => acumulado + comoDouble(pago['monto_abonado']));

    // Fecha de pago real por cuota (la más reciente, si una cuota recibió más
    // de un pago) para mostrarla junto a la fecha esperada en el listado.
    final fechaPagoPorCuota = <int, DateTime>{};
    for (final pago in pagos) {
      final cuotaId = pago['cuota_id'] as int?;
      final fechaPagoStr = pago['fecha_pago'] as String?;
      if (cuotaId == null || fechaPagoStr == null) continue;

      final fechaPago = DateTime.parse(fechaPagoStr);
      final actual = fechaPagoPorCuota[cuotaId];
      if (actual == null || fechaPago.isAfter(actual)) {
        fechaPagoPorCuota[cuotaId] = fechaPago;
      }
    }

    return PrestamoResumen(
      id: json['id'] as int,
      clienteId: json['cliente_id'] as int,
      referencia: json['referencia'] as String?,
      montoCapital: comoDouble(json['monto_capital']),
      porcentajeInteres: comoDouble(json['porcentaje_interes']),
      montoTotal: comoDouble(json['monto_total']),
      estado: json['estado'] as String,
      plazoCuotas: json['plazo_cuotas'] as int,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      extras: ((json['extras'] as List?) ?? const [])
          .map((e) => ExtraResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
      cuotas: ((json['cuotas'] as List?) ?? const [])
          .map((e) {
            final cuotaJson = e as Map<String, dynamic>;
            return CuotaResumen.fromJson(cuotaJson, fechaPago: fechaPagoPorCuota[cuotaJson['id'] as int]);
          })
          .toList(),
      pagos: pagos.map(PagoResumen.fromJson).toList(),
      totalPagado: totalPagado,
      totalAbonado: totalAbonado,
    );
  }
}

/// `GET /admin/usuarios/{id}/detalle`: el cobrador con sus clientes y
/// préstamos, de solo lectura (el admin no edita nada de esto desde la app).
class DetalleCobrador {
  const DetalleCobrador({required this.usuario, required this.clientes, required this.prestamos});

  final UsuarioAdmin usuario;
  final List<ClienteResumen> clientes;
  final List<PrestamoResumen> prestamos;

  factory DetalleCobrador.fromJson(Map<String, dynamic> json) {
    return DetalleCobrador(
      usuario: UsuarioAdmin.fromJson(json),
      clientes: ((json['clientes'] as List?) ?? const [])
          .map((e) => ClienteResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
      prestamos: ((json['prestamos'] as List?) ?? const [])
          .map((e) => PrestamoResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
