import '../../../data/app_database.dart';

export '../../../data/app_database.dart' show Cuota, Pago, Prestamo;

/// El abono supera lo pendiente de la cuota y hace falta que el cobrador
/// indique cómo manejar el excedente antes de poder calcular el plan de pago.
class ManejoExcedenteRequeridoException implements Exception {
  ManejoExcedenteRequeridoException(this.excedente);

  final double excedente;
}

/// El abono no alcanza a cubrir lo pendiente de la cuota y hace falta que el
/// cobrador elija qué política de mora aplicar antes de poder calcular el
/// plan de pago.
class PoliticaMoraRequeridaException implements Exception {
  PoliticaMoraRequeridaException(this.faltante);

  final double faltante;
}

/// Una fila que debe insertarse en `pagos`.
class PagoAInsertar {
  const PagoAInsertar({
    required this.cuotaId,
    required this.montoAbonado,
    required this.montoAplicado,
    required this.fechaPago,
    required this.diasMora,
    required this.saldoRestanteDespues,
  });

  final int cuotaId;
  final double montoAbonado;
  final double montoAplicado;
  final DateTime fechaPago;
  final int diasMora;
  final double saldoRestanteDespues;
}

/// Un cambio que debe aplicarse a una cuota existente como resultado del pago.
class ActualizacionCuota {
  const ActualizacionCuota({required this.cuotaId, this.nuevoEstado, this.nuevoMontoEsperado});

  final int cuotaId;
  final String? nuevoEstado;
  final double? nuevoMontoEsperado;

  @override
  bool operator ==(Object other) =>
      other is ActualizacionCuota &&
      other.cuotaId == cuotaId &&
      other.nuevoEstado == nuevoEstado &&
      other.nuevoMontoEsperado == nuevoMontoEsperado;

  @override
  int get hashCode => Object.hash(cuotaId, nuevoEstado, nuevoMontoEsperado);

  @override
  String toString() =>
      'ActualizacionCuota(cuotaId: $cuotaId, nuevoEstado: $nuevoEstado, nuevoMontoEsperado: $nuevoMontoEsperado)';
}

/// Resultado completo de procesar un pago: qué filas insertar en `pagos`, qué
/// cuotas actualizar, y el nuevo estado del préstamo. `politicaMoraAplicada`
/// solo viene informada cuando el abono fue insuficiente (faltante) y se usó
/// para decidir qué hacer con esa diferencia.
class PlanPago {
  const PlanPago({
    required this.pagos,
    required this.actualizacionesCuotas,
    required this.nuevoEstadoPrestamo,
    this.politicaMoraAplicada,
  });

  final List<PagoAInsertar> pagos;
  final List<ActualizacionCuota> actualizacionesCuotas;
  final String nuevoEstadoPrestamo;
  final String? politicaMoraAplicada;
}

/// Réplica en Dart de `App\Services\PagoProcessor` del backend Laravel: mismo
/// cálculo de mora, mismos tres escenarios (exacto/faltante/excedente),
/// mismas políticas de mora y mismo manejo de excedente. Cualquier cambio a
/// esta lógica en el backend debe reflejarse aquí también (ver nota en
/// CLAUDE.md sobre `PrestamoCalculator`, el mismo principio aplica).
///
/// A diferencia del backend (donde `politica_mora` es fija por préstamo), acá
/// se recibe como parámetro en cada llamada: la app permite que el cobrador
/// elija la política en el momento del pago cuando hay un faltante. Es
/// responsabilidad de quien use este resultado (`PagosRepository`) decidir si
/// esa elección también actualiza el préstamo para futuros pagos.
class PagoProcessor {
  const PagoProcessor();

  static const _politicasValidas = {'mantener', 'siguiente_pago', 'sumar_total'};
  static const _manejosExcedenteValidos = {'abono_deuda', 'cobro_extra'};

