import 'package:drift/drift.dart';

/// Movimiento de capital del cobrador: aporte (`tipo = 'carga'`) o retiro
/// (`tipo = 'retiro'`), ambos con `monto` siempre positivo (el signo lo da
/// `tipo`, mismo patrón que `monto_abonado` en pagos). `creadoEn` es la
/// fecha del registro: no se pide una fecha editable, siempre es "ahora".
/// `eliminadoEn` permite deshacer un registro por error sin borrar la fila
/// (mismo patrón de soft-delete que `prestamos`/`pagos`).
@DataClassName('CargaCapital')
class CargasCapital extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get usuarioId => integer()();
  RealColumn get monto => real()();
  TextColumn get tipo => text().withDefault(const Constant('carga'))();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get eliminadoEn => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
