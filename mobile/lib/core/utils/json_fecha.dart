/// El backend serializa cualquier columna `date` de Eloquent (una fecha de
/// calendario, sin hora real) como un string con hora y "Z" de UTC (ej.
/// `"2026-07-22T00:00:00.000000Z"`). Parsear eso con `DateTime.parse`
/// directo da un `DateTime` en UTC — y como Drift guarda sus columnas de
/// fecha como epoch y las reconstruye en hora LOCAL al leerlas, en
/// cualquier huso detrás de UTC (ej. Colombia, UTC-5) el día queda
/// desplazado un día hacia atrás apenas se guarda (`2026-07-22T00:00:00Z`
/// pasa a ser `2026-07-21 19:00` local). Bug real, no hipotético — ver
/// `RutasRepository.autogenerarHoy`.
///
/// Esta función toma solo la parte `YYYY-MM-DD` del string (ignora hora y
/// zona) y arma un `DateTime` LOCAL a medianoche, sin pasar nunca por UTC —
/// único helper para esto, igual que `comoDouble` lo es para decimales:
/// cualquier campo `date` nuevo del backend (no un timestamp real como
/// `created_at`, donde sí importa la hora) debe parsearse con esta función.
DateTime comoFecha(Object? valor) {
  final texto = valor.toString();
  final soloFecha = texto.split('T').first;
  final partes = soloFecha.split('-');
  return DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
}
