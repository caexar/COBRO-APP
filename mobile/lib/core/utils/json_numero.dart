/// El backend serializa los decimales (columnas `decimal:N` de Eloquent)
/// como string (ej. "100000.00") en vez de número — acepta tanto `num` como
/// `String` para no romperse según cómo llegue serializado cada campo.
/// Único helper para esta conversión en toda la app: cualquier parseo nuevo
/// de un JSON del backend con campos decimales debe reutilizar esta función
/// en vez de repetir el `is num` / `double.parse` por su cuenta.
double comoDouble(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.parse(valor.toString());
}
