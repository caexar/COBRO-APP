import 'package:drift/drift.dart';

import 'prestamos_table.dart';

/// Refleja la tabla `cuotas` del backend Laravel. `estado` es
/// pendiente|pagada|en_mora, igual que el enum del servidor.
class Cuotas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get prestamoId => integer().references(Prestamos, #id)();
  IntColumn get numeroCuota => integer()();
  DateTimeColumn get fechaEsperada => dateTime()();
  RealColumn get montoEsperado => real()();
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
