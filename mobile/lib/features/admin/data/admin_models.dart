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

/// Totales de cartera: capital prestado, total cobrado y cartera en mora.
class ResumenTotales {
  const ResumenTotales({required this.capitalPrestado, required this.totalCobrado, required this.carteraEnMora});

  final double capitalPrestado;
  final double totalCobrado;
  final double carteraEnMora;

  factory ResumenTotales.fromJson(Map<String, dynamic> json) {
    return ResumenTotales(
      capitalPrestado: _comoDouble(json['capital_prestado']),
      totalCobrado: _comoDouble(json['total_cobrado']),
      carteraEnMora: _comoDouble(json['cartera_en_mora']),
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

/// Préstamo tal como aparece dentro del detalle de un cobrador.
class PrestamoResumen {
  const PrestamoResumen({
    required this.id,
    required this.clienteId,
    required this.montoCapital,
    required this.porcentajeInteres,
    required this.estado,
    required this.plazoCuotas,
    required this.fechaInicio,
  });

  final int id;
  final int clienteId;
  final double montoCapital;
  final double porcentajeInteres;
  final String estado;
  final int plazoCuotas;
  final DateTime fechaInicio;

  factory PrestamoResumen.fromJson(Map<String, dynamic> json) {
    return PrestamoResumen(
      id: json['id'] as int,
      clienteId: json['cliente_id'] as int,
      montoCapital: _comoDouble(json['monto_capital']),
      porcentajeInteres: _comoDouble(json['porcentaje_interes']),
      estado: json['estado'] as String,
      plazoCuotas: json['plazo_cuotas'] as int,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
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
