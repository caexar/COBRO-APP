import 'package:drift/drift.dart';

import 'prestamos_table.dart';
import 'rutas_table.dart';

/// Un préstamo dentro de una ruta. Refleja la tabla `ruta_items` del
/// backend. `orden` es la posición manual (drag-and-drop) DENTRO de esa
/// ruta — independiente del `orden` de `Rutas`. `cobradoEn` se llena al
/// marcar el ítem como cobrado, ya sea directo desde `RutaDetalleScreen` o
/// porque se registró un pago real para ese préstamo (ver
/// `RutasRepository.marcarCobradoSiPertenece`, conectado desde
/// `PrestamoDetalleScreen.onPagoRegistrado`).
@DataClassName('RutaItem')
class RutaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get servidorId => integer().nullable().unique()();

  /// Generado al crear el registro localmente (no al sincronizar); nulo en
  /// un ítem creado por `autogenerarHoy()` (nace ya con `servidorId`).
  TextColumn get uuidLocal => text().nullable()();
  IntColumn get rutaId => integer().references(Rutas, #id)();
  IntColumn get prestamoId => integer().references(Prestamos, #id)();
  IntColumn get orden => integer().withDefault(const Constant(0))();

  /// 'pendiente' | 'cobrado'.
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  DateTimeColumn get cobradoEn => dateTime().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get actualizadoEn => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();
}
