import 'package:drift/drift.dart';

/// Cola local de cambios que todavía no se han enviado al servidor (outbox).
///
/// Cada fila representa una operación pendiente sobre un registro de otra
/// tabla local (`tabla` + `registroId`, donde `registroId` es el `id` local
/// de esa tabla). El botón de sincronización recorre esta tabla, intenta
/// aplicar cada cambio contra la API y, si tiene éxito, elimina la fila.
class CambiosPendientes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nombre de la tabla afectada: clientes|prestamos|prestamos_extras|cuotas|pagos.
  TextColumn get tabla => text()();

  /// Id local (de la tabla indicada en `tabla`) del registro afectado.
  IntColumn get registroId => integer()();

  /// crear|actualizar|eliminar.
  TextColumn get tipoOperacion => text()();

  /// Copia en JSON de los datos a enviar al servidor en el momento del cambio.
  TextColumn get payload => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  IntColumn get intentos => integer().withDefault(const Constant(0))();
  TextColumn get ultimoError => text().nullable()();
}
