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
  });

  final double capitalPrestado;
  final double totalCobrado;
  final double carteraEnMora;
  final double gananciaInteres;
  final double gananciaExtra;

  factory ResumenTotales.fromJson(Map<String, dynamic> json) {
    return ResumenTotales(
      capitalPrestado: _comoDouble(json['capital_prestado']),
      totalCobrado: _comoDouble(json['total_cobrado']),
      carteraEnMora: _comoDouble(json['cartera_en_mora']),
      gananciaInteres: _comoDouble(json['ganancia_interes']),
      gananciaExtra: _comoDouble(json['ganancia_extra']),
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
      tasasInteresDefault: (json['tasas_interes_default'] as List).map(_comoDouble).toList(),
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
    return ExtraResumen(concepto: json['concepto'] as String, valor: _comoDouble(json['valor']));
  }
}

/// Cuota de un préstamo, tal como aparece dentro del detalle de un cobrador.
class CuotaResumen {
  const CuotaResumen({
    required this.numeroCuota,
    required this.fechaEsperada,
    required this.montoEsperado,
    required this.estado,
  });

  final int numeroCuota;
  final DateTime fechaEsperada;
  final double montoEsperado;
  final String estado;

  factory CuotaResumen.fromJson(Map<String, dynamic> json) {
    return CuotaResumen(
      numeroCuota: json['numero_cuota'] as int,
      fechaEsperada: DateTime.parse(json['fecha_esperada'] as String),
      montoEsperado: _comoDouble(json['monto_esperado']),
      estado: json['estado'] as String,
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
    required this.totalPagado,
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

  /// Σ `pagos.monto_aplicado`, ya sumado de los pagos que trae la misma
  /// respuesta (no se pide nada aparte).
  final double totalPagado;

  double get montoExtras => extras.fold<double>(0, (acumulado, extra) => acumulado + extra.valor);

  /// Se obtiene restando de `montoTotal` (ya calculado por el backend) en
  /// vez de recalcular `capital * porcentaje / 100`, para no arriesgar un
  /// desajuste de redondeo entre este valor y el total que sí vino del
  /// servidor.
  double get montoInteres => montoTotal - montoCapital - montoExtras;

  factory PrestamoResumen.fromJson(Map<String, dynamic> json) {
    final totalPagado = ((json['pagos'] as List?) ?? const [])
        .map((pago) => _comoDouble((pago as Map<String, dynamic>)['monto_aplicado']))
        .fold<double>(0, (acumulado, monto) => acumulado + monto);

    return PrestamoResumen(
      id: json['id'] as int,
      clienteId: json['cliente_id'] as int,
      referencia: json['referencia'] as String?,
      montoCapital: _comoDouble(json['monto_capital']),
      porcentajeInteres: _comoDouble(json['porcentaje_interes']),
      montoTotal: _comoDouble(json['monto_total']),
      estado: json['estado'] as String,
      plazoCuotas: json['plazo_cuotas'] as int,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      extras: ((json['extras'] as List?) ?? const [])
          .map((e) => ExtraResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
      cuotas: ((json['cuotas'] as List?) ?? const [])
          .map((e) => CuotaResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPagado: totalPagado,
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

/// El backend serializa los decimales como string (ej. "100000.00"); acepta
/// tanto num como String para no romperse si algún campo llega distinto.
double _comoDouble(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.parse(valor.toString());
}
