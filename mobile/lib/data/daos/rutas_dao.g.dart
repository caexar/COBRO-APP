// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rutas_dao.dart';

// ignore_for_file: type=lint
mixin _$RutasDaoMixin on DatabaseAccessor<AppDatabase> {
  $RutasTable get rutas => attachedDatabase.rutas;
  RutasDaoManager get managers => RutasDaoManager(this);
}

class RutasDaoManager {
  final _$RutasDaoMixin _db;
  RutasDaoManager(this._db);
  $$RutasTableTableManager get rutas =>
      $$RutasTableTableManager(_db.attachedDatabase, _db.rutas);
}
