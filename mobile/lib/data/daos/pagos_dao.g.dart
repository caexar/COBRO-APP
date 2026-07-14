// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pagos_dao.dart';

// ignore_for_file: type=lint
mixin _$PagosDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientesTable get clientes => attachedDatabase.clientes;
  $PrestamosTable get prestamos => attachedDatabase.prestamos;
  $CuotasTable get cuotas => attachedDatabase.cuotas;
  $PagosTable get pagos => attachedDatabase.pagos;
  PagosDaoManager get managers => PagosDaoManager(this);
}

class PagosDaoManager {
  final _$PagosDaoMixin _db;
  PagosDaoManager(this._db);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db.attachedDatabase, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db.attachedDatabase, _db.prestamos);
  $$CuotasTableTableManager get cuotas =>
      $$CuotasTableTableManager(_db.attachedDatabase, _db.cuotas);
  $$PagosTableTableManager get pagos =>
      $$PagosTableTableManager(_db.attachedDatabase, _db.pagos);
}
