import 'package:flutter/services.dart';

/// Formatea en vivo un campo de texto de dinero con separador de miles
/// ("100000" -> "100.000") mientras el usuario escribe. El valor real (sin
/// puntos) se obtiene con [valorPlano]/[valorNumerico] — el separador nunca
/// se guarda ni se envía al backend, solo es para mostrar.
///
/// Úsalo en cualquier campo de dinero de la app (capital, montos extra,
/// futuros campos de pago, etc.) para que el formato sea consistente en
/// toda la app.
class FormateadorDinero extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final soloDigitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (soloDigitos.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formateado = _agregarSeparadorDeMiles(soloDigitos);

    return TextEditingValue(text: formateado, selection: TextSelection.collapsed(offset: formateado.length));
  }

  static String _agregarSeparadorDeMiles(String soloDigitos) {
    final invertido = soloDigitos.split('').reversed.join();
    final grupos = <String>[];

    for (var i = 0; i < invertido.length; i += 3) {
      final fin = (i + 3 < invertido.length) ? i + 3 : invertido.length;
      grupos.add(invertido.substring(i, fin));
    }

    return grupos.join('.').split('').reversed.join();
  }

  /// Quita los separadores de miles (ej. "100.000" -> "100000").
  static String valorPlano(String textoFormateado) => textoFormateado.replaceAll('.', '');

  /// Igual que [valorPlano], pero ya convertido a número (o `null` si el
  /// campo está vacío o no es un número válido).
  static double? valorNumerico(String textoFormateado) => double.tryParse(valorPlano(textoFormateado));
}

/// Formatea un monto para mostrarlo (ej. 125000 -> "$ 125.000"). Usa el
/// mismo separador que [FormateadorDinero] a propósito, para que los campos
/// de captura y los montos ya calculados/guardados luzcan consistentes.
String formatearMoneda(double valor) {
  final parteEntera = valor.truncate().toString();
  final conSeparadorDeMiles = parteEntera.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  return '\$ $conSeparadorDeMiles';
}

/// Interpreta lo que el usuario escribió en un campo de monto según la
/// preferencia de "atajo de miles" (ver `AtajoMilesRepository`): si está
/// activada, el valor escrito se multiplica por 1000 (ej. "300" al guardar
/// se persiste como 300000); si no, se usa tal cual. Punto único de entrada
/// para esa interpretación — cualquier pantalla que guarde un monto debe usar
/// esta función (nunca `FormateadorDinero.valorNumerico` directo) para que la
/// preferencia se respete consistentemente en toda la app. No afecta en
/// absoluto la visualización de montos ya guardados (`formatearMoneda`).
double? interpretarValorIngresado(String textoFormateado, {required bool atajoMilesActivado}) {
  final valor = FormateadorDinero.valorNumerico(textoFormateado);
  if (valor == null) return null;
  return atajoMilesActivado ? valor * 1000 : valor;
}

/// Texto de ayuda para mostrar en vivo bajo un campo de monto mientras el
/// usuario escribe (ej. "Se agregarán tres ceros: 300.000"), solo cuando el
/// atajo de miles está activado y el campo ya tiene un valor válido. `null`
/// en cualquier otro caso (no se muestra nada).
String? textoAyudaAtajoMiles(String textoFormateado, {required bool atajoMilesActivado}) {
  if (!atajoMilesActivado) return null;
  final valor = FormateadorDinero.valorNumerico(textoFormateado);
  if (valor == null || valor <= 0) return null;
  return 'Se agregarán tres ceros: ${formatearMoneda(valor * 1000)}';
}
