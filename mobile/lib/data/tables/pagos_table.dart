import 'package:drift/drift.dart';

import 'cuotas_table.dart';
import 'prestamos_table.dart';

/// Refleja la tabla `pagos` del backend Laravel, incluyendo `montoAplicado`
/// (cuánto del abono realmente redujo la deuda; solo difiere de
/// `montoAbonado` en el caso de un excedente registrado como cobro extra).
class Pagos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get prestamoId => integer().references(Prestamos, #id)();
  IntColumn get cuotaId => integer().nullable().references(Cuotas, #id)();
  RealColumn get montoAbonado => real()();
  RealColumn get montoAplicado => real()();
  DateTimeColumn get fechaPago => dateTime()();
  IntColumn get diasMora => integer().withDefault(const Constant(0))();
  RealColumn get saldoRestanteDespues => real()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get eliminadoEn => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
