// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cambios_pendientes_dao.dart';

// ignore_for_file: type=lint
mixin _$CambiosPendientesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CambiosPendientesTable get cambiosPendientes =>
      attachedDatabase.cambiosPendientes;
  CambiosPendientesDaoManager get managers => CambiosPendientesDaoManager(this);
}

class CambiosPendientesDaoManager {
  final _$CambiosPendientesDaoMixin _db;
  CambiosPendientesDaoManager(this._db);
  $$CambiosPendientesTableTableManager get cambiosPendientes =>
      $$CambiosPendientesTableTableManager(
        _db.attachedDatabase,
        _db.cambiosPendientes,
      );
}
