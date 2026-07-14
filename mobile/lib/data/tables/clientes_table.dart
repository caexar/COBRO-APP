import 'package:drift/drift.dart';

/// Refleja la tabla `clientes` del backend Laravel.
///
/// `servidorId` queda nulo mientras el registro no se ha sincronizado; `id` es
/// el identificador local (autoincrement) usado para las relaciones dentro de
/// esta base de datos SQLite, independiente del id que asigne el servidor.
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();
  IntColumn get usuarioId => integer()();
  TextColumn get nombre => text().withLength(min: 1, max: 255)();
  TextColumn get cedula => text().withLength(min: 1, max: 50)();
  TextColumn get telefono => text()();
  TextColumn get direccion => text()();
  TextColumn get referencia => text().nullable()();
  TextColumn get fotoUrl => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get eliminadoEn => dateTime().nullable()();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
