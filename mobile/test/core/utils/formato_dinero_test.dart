import 'package:cobro_app/core/utils/formato_dinero.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _valor(String texto) => TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));

void main() {
  group('FormateadorDinero (formato en vivo mientras se escribe)', () {
    final formateador = FormateadorDinero();

    test('agrega separador de miles al escribir', () {
      expect(
        formateador.formatEditUpdate(_valor(''), _valor('100000')).text,
        '100.000',
      );
      expect(
        formateador.formatEditUpdate(_valor(''), _valor('1234567')).text,
        '1.234.567',
      );
      expect(
        formateador.formatEditUpdate(_valor(''), _valor('12')).text,
        '12',
      );
    });

    test('borrar hasta dejar vacío no revienta', () {
      expect(formateador.formatEditUpdate(_valor('100.000'), _valor('')).text, '');
    });

    test('sigue funcionando al borrar un dígito de un valor ya formateado', () {
      // El usuario ve "100.000" y borra el último caracter visible (el
      // último "0"); el campo entrega "100.00" (con el punto que ya
      // estaba ahí) y el formateador debe quitarlo y recalcular a "10.000".
      final resultado = formateador.formatEditUpdate(_valor('100.000'), _valor('100.00'));
      expect(resultado.text, '10.000');
    });

    test('el cursor queda al final del texto formateado', () {
      final resultado = formateador.formatEditUpdate(_valor(''), _valor('100000'));
      expect(resultado.selection.baseOffset, resultado.text.length);
    });
  });

  group('FormateadorDinero.valorPlano / valorNumerico', () {
    test('quita los puntos para obtener el número real', () {
      expect(FormateadorDinero.valorPlano('100.000'), '100000');
      expect(FormateadorDinero.valorNumerico('100.000'), 100000.0);
    });

    test('un campo vacío da null, no una excepción', () {
      expect(FormateadorDinero.valorNumerico(''), isNull);
    });
  });

  group('formatearMoneda', () {
    test('formatea con el mismo separador que los inputs', () {
      expect(formatearMoneda(125000), r'$ 125.000');
      expect(formatearMoneda(1000000), r'$ 1.000.000');
      expect(formatearMoneda(500), r'$ 500');
    });
  });
}
