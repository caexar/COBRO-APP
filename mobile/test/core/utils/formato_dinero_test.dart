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

    test('un mismo monto ya guardado se muestra igual sin importar el atajo de miles', () {
      // El atajo de miles solo afecta la interpretación al escribir/guardar
      // (interpretarValorIngresado); la visualización de un monto ya
      // guardado siempre pasa por formatearMoneda tal cual, sin relación con
      // esa preferencia.
      expect(formatearMoneda(300000), r'$ 300.000');
    });
  });

  group('interpretarValorIngresado', () {
    test('con el atajo activado, multiplica por 1000 lo escrito', () {
      expect(interpretarValorIngresado('300', atajoMilesActivado: true), 300000.0);
    });

    test('con el atajo desactivado, usa el valor escrito tal cual', () {
      expect(interpretarValorIngresado('300', atajoMilesActivado: false), 300.0);
    });

    test('un campo vacío da null sin importar el atajo', () {
      expect(interpretarValorIngresado('', atajoMilesActivado: true), isNull);
      expect(interpretarValorIngresado('', atajoMilesActivado: false), isNull);
    });
  });

  group('textoAyudaAtajoMiles', () {
    test('con el atajo activado, describe el valor final con los tres ceros', () {
      expect(textoAyudaAtajoMiles('300', atajoMilesActivado: true), 'Se agregarán tres ceros: \$ 300.000');
    });

    test('con el atajo desactivado, no muestra ningún texto de ayuda', () {
      expect(textoAyudaAtajoMiles('300', atajoMilesActivado: false), isNull);
    });

    test('un campo vacío no muestra texto de ayuda aunque el atajo esté activado', () {
      expect(textoAyudaAtajoMiles('', atajoMilesActivado: true), isNull);
    });
  });
}
