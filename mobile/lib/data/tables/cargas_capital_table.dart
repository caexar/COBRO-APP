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

  /// Generado al crear el registro localmente (no al sincronizar) para los
  /// movimientos que registra el propio cobrador; en los que llegan
  /// descargados de un admin (ver `origen`) queda nulo, porque ya traen
  /// `servidorId` desde el primer momento y nunca se suben.
  TextColumn get uuidLocal => text().nullable()();
  IntColumn get usuarioId => integer()();
  RealColumn get monto => real()();
  TextColumn get tipo => text().withDefault(const Constant('carga'))();
  TextColumn get descripcion => text().nullable()();

  /// 'cobrador' (default, registrado desde este dispositivo) o 'admin'
  /// (descargado de `POST /sync` -> `cargas_capital_admin`, asignado por un
  /// admin vía `POST /admin/cargas-capital`).
  TextColumn get origen => text().withDefault(const Constant('cobrador'))();

  /// Solo viene informado cuando `origen = 'admin'` (id del admin que lo
  /// asignó, tal como lo manda el servidor); null en el flujo normal.
  IntColumn get creadoPorUsuarioId => integer().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get eliminadoEn => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