  /// Calcula el plan de pago. No toca la base de datos: [cuotas] y
  /// [pagosExistentes] deben reflejar el estado actual del préstamo, y
  /// [montoTotalPrestamo] es `PrestamoDetalle.montoTotal` (capital + interés
  /// + extras).
  ///
  /// Lanza [ManejoExcedenteRequeridoException] o [PoliticaMoraRequeridaException]
  /// si falta una decisión del cobrador para poder continuar; quien llame debe
  /// volver a invocar con el parámetro resuelto.
  PlanPago procesar({
    required List<Cuota> cuotas,
    required List<Pago> pagosExistentes,
    required double montoTotalPrestamo,
    required double montoAbonado,
    required DateTime fechaPago,
    String? politicaMora,
    String? manejoExcedente,
  }) {
    final pendientes = [...cuotas.where((c) => c.estado != 'pagada')]
      ..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));
    if (pendientes.isEmpty) {
      throw StateError('Este préstamo no tiene cuotas pendientes por pagar.');
    }
    final cuotaActual = pendientes.first;

    final fechaEsperada = _soloFecha(cuotaActual.fechaEsperada);
    final fechaDePago = _soloFecha(fechaPago);
    final diasMora = fechaDePago.isAfter(fechaEsperada) ? fechaDePago.difference(fechaEsperada).inDays : 0;

    final pendienteEnCuota = _pendienteEnCuota(cuotaActual, pagosExistentes);
    final montoAbonadoRedondeado = _redondear(montoAbonado);

    final pagos = <PagoAInsertar>[];
    final actualizaciones = <ActualizacionCuota>[];
    String? politicaMoraAplicada;

    var totalAplicadoAcumulado = _redondear(
      pagosExistentes.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado),
    );

    PagoAInsertar crearPago(int cuotaId, double montoAbonadoFila, double montoAplicado, int diasMoraFila) {
      totalAplicadoAcumulado = _redondear(totalAplicadoAcumulado + montoAplicado);
      final saldoRestante = _redondear(montoTotalPrestamo - totalAplicadoAcumulado);
      return PagoAInsertar(
        cuotaId: cuotaId,
        montoAbonado: montoAbonadoFila,
        montoAplicado: montoAplicado,
        fechaPago: fechaPago,
        diasMora: diasMoraFila,
        saldoRestanteDespues: saldoRestante < 0 ? 0 : saldoRestante,
      );
    }

    if (montoAbonadoRedondeado > pendienteEnCuota) {
      if (manejoExcedente == null || !_manejosExcedenteValidos.contains(manejoExcedente)) {
        throw ManejoExcedenteRequeridoException(_redondear(montoAbonadoRedondeado - pendienteEnCuota));
      }

      final excedente = _redondear(montoAbonadoRedondeado - pendienteEnCuota);
      actualizaciones.add(ActualizacionCuota(cuotaId: cuotaActual.id, nuevoEstado: 'pagada'));

      final montoAbonadoFila = manejoExcedente == 'cobro_extra' ? montoAbonadoRedondeado : pendienteEnCuota;
      pagos.add(crearPago(cuotaActual.id, montoAbonadoFila, pendienteEnCuota, diasMora));

      if (manejoExcedente == 'abono_deuda') {
        _aplicarExcedenteComoAbono(
          cuotas: cuotas,
          cuotaActual: cuotaActual,
          pagosExistentes: pagosExistentes,
          excedenteInicial: excedente,
          crearPago: crearPago,
          pagos: pagos,
          actualizaciones: actualizaciones,
        );
      }
    } else if (montoAbonadoRedondeado < pendienteEnCuota) {
      if (politicaMora == null || !_politicasValidas.contains(politicaMora)) {
        throw PoliticaMoraRequeridaException(_redondear(pendienteEnCuota - montoAbonadoRedondeado));
      }

      final faltante = _redondear(pendienteEnCuota - montoAbonadoRedondeado);
      politicaMoraAplicada = politicaMora;

      _aplicarPoliticaMora(
        cuotas: cuotas,
        cuotaActual: cuotaActual,
        politica: politicaMora,
        faltante: faltante,
        diasMora: diasMora,
        actualizaciones: actualizaciones,
      );

      pagos.add(crearPago(cuotaActual.id, montoAbonadoRedondeado, montoAbonadoRedondeado, diasMora));
    } else {
      actualizaciones.add(ActualizacionCuota(cuotaId: cuotaActual.id, nuevoEstado: 'pagada'));
      pagos.add(crearPago(cuotaActual.id, montoAbonadoRedondeado, montoAbonadoRedondeado, diasMora));
    }

    final nuevoEstadoPrestamo = _calcularEstadoPrestamo(cuotas, actualizaciones);

    return PlanPago(
      pagos: pagos,
      actualizacionesCuotas: actualizaciones,
      nuevoEstadoPrestamo: nuevoEstadoPrestamo,
      politicaMoraAplicada: politicaMoraAplicada,
    );
  }

  double _pendienteEnCuota(Cuota cuota, List<Pago> pagosExistentes) {
    final yaAplicado = pagosExistentes
        .where((p) => p.cuotaId == cuota.id)
        .fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
    return _redondear(cuota.montoEsperado - yaAplicado);
  }

  void _aplicarExcedenteComoAbono({
    required List<Cuota> cuotas,
    required Cuota cuotaActual,
    required List<Pago> pagosExistentes,
    required double excedenteInicial,
    required PagoAInsertar Function(int cuotaId, double montoAbonadoFila, double montoAplicado, int diasMoraFila)
    crearPago,
    required List<PagoAInsertar> pagos,
    required List<ActualizacionCuota> actualizaciones,
  }) {
    var excedente = excedenteInicial;

    final siguientes = [...cuotas.where((c) => c.estado != 'pagada' && c.numeroCuota > cuotaActual.numeroCuota)]
      ..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));

    for (final siguiente in siguientes) {
      if (excedente <= 0) break;

      final pendiente = _pendienteEnCuota(siguiente, pagosExistentes);
      final aAplicar = excedente < pendiente ? excedente : pendiente;

      if (aAplicar >= pendiente) {
        actualizaciones.add(ActualizacionCuota(cuotaId: siguiente.id, nuevoEstado: 'pagada'));
      }

      pagos.add(crearPago(siguiente.id, aAplicar, aAplicar, 0));
      excedente = _redondear(excedente - aAplicar);
    }
  }

  void _aplicarPoliticaMora({
    required List<Cuota> cuotas,
    required Cuota cuotaActual,
    required String politica,
    required double faltante,
    required int diasMora,
    required List<ActualizacionCuota> actualizaciones,
  }) {
    var politicaEfectiva = politica;

    if (politicaEfectiva == 'siguiente_pago') {
      final siguiente = [...cuotas.where((c) => c.estado != 'pagada' && c.numeroCuota > cuotaActual.numeroCuota)]
          .fold<Cuota?>(null, (menor, c) => menor == null || c.numeroCuota < menor.numeroCuota ? c : menor);

      if (siguiente != null) {
        actualizaciones.add(
          ActualizacionCuota(cuotaId: siguiente.id, nuevoMontoEsperado: _redondear(siguiente.montoEsperado + faltante)),
        );
        actualizaciones.add(ActualizacionCuota(cuotaId: cuotaActual.id, nuevoEstado: 'pagada'));
        return;
      }

      politicaEfectiva = 'mantener';
    }

    if (politicaEfectiva == 'sumar_total') {
      final pendientes = [...cuotas.where((c) => c.estado != 'pagada' && c.id != cuotaActual.id)]
        ..sort((a, b) => a.numeroCuota.compareTo(b.numeroCuota));

      if (pendientes.isNotEmpty) {
        final porCuota = _redondear(faltante / pendientes.length);
        var acumulado = 0.0;

        for (var indice = 0; indice < pendientes.length; indice++) {
          final esUltima = indice == pendientes.length - 1;
          final incremento = esUltima ? _redondear(faltante - acumulado) : porCuota;
          acumulado = _redondear(acumulado + incremento);

          actualizaciones.add(
            ActualizacionCuota(
              cuotaId: pendientes[indice].id,
              nuevoMontoEsperado: _redondear(pendientes[indice].montoEsperado + incremento),
            ),
          );
        }

        actualizaciones.add(ActualizacionCuota(cuotaId: cuotaActual.id, nuevoEstado: 'pagada'));
        return;
      }
    }

    actualizaciones.add(
      ActualizacionCuota(cuotaId: cuotaActual.id, nuevoEstado: diasMora > 0 ? 'en_mora' : 'pendiente'),
    );
  }

  String _calcularEstadoPrestamo(List<Cuota> cuotas, List<ActualizacionCuota> actualizaciones) {
    String estadoDe(Cuota cuota) {
      final actualizacion = actualizaciones.lastWhere(
        (a) => a.cuotaId == cuota.id && a.nuevoEstado != null,
        orElse: () => ActualizacionCuota(cuotaId: cuota.id),
      );
      return actualizacion.nuevoEstado ?? cuota.estado;
    }

    final quedaPendiente = cuotas.any((c) => estadoDe(c) != 'pagada');
    if (!quedaPendiente) return 'pagado';

    final hayMora = cuotas.any((c) => estadoDe(c) == 'en_mora');
    return hayMora ? 'en_mora' : 'activo';
  }

  DateTime _soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  double _redondear(double valor) => (valor * 100).round() / 100;
}
