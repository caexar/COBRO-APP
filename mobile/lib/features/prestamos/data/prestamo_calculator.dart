/// Un monto extra asociado a un préstamo (ej. papelería).
class ExtraPrestamo {
  const ExtraPrestamo({required this.concepto, required this.valor});

  final String concepto;
  final double valor;
}

class ResultadoCuota {
  const ResultadoCuota({required this.numeroCuota, required this.fechaEsperada, required this.montoEsperado});

  final int numeroCuota;
  final DateTime fechaEsperada;
  final double montoEsperado;
}

class ResultadoCalculoPrestamo {
  const ResultadoCalculoPrestamo({
    required this.montoCapital,
    required this.montoInteres,
    required this.montoExtras,
    required this.montoTotal,
    required this.cuotas,
  });

  final double montoCapital;
  final double montoInteres;
  final double montoExtras;
  final double montoTotal;
  final List<ResultadoCuota> cuotas;
}

/// Réplica en Dart de `App\Services\PrestamoCalculator` del backend Laravel:
/// misma fórmula de interés simple, mismo reparto de cuotas y mismas fechas
/// según frecuencia. Cualquier cambio a esta lógica debe reflejarse en
/// ambos lados (ver nota en CLAUDE.md).
///
/// Se usa tanto en el formulario de "nuevo préstamo" como en "simular
/// préstamo", para no duplicar el cálculo entre las dos pantallas.
class PrestamoCalculator {
  const PrestamoCalculator();

  ResultadoCalculoPrestamo calcular({
    required double montoCapital,
    required double porcentajeInteres,
    List<ExtraPrestamo> extras = const [],
    required String frecuenciaPago,
    int? diasPersonalizado,
    required int plazoCuotas,
    required DateTime fechaInicio,
  }) {
    final capital = _redondear(montoCapital);
    final interes = _redondear(capital * (porcentajeInteres / 100));
    final montoExtras = _redondear(extras.fold<double>(0, (acumulado, extra) => acumulado + extra.valor));
    final montoTotal = _redondear(capital + interes + montoExtras);

    return ResultadoCalculoPrestamo(
      montoCapital: capital,
      montoInteres: interes,
      montoExtras: montoExtras,
      montoTotal: montoTotal,
      cuotas: _repartirCuotas(
        montoTotal: montoTotal,
        plazoCuotas: plazoCuotas,
        fechaInicio: fechaInicio,
        frecuenciaPago: frecuenciaPago,
        diasPersonalizado: diasPersonalizado,
      ),
    );
  }

  List<ResultadoCuota> _repartirCuotas({
    required double montoTotal,
    required int plazoCuotas,
    required DateTime fechaInicio,
    required String frecuenciaPago,
    int? diasPersonalizado,
  }) {
    if (plazoCuotas <= 0) return const [];

    final montoBase = _redondear(montoTotal / plazoCuotas);
    var acumulado = 0.0;
    final cuotas = <ResultadoCuota>[];

    for (var numero = 1; numero <= plazoCuotas; numero++) {
      final esUltima = numero == plazoCuotas;
      final monto = esUltima ? _redondear(montoTotal - acumulado) : montoBase;
      acumulado = _redondear(acumulado + monto);

      cuotas.add(
        ResultadoCuota(
          numeroCuota: numero,
          fechaEsperada: _fechaParaCuota(fechaInicio, frecuenciaPago, diasPersonalizado, numero),
          montoEsperado: monto,
        ),
      );
    }

    return cuotas;
  }

  DateTime _fechaParaCuota(DateTime fechaInicio, String frecuenciaPago, int? diasPersonalizado, int numero) {
    switch (frecuenciaPago) {
      case 'diario':
        return _sumarDias(fechaInicio, numero);
      case 'semanal':
        return _sumarDias(fechaInicio, numero * 7);
      case 'quincenal':
        return _sumarDias(fechaInicio, numero * 15);
      case 'mensual':
        return _sumarMesesSinOverflow(fechaInicio, numero);
      case 'personalizado':
        return _sumarDias(fechaInicio, (diasPersonalizado ?? 0) * numero);
      default:
        throw ArgumentError('Frecuencia de pago inválida: $frecuenciaPago');
    }
  }

  DateTime _sumarDias(DateTime fecha, int dias) {
    // Se usa solo la parte de fecha (sin hora) para que sumar días no se
    // vea afectado por el horario de verano de la zona local.
    final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
    return soloFecha.add(Duration(days: dias));
  }

  /// Igual que `Carbon::addMonthsNoOverflow`: si el día de inicio no existe
  /// en el mes destino (ej. 31 de enero + 1 mes), se recorta al último día
  /// de ese mes en vez de desbordar al mes siguiente.
  DateTime _sumarMesesSinOverflow(DateTime fecha, int meses) {
    final totalMeses = fecha.month - 1 + meses;
    final anio = fecha.year + totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    final ultimoDiaDelMesDestino = DateTime(anio, mes + 1, 0).day;
    final dia = fecha.day > ultimoDiaDelMesDestino ? ultimoDiaDelMesDestino : fecha.day;
    return DateTime(anio, mes, dia);
  }

  double _redondear(double valor) => (valor * 100).round() / 100;
}
