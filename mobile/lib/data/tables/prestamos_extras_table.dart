import 'package:drift/drift.dart';

import 'prestamos_table.dart';

/// Refleja la tabla `prestamos_extras` del backend Laravel: montos extra
/// (ej. papelería) asociados a un préstamo.
class PrestamosExtras extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get prestamoId => integer().references(Prestamos, #id)();
  TextColumn get concepto => text()();
  RealColumn get valor => real()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
