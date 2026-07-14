// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prestamos_dao.dart';

// ignore_for_file: type=lint
mixin _$PrestamosDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientesTable get clientes => attachedDatabase.clientes;
  $PrestamosTable get prestamos => attachedDatabase.prestamos;
  PrestamosDaoManager get managers => PrestamosDaoManager(this);
}

class PrestamosDaoManager {
  final _$PrestamosDaoMixin _db;
  PrestamosDaoManager(this._db);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db.attachedDatabase, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db.attachedDatabase, _db.prestamos);
}
