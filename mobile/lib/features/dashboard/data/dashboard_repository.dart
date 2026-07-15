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
    required this.proyeccionHoy,
    required this.proyeccionSemana,
    required this.gananciaInteres,
    required this.gananciaExtras,
  });

  final double saldoDisponible;
  final double carteraPorCobrar;
  final double proyeccionHoy;

  /// Ventana móvil de 7 días (hoy inclusive, hasta 6 días después) — no
  /// semana calendario.
  final double proyeccionSemana;
  final double gananciaInteres;
  final double gananciaExtras;

  double get gananciaTotal => gananciaInteres + gananciaExtras;
}

/// Calcula el resumen financiero del dashboard: saldo disponible, cartera
/// por cobrar, proyección de entradas y ganancia realizada.
///
/// `saldo_disponible = (cargas de capital) + (todo lo cobrado, monto_abonado)
/// - (capital de préstamos activos/en_mora)`: usa `monto_abonado` (no
/// `monto_aplicado`) porque es efectivo real en caja, incluyendo el
/// excedente de pagos `cobro_extra` que no reduce la deuda pero sí es
/// dinero que el cobrador tiene en la mano.
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

  Future<ResumenDashboard> calcularResumen() async {
    final prestamos = await _prestamosRepository.listarTodos();
    final cargas = await _cargasCapitalRepository.listarTodas();

    final hoy = _soloFecha(DateTime.now());
    final finSemana = hoy.add(const Duration(days: 7));

    var carteraPorCobrar = 0.0;
    var capitalEnPrestamosActivos = 0.0;
    var proyeccionHoy = 0.0;
    var proyeccionSemana = 0.0;
    var gananciaInteres = 0.0;
    var gananciaExtras = 0.0;
    var totalAbonadoGlobal = 0.0;

    for (final prestamo in prestamos) {
      final detalle = await _prestamosRepository.obtenerDetalle(prestamo.id);
      final pagos = await _pagosRepository.listarPorPrestamo(prestamo.id);

      final totalAplicado = pagos.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAplicado);
      final totalAbonado = pagos.fold<double>(0, (acumulado, pago) => acumulado + pago.montoAbonado);
      totalAbonadoGlobal += totalAbonado;

      final montoTotal = detalle.montoTotal;
      if (montoTotal > 0) {
        gananciaInteres += totalAplicado * (detalle.montoInteres / montoTotal);
        gananciaExtras += totalAplicado * (detalle.montoExtras / montoTotal);
      }
      // Único caso donde monto_abonado > monto_aplicado en una misma fila
      // de pago (ver PagoProcessor.php): el excedente de un cobro_extra.
      gananciaExtras += totalAbonado - totalAplicado;

      if (_estadosOutstanding.contains(prestamo.estado)) {
        final saldoPendiente = montoTotal - totalAplicado;
        carteraPorCobrar += saldoPendiente < 0 ? 0 : saldoPendiente;
        capitalEnPrestamosActivos += prestamo.montoCapital;

        for (final cuota in detalle.cuotas) {
          if (cuota.estado == 'pagada') continue;

          final fechaCuota = _soloFecha(cuota.fechaEsperada);
          if (fechaCuota.isAtSameMomentAs(hoy)) {
            proyeccionHoy += cuota.montoEsperado;
          }
          if (!fechaCuota.isBefore(hoy) && fechaCuota.isBefore(finSemana)) {
            proyeccionSemana += cuota.montoEsperado;
          }
        }
      }
    }

    final totalCargasCapital = cargas.fold<double>(0, (acumulado, carga) => acumulado + carga.monto);
    final saldoDisponible = totalCargasCapital + totalAbonadoGlobal - capitalEnPrestamosActivos;

    return ResumenDashboard(
      saldoDisponible: saldoDisponible,
      carteraPorCobrar: carteraPorCobrar,
      proyeccionHoy: proyeccionHoy,
      proyeccionSemana: proyeccionSemana,
      gananciaInteres: gananciaInteres,
      gananciaExtras: gananciaExtras,
    );
  }

  DateTime _soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}
