// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prestamos_extras_dao.dart';

// ignore_for_file: type=lint
mixin _$PrestamosExtrasDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientesTable get clientes => attachedDatabase.clientes;
  $PrestamosTable get prestamos => attachedDatabase.prestamos;
  $PrestamosExtrasTable get prestamosExtras => attachedDatabase.prestamosExtras;
  PrestamosExtrasDaoManager get managers => PrestamosExtrasDaoManager(this);
}

class PrestamosExtrasDaoManager {
  final _$PrestamosExtrasDaoMixin _db;
  PrestamosExtrasDaoManager(this._db);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db.attachedDatabase, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db.attachedDatabase, _db.prestamos);
  $$PrestamosExtrasTableTableManager get prestamosExtras =>
      $$PrestamosExtrasTableTableManager(
        _db.attachedDatabase,
        _db.prestamosExtras,
      );
}
