import 'package:drift/drift.dart';

import 'clientes_table.dart';

/// Refleja la tabla `prestamos` del backend Laravel.
///
/// `frecuenciaPago` (diario|semanal|mensual|personalizado), `estado`
/// (activo|pagado|en_mora|anulado) y `politicaMora`
/// (mantener|siguiente_pago|sumar_total) se guardan como texto plano, igual
/// que los enums del lado del servidor.
class Prestamos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get usuarioId => integer()();
  RealColumn get montoCapital => real()();
  RealColumn get porcentajeInteres => real()();
  TextColumn get frecuenciaPago => text()();
  IntColumn get diasPersonalizado => integer().nullable()();
  IntColumn get plazoCuotas => integer()();
  DateTimeColumn get fechaInicio => dateTime()();
  TextColumn get estado => text().withDefault(const Constant('activo'))();
  TextColumn get politicaMora => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get eliminadoEn => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
