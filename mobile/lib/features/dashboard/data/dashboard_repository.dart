import '../../capital/data/cargas_capital_repository.dart';
import '../../pagos/data/pagos_repository.dart';
import '../../prestamos/data/prestamos_repository.dart';

/// Cifras del dashboard del cobrador, calculadas localmente a partir de sus
/// clientes/préstamos/pagos/cargas de capital ya guardados (offline-first,
/// no se llama al backend para nada de esto).
class ResumenDashboard {
  const ResumenDashboard({
    required this.saldoDisponible,
    required this.carteraPorCobrar,
    required this.entradasHoy,
    required this.entradasUltimos7Dias,
    required this.gananciaInteres,
    required this.gananciaExtras,
  });

  final double saldoDisponible;
  final double carteraPorCobrar;

  /// Dinero realmente cobrado (`pagos.fecha_pago` == hoy), no lo que se
  /// espera cobrar — no confundir con una proyección de cuotas por vencer.
  final double entradasHoy;

  /// Igual que [entradasHoy] pero sumando los últimos 7 días (hoy inclusive,
  /// hasta 6 días atrás), sin importar si esos pagos correspondían o no a la
  /// cuota que vencía ese día.
  final double entradasUltimos7Dias;
  final double gananciaInteres;
  final double gananciaExtras;

  double get gananciaTotal => gananciaInteres + gananciaExtras;
}

/// Calcula el resumen financiero del dashboard: saldo disponible, cartera
/// por cobrar, entradas reales de los últimos días y ganancia realizada.
///
/// `saldo_disponible = (cargas de capital) - (retiros de capital) + (todo lo
/// cobrado, monto_abonado) - (capital de préstamos no anulados)`: resta el
/// capital de **cualquier** préstamo no anulado (activo, en_mora o ya
/// pagado), no solo los que siguen activos — el capital sale de caja en el
/// momento de prestarlo sin importar si después se terminó de cobrar o no;
/// lo que vuelve a entrar (capital + interés) ya está contado en
/// `monto_abonado`. Restar el capital solo mientras el préstamo seguía
/// activo/en_mora (como se hacía antes) infla el saldo: un préstamo que ya
/// se pagó por completo dejaba de descontarse pese a que su capital sí salió
/// de caja alguna vez. Usa `monto_abonado` (no `monto_aplicado`) porque es
/// efectivo real en caja, incluyendo el excedente de pagos `cobro_extra` que
/// no reduce la deuda pero sí es dinero que el cobrador tiene en la mano.
///
/// La ganancia realizada reparte cada préstamo proporcionalmente entre
/// capital/interés/extras según el peso de cada uno sobre `montoTotal`,
/// aplicado a lo ya cobrado (`monto_aplicado`); el excedente de un pago
/// `cobro_extra` (que no entra en esa proporción, no corresponde a ningún
/// concepto del préstamo) se suma íntegro al balde de "extras" — mismo
/// balde que los montos extra del préstamo, por decisión explícita.
class DashboardRepository {
  DashboardRepository({
    PrestamosRepository? prestamosRepository,
    PagosRepository? pagosRepository,
    CargasCapitalRepository? cargasCapitalRepository,
  }) : _prestamosRepository = prestamosRepository ?? PrestamosRepository(),
       _pagosRepository = pagosRepository ?? PagosRepository(),
       _cargasCapitalRepository = cargasCapitalRepository ?? CargasCapitalRepository();

  final PrestamosRepository _prestamosRepository;
  final PagosRepository _pagosRepository;
  final CargasCapitalRepository _cargasCapitalRepository;

  static const _estadosOutstanding = {'activo', 'en_mora'};

  /// [ahora] es la fecha de referencia usada para "hoy" y la ventana de los
  /// últimos 7 días — parametrizable para que los tests puedan fijarla en vez
  /// de depender del reloj real; en producción siempre se omite y usa
  /// `DateTime.now()`.
  Future<ResumenDashboard> calcularResumen({DateTime? ahora}) async {
    final prestamos = await _prestamosRepository.listarTodos();
    final movimientosCapital = await _cargasCapitalRepository.listarTodas();

    final hoy = _soloFecha(ahora ?? DateTime.now());
    final inicioVentana7Dias = hoy.subtract(const Duration(days: 6));

    var carteraPorCobrar = 0.0;
    var capitalPrestadoNoAnulado = 0.0;
    var entradasHoy = 0.0;
    var entradasUltimos7Dias = 0.0;
    var gananciaInteres = 0.0;
    var gananciaExtras = 0.0;
    var totalAbonadoGlobal = 0.0;

    for (final prestamo in prestamos) {
      final detalle = await _prestamosRepository.obtenerDetalle(prestamo.id);
      final pagos = await _pagosRepository.listarPorPrestamo(prestamo.id);

      var totalAplicado = 0.0;
      var totalAbonado = 0.0;
      for (final pago in pagos) {
        totalAplicado += pago.montoAplicado;
        totalAbonado += pago.montoAbonado;

        final fechaPago = _soloFecha(pago.fechaPago);
        if (fechaPago.isAtSameMomentAs(hoy)) {
          entradasHoy += pago.montoAbonado;
        }
        if (!fechaPago.isBefore(inicioVentana7Dias) && !fechaPago.isAfter(hoy)) {
          entradasUltimos7Dias += pago.montoAbonado;
        }
      }
      totalAbonadoGlobal += totalAbonado;

      final montoTotal = detalle.montoTotal;
      if (montoTotal > 0) {
        gananciaInteres += totalAplicado * (detalle.montoInteres / montoTotal);
        gananciaExtras += totalAplicado * (detalle.montoExtras / montoTotal);
      }
      // Único caso donde monto_abonado > monto_aplicado en una misma fila
      // de pago (ver PagoProcessor.php): el excedente de un cobro_extra.
      gananciaExtras += totalAbonado - totalAplicado;

      // El capital sale de caja al prestarlo, sin importar si el préstamo
      // ya se terminó de cobrar o sigue activo — solo un préstamo anulado
      // no cuenta (nunca se entregó o se revirtió).
      if (prestamo.estado != 'anulado') {
        capitalPrestadoNoAnulado += prestamo.montoCapital;
      }

      if (_estadosOutstanding.contains(prestamo.estado)) {
        final saldoPendiente = montoTotal - totalAplicado;
        carteraPorCobrar += saldoPendiente < 0 ? 0 : saldoPendiente;
      }
    }

    var totalCargas = 0.0;
    var totalRetiros = 0.0;
    for (final movimiento in movimientosCapital) {
      if (movimiento.tipo == 'retiro') {
        totalRetiros += movimiento.monto;
      } else {
        totalCargas += movimiento.monto;
      }
    }

    final saldoDisponible = totalCargas - totalRetiros + totalAbonadoGlobal - capitalPrestadoNoAnulado;

    return ResumenDashboard(
      saldoDisponible: saldoDisponible,
      carteraPorCobrar: carteraPorCobrar,
      entradasHoy: entradasHoy,
      entradasUltimos7Dias: entradasUltimos7Dias,
      gananciaInteres: gananciaInteres,
      gananciaExtras: gananciaExtras,
    );
  }

  DateTime _soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}
