import 'package:drift/drift.dart';

import 'cierres_caja_table.dart';

/// Un gasto del día asociado a un cierre de caja (ej. "almuerzo", "gasolina")
/// — varios por cierre. `detalle` es texto libre obligatorio, no una
/// categoría cerrada (a diferencia de `cargas_capital`).
@DataClassName('CierreCajaGasto')
class CierreCajaGastos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cierreCajaId => integer().references(CierresCaja, #id)();
  RealColumn get monto => real()();
  TextColumn get detalle => text()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}
