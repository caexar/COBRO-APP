import 'package:cobro_app/features/prestamos/data/prestamo_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculadora = PrestamoCalculator();

  test('capital + interés simple + extras, repartido en cuotas diarias iguales', () {
    // Mismos valores usados para verificar el backend: 100000 al 20%, 5000
    // de extras, 10 cuotas diarias desde 2026-07-10 -> total 125000, cada
    // cuota 12500, cuota 1 vence el 2026-07-11.
    final resultado = calculadora.calcular(
      montoCapital: 100000,
      porcentajeInteres: 20,
      extras: const [ExtraPrestamo(concepto: 'papeleria', valor: 5000)],
      frecuenciaPago: 'diario',
      plazoCuotas: 10,
      fechaInicio: DateTime(2026, 7, 10),
    );

    expect(resultado.montoCapital, 100000);
    expect(resultado.montoInteres, 20000);
    expect(resultado.montoExtras, 5000);
    expect(resultado.montoTotal, 125000);
    expect(resultado.cuotas, hasLength(10));
    expect(resultado.cuotas.every((c) => c.montoEsperado == 12500), isTrue);
    expect(resultado.cuotas.first.fechaEsperada, DateTime(2026, 7, 11));
    expect(resultado.cuotas.last.fechaEsperada, DateTime(2026, 7, 20));
  });

  test('la última cuota absorbe el residuo de redondeo', () {
    final resultado = calculadora.calcular(
      montoCapital: 100,
      porcentajeInteres: 0,
      frecuenciaPago: 'diario',
      plazoCuotas: 3,
      fechaInicio: DateTime(2026, 1, 1),
    );

    // 100 / 3 = 33.33... -> 33.33, 33.33, y la última absorbe el residuo (33.34).
    expect(resultado.cuotas[0].montoEsperado, 33.33);
    expect(resultado.cuotas[1].montoEsperado, 33.33);
    expect(resultado.cuotas[2].montoEsperado, 33.34);

    final suma = resultado.cuotas.fold<double>(0, (acumulado, c) => acumulado + c.montoEsperado);
    expect(suma, resultado.montoTotal);
  });

  test('frecuencia semanal suma semanas completas', () {
    final resultado = calculadora.calcular(
      montoCapital: 1000,
      porcentajeInteres: 0,
      frecuenciaPago: 'semanal',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );

    expect(resultado.cuotas[0].fechaEsperada, DateTime(2026, 1, 8));
    expect(resultado.cuotas[1].fechaEsperada, DateTime(2026, 1, 15));
  });

  test('frecuencia personalizado suma dias_personalizado * numero_cuota', () {
    final resultado = calculadora.calcular(
      montoCapital: 1000,
      porcentajeInteres: 0,
      frecuenciaPago: 'personalizado',
      diasPersonalizado: 3,
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 1),
    );

    expect(resultado.cuotas[0].fechaEsperada, DateTime(2026, 1, 4));
    expect(resultado.cuotas[1].fechaEsperada, DateTime(2026, 1, 7));
  });

  test('frecuencia mensual no desborda cuando el día de inicio no existe en el mes destino', () {
    final resultado = calculadora.calcular(
      montoCapital: 1000,
      porcentajeInteres: 0,
      frecuenciaPago: 'mensual',
      plazoCuotas: 2,
      fechaInicio: DateTime(2026, 1, 31),
    );

    // Enero 31 + 1 mes -> Febrero no tiene 31, debe recortar a Feb 28 (2026 no es bisiesto).
    expect(resultado.cuotas[0].fechaEsperada, DateTime(2026, 2, 28));
    // + 2 meses -> Marzo 31 (marzo sí tiene 31 días).
    expect(resultado.cuotas[1].fechaEsperada, DateTime(2026, 3, 31));
  });
}
