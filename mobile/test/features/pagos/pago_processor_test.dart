import 'package:cobro_app/features/pagos/data/pago_processor.dart';
import 'package:flutter_test/flutter_test.dart';

Cuota _cuota({
  required int id,
  required int numeroCuota,
  required DateTime fechaEsperada,
  required double montoEsperado,
  String estado = 'pendiente',
}) {
  return Cuota(
    id: id,
    prestamoId: 1,
    numeroCuota: numeroCuota,
    fechaEsperada: fechaEsperada,
    montoEsperado: montoEsperado,
    estado: estado,
    creadoEn: DateTime(2026, 1, 1),
    actualizadoEn: DateTime(2026, 1, 1),
    sincronizado: false,
  );
}

Pago _pagoExistente({required int cuotaId, required double montoAplicado}) {
  return Pago(
    id: 0,
    prestamoId: 1,
    cuotaId: cuotaId,
    montoAbonado: montoAplicado,
    montoAplicado: montoAplicado,
    fechaPago: DateTime(2026, 1, 1),
    diasMora: 0,
    saldoRestanteDespues: 0,
    creadoEn: DateTime(2026, 1, 1),
    actualizadoEn: DateTime(2026, 1, 1),
    sincronizado: true,
  );
}

void main() {
  const processor = PagoProcessor();

  group('pago exacto', () {
    test('marca la cuota como pagada y calcula el saldo restante', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 20000,
        montoAbonado: 10000,
        fechaPago: DateTime(2026, 1, 10),
      );

      expect(plan.pagos, hasLength(1));
      expect(plan.pagos.first.montoAplicado, 10000);
      expect(plan.pagos.first.saldoRestanteDespues, 10000);
      expect(plan.pagos.first.diasMora, 0);
      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pagada')]);
      expect(plan.nuevoEstadoPrestamo, 'activo');
      expect(plan.politicaMoraAplicada, isNull);
    });

    test('deja el préstamo pagado cuando era la última cuota pendiente', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 10000,
        montoAbonado: 10000,
        fechaPago: DateTime(2026, 1, 10),
      );

      expect(plan.nuevoEstadoPrestamo, 'pagado');
    });

    test('calcula días de mora cuando la fecha de pago es posterior a la esperada', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 10000,
        montoAbonado: 10000,
        fechaPago: DateTime(2026, 1, 15),
      );

      expect(plan.pagos.first.diasMora, 5);
    });

    test('lanza StateError si no hay cuotas pendientes', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000, estado: 'pagada')];

      expect(
        () => processor.procesar(
          cuotas: cuotas,
          pagosExistentes: const [],
          montoTotalPrestamo: 10000,
          montoAbonado: 10000,
          fechaPago: DateTime(2026, 1, 10),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('faltante (abono menor a lo pendiente)', () {
    test('sin política indicada, lanza PoliticaMoraRequeridaException con el faltante', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      expect(
        () => processor.procesar(
          cuotas: cuotas,
          pagosExistentes: const [],
          montoTotalPrestamo: 10000,
          montoAbonado: 6000,
          fechaPago: DateTime(2026, 1, 10),
        ),
        throwsA(isA<PoliticaMoraRequeridaException>().having((e) => e.faltante, 'faltante', 4000)),
      );
    });

    test('mantener: la cuota queda en_mora si el pago fue tarde', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 20000,
        montoAbonado: 6000,
        fechaPago: DateTime(2026, 1, 15),
        politicaMora: 'mantener',
      );

      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'en_mora')]);
      expect(plan.pagos.single.montoAplicado, 6000);
      expect(plan.nuevoEstadoPrestamo, 'en_mora');
      expect(plan.politicaMoraAplicada, 'mantener');
    });

    test('mantener: la cuota queda pendiente si el pago fue a tiempo', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 10000,
        montoAbonado: 6000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'mantener',
      );

      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pendiente')]);
    });

    test('siguiente_pago: suma el faltante a la siguiente cuota pendiente y marca la actual pagada', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 20000,
        montoAbonado: 6000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'siguiente_pago',
      );

      expect(plan.actualizacionesCuotas, containsAll([
        const ActualizacionCuota(cuotaId: 2, nuevoMontoEsperado: 14000),
        const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pagada'),
      ]));
    });

    test('siguiente_pago cae a mantener si no hay otra cuota pendiente', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 10000,
        montoAbonado: 6000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'siguiente_pago',
      );

      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pendiente')]);
    });

    test('sumar_total: reparte el faltante entre todas las demás cuotas pendientes, la última absorbe el residuo', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
        _cuota(id: 3, numeroCuota: 3, fechaEsperada: DateTime(2026, 1, 24), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 30000,
        montoAbonado: 9000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'sumar_total',
      );

      // faltante = 1000, repartido entre 2 cuotas -> 500 cada una.
      expect(plan.actualizacionesCuotas, containsAll([
        const ActualizacionCuota(cuotaId: 2, nuevoMontoEsperado: 10500),
        const ActualizacionCuota(cuotaId: 3, nuevoMontoEsperado: 10500),
        const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pagada'),
      ]));
    });

    test('sumar_total cae a mantener si no hay otras cuotas pendientes', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 10000,
        montoAbonado: 6000,
        fechaPago: DateTime(2026, 1, 12),
        politicaMora: 'sumar_total',
      );

      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'en_mora')]);
    });

    test('el faltante considera abonos parciales previos ya aplicados a la misma cuota', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];
      final pagosExistentes = [_pagoExistente(cuotaId: 1, montoAplicado: 4000)];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: pagosExistentes,
        montoTotalPrestamo: 10000,
        montoAbonado: 3000,
        fechaPago: DateTime(2026, 1, 10),
        politicaMora: 'mantener',
      );

      // pendiente en cuota = 10000 - 4000 = 6000; abono 3000 -> faltante 3000.
      expect(plan.pagos.single.montoAplicado, 3000);
      expect(plan.pagos.single.saldoRestanteDespues, 3000);
    });
  });

  group('excedente (abono mayor a lo pendiente)', () {
    test('sin manejo indicado, lanza ManejoExcedenteRequeridoException con el excedente', () {
      final cuotas = [_cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000)];

      expect(
        () => processor.procesar(
          cuotas: cuotas,
          pagosExistentes: const [],
          montoTotalPrestamo: 10000,
          montoAbonado: 13000,
          fechaPago: DateTime(2026, 1, 10),
        ),
        throwsA(isA<ManejoExcedenteRequeridoException>().having((e) => e.excedente, 'excedente', 3000)),
      );
    });

    test('cobro_extra: no reduce otras cuotas, solo registra el abono completo en esa fila', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 20000,
        montoAbonado: 13000,
        fechaPago: DateTime(2026, 1, 10),
        manejoExcedente: 'cobro_extra',
      );

      expect(plan.pagos, hasLength(1));
      expect(plan.pagos.single.montoAbonado, 13000);
      expect(plan.pagos.single.montoAplicado, 10000);
      expect(plan.actualizacionesCuotas, [const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pagada')]);
    });

    test('abono_deuda: aplica el excedente en cascada a las siguientes cuotas pendientes', () {
      final cuotas = [
        _cuota(id: 1, numeroCuota: 1, fechaEsperada: DateTime(2026, 1, 10), montoEsperado: 10000),
        _cuota(id: 2, numeroCuota: 2, fechaEsperada: DateTime(2026, 1, 17), montoEsperado: 10000),
        _cuota(id: 3, numeroCuota: 3, fechaEsperada: DateTime(2026, 1, 24), montoEsperado: 10000),
      ];

      final plan = processor.procesar(
        cuotas: cuotas,
        pagosExistentes: const [],
        montoTotalPrestamo: 30000,
        montoAbonado: 25000,
        fechaPago: DateTime(2026, 1, 10),
        manejoExcedente: 'abono_deuda',
      );

      // cuota 1: pagada con 10000. excedente 15000 -> cuota 2 (10000, pagada), sobra 5000 -> cuota 3 (5000, no alcanza).
      expect(plan.pagos, hasLength(3));
      expect(plan.pagos[0].cuotaId, 1);
      expect(plan.pagos[0].montoAplicado, 10000);
      expect(plan.pagos[1].cuotaId, 2);
      expect(plan.pagos[1].montoAplicado, 10000);
      expect(plan.pagos[2].cuotaId, 3);
      expect(plan.pagos[2].montoAplicado, 5000);

      expect(plan.actualizacionesCuotas, containsAll([
        const ActualizacionCuota(cuotaId: 1, nuevoEstado: 'pagada'),
        const ActualizacionCuota(cuotaId: 2, nuevoEstado: 'pagada'),
      ]));
      expect(plan.actualizacionesCuotas.any((a) => a.cuotaId == 3 && a.nuevoEstado == 'pagada'), isFalse);
      expect(plan.pagos.last.saldoRestanteDespues, 5000);
      expect(plan.nuevoEstadoPrestamo, 'activo');
    });
  });
}
