import 'package:cobro_app/core/utils/json_fecha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('comoFecha', () {
    test('parsea un date del backend con hora y Z sin desplazar el día', () {
      final fecha = comoFecha('2026-07-22T00:00:00.000000Z');

      expect(fecha.year, 2026);
      expect(fecha.month, 7);
      expect(fecha.day, 22);
      expect(fecha.isUtc, isFalse);
    });

    test('también acepta solo la fecha, sin hora', () {
      final fecha = comoFecha('2026-01-05');

      expect(fecha, DateTime(2026, 1, 5));
    });
  });
}
