import 'package:drift/drift.dart';

/// Cierre de caja diario del cobrador: capital al inicio y al cierre del
/// día (`fecha`, la fecha operativa elegida por el cobrador — no
/// `creadoEn`, que es el timestamp real de cuándo se guardó el registro),
/// ambos prellenados por la pantalla con el saldo disponible calculado
/// (`DashboardRepository.calcularResumen`) pero editables antes de guardar.
/// `justificacionDiferencia` es obligatoria en la UI solo si el cobrador
/// edita alguno de los dos valores prellenados (regla que se resuelve en la
/// pantalla, no acá). `gastosTotal` es la suma de los `CierreCajaGasto`
/// asociados, calculada al guardar (ver `CierresCajaRepository.crear`).
@DataClassName('CierreCaja')
class CierresCaja extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();

  /// Generado al crear el registro localmente (no al sincronizar), mismo
  /// patrón que `clientes`/`prestamos`/`pagos`/`cargas_capital`.
  TextColumn get uuidLocal => text().nullable()();
  IntColumn get usuarioId => integer()();
  DateTimeColumn get fecha => dateTime()();
  RealColumn get capitalInicio => real()();
  RealColumn get capitalCierre => real()();
  TextColumn get justificacionDiferencia => text().nullable()();
  RealColumn get gastosTotal => real().withDefault(const Constant(0))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
