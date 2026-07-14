// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cuotas_dao.dart';

// ignore_for_file: type=lint
mixin _$CuotasDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientesTable get clientes => attachedDatabase.clientes;
  $PrestamosTable get prestamos => attachedDatabase.prestamos;
  $CuotasTable get cuotas => attachedDatabase.cuotas;
  CuotasDaoManager get managers => CuotasDaoManager(this);
}

class CuotasDaoManager {
  final _$CuotasDaoMixin _db;
  CuotasDaoManager(this._db);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db.attachedDatabase, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db.attachedDatabase, _db.prestamos);
  $$CuotasTableTableManager get cuotas =>
      $$CuotasTableTableManager(_db.attachedDatabase, _db.cuotas);
}
