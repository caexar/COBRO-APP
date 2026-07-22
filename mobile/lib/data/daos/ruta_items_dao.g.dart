// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ruta_items_dao.dart';

// ignore_for_file: type=lint
mixin _$RutaItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RutasTable get rutas => attachedDatabase.rutas;
  $ClientesTable get clientes => attachedDatabase.clientes;
  $PrestamosTable get prestamos => attachedDatabase.prestamos;
  $RutaItemsTable get rutaItems => attachedDatabase.rutaItems;
  RutaItemsDaoManager get managers => RutaItemsDaoManager(this);
}

class RutaItemsDaoManager {
  final _$RutaItemsDaoMixin _db;
  RutaItemsDaoManager(this._db);
  $$RutasTableTableManager get rutas =>
      $$RutasTableTableManager(_db.attachedDatabase, _db.rutas);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db.attachedDatabase, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db.attachedDatabase, _db.prestamos);
  $$RutaItemsTableTableManager get rutaItems =>
      $$RutaItemsTableTableManager(_db.attachedDatabase, _db.rutaItems);
}
