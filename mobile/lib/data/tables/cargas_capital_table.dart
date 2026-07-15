import 'package:drift/drift.dart';

/// Dinero que el cobrador mete al negocio (aporte de capital). `creadoEn` es
/// la fecha del registro: no se pide una fecha editable, siempre es "ahora".
@DataClassName('CargaCapital')
class CargasCapital extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get usuarioId => integer()();
  RealColumn get monto => real()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
