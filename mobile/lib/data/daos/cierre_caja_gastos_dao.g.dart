// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cierre_caja_gastos_dao.dart';

// ignore_for_file: type=lint
mixin _$CierreCajaGastosDaoMixin on DatabaseAccessor<AppDatabase> {
  $CierresCajaTable get cierresCaja => attachedDatabase.cierresCaja;
  $CierreCajaGastosTable get cierreCajaGastos =>
      attachedDatabase.cierreCajaGastos;
  CierreCajaGastosDaoManager get managers => CierreCajaGastosDaoManager(this);
}

class CierreCajaGastosDaoManager {
  final _$CierreCajaGastosDaoMixin _db;
  CierreCajaGastosDaoManager(this._db);
  $$CierresCajaTableTableManager get cierresCaja =>
      $$CierresCajaTableTableManager(_db.attachedDatabase, _db.cierresCaja);
  $$CierreCajaGastosTableTableManager get cierreCajaGastos =>
      $$CierreCajaGastosTableTableManager(
        _db.attachedDatabase,
        _db.cierreCajaGastos,
      );
}
