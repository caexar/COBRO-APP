import 'package:drift/drift.dart';

/// Una lista organizada de préstamos a cobrar, propiedad de un cobrador.
/// Refleja la tabla `rutas` del backend. `fecha` nullable: con valor, la
/// ruta está asociada a un día específico (ej. la creada por
/// `RutasRepository.autogenerarHoy`); `null` es una ruta general/reutilizable
/// sin fecha fija. `orden` es la posición manual (drag-and-drop) de esta
/// ruta dentro de la LISTA de rutas del cobrador — no tiene relación con el
/// orden de sus `RutaItems`.
@DataClassName('Ruta')
class Rutas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();

  /// Generado al crear el registro localmente (no al sincronizar); ver nota
  /// equivalente en `Clientes.uuidLocal`. Nulo en una ruta creada por
  /// `autogenerarHoy()` (nace ya con `servidorId`, nunca se sube).
  TextColumn get uuidLocal => text().nullable()();
  IntColumn get usuarioId => integer()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime().nullable()();

  /// Solo tiene sentido en una ruta creada por [RutasRepository.autogenerarHoy]: `null` en
  /// una ruta manual (no aplica), `false`/`true` según la opción que eligió el cobrador al
  /// autogenerar ("solo ese día" vs. "incluir vencidas también") — se muestra como un aviso
  /// sutil junto al nombre en `RutasListScreen`.
  BoolColumn get incluyeVencidas => boolean().nullable()();
  IntColumn get orden => integer().withDefault(const Constant(0))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
