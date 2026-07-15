// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ClientesTable extends Clientes with TableInfo<$ClientesTable, Cliente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
    'usuario_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cedulaMeta = const VerificationMeta('cedula');
  @override
  late final GeneratedColumn<String> cedula = GeneratedColumn<String>(
    'cedula',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telefonoMeta = const VerificationMeta(
    'telefono',
  );
  @override
  late final GeneratedColumn<String> telefono = GeneratedColumn<String>(
    'telefono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _direccionMeta = const VerificationMeta(
    'direccion',
  );
  @override
  late final GeneratedColumn<String> direccion = GeneratedColumn<String>(
    'direccion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenciaMeta = const VerificationMeta(
    'referencia',
  );
  @override
  late final GeneratedColumn<String> referencia = GeneratedColumn<String>(
    'referencia',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fotoUrlMeta = const VerificationMeta(
    'fotoUrl',
  );
  @override
  late final GeneratedColumn<String> fotoUrl = GeneratedColumn<String>(
    'foto_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actualizadoEnMeta = const VerificationMeta(
    'actualizadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> actualizadoEn =
      GeneratedColumn<DateTime>(
        'actualizado_en',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _eliminadoEnMeta = const VerificationMeta(
    'eliminadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> eliminadoEn = GeneratedColumn<DateTime>(
    'eliminado_en',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    usuarioId,
    nombre,
    cedula,
    telefono,
    direccion,
    referencia,
    fotoUrl,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clientes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cliente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('cedula')) {
      context.handle(
        _cedulaMeta,
        cedula.isAcceptableOrUnknown(data['cedula']!, _cedulaMeta),
      );
    } else if (isInserting) {
      context.missing(_cedulaMeta);
    }
    if (data.containsKey('telefono')) {
      context.handle(
        _telefonoMeta,
        telefono.isAcceptableOrUnknown(data['telefono']!, _telefonoMeta),
      );
    } else if (isInserting) {
      context.missing(_telefonoMeta);
    }
    if (data.containsKey('direccion')) {
      context.handle(
        _direccionMeta,
        direccion.isAcceptableOrUnknown(data['direccion']!, _direccionMeta),
      );
    } else if (isInserting) {
      context.missing(_direccionMeta);
    }
    if (data.containsKey('referencia')) {
      context.handle(
        _referenciaMeta,
        referencia.isAcceptableOrUnknown(data['referencia']!, _referenciaMeta),
      );
    }
    if (data.containsKey('foto_url')) {
      context.handle(
        _fotoUrlMeta,
        fotoUrl.isAcceptableOrUnknown(data['foto_url']!, _fotoUrlMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('actualizado_en')) {
      context.handle(
        _actualizadoEnMeta,
        actualizadoEn.isAcceptableOrUnknown(
          data['actualizado_en']!,
          _actualizadoEnMeta,
        ),
      );
    }
    if (data.containsKey('eliminado_en')) {
      context.handle(
        _eliminadoEnMeta,
        eliminadoEn.isAcceptableOrUnknown(
          data['eliminado_en']!,
          _eliminadoEnMeta,
        ),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cliente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cliente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usuario_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      cedula: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cedula'],
      )!,
      telefono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telefono'],
      )!,
      direccion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direccion'],
      )!,
      referencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}referencia'],
      ),
      fotoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foto_url'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      actualizadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado_en'],
      )!,
      eliminadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eliminado_en'],
      ),
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $ClientesTable createAlias(String alias) {
    return $ClientesTable(attachedDatabase, alias);
  }
}

class Cliente extends DataClass implements Insertable<Cliente> {
  final int id;
  final int? servidorId;
  final int usuarioId;
  final String nombre;
  final String cedula;
  final String telefono;
  final String direccion;
  final String? referencia;
  final String? fotoUrl;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final DateTime? eliminadoEn;
  final bool sincronizado;
  const Cliente({
    required this.id,
    this.servidorId,
    required this.usuarioId,
    required this.nombre,
    required this.cedula,
    required this.telefono,
    required this.direccion,
    this.referencia,
    this.fotoUrl,
    required this.creadoEn,
    required this.actualizadoEn,
    this.eliminadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['usuario_id'] = Variable<int>(usuarioId);
    map['nombre'] = Variable<String>(nombre);
    map['cedula'] = Variable<String>(cedula);
    map['telefono'] = Variable<String>(telefono);
    map['direccion'] = Variable<String>(direccion);
    if (!nullToAbsent || referencia != null) {
      map['referencia'] = Variable<String>(referencia);
    }
    if (!nullToAbsent || fotoUrl != null) {
      map['foto_url'] = Variable<String>(fotoUrl);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['actualizado_en'] = Variable<DateTime>(actualizadoEn);
    if (!nullToAbsent || eliminadoEn != null) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  ClientesCompanion toCompanion(bool nullToAbsent) {
    return ClientesCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      usuarioId: Value(usuarioId),
      nombre: Value(nombre),
      cedula: Value(cedula),
      telefono: Value(telefono),
      direccion: Value(direccion),
      referencia: referencia == null && nullToAbsent
          ? const Value.absent()
          : Value(referencia),
      fotoUrl: fotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fotoUrl),
      creadoEn: Value(creadoEn),
      actualizadoEn: Value(actualizadoEn),
      eliminadoEn: eliminadoEn == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory Cliente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cliente(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      cedula: serializer.fromJson<String>(json['cedula']),
      telefono: serializer.fromJson<String>(json['telefono']),
      direccion: serializer.fromJson<String>(json['direccion']),
      referencia: serializer.fromJson<String?>(json['referencia']),
      fotoUrl: serializer.fromJson<String?>(json['fotoUrl']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      actualizadoEn: serializer.fromJson<DateTime>(json['actualizadoEn']),
      eliminadoEn: serializer.fromJson<DateTime?>(json['eliminadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'usuarioId': serializer.toJson<int>(usuarioId),
      'nombre': serializer.toJson<String>(nombre),
      'cedula': serializer.toJson<String>(cedula),
      'telefono': serializer.toJson<String>(telefono),
      'direccion': serializer.toJson<String>(direccion),
      'referencia': serializer.toJson<String?>(referencia),
      'fotoUrl': serializer.toJson<String?>(fotoUrl),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'actualizadoEn': serializer.toJson<DateTime>(actualizadoEn),
      'eliminadoEn': serializer.toJson<DateTime?>(eliminadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Cliente copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? usuarioId,
    String? nombre,
    String? cedula,
    String? telefono,
    String? direccion,
    Value<String?> referencia = const Value.absent(),
    Value<String?> fotoUrl = const Value.absent(),
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    Value<DateTime?> eliminadoEn = const Value.absent(),
    bool? sincronizado,
  }) => Cliente(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    usuarioId: usuarioId ?? this.usuarioId,
    nombre: nombre ?? this.nombre,
    cedula: cedula ?? this.cedula,
    telefono: telefono ?? this.telefono,
    direccion: direccion ?? this.direccion,
    referencia: referencia.present ? referencia.value : this.referencia,
    fotoUrl: fotoUrl.present ? fotoUrl.value : this.fotoUrl,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    eliminadoEn: eliminadoEn.present ? eliminadoEn.value : this.eliminadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Cliente copyWithCompanion(ClientesCompanion data) {
    return Cliente(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      cedula: data.cedula.present ? data.cedula.value : this.cedula,
      telefono: data.telefono.present ? data.telefono.value : this.telefono,
      direccion: data.direccion.present ? data.direccion.value : this.direccion,
      referencia: data.referencia.present
          ? data.referencia.value
          : this.referencia,
      fotoUrl: data.fotoUrl.present ? data.fotoUrl.value : this.fotoUrl,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      actualizadoEn: data.actualizadoEn.present
          ? data.actualizadoEn.value
          : this.actualizadoEn,
      eliminadoEn: data.eliminadoEn.present
          ? data.eliminadoEn.value
          : this.eliminadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cliente(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('nombre: $nombre, ')
          ..write('cedula: $cedula, ')
          ..write('telefono: $telefono, ')
          ..write('direccion: $direccion, ')
          ..write('referencia: $referencia, ')
          ..write('fotoUrl: $fotoUrl, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    usuarioId,
    nombre,
    cedula,
    telefono,
    direccion,
    referencia,
    fotoUrl,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cliente &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.usuarioId == this.usuarioId &&
          other.nombre == this.nombre &&
          other.cedula == this.cedula &&
          other.telefono == this.telefono &&
          other.direccion == this.direccion &&
          other.referencia == this.referencia &&
          other.fotoUrl == this.fotoUrl &&
          other.creadoEn == this.creadoEn &&
          other.actualizadoEn == this.actualizadoEn &&
          other.eliminadoEn == this.eliminadoEn &&
          other.sincronizado == this.sincronizado);
}

class ClientesCompanion extends UpdateCompanion<Cliente> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> usuarioId;
  final Value<String> nombre;
  final Value<String> cedula;
  final Value<String> telefono;
  final Value<String> direccion;
  final Value<String?> referencia;
  final Value<String?> fotoUrl;
  final Value<DateTime> creadoEn;
  final Value<DateTime> actualizadoEn;
  final Value<DateTime?> eliminadoEn;
  final Value<bool> sincronizado;
  const ClientesCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.cedula = const Value.absent(),
    this.telefono = const Value.absent(),
    this.direccion = const Value.absent(),
    this.referencia = const Value.absent(),
    this.fotoUrl = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  ClientesCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int usuarioId,
    required String nombre,
    required String cedula,
    required String telefono,
    required String direccion,
    this.referencia = const Value.absent(),
    this.fotoUrl = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : usuarioId = Value(usuarioId),
       nombre = Value(nombre),
       cedula = Value(cedula),
       telefono = Value(telefono),
       direccion = Value(direccion);
  static Insertable<Cliente> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? usuarioId,
    Expression<String>? nombre,
    Expression<String>? cedula,
    Expression<String>? telefono,
    Expression<String>? direccion,
    Expression<String>? referencia,
    Expression<String>? fotoUrl,
    Expression<DateTime>? creadoEn,
    Expression<DateTime>? actualizadoEn,
    Expression<DateTime>? eliminadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (nombre != null) 'nombre': nombre,
      if (cedula != null) 'cedula': cedula,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      if (referencia != null) 'referencia': referencia,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (actualizadoEn != null) 'actualizado_en': actualizadoEn,
      if (eliminadoEn != null) 'eliminado_en': eliminadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  ClientesCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? usuarioId,
    Value<String>? nombre,
    Value<String>? cedula,
    Value<String>? telefono,
    Value<String>? direccion,
    Value<String?>? referencia,
    Value<String?>? fotoUrl,
    Value<DateTime>? creadoEn,
    Value<DateTime>? actualizadoEn,
    Value<DateTime?>? eliminadoEn,
    Value<bool>? sincronizado,
  }) {
    return ClientesCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      cedula: cedula ?? this.cedula,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      referencia: referencia ?? this.referencia,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: eliminadoEn ?? this.eliminadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (cedula.present) {
      map['cedula'] = Variable<String>(cedula.value);
    }
    if (telefono.present) {
      map['telefono'] = Variable<String>(telefono.value);
    }
    if (direccion.present) {
      map['direccion'] = Variable<String>(direccion.value);
    }
    if (referencia.present) {
      map['referencia'] = Variable<String>(referencia.value);
    }
    if (fotoUrl.present) {
      map['foto_url'] = Variable<String>(fotoUrl.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (actualizadoEn.present) {
      map['actualizado_en'] = Variable<DateTime>(actualizadoEn.value);
    }
    if (eliminadoEn.present) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientesCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('nombre: $nombre, ')
          ..write('cedula: $cedula, ')
          ..write('telefono: $telefono, ')
          ..write('direccion: $direccion, ')
          ..write('referencia: $referencia, ')
          ..write('fotoUrl: $fotoUrl, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

class $PrestamosTable extends Prestamos
    with TableInfo<$PrestamosTable, Prestamo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrestamosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clientes (id)',
    ),
  );
  static const VerificationMeta _referenciaMeta = const VerificationMeta(
    'referencia',
  );
  @override
  late final GeneratedColumn<String> referencia = GeneratedColumn<String>(
    'referencia',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
    'usuario_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoCapitalMeta = const VerificationMeta(
    'montoCapital',
  );
  @override
  late final GeneratedColumn<double> montoCapital = GeneratedColumn<double>(
    'monto_capital',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _porcentajeInteresMeta = const VerificationMeta(
    'porcentajeInteres',
  );
  @override
  late final GeneratedColumn<double> porcentajeInteres =
      GeneratedColumn<double>(
        'porcentaje_interes',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _frecuenciaPagoMeta = const VerificationMeta(
    'frecuenciaPago',
  );
  @override
  late final GeneratedColumn<String> frecuenciaPago = GeneratedColumn<String>(
    'frecuencia_pago',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diasPersonalizadoMeta = const VerificationMeta(
    'diasPersonalizado',
  );
  @override
  late final GeneratedColumn<int> diasPersonalizado = GeneratedColumn<int>(
    'dias_personalizado',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plazoCuotasMeta = const VerificationMeta(
    'plazoCuotas',
  );
  @override
  late final GeneratedColumn<int> plazoCuotas = GeneratedColumn<int>(
    'plazo_cuotas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaInicioMeta = const VerificationMeta(
    'fechaInicio',
  );
  @override
  late final GeneratedColumn<DateTime> fechaInicio = GeneratedColumn<DateTime>(
    'fecha_inicio',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('activo'),
  );
  static const VerificationMeta _politicaMoraMeta = const VerificationMeta(
    'politicaMora',
  );
  @override
  late final GeneratedColumn<String> politicaMora = GeneratedColumn<String>(
    'politica_mora',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actualizadoEnMeta = const VerificationMeta(
    'actualizadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> actualizadoEn =
      GeneratedColumn<DateTime>(
        'actualizado_en',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _eliminadoEnMeta = const VerificationMeta(
    'eliminadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> eliminadoEn = GeneratedColumn<DateTime>(
    'eliminado_en',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    clienteId,
    referencia,
    usuarioId,
    montoCapital,
    porcentajeInteres,
    frecuenciaPago,
    diasPersonalizado,
    plazoCuotas,
    fechaInicio,
    estado,
    politicaMora,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prestamos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Prestamo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('referencia')) {
      context.handle(
        _referenciaMeta,
        referencia.isAcceptableOrUnknown(data['referencia']!, _referenciaMeta),
      );
    }
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('monto_capital')) {
      context.handle(
        _montoCapitalMeta,
        montoCapital.isAcceptableOrUnknown(
          data['monto_capital']!,
          _montoCapitalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoCapitalMeta);
    }
    if (data.containsKey('porcentaje_interes')) {
      context.handle(
        _porcentajeInteresMeta,
        porcentajeInteres.isAcceptableOrUnknown(
          data['porcentaje_interes']!,
          _porcentajeInteresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_porcentajeInteresMeta);
    }
    if (data.containsKey('frecuencia_pago')) {
      context.handle(
        _frecuenciaPagoMeta,
        frecuenciaPago.isAcceptableOrUnknown(
          data['frecuencia_pago']!,
          _frecuenciaPagoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frecuenciaPagoMeta);
    }
    if (data.containsKey('dias_personalizado')) {
      context.handle(
        _diasPersonalizadoMeta,
        diasPersonalizado.isAcceptableOrUnknown(
          data['dias_personalizado']!,
          _diasPersonalizadoMeta,
        ),
      );
    }
    if (data.containsKey('plazo_cuotas')) {
      context.handle(
        _plazoCuotasMeta,
        plazoCuotas.isAcceptableOrUnknown(
          data['plazo_cuotas']!,
          _plazoCuotasMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plazoCuotasMeta);
    }
    if (data.containsKey('fecha_inicio')) {
      context.handle(
        _fechaInicioMeta,
        fechaInicio.isAcceptableOrUnknown(
          data['fecha_inicio']!,
          _fechaInicioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaInicioMeta);
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    }
    if (data.containsKey('politica_mora')) {
      context.handle(
        _politicaMoraMeta,
        politicaMora.isAcceptableOrUnknown(
          data['politica_mora']!,
          _politicaMoraMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('actualizado_en')) {
      context.handle(
        _actualizadoEnMeta,
        actualizadoEn.isAcceptableOrUnknown(
          data['actualizado_en']!,
          _actualizadoEnMeta,
        ),
      );
    }
    if (data.containsKey('eliminado_en')) {
      context.handle(
        _eliminadoEnMeta,
        eliminadoEn.isAcceptableOrUnknown(
          data['eliminado_en']!,
          _eliminadoEnMeta,
        ),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Prestamo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Prestamo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      referencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}referencia'],
      ),
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usuario_id'],
      )!,
      montoCapital: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_capital'],
      )!,
      porcentajeInteres: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}porcentaje_interes'],
      )!,
      frecuenciaPago: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frecuencia_pago'],
      )!,
      diasPersonalizado: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_personalizado'],
      ),
      plazoCuotas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plazo_cuotas'],
      )!,
      fechaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_inicio'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      politicaMora: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}politica_mora'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      actualizadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado_en'],
      )!,
      eliminadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eliminado_en'],
      ),
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $PrestamosTable createAlias(String alias) {
    return $PrestamosTable(attachedDatabase, alias);
  }
}

class Prestamo extends DataClass implements Insertable<Prestamo> {
  final int id;
  final int? servidorId;
  final int clienteId;
  final String? referencia;
  final int usuarioId;
  final double montoCapital;
  final double porcentajeInteres;
  final String frecuenciaPago;
  final int? diasPersonalizado;
  final int plazoCuotas;
  final DateTime fechaInicio;
  final String estado;
  final String? politicaMora;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final DateTime? eliminadoEn;
  final bool sincronizado;
  const Prestamo({
    required this.id,
    this.servidorId,
    required this.clienteId,
    this.referencia,
    required this.usuarioId,
    required this.montoCapital,
    required this.porcentajeInteres,
    required this.frecuenciaPago,
    this.diasPersonalizado,
    required this.plazoCuotas,
    required this.fechaInicio,
    required this.estado,
    this.politicaMora,
    required this.creadoEn,
    required this.actualizadoEn,
    this.eliminadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['cliente_id'] = Variable<int>(clienteId);
    if (!nullToAbsent || referencia != null) {
      map['referencia'] = Variable<String>(referencia);
    }
    map['usuario_id'] = Variable<int>(usuarioId);
    map['monto_capital'] = Variable<double>(montoCapital);
    map['porcentaje_interes'] = Variable<double>(porcentajeInteres);
    map['frecuencia_pago'] = Variable<String>(frecuenciaPago);
    if (!nullToAbsent || diasPersonalizado != null) {
      map['dias_personalizado'] = Variable<int>(diasPersonalizado);
    }
    map['plazo_cuotas'] = Variable<int>(plazoCuotas);
    map['fecha_inicio'] = Variable<DateTime>(fechaInicio);
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || politicaMora != null) {
      map['politica_mora'] = Variable<String>(politicaMora);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['actualizado_en'] = Variable<DateTime>(actualizadoEn);
    if (!nullToAbsent || eliminadoEn != null) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  PrestamosCompanion toCompanion(bool nullToAbsent) {
    return PrestamosCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      clienteId: Value(clienteId),
      referencia: referencia == null && nullToAbsent
          ? const Value.absent()
          : Value(referencia),
      usuarioId: Value(usuarioId),
      montoCapital: Value(montoCapital),
      porcentajeInteres: Value(porcentajeInteres),
      frecuenciaPago: Value(frecuenciaPago),
      diasPersonalizado: diasPersonalizado == null && nullToAbsent
          ? const Value.absent()
          : Value(diasPersonalizado),
      plazoCuotas: Value(plazoCuotas),
      fechaInicio: Value(fechaInicio),
      estado: Value(estado),
      politicaMora: politicaMora == null && nullToAbsent
          ? const Value.absent()
          : Value(politicaMora),
      creadoEn: Value(creadoEn),
      actualizadoEn: Value(actualizadoEn),
      eliminadoEn: eliminadoEn == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory Prestamo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Prestamo(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      referencia: serializer.fromJson<String?>(json['referencia']),
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
      montoCapital: serializer.fromJson<double>(json['montoCapital']),
      porcentajeInteres: serializer.fromJson<double>(json['porcentajeInteres']),
      frecuenciaPago: serializer.fromJson<String>(json['frecuenciaPago']),
      diasPersonalizado: serializer.fromJson<int?>(json['diasPersonalizado']),
      plazoCuotas: serializer.fromJson<int>(json['plazoCuotas']),
      fechaInicio: serializer.fromJson<DateTime>(json['fechaInicio']),
      estado: serializer.fromJson<String>(json['estado']),
      politicaMora: serializer.fromJson<String?>(json['politicaMora']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      actualizadoEn: serializer.fromJson<DateTime>(json['actualizadoEn']),
      eliminadoEn: serializer.fromJson<DateTime?>(json['eliminadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'clienteId': serializer.toJson<int>(clienteId),
      'referencia': serializer.toJson<String?>(referencia),
      'usuarioId': serializer.toJson<int>(usuarioId),
      'montoCapital': serializer.toJson<double>(montoCapital),
      'porcentajeInteres': serializer.toJson<double>(porcentajeInteres),
      'frecuenciaPago': serializer.toJson<String>(frecuenciaPago),
      'diasPersonalizado': serializer.toJson<int?>(diasPersonalizado),
      'plazoCuotas': serializer.toJson<int>(plazoCuotas),
      'fechaInicio': serializer.toJson<DateTime>(fechaInicio),
      'estado': serializer.toJson<String>(estado),
      'politicaMora': serializer.toJson<String?>(politicaMora),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'actualizadoEn': serializer.toJson<DateTime>(actualizadoEn),
      'eliminadoEn': serializer.toJson<DateTime?>(eliminadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Prestamo copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? clienteId,
    Value<String?> referencia = const Value.absent(),
    int? usuarioId,
    double? montoCapital,
    double? porcentajeInteres,
    String? frecuenciaPago,
    Value<int?> diasPersonalizado = const Value.absent(),
    int? plazoCuotas,
    DateTime? fechaInicio,
    String? estado,
    Value<String?> politicaMora = const Value.absent(),
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    Value<DateTime?> eliminadoEn = const Value.absent(),
    bool? sincronizado,
  }) => Prestamo(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    clienteId: clienteId ?? this.clienteId,
    referencia: referencia.present ? referencia.value : this.referencia,
    usuarioId: usuarioId ?? this.usuarioId,
    montoCapital: montoCapital ?? this.montoCapital,
    porcentajeInteres: porcentajeInteres ?? this.porcentajeInteres,
    frecuenciaPago: frecuenciaPago ?? this.frecuenciaPago,
    diasPersonalizado: diasPersonalizado.present
        ? diasPersonalizado.value
        : this.diasPersonalizado,
    plazoCuotas: plazoCuotas ?? this.plazoCuotas,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    estado: estado ?? this.estado,
    politicaMora: politicaMora.present ? politicaMora.value : this.politicaMora,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    eliminadoEn: eliminadoEn.present ? eliminadoEn.value : this.eliminadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Prestamo copyWithCompanion(PrestamosCompanion data) {
    return Prestamo(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      referencia: data.referencia.present
          ? data.referencia.value
          : this.referencia,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      montoCapital: data.montoCapital.present
          ? data.montoCapital.value
          : this.montoCapital,
      porcentajeInteres: data.porcentajeInteres.present
          ? data.porcentajeInteres.value
          : this.porcentajeInteres,
      frecuenciaPago: data.frecuenciaPago.present
          ? data.frecuenciaPago.value
          : this.frecuenciaPago,
      diasPersonalizado: data.diasPersonalizado.present
          ? data.diasPersonalizado.value
          : this.diasPersonalizado,
      plazoCuotas: data.plazoCuotas.present
          ? data.plazoCuotas.value
          : this.plazoCuotas,
      fechaInicio: data.fechaInicio.present
          ? data.fechaInicio.value
          : this.fechaInicio,
      estado: data.estado.present ? data.estado.value : this.estado,
      politicaMora: data.politicaMora.present
          ? data.politicaMora.value
          : this.politicaMora,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      actualizadoEn: data.actualizadoEn.present
          ? data.actualizadoEn.value
          : this.actualizadoEn,
      eliminadoEn: data.eliminadoEn.present
          ? data.eliminadoEn.value
          : this.eliminadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Prestamo(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('clienteId: $clienteId, ')
          ..write('referencia: $referencia, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('montoCapital: $montoCapital, ')
          ..write('porcentajeInteres: $porcentajeInteres, ')
          ..write('frecuenciaPago: $frecuenciaPago, ')
          ..write('diasPersonalizado: $diasPersonalizado, ')
          ..write('plazoCuotas: $plazoCuotas, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('estado: $estado, ')
          ..write('politicaMora: $politicaMora, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    clienteId,
    referencia,
    usuarioId,
    montoCapital,
    porcentajeInteres,
    frecuenciaPago,
    diasPersonalizado,
    plazoCuotas,
    fechaInicio,
    estado,
    politicaMora,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Prestamo &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.clienteId == this.clienteId &&
          other.referencia == this.referencia &&
          other.usuarioId == this.usuarioId &&
          other.montoCapital == this.montoCapital &&
          other.porcentajeInteres == this.porcentajeInteres &&
          other.frecuenciaPago == this.frecuenciaPago &&
          other.diasPersonalizado == this.diasPersonalizado &&
          other.plazoCuotas == this.plazoCuotas &&
          other.fechaInicio == this.fechaInicio &&
          other.estado == this.estado &&
          other.politicaMora == this.politicaMora &&
          other.creadoEn == this.creadoEn &&
          other.actualizadoEn == this.actualizadoEn &&
          other.eliminadoEn == this.eliminadoEn &&
          other.sincronizado == this.sincronizado);
}

class PrestamosCompanion extends UpdateCompanion<Prestamo> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> clienteId;
  final Value<String?> referencia;
  final Value<int> usuarioId;
  final Value<double> montoCapital;
  final Value<double> porcentajeInteres;
  final Value<String> frecuenciaPago;
  final Value<int?> diasPersonalizado;
  final Value<int> plazoCuotas;
  final Value<DateTime> fechaInicio;
  final Value<String> estado;
  final Value<String?> politicaMora;
  final Value<DateTime> creadoEn;
  final Value<DateTime> actualizadoEn;
  final Value<DateTime?> eliminadoEn;
  final Value<bool> sincronizado;
  const PrestamosCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.referencia = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.montoCapital = const Value.absent(),
    this.porcentajeInteres = const Value.absent(),
    this.frecuenciaPago = const Value.absent(),
    this.diasPersonalizado = const Value.absent(),
    this.plazoCuotas = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.estado = const Value.absent(),
    this.politicaMora = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  PrestamosCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int clienteId,
    this.referencia = const Value.absent(),
    required int usuarioId,
    required double montoCapital,
    required double porcentajeInteres,
    required String frecuenciaPago,
    this.diasPersonalizado = const Value.absent(),
    required int plazoCuotas,
    required DateTime fechaInicio,
    this.estado = const Value.absent(),
    this.politicaMora = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : clienteId = Value(clienteId),
       usuarioId = Value(usuarioId),
       montoCapital = Value(montoCapital),
       porcentajeInteres = Value(porcentajeInteres),
       frecuenciaPago = Value(frecuenciaPago),
       plazoCuotas = Value(plazoCuotas),
       fechaInicio = Value(fechaInicio);
  static Insertable<Prestamo> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? clienteId,
    Expression<String>? referencia,
    Expression<int>? usuarioId,
    Expression<double>? montoCapital,
    Expression<double>? porcentajeInteres,
    Expression<String>? frecuenciaPago,
    Expression<int>? diasPersonalizado,
    Expression<int>? plazoCuotas,
    Expression<DateTime>? fechaInicio,
    Expression<String>? estado,
    Expression<String>? politicaMora,
    Expression<DateTime>? creadoEn,
    Expression<DateTime>? actualizadoEn,
    Expression<DateTime>? eliminadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (clienteId != null) 'cliente_id': clienteId,
      if (referencia != null) 'referencia': referencia,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (montoCapital != null) 'monto_capital': montoCapital,
      if (porcentajeInteres != null) 'porcentaje_interes': porcentajeInteres,
      if (frecuenciaPago != null) 'frecuencia_pago': frecuenciaPago,
      if (diasPersonalizado != null) 'dias_personalizado': diasPersonalizado,
      if (plazoCuotas != null) 'plazo_cuotas': plazoCuotas,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (estado != null) 'estado': estado,
      if (politicaMora != null) 'politica_mora': politicaMora,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (actualizadoEn != null) 'actualizado_en': actualizadoEn,
      if (eliminadoEn != null) 'eliminado_en': eliminadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  PrestamosCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? clienteId,
    Value<String?>? referencia,
    Value<int>? usuarioId,
    Value<double>? montoCapital,
    Value<double>? porcentajeInteres,
    Value<String>? frecuenciaPago,
    Value<int?>? diasPersonalizado,
    Value<int>? plazoCuotas,
    Value<DateTime>? fechaInicio,
    Value<String>? estado,
    Value<String?>? politicaMora,
    Value<DateTime>? creadoEn,
    Value<DateTime>? actualizadoEn,
    Value<DateTime?>? eliminadoEn,
    Value<bool>? sincronizado,
  }) {
    return PrestamosCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      clienteId: clienteId ?? this.clienteId,
      referencia: referencia ?? this.referencia,
      usuarioId: usuarioId ?? this.usuarioId,
      montoCapital: montoCapital ?? this.montoCapital,
      porcentajeInteres: porcentajeInteres ?? this.porcentajeInteres,
      frecuenciaPago: frecuenciaPago ?? this.frecuenciaPago,
      diasPersonalizado: diasPersonalizado ?? this.diasPersonalizado,
      plazoCuotas: plazoCuotas ?? this.plazoCuotas,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      estado: estado ?? this.estado,
      politicaMora: politicaMora ?? this.politicaMora,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: eliminadoEn ?? this.eliminadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (referencia.present) {
      map['referencia'] = Variable<String>(referencia.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (montoCapital.present) {
      map['monto_capital'] = Variable<double>(montoCapital.value);
    }
    if (porcentajeInteres.present) {
      map['porcentaje_interes'] = Variable<double>(porcentajeInteres.value);
    }
    if (frecuenciaPago.present) {
      map['frecuencia_pago'] = Variable<String>(frecuenciaPago.value);
    }
    if (diasPersonalizado.present) {
      map['dias_personalizado'] = Variable<int>(diasPersonalizado.value);
    }
    if (plazoCuotas.present) {
      map['plazo_cuotas'] = Variable<int>(plazoCuotas.value);
    }
    if (fechaInicio.present) {
      map['fecha_inicio'] = Variable<DateTime>(fechaInicio.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (politicaMora.present) {
      map['politica_mora'] = Variable<String>(politicaMora.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (actualizadoEn.present) {
      map['actualizado_en'] = Variable<DateTime>(actualizadoEn.value);
    }
    if (eliminadoEn.present) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrestamosCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('clienteId: $clienteId, ')
          ..write('referencia: $referencia, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('montoCapital: $montoCapital, ')
          ..write('porcentajeInteres: $porcentajeInteres, ')
          ..write('frecuenciaPago: $frecuenciaPago, ')
          ..write('diasPersonalizado: $diasPersonalizado, ')
          ..write('plazoCuotas: $plazoCuotas, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('estado: $estado, ')
          ..write('politicaMora: $politicaMora, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

class $PrestamosExtrasTable extends PrestamosExtras
    with TableInfo<$PrestamosExtrasTable, PrestamosExtra> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrestamosExtrasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _prestamoIdMeta = const VerificationMeta(
    'prestamoId',
  );
  @override
  late final GeneratedColumn<int> prestamoId = GeneratedColumn<int>(
    'prestamo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES prestamos (id)',
    ),
  );
  static const VerificationMeta _conceptoMeta = const VerificationMeta(
    'concepto',
  );
  @override
  late final GeneratedColumn<String> concepto = GeneratedColumn<String>(
    'concepto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<double> valor = GeneratedColumn<double>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actualizadoEnMeta = const VerificationMeta(
    'actualizadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> actualizadoEn =
      GeneratedColumn<DateTime>(
        'actualizado_en',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    prestamoId,
    concepto,
    valor,
    creadoEn,
    actualizadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prestamos_extras';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrestamosExtra> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('prestamo_id')) {
      context.handle(
        _prestamoIdMeta,
        prestamoId.isAcceptableOrUnknown(data['prestamo_id']!, _prestamoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_prestamoIdMeta);
    }
    if (data.containsKey('concepto')) {
      context.handle(
        _conceptoMeta,
        concepto.isAcceptableOrUnknown(data['concepto']!, _conceptoMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptoMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('actualizado_en')) {
      context.handle(
        _actualizadoEnMeta,
        actualizadoEn.isAcceptableOrUnknown(
          data['actualizado_en']!,
          _actualizadoEnMeta,
        ),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrestamosExtra map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrestamosExtra(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      prestamoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prestamo_id'],
      )!,
      concepto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concepto'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}valor'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      actualizadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $PrestamosExtrasTable createAlias(String alias) {
    return $PrestamosExtrasTable(attachedDatabase, alias);
  }
}

class PrestamosExtra extends DataClass implements Insertable<PrestamosExtra> {
  final int id;
  final int? servidorId;
  final int prestamoId;
  final String concepto;
  final double valor;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final bool sincronizado;
  const PrestamosExtra({
    required this.id,
    this.servidorId,
    required this.prestamoId,
    required this.concepto,
    required this.valor,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['prestamo_id'] = Variable<int>(prestamoId);
    map['concepto'] = Variable<String>(concepto);
    map['valor'] = Variable<double>(valor);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['actualizado_en'] = Variable<DateTime>(actualizadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  PrestamosExtrasCompanion toCompanion(bool nullToAbsent) {
    return PrestamosExtrasCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      prestamoId: Value(prestamoId),
      concepto: Value(concepto),
      valor: Value(valor),
      creadoEn: Value(creadoEn),
      actualizadoEn: Value(actualizadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory PrestamosExtra.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrestamosExtra(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      prestamoId: serializer.fromJson<int>(json['prestamoId']),
      concepto: serializer.fromJson<String>(json['concepto']),
      valor: serializer.fromJson<double>(json['valor']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      actualizadoEn: serializer.fromJson<DateTime>(json['actualizadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'prestamoId': serializer.toJson<int>(prestamoId),
      'concepto': serializer.toJson<String>(concepto),
      'valor': serializer.toJson<double>(valor),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'actualizadoEn': serializer.toJson<DateTime>(actualizadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  PrestamosExtra copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? prestamoId,
    String? concepto,
    double? valor,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    bool? sincronizado,
  }) => PrestamosExtra(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    prestamoId: prestamoId ?? this.prestamoId,
    concepto: concepto ?? this.concepto,
    valor: valor ?? this.valor,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  PrestamosExtra copyWithCompanion(PrestamosExtrasCompanion data) {
    return PrestamosExtra(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      prestamoId: data.prestamoId.present
          ? data.prestamoId.value
          : this.prestamoId,
      concepto: data.concepto.present ? data.concepto.value : this.concepto,
      valor: data.valor.present ? data.valor.value : this.valor,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      actualizadoEn: data.actualizadoEn.present
          ? data.actualizadoEn.value
          : this.actualizadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrestamosExtra(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('concepto: $concepto, ')
          ..write('valor: $valor, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    prestamoId,
    concepto,
    valor,
    creadoEn,
    actualizadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrestamosExtra &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.prestamoId == this.prestamoId &&
          other.concepto == this.concepto &&
          other.valor == this.valor &&
          other.creadoEn == this.creadoEn &&
          other.actualizadoEn == this.actualizadoEn &&
          other.sincronizado == this.sincronizado);
}

class PrestamosExtrasCompanion extends UpdateCompanion<PrestamosExtra> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> prestamoId;
  final Value<String> concepto;
  final Value<double> valor;
  final Value<DateTime> creadoEn;
  final Value<DateTime> actualizadoEn;
  final Value<bool> sincronizado;
  const PrestamosExtrasCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.prestamoId = const Value.absent(),
    this.concepto = const Value.absent(),
    this.valor = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  PrestamosExtrasCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int prestamoId,
    required String concepto,
    required double valor,
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : prestamoId = Value(prestamoId),
       concepto = Value(concepto),
       valor = Value(valor);
  static Insertable<PrestamosExtra> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? prestamoId,
    Expression<String>? concepto,
    Expression<double>? valor,
    Expression<DateTime>? creadoEn,
    Expression<DateTime>? actualizadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (prestamoId != null) 'prestamo_id': prestamoId,
      if (concepto != null) 'concepto': concepto,
      if (valor != null) 'valor': valor,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (actualizadoEn != null) 'actualizado_en': actualizadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  PrestamosExtrasCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? prestamoId,
    Value<String>? concepto,
    Value<double>? valor,
    Value<DateTime>? creadoEn,
    Value<DateTime>? actualizadoEn,
    Value<bool>? sincronizado,
  }) {
    return PrestamosExtrasCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      prestamoId: prestamoId ?? this.prestamoId,
      concepto: concepto ?? this.concepto,
      valor: valor ?? this.valor,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (prestamoId.present) {
      map['prestamo_id'] = Variable<int>(prestamoId.value);
    }
    if (concepto.present) {
      map['concepto'] = Variable<String>(concepto.value);
    }
    if (valor.present) {
      map['valor'] = Variable<double>(valor.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (actualizadoEn.present) {
      map['actualizado_en'] = Variable<DateTime>(actualizadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrestamosExtrasCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('concepto: $concepto, ')
          ..write('valor: $valor, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

class $CuotasTable extends Cuotas with TableInfo<$CuotasTable, Cuota> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuotasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _prestamoIdMeta = const VerificationMeta(
    'prestamoId',
  );
  @override
  late final GeneratedColumn<int> prestamoId = GeneratedColumn<int>(
    'prestamo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES prestamos (id)',
    ),
  );
  static const VerificationMeta _numeroCuotaMeta = const VerificationMeta(
    'numeroCuota',
  );
  @override
  late final GeneratedColumn<int> numeroCuota = GeneratedColumn<int>(
    'numero_cuota',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaEsperadaMeta = const VerificationMeta(
    'fechaEsperada',
  );
  @override
  late final GeneratedColumn<DateTime> fechaEsperada =
      GeneratedColumn<DateTime>(
        'fecha_esperada',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _montoEsperadoMeta = const VerificationMeta(
    'montoEsperado',
  );
  @override
  late final GeneratedColumn<double> montoEsperado = GeneratedColumn<double>(
    'monto_esperado',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pendiente'),
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actualizadoEnMeta = const VerificationMeta(
    'actualizadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> actualizadoEn =
      GeneratedColumn<DateTime>(
        'actualizado_en',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    prestamoId,
    numeroCuota,
    fechaEsperada,
    montoEsperado,
    estado,
    creadoEn,
    actualizadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cuotas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cuota> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('prestamo_id')) {
      context.handle(
        _prestamoIdMeta,
        prestamoId.isAcceptableOrUnknown(data['prestamo_id']!, _prestamoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_prestamoIdMeta);
    }
    if (data.containsKey('numero_cuota')) {
      context.handle(
        _numeroCuotaMeta,
        numeroCuota.isAcceptableOrUnknown(
          data['numero_cuota']!,
          _numeroCuotaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_numeroCuotaMeta);
    }
    if (data.containsKey('fecha_esperada')) {
      context.handle(
        _fechaEsperadaMeta,
        fechaEsperada.isAcceptableOrUnknown(
          data['fecha_esperada']!,
          _fechaEsperadaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaEsperadaMeta);
    }
    if (data.containsKey('monto_esperado')) {
      context.handle(
        _montoEsperadoMeta,
        montoEsperado.isAcceptableOrUnknown(
          data['monto_esperado']!,
          _montoEsperadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoEsperadoMeta);
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('actualizado_en')) {
      context.handle(
        _actualizadoEnMeta,
        actualizadoEn.isAcceptableOrUnknown(
          data['actualizado_en']!,
          _actualizadoEnMeta,
        ),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cuota map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cuota(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      prestamoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prestamo_id'],
      )!,
      numeroCuota: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero_cuota'],
      )!,
      fechaEsperada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_esperada'],
      )!,
      montoEsperado: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_esperado'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      actualizadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $CuotasTable createAlias(String alias) {
    return $CuotasTable(attachedDatabase, alias);
  }
}

class Cuota extends DataClass implements Insertable<Cuota> {
  final int id;
  final int? servidorId;
  final int prestamoId;
  final int numeroCuota;
  final DateTime fechaEsperada;
  final double montoEsperado;
  final String estado;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final bool sincronizado;
  const Cuota({
    required this.id,
    this.servidorId,
    required this.prestamoId,
    required this.numeroCuota,
    required this.fechaEsperada,
    required this.montoEsperado,
    required this.estado,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['prestamo_id'] = Variable<int>(prestamoId);
    map['numero_cuota'] = Variable<int>(numeroCuota);
    map['fecha_esperada'] = Variable<DateTime>(fechaEsperada);
    map['monto_esperado'] = Variable<double>(montoEsperado);
    map['estado'] = Variable<String>(estado);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['actualizado_en'] = Variable<DateTime>(actualizadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  CuotasCompanion toCompanion(bool nullToAbsent) {
    return CuotasCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      prestamoId: Value(prestamoId),
      numeroCuota: Value(numeroCuota),
      fechaEsperada: Value(fechaEsperada),
      montoEsperado: Value(montoEsperado),
      estado: Value(estado),
      creadoEn: Value(creadoEn),
      actualizadoEn: Value(actualizadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory Cuota.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cuota(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      prestamoId: serializer.fromJson<int>(json['prestamoId']),
      numeroCuota: serializer.fromJson<int>(json['numeroCuota']),
      fechaEsperada: serializer.fromJson<DateTime>(json['fechaEsperada']),
      montoEsperado: serializer.fromJson<double>(json['montoEsperado']),
      estado: serializer.fromJson<String>(json['estado']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      actualizadoEn: serializer.fromJson<DateTime>(json['actualizadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'prestamoId': serializer.toJson<int>(prestamoId),
      'numeroCuota': serializer.toJson<int>(numeroCuota),
      'fechaEsperada': serializer.toJson<DateTime>(fechaEsperada),
      'montoEsperado': serializer.toJson<double>(montoEsperado),
      'estado': serializer.toJson<String>(estado),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'actualizadoEn': serializer.toJson<DateTime>(actualizadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Cuota copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? prestamoId,
    int? numeroCuota,
    DateTime? fechaEsperada,
    double? montoEsperado,
    String? estado,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    bool? sincronizado,
  }) => Cuota(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    prestamoId: prestamoId ?? this.prestamoId,
    numeroCuota: numeroCuota ?? this.numeroCuota,
    fechaEsperada: fechaEsperada ?? this.fechaEsperada,
    montoEsperado: montoEsperado ?? this.montoEsperado,
    estado: estado ?? this.estado,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Cuota copyWithCompanion(CuotasCompanion data) {
    return Cuota(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      prestamoId: data.prestamoId.present
          ? data.prestamoId.value
          : this.prestamoId,
      numeroCuota: data.numeroCuota.present
          ? data.numeroCuota.value
          : this.numeroCuota,
      fechaEsperada: data.fechaEsperada.present
          ? data.fechaEsperada.value
          : this.fechaEsperada,
      montoEsperado: data.montoEsperado.present
          ? data.montoEsperado.value
          : this.montoEsperado,
      estado: data.estado.present ? data.estado.value : this.estado,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      actualizadoEn: data.actualizadoEn.present
          ? data.actualizadoEn.value
          : this.actualizadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cuota(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('numeroCuota: $numeroCuota, ')
          ..write('fechaEsperada: $fechaEsperada, ')
          ..write('montoEsperado: $montoEsperado, ')
          ..write('estado: $estado, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    prestamoId,
    numeroCuota,
    fechaEsperada,
    montoEsperado,
    estado,
    creadoEn,
    actualizadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cuota &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.prestamoId == this.prestamoId &&
          other.numeroCuota == this.numeroCuota &&
          other.fechaEsperada == this.fechaEsperada &&
          other.montoEsperado == this.montoEsperado &&
          other.estado == this.estado &&
          other.creadoEn == this.creadoEn &&
          other.actualizadoEn == this.actualizadoEn &&
          other.sincronizado == this.sincronizado);
}

class CuotasCompanion extends UpdateCompanion<Cuota> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> prestamoId;
  final Value<int> numeroCuota;
  final Value<DateTime> fechaEsperada;
  final Value<double> montoEsperado;
  final Value<String> estado;
  final Value<DateTime> creadoEn;
  final Value<DateTime> actualizadoEn;
  final Value<bool> sincronizado;
  const CuotasCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.prestamoId = const Value.absent(),
    this.numeroCuota = const Value.absent(),
    this.fechaEsperada = const Value.absent(),
    this.montoEsperado = const Value.absent(),
    this.estado = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  CuotasCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int prestamoId,
    required int numeroCuota,
    required DateTime fechaEsperada,
    required double montoEsperado,
    this.estado = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : prestamoId = Value(prestamoId),
       numeroCuota = Value(numeroCuota),
       fechaEsperada = Value(fechaEsperada),
       montoEsperado = Value(montoEsperado);
  static Insertable<Cuota> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? prestamoId,
    Expression<int>? numeroCuota,
    Expression<DateTime>? fechaEsperada,
    Expression<double>? montoEsperado,
    Expression<String>? estado,
    Expression<DateTime>? creadoEn,
    Expression<DateTime>? actualizadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (prestamoId != null) 'prestamo_id': prestamoId,
      if (numeroCuota != null) 'numero_cuota': numeroCuota,
      if (fechaEsperada != null) 'fecha_esperada': fechaEsperada,
      if (montoEsperado != null) 'monto_esperado': montoEsperado,
      if (estado != null) 'estado': estado,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (actualizadoEn != null) 'actualizado_en': actualizadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  CuotasCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? prestamoId,
    Value<int>? numeroCuota,
    Value<DateTime>? fechaEsperada,
    Value<double>? montoEsperado,
    Value<String>? estado,
    Value<DateTime>? creadoEn,
    Value<DateTime>? actualizadoEn,
    Value<bool>? sincronizado,
  }) {
    return CuotasCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      prestamoId: prestamoId ?? this.prestamoId,
      numeroCuota: numeroCuota ?? this.numeroCuota,
      fechaEsperada: fechaEsperada ?? this.fechaEsperada,
      montoEsperado: montoEsperado ?? this.montoEsperado,
      estado: estado ?? this.estado,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (prestamoId.present) {
      map['prestamo_id'] = Variable<int>(prestamoId.value);
    }
    if (numeroCuota.present) {
      map['numero_cuota'] = Variable<int>(numeroCuota.value);
    }
    if (fechaEsperada.present) {
      map['fecha_esperada'] = Variable<DateTime>(fechaEsperada.value);
    }
    if (montoEsperado.present) {
      map['monto_esperado'] = Variable<double>(montoEsperado.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (actualizadoEn.present) {
      map['actualizado_en'] = Variable<DateTime>(actualizadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuotasCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('numeroCuota: $numeroCuota, ')
          ..write('fechaEsperada: $fechaEsperada, ')
          ..write('montoEsperado: $montoEsperado, ')
          ..write('estado: $estado, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

class $PagosTable extends Pagos with TableInfo<$PagosTable, Pago> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _prestamoIdMeta = const VerificationMeta(
    'prestamoId',
  );
  @override
  late final GeneratedColumn<int> prestamoId = GeneratedColumn<int>(
    'prestamo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES prestamos (id)',
    ),
  );
  static const VerificationMeta _cuotaIdMeta = const VerificationMeta(
    'cuotaId',
  );
  @override
  late final GeneratedColumn<int> cuotaId = GeneratedColumn<int>(
    'cuota_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cuotas (id)',
    ),
  );
  static const VerificationMeta _montoAbonadoMeta = const VerificationMeta(
    'montoAbonado',
  );
  @override
  late final GeneratedColumn<double> montoAbonado = GeneratedColumn<double>(
    'monto_abonado',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoAplicadoMeta = const VerificationMeta(
    'montoAplicado',
  );
  @override
  late final GeneratedColumn<double> montoAplicado = GeneratedColumn<double>(
    'monto_aplicado',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaPagoMeta = const VerificationMeta(
    'fechaPago',
  );
  @override
  late final GeneratedColumn<DateTime> fechaPago = GeneratedColumn<DateTime>(
    'fecha_pago',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diasMoraMeta = const VerificationMeta(
    'diasMora',
  );
  @override
  late final GeneratedColumn<int> diasMora = GeneratedColumn<int>(
    'dias_mora',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _saldoRestanteDespuesMeta =
      const VerificationMeta('saldoRestanteDespues');
  @override
  late final GeneratedColumn<double> saldoRestanteDespues =
      GeneratedColumn<double>(
        'saldo_restante_despues',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actualizadoEnMeta = const VerificationMeta(
    'actualizadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> actualizadoEn =
      GeneratedColumn<DateTime>(
        'actualizado_en',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _eliminadoEnMeta = const VerificationMeta(
    'eliminadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> eliminadoEn = GeneratedColumn<DateTime>(
    'eliminado_en',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    prestamoId,
    cuotaId,
    montoAbonado,
    montoAplicado,
    fechaPago,
    diasMora,
    saldoRestanteDespues,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pagos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pago> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('prestamo_id')) {
      context.handle(
        _prestamoIdMeta,
        prestamoId.isAcceptableOrUnknown(data['prestamo_id']!, _prestamoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_prestamoIdMeta);
    }
    if (data.containsKey('cuota_id')) {
      context.handle(
        _cuotaIdMeta,
        cuotaId.isAcceptableOrUnknown(data['cuota_id']!, _cuotaIdMeta),
      );
    }
    if (data.containsKey('monto_abonado')) {
      context.handle(
        _montoAbonadoMeta,
        montoAbonado.isAcceptableOrUnknown(
          data['monto_abonado']!,
          _montoAbonadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoAbonadoMeta);
    }
    if (data.containsKey('monto_aplicado')) {
      context.handle(
        _montoAplicadoMeta,
        montoAplicado.isAcceptableOrUnknown(
          data['monto_aplicado']!,
          _montoAplicadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoAplicadoMeta);
    }
    if (data.containsKey('fecha_pago')) {
      context.handle(
        _fechaPagoMeta,
        fechaPago.isAcceptableOrUnknown(data['fecha_pago']!, _fechaPagoMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaPagoMeta);
    }
    if (data.containsKey('dias_mora')) {
      context.handle(
        _diasMoraMeta,
        diasMora.isAcceptableOrUnknown(data['dias_mora']!, _diasMoraMeta),
      );
    }
    if (data.containsKey('saldo_restante_despues')) {
      context.handle(
        _saldoRestanteDespuesMeta,
        saldoRestanteDespues.isAcceptableOrUnknown(
          data['saldo_restante_despues']!,
          _saldoRestanteDespuesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_saldoRestanteDespuesMeta);
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('actualizado_en')) {
      context.handle(
        _actualizadoEnMeta,
        actualizadoEn.isAcceptableOrUnknown(
          data['actualizado_en']!,
          _actualizadoEnMeta,
        ),
      );
    }
    if (data.containsKey('eliminado_en')) {
      context.handle(
        _eliminadoEnMeta,
        eliminadoEn.isAcceptableOrUnknown(
          data['eliminado_en']!,
          _eliminadoEnMeta,
        ),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pago map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pago(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      prestamoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prestamo_id'],
      )!,
      cuotaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuota_id'],
      ),
      montoAbonado: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_abonado'],
      )!,
      montoAplicado: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_aplicado'],
      )!,
      fechaPago: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_pago'],
      )!,
      diasMora: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_mora'],
      )!,
      saldoRestanteDespues: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}saldo_restante_despues'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      actualizadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado_en'],
      )!,
      eliminadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eliminado_en'],
      ),
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $PagosTable createAlias(String alias) {
    return $PagosTable(attachedDatabase, alias);
  }
}

class Pago extends DataClass implements Insertable<Pago> {
  final int id;
  final int? servidorId;
  final int prestamoId;
  final int? cuotaId;
  final double montoAbonado;
  final double montoAplicado;
  final DateTime fechaPago;
  final int diasMora;
  final double saldoRestanteDespues;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final DateTime? eliminadoEn;
  final bool sincronizado;
  const Pago({
    required this.id,
    this.servidorId,
    required this.prestamoId,
    this.cuotaId,
    required this.montoAbonado,
    required this.montoAplicado,
    required this.fechaPago,
    required this.diasMora,
    required this.saldoRestanteDespues,
    required this.creadoEn,
    required this.actualizadoEn,
    this.eliminadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['prestamo_id'] = Variable<int>(prestamoId);
    if (!nullToAbsent || cuotaId != null) {
      map['cuota_id'] = Variable<int>(cuotaId);
    }
    map['monto_abonado'] = Variable<double>(montoAbonado);
    map['monto_aplicado'] = Variable<double>(montoAplicado);
    map['fecha_pago'] = Variable<DateTime>(fechaPago);
    map['dias_mora'] = Variable<int>(diasMora);
    map['saldo_restante_despues'] = Variable<double>(saldoRestanteDespues);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['actualizado_en'] = Variable<DateTime>(actualizadoEn);
    if (!nullToAbsent || eliminadoEn != null) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  PagosCompanion toCompanion(bool nullToAbsent) {
    return PagosCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      prestamoId: Value(prestamoId),
      cuotaId: cuotaId == null && nullToAbsent
          ? const Value.absent()
          : Value(cuotaId),
      montoAbonado: Value(montoAbonado),
      montoAplicado: Value(montoAplicado),
      fechaPago: Value(fechaPago),
      diasMora: Value(diasMora),
      saldoRestanteDespues: Value(saldoRestanteDespues),
      creadoEn: Value(creadoEn),
      actualizadoEn: Value(actualizadoEn),
      eliminadoEn: eliminadoEn == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory Pago.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pago(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      prestamoId: serializer.fromJson<int>(json['prestamoId']),
      cuotaId: serializer.fromJson<int?>(json['cuotaId']),
      montoAbonado: serializer.fromJson<double>(json['montoAbonado']),
      montoAplicado: serializer.fromJson<double>(json['montoAplicado']),
      fechaPago: serializer.fromJson<DateTime>(json['fechaPago']),
      diasMora: serializer.fromJson<int>(json['diasMora']),
      saldoRestanteDespues: serializer.fromJson<double>(
        json['saldoRestanteDespues'],
      ),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      actualizadoEn: serializer.fromJson<DateTime>(json['actualizadoEn']),
      eliminadoEn: serializer.fromJson<DateTime?>(json['eliminadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'prestamoId': serializer.toJson<int>(prestamoId),
      'cuotaId': serializer.toJson<int?>(cuotaId),
      'montoAbonado': serializer.toJson<double>(montoAbonado),
      'montoAplicado': serializer.toJson<double>(montoAplicado),
      'fechaPago': serializer.toJson<DateTime>(fechaPago),
      'diasMora': serializer.toJson<int>(diasMora),
      'saldoRestanteDespues': serializer.toJson<double>(saldoRestanteDespues),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'actualizadoEn': serializer.toJson<DateTime>(actualizadoEn),
      'eliminadoEn': serializer.toJson<DateTime?>(eliminadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  Pago copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? prestamoId,
    Value<int?> cuotaId = const Value.absent(),
    double? montoAbonado,
    double? montoAplicado,
    DateTime? fechaPago,
    int? diasMora,
    double? saldoRestanteDespues,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
    Value<DateTime?> eliminadoEn = const Value.absent(),
    bool? sincronizado,
  }) => Pago(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    prestamoId: prestamoId ?? this.prestamoId,
    cuotaId: cuotaId.present ? cuotaId.value : this.cuotaId,
    montoAbonado: montoAbonado ?? this.montoAbonado,
    montoAplicado: montoAplicado ?? this.montoAplicado,
    fechaPago: fechaPago ?? this.fechaPago,
    diasMora: diasMora ?? this.diasMora,
    saldoRestanteDespues: saldoRestanteDespues ?? this.saldoRestanteDespues,
    creadoEn: creadoEn ?? this.creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    eliminadoEn: eliminadoEn.present ? eliminadoEn.value : this.eliminadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  Pago copyWithCompanion(PagosCompanion data) {
    return Pago(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      prestamoId: data.prestamoId.present
          ? data.prestamoId.value
          : this.prestamoId,
      cuotaId: data.cuotaId.present ? data.cuotaId.value : this.cuotaId,
      montoAbonado: data.montoAbonado.present
          ? data.montoAbonado.value
          : this.montoAbonado,
      montoAplicado: data.montoAplicado.present
          ? data.montoAplicado.value
          : this.montoAplicado,
      fechaPago: data.fechaPago.present ? data.fechaPago.value : this.fechaPago,
      diasMora: data.diasMora.present ? data.diasMora.value : this.diasMora,
      saldoRestanteDespues: data.saldoRestanteDespues.present
          ? data.saldoRestanteDespues.value
          : this.saldoRestanteDespues,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      actualizadoEn: data.actualizadoEn.present
          ? data.actualizadoEn.value
          : this.actualizadoEn,
      eliminadoEn: data.eliminadoEn.present
          ? data.eliminadoEn.value
          : this.eliminadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pago(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('cuotaId: $cuotaId, ')
          ..write('montoAbonado: $montoAbonado, ')
          ..write('montoAplicado: $montoAplicado, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('diasMora: $diasMora, ')
          ..write('saldoRestanteDespues: $saldoRestanteDespues, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    prestamoId,
    cuotaId,
    montoAbonado,
    montoAplicado,
    fechaPago,
    diasMora,
    saldoRestanteDespues,
    creadoEn,
    actualizadoEn,
    eliminadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pago &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.prestamoId == this.prestamoId &&
          other.cuotaId == this.cuotaId &&
          other.montoAbonado == this.montoAbonado &&
          other.montoAplicado == this.montoAplicado &&
          other.fechaPago == this.fechaPago &&
          other.diasMora == this.diasMora &&
          other.saldoRestanteDespues == this.saldoRestanteDespues &&
          other.creadoEn == this.creadoEn &&
          other.actualizadoEn == this.actualizadoEn &&
          other.eliminadoEn == this.eliminadoEn &&
          other.sincronizado == this.sincronizado);
}

class PagosCompanion extends UpdateCompanion<Pago> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> prestamoId;
  final Value<int?> cuotaId;
  final Value<double> montoAbonado;
  final Value<double> montoAplicado;
  final Value<DateTime> fechaPago;
  final Value<int> diasMora;
  final Value<double> saldoRestanteDespues;
  final Value<DateTime> creadoEn;
  final Value<DateTime> actualizadoEn;
  final Value<DateTime?> eliminadoEn;
  final Value<bool> sincronizado;
  const PagosCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.prestamoId = const Value.absent(),
    this.cuotaId = const Value.absent(),
    this.montoAbonado = const Value.absent(),
    this.montoAplicado = const Value.absent(),
    this.fechaPago = const Value.absent(),
    this.diasMora = const Value.absent(),
    this.saldoRestanteDespues = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  PagosCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int prestamoId,
    this.cuotaId = const Value.absent(),
    required double montoAbonado,
    required double montoAplicado,
    required DateTime fechaPago,
    this.diasMora = const Value.absent(),
    required double saldoRestanteDespues,
    this.creadoEn = const Value.absent(),
    this.actualizadoEn = const Value.absent(),
    this.eliminadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : prestamoId = Value(prestamoId),
       montoAbonado = Value(montoAbonado),
       montoAplicado = Value(montoAplicado),
       fechaPago = Value(fechaPago),
       saldoRestanteDespues = Value(saldoRestanteDespues);
  static Insertable<Pago> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? prestamoId,
    Expression<int>? cuotaId,
    Expression<double>? montoAbonado,
    Expression<double>? montoAplicado,
    Expression<DateTime>? fechaPago,
    Expression<int>? diasMora,
    Expression<double>? saldoRestanteDespues,
    Expression<DateTime>? creadoEn,
    Expression<DateTime>? actualizadoEn,
    Expression<DateTime>? eliminadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (prestamoId != null) 'prestamo_id': prestamoId,
      if (cuotaId != null) 'cuota_id': cuotaId,
      if (montoAbonado != null) 'monto_abonado': montoAbonado,
      if (montoAplicado != null) 'monto_aplicado': montoAplicado,
      if (fechaPago != null) 'fecha_pago': fechaPago,
      if (diasMora != null) 'dias_mora': diasMora,
      if (saldoRestanteDespues != null)
        'saldo_restante_despues': saldoRestanteDespues,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (actualizadoEn != null) 'actualizado_en': actualizadoEn,
      if (eliminadoEn != null) 'eliminado_en': eliminadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  PagosCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? prestamoId,
    Value<int?>? cuotaId,
    Value<double>? montoAbonado,
    Value<double>? montoAplicado,
    Value<DateTime>? fechaPago,
    Value<int>? diasMora,
    Value<double>? saldoRestanteDespues,
    Value<DateTime>? creadoEn,
    Value<DateTime>? actualizadoEn,
    Value<DateTime?>? eliminadoEn,
    Value<bool>? sincronizado,
  }) {
    return PagosCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      prestamoId: prestamoId ?? this.prestamoId,
      cuotaId: cuotaId ?? this.cuotaId,
      montoAbonado: montoAbonado ?? this.montoAbonado,
      montoAplicado: montoAplicado ?? this.montoAplicado,
      fechaPago: fechaPago ?? this.fechaPago,
      diasMora: diasMora ?? this.diasMora,
      saldoRestanteDespues: saldoRestanteDespues ?? this.saldoRestanteDespues,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: eliminadoEn ?? this.eliminadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (prestamoId.present) {
      map['prestamo_id'] = Variable<int>(prestamoId.value);
    }
    if (cuotaId.present) {
      map['cuota_id'] = Variable<int>(cuotaId.value);
    }
    if (montoAbonado.present) {
      map['monto_abonado'] = Variable<double>(montoAbonado.value);
    }
    if (montoAplicado.present) {
      map['monto_aplicado'] = Variable<double>(montoAplicado.value);
    }
    if (fechaPago.present) {
      map['fecha_pago'] = Variable<DateTime>(fechaPago.value);
    }
    if (diasMora.present) {
      map['dias_mora'] = Variable<int>(diasMora.value);
    }
    if (saldoRestanteDespues.present) {
      map['saldo_restante_despues'] = Variable<double>(
        saldoRestanteDespues.value,
      );
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (actualizadoEn.present) {
      map['actualizado_en'] = Variable<DateTime>(actualizadoEn.value);
    }
    if (eliminadoEn.present) {
      map['eliminado_en'] = Variable<DateTime>(eliminadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagosCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('prestamoId: $prestamoId, ')
          ..write('cuotaId: $cuotaId, ')
          ..write('montoAbonado: $montoAbonado, ')
          ..write('montoAplicado: $montoAplicado, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('diasMora: $diasMora, ')
          ..write('saldoRestanteDespues: $saldoRestanteDespues, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('actualizadoEn: $actualizadoEn, ')
          ..write('eliminadoEn: $eliminadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

class $CambiosPendientesTable extends CambiosPendientes
    with TableInfo<$CambiosPendientesTable, CambiosPendiente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CambiosPendientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
    'usuario_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tablaMeta = const VerificationMeta('tabla');
  @override
  late final GeneratedColumn<String> tabla = GeneratedColumn<String>(
    'tabla',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registroIdMeta = const VerificationMeta(
    'registroId',
  );
  @override
  late final GeneratedColumn<int> registroId = GeneratedColumn<int>(
    'registro_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoOperacionMeta = const VerificationMeta(
    'tipoOperacion',
  );
  @override
  late final GeneratedColumn<String> tipoOperacion = GeneratedColumn<String>(
    'tipo_operacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _intentosMeta = const VerificationMeta(
    'intentos',
  );
  @override
  late final GeneratedColumn<int> intentos = GeneratedColumn<int>(
    'intentos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ultimoErrorMeta = const VerificationMeta(
    'ultimoError',
  );
  @override
  late final GeneratedColumn<String> ultimoError = GeneratedColumn<String>(
    'ultimo_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    usuarioId,
    tabla,
    registroId,
    tipoOperacion,
    payload,
    creadoEn,
    intentos,
    ultimoError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cambios_pendientes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CambiosPendiente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    }
    if (data.containsKey('tabla')) {
      context.handle(
        _tablaMeta,
        tabla.isAcceptableOrUnknown(data['tabla']!, _tablaMeta),
      );
    } else if (isInserting) {
      context.missing(_tablaMeta);
    }
    if (data.containsKey('registro_id')) {
      context.handle(
        _registroIdMeta,
        registroId.isAcceptableOrUnknown(data['registro_id']!, _registroIdMeta),
      );
    } else if (isInserting) {
      context.missing(_registroIdMeta);
    }
    if (data.containsKey('tipo_operacion')) {
      context.handle(
        _tipoOperacionMeta,
        tipoOperacion.isAcceptableOrUnknown(
          data['tipo_operacion']!,
          _tipoOperacionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tipoOperacionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('intentos')) {
      context.handle(
        _intentosMeta,
        intentos.isAcceptableOrUnknown(data['intentos']!, _intentosMeta),
      );
    }
    if (data.containsKey('ultimo_error')) {
      context.handle(
        _ultimoErrorMeta,
        ultimoError.isAcceptableOrUnknown(
          data['ultimo_error']!,
          _ultimoErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CambiosPendiente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CambiosPendiente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usuario_id'],
      ),
      tabla: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabla'],
      )!,
      registroId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}registro_id'],
      )!,
      tipoOperacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_operacion'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      intentos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intentos'],
      )!,
      ultimoError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ultimo_error'],
      ),
    );
  }

  @override
  $CambiosPendientesTable createAlias(String alias) {
    return $CambiosPendientesTable(attachedDatabase, alias);
  }
}

class CambiosPendiente extends DataClass
    implements Insertable<CambiosPendiente> {
  final int id;

  /// Dueño del cambio (el cobrador que lo generó). Nullable solo porque las
  /// filas creadas antes de esta columna no lo tienen; toda fila nueva
  /// siempre lo trae. Sin esto, dos cobradores que comparten dispositivo
  /// verían la cola de sincronización del otro.
  final int? usuarioId;

  /// Nombre de la tabla afectada: clientes|prestamos|prestamos_extras|cuotas|pagos|cargas_capital.
  final String tabla;

  /// Id local (de la tabla indicada en `tabla`) del registro afectado.
  final int registroId;

  /// crear|actualizar|eliminar.
  final String tipoOperacion;

  /// Copia en JSON de los datos a enviar al servidor en el momento del cambio.
  final String? payload;
  final DateTime creadoEn;
  final int intentos;
  final String? ultimoError;
  const CambiosPendiente({
    required this.id,
    this.usuarioId,
    required this.tabla,
    required this.registroId,
    required this.tipoOperacion,
    this.payload,
    required this.creadoEn,
    required this.intentos,
    this.ultimoError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || usuarioId != null) {
      map['usuario_id'] = Variable<int>(usuarioId);
    }
    map['tabla'] = Variable<String>(tabla);
    map['registro_id'] = Variable<int>(registroId);
    map['tipo_operacion'] = Variable<String>(tipoOperacion);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['intentos'] = Variable<int>(intentos);
    if (!nullToAbsent || ultimoError != null) {
      map['ultimo_error'] = Variable<String>(ultimoError);
    }
    return map;
  }

  CambiosPendientesCompanion toCompanion(bool nullToAbsent) {
    return CambiosPendientesCompanion(
      id: Value(id),
      usuarioId: usuarioId == null && nullToAbsent
          ? const Value.absent()
          : Value(usuarioId),
      tabla: Value(tabla),
      registroId: Value(registroId),
      tipoOperacion: Value(tipoOperacion),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      creadoEn: Value(creadoEn),
      intentos: Value(intentos),
      ultimoError: ultimoError == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoError),
    );
  }

  factory CambiosPendiente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CambiosPendiente(
      id: serializer.fromJson<int>(json['id']),
      usuarioId: serializer.fromJson<int?>(json['usuarioId']),
      tabla: serializer.fromJson<String>(json['tabla']),
      registroId: serializer.fromJson<int>(json['registroId']),
      tipoOperacion: serializer.fromJson<String>(json['tipoOperacion']),
      payload: serializer.fromJson<String?>(json['payload']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      intentos: serializer.fromJson<int>(json['intentos']),
      ultimoError: serializer.fromJson<String?>(json['ultimoError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'usuarioId': serializer.toJson<int?>(usuarioId),
      'tabla': serializer.toJson<String>(tabla),
      'registroId': serializer.toJson<int>(registroId),
      'tipoOperacion': serializer.toJson<String>(tipoOperacion),
      'payload': serializer.toJson<String?>(payload),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'intentos': serializer.toJson<int>(intentos),
      'ultimoError': serializer.toJson<String?>(ultimoError),
    };
  }

  CambiosPendiente copyWith({
    int? id,
    Value<int?> usuarioId = const Value.absent(),
    String? tabla,
    int? registroId,
    String? tipoOperacion,
    Value<String?> payload = const Value.absent(),
    DateTime? creadoEn,
    int? intentos,
    Value<String?> ultimoError = const Value.absent(),
  }) => CambiosPendiente(
    id: id ?? this.id,
    usuarioId: usuarioId.present ? usuarioId.value : this.usuarioId,
    tabla: tabla ?? this.tabla,
    registroId: registroId ?? this.registroId,
    tipoOperacion: tipoOperacion ?? this.tipoOperacion,
    payload: payload.present ? payload.value : this.payload,
    creadoEn: creadoEn ?? this.creadoEn,
    intentos: intentos ?? this.intentos,
    ultimoError: ultimoError.present ? ultimoError.value : this.ultimoError,
  );
  CambiosPendiente copyWithCompanion(CambiosPendientesCompanion data) {
    return CambiosPendiente(
      id: data.id.present ? data.id.value : this.id,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      tabla: data.tabla.present ? data.tabla.value : this.tabla,
      registroId: data.registroId.present
          ? data.registroId.value
          : this.registroId,
      tipoOperacion: data.tipoOperacion.present
          ? data.tipoOperacion.value
          : this.tipoOperacion,
      payload: data.payload.present ? data.payload.value : this.payload,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      intentos: data.intentos.present ? data.intentos.value : this.intentos,
      ultimoError: data.ultimoError.present
          ? data.ultimoError.value
          : this.ultimoError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CambiosPendiente(')
          ..write('id: $id, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tabla: $tabla, ')
          ..write('registroId: $registroId, ')
          ..write('tipoOperacion: $tipoOperacion, ')
          ..write('payload: $payload, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('intentos: $intentos, ')
          ..write('ultimoError: $ultimoError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    usuarioId,
    tabla,
    registroId,
    tipoOperacion,
    payload,
    creadoEn,
    intentos,
    ultimoError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CambiosPendiente &&
          other.id == this.id &&
          other.usuarioId == this.usuarioId &&
          other.tabla == this.tabla &&
          other.registroId == this.registroId &&
          other.tipoOperacion == this.tipoOperacion &&
          other.payload == this.payload &&
          other.creadoEn == this.creadoEn &&
          other.intentos == this.intentos &&
          other.ultimoError == this.ultimoError);
}

class CambiosPendientesCompanion extends UpdateCompanion<CambiosPendiente> {
  final Value<int> id;
  final Value<int?> usuarioId;
  final Value<String> tabla;
  final Value<int> registroId;
  final Value<String> tipoOperacion;
  final Value<String?> payload;
  final Value<DateTime> creadoEn;
  final Value<int> intentos;
  final Value<String?> ultimoError;
  const CambiosPendientesCompanion({
    this.id = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.tabla = const Value.absent(),
    this.registroId = const Value.absent(),
    this.tipoOperacion = const Value.absent(),
    this.payload = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.intentos = const Value.absent(),
    this.ultimoError = const Value.absent(),
  });
  CambiosPendientesCompanion.insert({
    this.id = const Value.absent(),
    this.usuarioId = const Value.absent(),
    required String tabla,
    required int registroId,
    required String tipoOperacion,
    this.payload = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.intentos = const Value.absent(),
    this.ultimoError = const Value.absent(),
  }) : tabla = Value(tabla),
       registroId = Value(registroId),
       tipoOperacion = Value(tipoOperacion);
  static Insertable<CambiosPendiente> custom({
    Expression<int>? id,
    Expression<int>? usuarioId,
    Expression<String>? tabla,
    Expression<int>? registroId,
    Expression<String>? tipoOperacion,
    Expression<String>? payload,
    Expression<DateTime>? creadoEn,
    Expression<int>? intentos,
    Expression<String>? ultimoError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (tabla != null) 'tabla': tabla,
      if (registroId != null) 'registro_id': registroId,
      if (tipoOperacion != null) 'tipo_operacion': tipoOperacion,
      if (payload != null) 'payload': payload,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (intentos != null) 'intentos': intentos,
      if (ultimoError != null) 'ultimo_error': ultimoError,
    });
  }

  CambiosPendientesCompanion copyWith({
    Value<int>? id,
    Value<int?>? usuarioId,
    Value<String>? tabla,
    Value<int>? registroId,
    Value<String>? tipoOperacion,
    Value<String?>? payload,
    Value<DateTime>? creadoEn,
    Value<int>? intentos,
    Value<String?>? ultimoError,
  }) {
    return CambiosPendientesCompanion(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      tabla: tabla ?? this.tabla,
      registroId: registroId ?? this.registroId,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      payload: payload ?? this.payload,
      creadoEn: creadoEn ?? this.creadoEn,
      intentos: intentos ?? this.intentos,
      ultimoError: ultimoError ?? this.ultimoError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (tabla.present) {
      map['tabla'] = Variable<String>(tabla.value);
    }
    if (registroId.present) {
      map['registro_id'] = Variable<int>(registroId.value);
    }
    if (tipoOperacion.present) {
      map['tipo_operacion'] = Variable<String>(tipoOperacion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (intentos.present) {
      map['intentos'] = Variable<int>(intentos.value);
    }
    if (ultimoError.present) {
      map['ultimo_error'] = Variable<String>(ultimoError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CambiosPendientesCompanion(')
          ..write('id: $id, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tabla: $tabla, ')
          ..write('registroId: $registroId, ')
          ..write('tipoOperacion: $tipoOperacion, ')
          ..write('payload: $payload, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('intentos: $intentos, ')
          ..write('ultimoError: $ultimoError')
          ..write(')'))
        .toString();
  }
}

class $CargasCapitalTable extends CargasCapital
    with TableInfo<$CargasCapitalTable, CargaCapital> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CargasCapitalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _servidorIdMeta = const VerificationMeta(
    'servidorId',
  );
  @override
  late final GeneratedColumn<int> servidorId = GeneratedColumn<int>(
    'servidor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
    'usuario_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    servidorId,
    usuarioId,
    monto,
    descripcion,
    creadoEn,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cargas_capital';
  @override
  VerificationContext validateIntegrity(
    Insertable<CargaCapital> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('servidor_id')) {
      context.handle(
        _servidorIdMeta,
        servidorId.isAcceptableOrUnknown(data['servidor_id']!, _servidorIdMeta),
      );
    }
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CargaCapital map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CargaCapital(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      servidorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servidor_id'],
      ),
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usuario_id'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $CargasCapitalTable createAlias(String alias) {
    return $CargasCapitalTable(attachedDatabase, alias);
  }
}

class CargaCapital extends DataClass implements Insertable<CargaCapital> {
  final int id;
  final int? servidorId;
  final int usuarioId;
  final double monto;
  final String? descripcion;
  final DateTime creadoEn;
  final bool sincronizado;
  const CargaCapital({
    required this.id,
    this.servidorId,
    required this.usuarioId,
    required this.monto,
    this.descripcion,
    required this.creadoEn,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || servidorId != null) {
      map['servidor_id'] = Variable<int>(servidorId);
    }
    map['usuario_id'] = Variable<int>(usuarioId);
    map['monto'] = Variable<double>(monto);
    if (!nullToAbsent || descripcion != null) {
      map['descripcion'] = Variable<String>(descripcion);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  CargasCapitalCompanion toCompanion(bool nullToAbsent) {
    return CargasCapitalCompanion(
      id: Value(id),
      servidorId: servidorId == null && nullToAbsent
          ? const Value.absent()
          : Value(servidorId),
      usuarioId: Value(usuarioId),
      monto: Value(monto),
      descripcion: descripcion == null && nullToAbsent
          ? const Value.absent()
          : Value(descripcion),
      creadoEn: Value(creadoEn),
      sincronizado: Value(sincronizado),
    );
  }

  factory CargaCapital.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CargaCapital(
      id: serializer.fromJson<int>(json['id']),
      servidorId: serializer.fromJson<int?>(json['servidorId']),
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
      monto: serializer.fromJson<double>(json['monto']),
      descripcion: serializer.fromJson<String?>(json['descripcion']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'servidorId': serializer.toJson<int?>(servidorId),
      'usuarioId': serializer.toJson<int>(usuarioId),
      'monto': serializer.toJson<double>(monto),
      'descripcion': serializer.toJson<String?>(descripcion),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  CargaCapital copyWith({
    int? id,
    Value<int?> servidorId = const Value.absent(),
    int? usuarioId,
    double? monto,
    Value<String?> descripcion = const Value.absent(),
    DateTime? creadoEn,
    bool? sincronizado,
  }) => CargaCapital(
    id: id ?? this.id,
    servidorId: servidorId.present ? servidorId.value : this.servidorId,
    usuarioId: usuarioId ?? this.usuarioId,
    monto: monto ?? this.monto,
    descripcion: descripcion.present ? descripcion.value : this.descripcion,
    creadoEn: creadoEn ?? this.creadoEn,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  CargaCapital copyWithCompanion(CargasCapitalCompanion data) {
    return CargaCapital(
      id: data.id.present ? data.id.value : this.id,
      servidorId: data.servidorId.present
          ? data.servidorId.value
          : this.servidorId,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      monto: data.monto.present ? data.monto.value : this.monto,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CargaCapital(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    servidorId,
    usuarioId,
    monto,
    descripcion,
    creadoEn,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CargaCapital &&
          other.id == this.id &&
          other.servidorId == this.servidorId &&
          other.usuarioId == this.usuarioId &&
          other.monto == this.monto &&
          other.descripcion == this.descripcion &&
          other.creadoEn == this.creadoEn &&
          other.sincronizado == this.sincronizado);
}

class CargasCapitalCompanion extends UpdateCompanion<CargaCapital> {
  final Value<int> id;
  final Value<int?> servidorId;
  final Value<int> usuarioId;
  final Value<double> monto;
  final Value<String?> descripcion;
  final Value<DateTime> creadoEn;
  final Value<bool> sincronizado;
  const CargasCapitalCompanion({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.monto = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  });
  CargasCapitalCompanion.insert({
    this.id = const Value.absent(),
    this.servidorId = const Value.absent(),
    required int usuarioId,
    required double monto,
    this.descripcion = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.sincronizado = const Value.absent(),
  }) : usuarioId = Value(usuarioId),
       monto = Value(monto);
  static Insertable<CargaCapital> custom({
    Expression<int>? id,
    Expression<int>? servidorId,
    Expression<int>? usuarioId,
    Expression<double>? monto,
    Expression<String>? descripcion,
    Expression<DateTime>? creadoEn,
    Expression<bool>? sincronizado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (servidorId != null) 'servidor_id': servidorId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (monto != null) 'monto': monto,
      if (descripcion != null) 'descripcion': descripcion,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (sincronizado != null) 'sincronizado': sincronizado,
    });
  }

  CargasCapitalCompanion copyWith({
    Value<int>? id,
    Value<int?>? servidorId,
    Value<int>? usuarioId,
    Value<double>? monto,
    Value<String?>? descripcion,
    Value<DateTime>? creadoEn,
    Value<bool>? sincronizado,
  }) {
    return CargasCapitalCompanion(
      id: id ?? this.id,
      servidorId: servidorId ?? this.servidorId,
      usuarioId: usuarioId ?? this.usuarioId,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      creadoEn: creadoEn ?? this.creadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (servidorId.present) {
      map['servidor_id'] = Variable<int>(servidorId.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CargasCapitalCompanion(')
          ..write('id: $id, ')
          ..write('servidorId: $servidorId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ClientesTable clientes = $ClientesTable(this);
  late final $PrestamosTable prestamos = $PrestamosTable(this);
  late final $PrestamosExtrasTable prestamosExtras = $PrestamosExtrasTable(
    this,
  );
  late final $CuotasTable cuotas = $CuotasTable(this);
  late final $PagosTable pagos = $PagosTable(this);
  late final $CambiosPendientesTable cambiosPendientes =
      $CambiosPendientesTable(this);
  late final $CargasCapitalTable cargasCapital = $CargasCapitalTable(this);
  late final ClientesDao clientesDao = ClientesDao(this as AppDatabase);
  late final PrestamosDao prestamosDao = PrestamosDao(this as AppDatabase);
  late final PrestamosExtrasDao prestamosExtrasDao = PrestamosExtrasDao(
    this as AppDatabase,
  );
  late final CuotasDao cuotasDao = CuotasDao(this as AppDatabase);
  late final PagosDao pagosDao = PagosDao(this as AppDatabase);
  late final CambiosPendientesDao cambiosPendientesDao = CambiosPendientesDao(
    this as AppDatabase,
  );
  late final CargasCapitalDao cargasCapitalDao = CargasCapitalDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    clientes,
    prestamos,
    prestamosExtras,
    cuotas,
    pagos,
    cambiosPendientes,
    cargasCapital,
  ];
}

typedef $$ClientesTableCreateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int usuarioId,
      required String nombre,
      required String cedula,
      required String telefono,
      required String direccion,
      Value<String?> referencia,
      Value<String?> fotoUrl,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });
typedef $$ClientesTableUpdateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> usuarioId,
      Value<String> nombre,
      Value<String> cedula,
      Value<String> telefono,
      Value<String> direccion,
      Value<String?> referencia,
      Value<String?> fotoUrl,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });

final class $$ClientesTableReferences
    extends BaseReferences<_$AppDatabase, $ClientesTable, Cliente> {
  $$ClientesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PrestamosTable, List<Prestamo>>
  _prestamosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.prestamos,
    aliasName: 'clientes__id__prestamos__cliente_id',
  );

  $$PrestamosTableProcessedTableManager get prestamosRefs {
    final manager = $$PrestamosTableTableManager(
      $_db,
      $_db.prestamos,
    ).filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_prestamosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClientesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cedula => $composableBuilder(
    column: $table.cedula,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fotoUrl => $composableBuilder(
    column: $table.fotoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> prestamosRefs(
    Expression<bool> Function($$PrestamosTableFilterComposer f) f,
  ) {
    final $$PrestamosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableFilterComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cedula => $composableBuilder(
    column: $table.cedula,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fotoUrl => $composableBuilder(
    column: $table.fotoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get cedula =>
      $composableBuilder(column: $table.cedula, builder: (column) => column);

  GeneratedColumn<String> get telefono =>
      $composableBuilder(column: $table.telefono, builder: (column) => column);

  GeneratedColumn<String> get direccion =>
      $composableBuilder(column: $table.direccion, builder: (column) => column);

  GeneratedColumn<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fotoUrl =>
      $composableBuilder(column: $table.fotoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  Expression<T> prestamosRefs<T extends Object>(
    Expression<T> Function($$PrestamosTableAnnotationComposer a) f,
  ) {
    final $$PrestamosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableAnnotationComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientesTable,
          Cliente,
          $$ClientesTableFilterComposer,
          $$ClientesTableOrderingComposer,
          $$ClientesTableAnnotationComposer,
          $$ClientesTableCreateCompanionBuilder,
          $$ClientesTableUpdateCompanionBuilder,
          (Cliente, $$ClientesTableReferences),
          Cliente,
          PrefetchHooks Function({bool prestamosRefs})
        > {
  $$ClientesTableTableManager(_$AppDatabase db, $ClientesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> usuarioId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> cedula = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<String> direccion = const Value.absent(),
                Value<String?> referencia = const Value.absent(),
                Value<String?> fotoUrl = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => ClientesCompanion(
                id: id,
                servidorId: servidorId,
                usuarioId: usuarioId,
                nombre: nombre,
                cedula: cedula,
                telefono: telefono,
                direccion: direccion,
                referencia: referencia,
                fotoUrl: fotoUrl,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int usuarioId,
                required String nombre,
                required String cedula,
                required String telefono,
                required String direccion,
                Value<String?> referencia = const Value.absent(),
                Value<String?> fotoUrl = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => ClientesCompanion.insert(
                id: id,
                servidorId: servidorId,
                usuarioId: usuarioId,
                nombre: nombre,
                cedula: cedula,
                telefono: telefono,
                direccion: direccion,
                referencia: referencia,
                fotoUrl: fotoUrl,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClientesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({prestamosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (prestamosRefs) db.prestamos],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (prestamosRefs)
                    await $_getPrefetchedData<
                      Cliente,
                      $ClientesTable,
                      Prestamo
                    >(
                      currentTable: table,
                      referencedTable: $$ClientesTableReferences
                          ._prestamosRefsTable(db),
                      managerFromTypedResult: (p0) => $$ClientesTableReferences(
                        db,
                        table,
                        p0,
                      ).prestamosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.clienteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ClientesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientesTable,
      Cliente,
      $$ClientesTableFilterComposer,
      $$ClientesTableOrderingComposer,
      $$ClientesTableAnnotationComposer,
      $$ClientesTableCreateCompanionBuilder,
      $$ClientesTableUpdateCompanionBuilder,
      (Cliente, $$ClientesTableReferences),
      Cliente,
      PrefetchHooks Function({bool prestamosRefs})
    >;
typedef $$PrestamosTableCreateCompanionBuilder =
    PrestamosCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int clienteId,
      Value<String?> referencia,
      required int usuarioId,
      required double montoCapital,
      required double porcentajeInteres,
      required String frecuenciaPago,
      Value<int?> diasPersonalizado,
      required int plazoCuotas,
      required DateTime fechaInicio,
      Value<String> estado,
      Value<String?> politicaMora,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });
typedef $$PrestamosTableUpdateCompanionBuilder =
    PrestamosCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> clienteId,
      Value<String?> referencia,
      Value<int> usuarioId,
      Value<double> montoCapital,
      Value<double> porcentajeInteres,
      Value<String> frecuenciaPago,
      Value<int?> diasPersonalizado,
      Value<int> plazoCuotas,
      Value<DateTime> fechaInicio,
      Value<String> estado,
      Value<String?> politicaMora,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });

final class $$PrestamosTableReferences
    extends BaseReferences<_$AppDatabase, $PrestamosTable, Prestamo> {
  $$PrestamosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) =>
      db.clientes.createAlias('prestamos__cliente_id__clientes__id');

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PrestamosExtrasTable, List<PrestamosExtra>>
  _prestamosExtrasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.prestamosExtras,
    aliasName: 'prestamos__id__prestamos_extras__prestamo_id',
  );

  $$PrestamosExtrasTableProcessedTableManager get prestamosExtrasRefs {
    final manager = $$PrestamosExtrasTableTableManager(
      $_db,
      $_db.prestamosExtras,
    ).filter((f) => f.prestamoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _prestamosExtrasRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CuotasTable, List<Cuota>> _cuotasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cuotas,
    aliasName: 'prestamos__id__cuotas__prestamo_id',
  );

  $$CuotasTableProcessedTableManager get cuotasRefs {
    final manager = $$CuotasTableTableManager(
      $_db,
      $_db.cuotas,
    ).filter((f) => f.prestamoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cuotasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PagosTable, List<Pago>> _pagosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pagos,
    aliasName: 'prestamos__id__pagos__prestamo_id',
  );

  $$PagosTableProcessedTableManager get pagosRefs {
    final manager = $$PagosTableTableManager(
      $_db,
      $_db.pagos,
    ).filter((f) => f.prestamoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PrestamosTableFilterComposer
    extends Composer<_$AppDatabase, $PrestamosTable> {
  $$PrestamosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get porcentajeInteres => $composableBuilder(
    column: $table.porcentajeInteres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frecuenciaPago => $composableBuilder(
    column: $table.frecuenciaPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasPersonalizado => $composableBuilder(
    column: $table.diasPersonalizado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plazoCuotas => $composableBuilder(
    column: $table.plazoCuotas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get politicaMora => $composableBuilder(
    column: $table.politicaMora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> prestamosExtrasRefs(
    Expression<bool> Function($$PrestamosExtrasTableFilterComposer f) f,
  ) {
    final $$PrestamosExtrasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.prestamosExtras,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosExtrasTableFilterComposer(
            $db: $db,
            $table: $db.prestamosExtras,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cuotasRefs(
    Expression<bool> Function($$CuotasTableFilterComposer f) f,
  ) {
    final $$CuotasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuotas,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuotasTableFilterComposer(
            $db: $db,
            $table: $db.cuotas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pagosRefs(
    Expression<bool> Function($$PagosTableFilterComposer f) f,
  ) {
    final $$PagosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableFilterComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PrestamosTableOrderingComposer
    extends Composer<_$AppDatabase, $PrestamosTable> {
  $$PrestamosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get porcentajeInteres => $composableBuilder(
    column: $table.porcentajeInteres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frecuenciaPago => $composableBuilder(
    column: $table.frecuenciaPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasPersonalizado => $composableBuilder(
    column: $table.diasPersonalizado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plazoCuotas => $composableBuilder(
    column: $table.plazoCuotas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get politicaMora => $composableBuilder(
    column: $table.politicaMora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableOrderingComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrestamosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrestamosTable> {
  $$PrestamosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referencia => $composableBuilder(
    column: $table.referencia,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

  GeneratedColumn<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => column,
  );

  GeneratedColumn<double> get porcentajeInteres => $composableBuilder(
    column: $table.porcentajeInteres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frecuenciaPago => $composableBuilder(
    column: $table.frecuenciaPago,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diasPersonalizado => $composableBuilder(
    column: $table.diasPersonalizado,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plazoCuotas => $composableBuilder(
    column: $table.plazoCuotas,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get politicaMora => $composableBuilder(
    column: $table.politicaMora,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> prestamosExtrasRefs<T extends Object>(
    Expression<T> Function($$PrestamosExtrasTableAnnotationComposer a) f,
  ) {
    final $$PrestamosExtrasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.prestamosExtras,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosExtrasTableAnnotationComposer(
            $db: $db,
            $table: $db.prestamosExtras,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cuotasRefs<T extends Object>(
    Expression<T> Function($$CuotasTableAnnotationComposer a) f,
  ) {
    final $$CuotasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuotas,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuotasTableAnnotationComposer(
            $db: $db,
            $table: $db.cuotas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pagosRefs<T extends Object>(
    Expression<T> Function($$PagosTableAnnotationComposer a) f,
  ) {
    final $$PagosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.prestamoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableAnnotationComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PrestamosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrestamosTable,
          Prestamo,
          $$PrestamosTableFilterComposer,
          $$PrestamosTableOrderingComposer,
          $$PrestamosTableAnnotationComposer,
          $$PrestamosTableCreateCompanionBuilder,
          $$PrestamosTableUpdateCompanionBuilder,
          (Prestamo, $$PrestamosTableReferences),
          Prestamo,
          PrefetchHooks Function({
            bool clienteId,
            bool prestamosExtrasRefs,
            bool cuotasRefs,
            bool pagosRefs,
          })
        > {
  $$PrestamosTableTableManager(_$AppDatabase db, $PrestamosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrestamosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrestamosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrestamosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<String?> referencia = const Value.absent(),
                Value<int> usuarioId = const Value.absent(),
                Value<double> montoCapital = const Value.absent(),
                Value<double> porcentajeInteres = const Value.absent(),
                Value<String> frecuenciaPago = const Value.absent(),
                Value<int?> diasPersonalizado = const Value.absent(),
                Value<int> plazoCuotas = const Value.absent(),
                Value<DateTime> fechaInicio = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String?> politicaMora = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PrestamosCompanion(
                id: id,
                servidorId: servidorId,
                clienteId: clienteId,
                referencia: referencia,
                usuarioId: usuarioId,
                montoCapital: montoCapital,
                porcentajeInteres: porcentajeInteres,
                frecuenciaPago: frecuenciaPago,
                diasPersonalizado: diasPersonalizado,
                plazoCuotas: plazoCuotas,
                fechaInicio: fechaInicio,
                estado: estado,
                politicaMora: politicaMora,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int clienteId,
                Value<String?> referencia = const Value.absent(),
                required int usuarioId,
                required double montoCapital,
                required double porcentajeInteres,
                required String frecuenciaPago,
                Value<int?> diasPersonalizado = const Value.absent(),
                required int plazoCuotas,
                required DateTime fechaInicio,
                Value<String> estado = const Value.absent(),
                Value<String?> politicaMora = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PrestamosCompanion.insert(
                id: id,
                servidorId: servidorId,
                clienteId: clienteId,
                referencia: referencia,
                usuarioId: usuarioId,
                montoCapital: montoCapital,
                porcentajeInteres: porcentajeInteres,
                frecuenciaPago: frecuenciaPago,
                diasPersonalizado: diasPersonalizado,
                plazoCuotas: plazoCuotas,
                fechaInicio: fechaInicio,
                estado: estado,
                politicaMora: politicaMora,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrestamosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                clienteId = false,
                prestamosExtrasRefs = false,
                cuotasRefs = false,
                pagosRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (prestamosExtrasRefs) db.prestamosExtras,
                    if (cuotasRefs) db.cuotas,
                    if (pagosRefs) db.pagos,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (clienteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.clienteId,
                                    referencedTable: $$PrestamosTableReferences
                                        ._clienteIdTable(db),
                                    referencedColumn: $$PrestamosTableReferences
                                        ._clienteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (prestamosExtrasRefs)
                        await $_getPrefetchedData<
                          Prestamo,
                          $PrestamosTable,
                          PrestamosExtra
                        >(
                          currentTable: table,
                          referencedTable: $$PrestamosTableReferences
                              ._prestamosExtrasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PrestamosTableReferences(
                                db,
                                table,
                                p0,
                              ).prestamosExtrasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.prestamoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cuotasRefs)
                        await $_getPrefetchedData<
                          Prestamo,
                          $PrestamosTable,
                          Cuota
                        >(
                          currentTable: table,
                          referencedTable: $$PrestamosTableReferences
                              ._cuotasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PrestamosTableReferences(
                                db,
                                table,
                                p0,
                              ).cuotasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.prestamoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pagosRefs)
                        await $_getPrefetchedData<
                          Prestamo,
                          $PrestamosTable,
                          Pago
                        >(
                          currentTable: table,
                          referencedTable: $$PrestamosTableReferences
                              ._pagosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PrestamosTableReferences(
                                db,
                                table,
                                p0,
                              ).pagosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.prestamoId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PrestamosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrestamosTable,
      Prestamo,
      $$PrestamosTableFilterComposer,
      $$PrestamosTableOrderingComposer,
      $$PrestamosTableAnnotationComposer,
      $$PrestamosTableCreateCompanionBuilder,
      $$PrestamosTableUpdateCompanionBuilder,
      (Prestamo, $$PrestamosTableReferences),
      Prestamo,
      PrefetchHooks Function({
        bool clienteId,
        bool prestamosExtrasRefs,
        bool cuotasRefs,
        bool pagosRefs,
      })
    >;
typedef $$PrestamosExtrasTableCreateCompanionBuilder =
    PrestamosExtrasCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int prestamoId,
      required String concepto,
      required double valor,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<bool> sincronizado,
    });
typedef $$PrestamosExtrasTableUpdateCompanionBuilder =
    PrestamosExtrasCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> prestamoId,
      Value<String> concepto,
      Value<double> valor,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<bool> sincronizado,
    });

final class $$PrestamosExtrasTableReferences
    extends
        BaseReferences<_$AppDatabase, $PrestamosExtrasTable, PrestamosExtra> {
  $$PrestamosExtrasTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PrestamosTable _prestamoIdTable(_$AppDatabase db) =>
      db.prestamos.createAlias('prestamos_extras__prestamo_id__prestamos__id');

  $$PrestamosTableProcessedTableManager get prestamoId {
    final $_column = $_itemColumn<int>('prestamo_id')!;

    final manager = $$PrestamosTableTableManager(
      $_db,
      $_db.prestamos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prestamoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrestamosExtrasTableFilterComposer
    extends Composer<_$AppDatabase, $PrestamosExtrasTable> {
  $$PrestamosExtrasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get concepto => $composableBuilder(
    column: $table.concepto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$PrestamosTableFilterComposer get prestamoId {
    final $$PrestamosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableFilterComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrestamosExtrasTableOrderingComposer
    extends Composer<_$AppDatabase, $PrestamosExtrasTable> {
  $$PrestamosExtrasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get concepto => $composableBuilder(
    column: $table.concepto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$PrestamosTableOrderingComposer get prestamoId {
    final $$PrestamosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableOrderingComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrestamosExtrasTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrestamosExtrasTable> {
  $$PrestamosExtrasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get concepto =>
      $composableBuilder(column: $table.concepto, builder: (column) => column);

  GeneratedColumn<double> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$PrestamosTableAnnotationComposer get prestamoId {
    final $$PrestamosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableAnnotationComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrestamosExtrasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrestamosExtrasTable,
          PrestamosExtra,
          $$PrestamosExtrasTableFilterComposer,
          $$PrestamosExtrasTableOrderingComposer,
          $$PrestamosExtrasTableAnnotationComposer,
          $$PrestamosExtrasTableCreateCompanionBuilder,
          $$PrestamosExtrasTableUpdateCompanionBuilder,
          (PrestamosExtra, $$PrestamosExtrasTableReferences),
          PrestamosExtra,
          PrefetchHooks Function({bool prestamoId})
        > {
  $$PrestamosExtrasTableTableManager(
    _$AppDatabase db,
    $PrestamosExtrasTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrestamosExtrasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrestamosExtrasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrestamosExtrasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> prestamoId = const Value.absent(),
                Value<String> concepto = const Value.absent(),
                Value<double> valor = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PrestamosExtrasCompanion(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                concepto: concepto,
                valor: valor,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int prestamoId,
                required String concepto,
                required double valor,
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PrestamosExtrasCompanion.insert(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                concepto: concepto,
                valor: valor,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrestamosExtrasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({prestamoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (prestamoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.prestamoId,
                                referencedTable:
                                    $$PrestamosExtrasTableReferences
                                        ._prestamoIdTable(db),
                                referencedColumn:
                                    $$PrestamosExtrasTableReferences
                                        ._prestamoIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PrestamosExtrasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrestamosExtrasTable,
      PrestamosExtra,
      $$PrestamosExtrasTableFilterComposer,
      $$PrestamosExtrasTableOrderingComposer,
      $$PrestamosExtrasTableAnnotationComposer,
      $$PrestamosExtrasTableCreateCompanionBuilder,
      $$PrestamosExtrasTableUpdateCompanionBuilder,
      (PrestamosExtra, $$PrestamosExtrasTableReferences),
      PrestamosExtra,
      PrefetchHooks Function({bool prestamoId})
    >;
typedef $$CuotasTableCreateCompanionBuilder =
    CuotasCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int prestamoId,
      required int numeroCuota,
      required DateTime fechaEsperada,
      required double montoEsperado,
      Value<String> estado,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<bool> sincronizado,
    });
typedef $$CuotasTableUpdateCompanionBuilder =
    CuotasCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> prestamoId,
      Value<int> numeroCuota,
      Value<DateTime> fechaEsperada,
      Value<double> montoEsperado,
      Value<String> estado,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<bool> sincronizado,
    });

final class $$CuotasTableReferences
    extends BaseReferences<_$AppDatabase, $CuotasTable, Cuota> {
  $$CuotasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PrestamosTable _prestamoIdTable(_$AppDatabase db) =>
      db.prestamos.createAlias('cuotas__prestamo_id__prestamos__id');

  $$PrestamosTableProcessedTableManager get prestamoId {
    final $_column = $_itemColumn<int>('prestamo_id')!;

    final manager = $$PrestamosTableTableManager(
      $_db,
      $_db.prestamos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prestamoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PagosTable, List<Pago>> _pagosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pagos,
    aliasName: 'cuotas__id__pagos__cuota_id',
  );

  $$PagosTableProcessedTableManager get pagosRefs {
    final manager = $$PagosTableTableManager(
      $_db,
      $_db.pagos,
    ).filter((f) => f.cuotaId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CuotasTableFilterComposer
    extends Composer<_$AppDatabase, $CuotasTable> {
  $$CuotasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoEsperado => $composableBuilder(
    column: $table.montoEsperado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$PrestamosTableFilterComposer get prestamoId {
    final $$PrestamosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableFilterComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pagosRefs(
    Expression<bool> Function($$PagosTableFilterComposer f) f,
  ) {
    final $$PagosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.cuotaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableFilterComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CuotasTableOrderingComposer
    extends Composer<_$AppDatabase, $CuotasTable> {
  $$CuotasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoEsperado => $composableBuilder(
    column: $table.montoEsperado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$PrestamosTableOrderingComposer get prestamoId {
    final $$PrestamosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableOrderingComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CuotasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuotasTable> {
  $$CuotasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoEsperado => $composableBuilder(
    column: $table.montoEsperado,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$PrestamosTableAnnotationComposer get prestamoId {
    final $$PrestamosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableAnnotationComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pagosRefs<T extends Object>(
    Expression<T> Function($$PagosTableAnnotationComposer a) f,
  ) {
    final $$PagosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.cuotaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableAnnotationComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CuotasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuotasTable,
          Cuota,
          $$CuotasTableFilterComposer,
          $$CuotasTableOrderingComposer,
          $$CuotasTableAnnotationComposer,
          $$CuotasTableCreateCompanionBuilder,
          $$CuotasTableUpdateCompanionBuilder,
          (Cuota, $$CuotasTableReferences),
          Cuota,
          PrefetchHooks Function({bool prestamoId, bool pagosRefs})
        > {
  $$CuotasTableTableManager(_$AppDatabase db, $CuotasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuotasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuotasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CuotasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> prestamoId = const Value.absent(),
                Value<int> numeroCuota = const Value.absent(),
                Value<DateTime> fechaEsperada = const Value.absent(),
                Value<double> montoEsperado = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => CuotasCompanion(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                numeroCuota: numeroCuota,
                fechaEsperada: fechaEsperada,
                montoEsperado: montoEsperado,
                estado: estado,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int prestamoId,
                required int numeroCuota,
                required DateTime fechaEsperada,
                required double montoEsperado,
                Value<String> estado = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => CuotasCompanion.insert(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                numeroCuota: numeroCuota,
                fechaEsperada: fechaEsperada,
                montoEsperado: montoEsperado,
                estado: estado,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CuotasTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({prestamoId = false, pagosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (pagosRefs) db.pagos],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (prestamoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.prestamoId,
                                referencedTable: $$CuotasTableReferences
                                    ._prestamoIdTable(db),
                                referencedColumn: $$CuotasTableReferences
                                    ._prestamoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pagosRefs)
                    await $_getPrefetchedData<Cuota, $CuotasTable, Pago>(
                      currentTable: table,
                      referencedTable: $$CuotasTableReferences._pagosRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$CuotasTableReferences(db, table, p0).pagosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cuotaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CuotasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuotasTable,
      Cuota,
      $$CuotasTableFilterComposer,
      $$CuotasTableOrderingComposer,
      $$CuotasTableAnnotationComposer,
      $$CuotasTableCreateCompanionBuilder,
      $$CuotasTableUpdateCompanionBuilder,
      (Cuota, $$CuotasTableReferences),
      Cuota,
      PrefetchHooks Function({bool prestamoId, bool pagosRefs})
    >;
typedef $$PagosTableCreateCompanionBuilder =
    PagosCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int prestamoId,
      Value<int?> cuotaId,
      required double montoAbonado,
      required double montoAplicado,
      required DateTime fechaPago,
      Value<int> diasMora,
      required double saldoRestanteDespues,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });
typedef $$PagosTableUpdateCompanionBuilder =
    PagosCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> prestamoId,
      Value<int?> cuotaId,
      Value<double> montoAbonado,
      Value<double> montoAplicado,
      Value<DateTime> fechaPago,
      Value<int> diasMora,
      Value<double> saldoRestanteDespues,
      Value<DateTime> creadoEn,
      Value<DateTime> actualizadoEn,
      Value<DateTime?> eliminadoEn,
      Value<bool> sincronizado,
    });

final class $$PagosTableReferences
    extends BaseReferences<_$AppDatabase, $PagosTable, Pago> {
  $$PagosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PrestamosTable _prestamoIdTable(_$AppDatabase db) =>
      db.prestamos.createAlias('pagos__prestamo_id__prestamos__id');

  $$PrestamosTableProcessedTableManager get prestamoId {
    final $_column = $_itemColumn<int>('prestamo_id')!;

    final manager = $$PrestamosTableTableManager(
      $_db,
      $_db.prestamos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prestamoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CuotasTable _cuotaIdTable(_$AppDatabase db) =>
      db.cuotas.createAlias('pagos__cuota_id__cuotas__id');

  $$CuotasTableProcessedTableManager? get cuotaId {
    final $_column = $_itemColumn<int>('cuota_id');
    if ($_column == null) return null;
    final manager = $$CuotasTableTableManager(
      $_db,
      $_db.cuotas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cuotaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PagosTableFilterComposer extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoAbonado => $composableBuilder(
    column: $table.montoAbonado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoAplicado => $composableBuilder(
    column: $table.montoAplicado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaPago => $composableBuilder(
    column: $table.fechaPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasMora => $composableBuilder(
    column: $table.diasMora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saldoRestanteDespues => $composableBuilder(
    column: $table.saldoRestanteDespues,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );

  $$PrestamosTableFilterComposer get prestamoId {
    final $$PrestamosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableFilterComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CuotasTableFilterComposer get cuotaId {
    final $$CuotasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuotaId,
      referencedTable: $db.cuotas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuotasTableFilterComposer(
            $db: $db,
            $table: $db.cuotas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableOrderingComposer
    extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoAbonado => $composableBuilder(
    column: $table.montoAbonado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoAplicado => $composableBuilder(
    column: $table.montoAplicado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaPago => $composableBuilder(
    column: $table.fechaPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasMora => $composableBuilder(
    column: $table.diasMora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saldoRestanteDespues => $composableBuilder(
    column: $table.saldoRestanteDespues,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );

  $$PrestamosTableOrderingComposer get prestamoId {
    final $$PrestamosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableOrderingComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CuotasTableOrderingComposer get cuotaId {
    final $$CuotasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuotaId,
      referencedTable: $db.cuotas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuotasTableOrderingComposer(
            $db: $db,
            $table: $db.cuotas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoAbonado => $composableBuilder(
    column: $table.montoAbonado,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoAplicado => $composableBuilder(
    column: $table.montoAplicado,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaPago =>
      $composableBuilder(column: $table.fechaPago, builder: (column) => column);

  GeneratedColumn<int> get diasMora =>
      $composableBuilder(column: $table.diasMora, builder: (column) => column);

  GeneratedColumn<double> get saldoRestanteDespues => $composableBuilder(
    column: $table.saldoRestanteDespues,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizadoEn => $composableBuilder(
    column: $table.actualizadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eliminadoEn => $composableBuilder(
    column: $table.eliminadoEn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );

  $$PrestamosTableAnnotationComposer get prestamoId {
    final $$PrestamosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prestamoId,
      referencedTable: $db.prestamos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrestamosTableAnnotationComposer(
            $db: $db,
            $table: $db.prestamos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CuotasTableAnnotationComposer get cuotaId {
    final $$CuotasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuotaId,
      referencedTable: $db.cuotas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuotasTableAnnotationComposer(
            $db: $db,
            $table: $db.cuotas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PagosTable,
          Pago,
          $$PagosTableFilterComposer,
          $$PagosTableOrderingComposer,
          $$PagosTableAnnotationComposer,
          $$PagosTableCreateCompanionBuilder,
          $$PagosTableUpdateCompanionBuilder,
          (Pago, $$PagosTableReferences),
          Pago,
          PrefetchHooks Function({bool prestamoId, bool cuotaId})
        > {
  $$PagosTableTableManager(_$AppDatabase db, $PagosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> prestamoId = const Value.absent(),
                Value<int?> cuotaId = const Value.absent(),
                Value<double> montoAbonado = const Value.absent(),
                Value<double> montoAplicado = const Value.absent(),
                Value<DateTime> fechaPago = const Value.absent(),
                Value<int> diasMora = const Value.absent(),
                Value<double> saldoRestanteDespues = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PagosCompanion(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                cuotaId: cuotaId,
                montoAbonado: montoAbonado,
                montoAplicado: montoAplicado,
                fechaPago: fechaPago,
                diasMora: diasMora,
                saldoRestanteDespues: saldoRestanteDespues,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int prestamoId,
                Value<int?> cuotaId = const Value.absent(),
                required double montoAbonado,
                required double montoAplicado,
                required DateTime fechaPago,
                Value<int> diasMora = const Value.absent(),
                required double saldoRestanteDespues,
                Value<DateTime> creadoEn = const Value.absent(),
                Value<DateTime> actualizadoEn = const Value.absent(),
                Value<DateTime?> eliminadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => PagosCompanion.insert(
                id: id,
                servidorId: servidorId,
                prestamoId: prestamoId,
                cuotaId: cuotaId,
                montoAbonado: montoAbonado,
                montoAplicado: montoAplicado,
                fechaPago: fechaPago,
                diasMora: diasMora,
                saldoRestanteDespues: saldoRestanteDespues,
                creadoEn: creadoEn,
                actualizadoEn: actualizadoEn,
                eliminadoEn: eliminadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PagosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({prestamoId = false, cuotaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (prestamoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.prestamoId,
                                referencedTable: $$PagosTableReferences
                                    ._prestamoIdTable(db),
                                referencedColumn: $$PagosTableReferences
                                    ._prestamoIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (cuotaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cuotaId,
                                referencedTable: $$PagosTableReferences
                                    ._cuotaIdTable(db),
                                referencedColumn: $$PagosTableReferences
                                    ._cuotaIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PagosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PagosTable,
      Pago,
      $$PagosTableFilterComposer,
      $$PagosTableOrderingComposer,
      $$PagosTableAnnotationComposer,
      $$PagosTableCreateCompanionBuilder,
      $$PagosTableUpdateCompanionBuilder,
      (Pago, $$PagosTableReferences),
      Pago,
      PrefetchHooks Function({bool prestamoId, bool cuotaId})
    >;
typedef $$CambiosPendientesTableCreateCompanionBuilder =
    CambiosPendientesCompanion Function({
      Value<int> id,
      Value<int?> usuarioId,
      required String tabla,
      required int registroId,
      required String tipoOperacion,
      Value<String?> payload,
      Value<DateTime> creadoEn,
      Value<int> intentos,
      Value<String?> ultimoError,
    });
typedef $$CambiosPendientesTableUpdateCompanionBuilder =
    CambiosPendientesCompanion Function({
      Value<int> id,
      Value<int?> usuarioId,
      Value<String> tabla,
      Value<int> registroId,
      Value<String> tipoOperacion,
      Value<String?> payload,
      Value<DateTime> creadoEn,
      Value<int> intentos,
      Value<String?> ultimoError,
    });

class $$CambiosPendientesTableFilterComposer
    extends Composer<_$AppDatabase, $CambiosPendientesTable> {
  $$CambiosPendientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tabla => $composableBuilder(
    column: $table.tabla,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoOperacion => $composableBuilder(
    column: $table.tipoOperacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CambiosPendientesTableOrderingComposer
    extends Composer<_$AppDatabase, $CambiosPendientesTable> {
  $$CambiosPendientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tabla => $composableBuilder(
    column: $table.tabla,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoOperacion => $composableBuilder(
    column: $table.tipoOperacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CambiosPendientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CambiosPendientesTable> {
  $$CambiosPendientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

  GeneratedColumn<String> get tabla =>
      $composableBuilder(column: $table.tabla, builder: (column) => column);

  GeneratedColumn<int> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tipoOperacion => $composableBuilder(
    column: $table.tipoOperacion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<int> get intentos =>
      $composableBuilder(column: $table.intentos, builder: (column) => column);

  GeneratedColumn<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => column,
  );
}

class $$CambiosPendientesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CambiosPendientesTable,
          CambiosPendiente,
          $$CambiosPendientesTableFilterComposer,
          $$CambiosPendientesTableOrderingComposer,
          $$CambiosPendientesTableAnnotationComposer,
          $$CambiosPendientesTableCreateCompanionBuilder,
          $$CambiosPendientesTableUpdateCompanionBuilder,
          (
            CambiosPendiente,
            BaseReferences<
              _$AppDatabase,
              $CambiosPendientesTable,
              CambiosPendiente
            >,
          ),
          CambiosPendiente,
          PrefetchHooks Function()
        > {
  $$CambiosPendientesTableTableManager(
    _$AppDatabase db,
    $CambiosPendientesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CambiosPendientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CambiosPendientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CambiosPendientesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> usuarioId = const Value.absent(),
                Value<String> tabla = const Value.absent(),
                Value<int> registroId = const Value.absent(),
                Value<String> tipoOperacion = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<int> intentos = const Value.absent(),
                Value<String?> ultimoError = const Value.absent(),
              }) => CambiosPendientesCompanion(
                id: id,
                usuarioId: usuarioId,
                tabla: tabla,
                registroId: registroId,
                tipoOperacion: tipoOperacion,
                payload: payload,
                creadoEn: creadoEn,
                intentos: intentos,
                ultimoError: ultimoError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> usuarioId = const Value.absent(),
                required String tabla,
                required int registroId,
                required String tipoOperacion,
                Value<String?> payload = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<int> intentos = const Value.absent(),
                Value<String?> ultimoError = const Value.absent(),
              }) => CambiosPendientesCompanion.insert(
                id: id,
                usuarioId: usuarioId,
                tabla: tabla,
                registroId: registroId,
                tipoOperacion: tipoOperacion,
                payload: payload,
                creadoEn: creadoEn,
                intentos: intentos,
                ultimoError: ultimoError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CambiosPendientesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CambiosPendientesTable,
      CambiosPendiente,
      $$CambiosPendientesTableFilterComposer,
      $$CambiosPendientesTableOrderingComposer,
      $$CambiosPendientesTableAnnotationComposer,
      $$CambiosPendientesTableCreateCompanionBuilder,
      $$CambiosPendientesTableUpdateCompanionBuilder,
      (
        CambiosPendiente,
        BaseReferences<
          _$AppDatabase,
          $CambiosPendientesTable,
          CambiosPendiente
        >,
      ),
      CambiosPendiente,
      PrefetchHooks Function()
    >;
typedef $$CargasCapitalTableCreateCompanionBuilder =
    CargasCapitalCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      required int usuarioId,
      required double monto,
      Value<String?> descripcion,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
    });
typedef $$CargasCapitalTableUpdateCompanionBuilder =
    CargasCapitalCompanion Function({
      Value<int> id,
      Value<int?> servidorId,
      Value<int> usuarioId,
      Value<double> monto,
      Value<String?> descripcion,
      Value<DateTime> creadoEn,
      Value<bool> sincronizado,
    });

class $$CargasCapitalTableFilterComposer
    extends Composer<_$AppDatabase, $CargasCapitalTable> {
  $$CargasCapitalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CargasCapitalTableOrderingComposer
    extends Composer<_$AppDatabase, $CargasCapitalTable> {
  $$CargasCapitalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CargasCapitalTableAnnotationComposer
    extends Composer<_$AppDatabase, $CargasCapitalTable> {
  $$CargasCapitalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get servidorId => $composableBuilder(
    column: $table.servidorId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );
}

class $$CargasCapitalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CargasCapitalTable,
          CargaCapital,
          $$CargasCapitalTableFilterComposer,
          $$CargasCapitalTableOrderingComposer,
          $$CargasCapitalTableAnnotationComposer,
          $$CargasCapitalTableCreateCompanionBuilder,
          $$CargasCapitalTableUpdateCompanionBuilder,
          (
            CargaCapital,
            BaseReferences<_$AppDatabase, $CargasCapitalTable, CargaCapital>,
          ),
          CargaCapital,
          PrefetchHooks Function()
        > {
  $$CargasCapitalTableTableManager(_$AppDatabase db, $CargasCapitalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CargasCapitalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CargasCapitalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CargasCapitalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                Value<int> usuarioId = const Value.absent(),
                Value<double> monto = const Value.absent(),
                Value<String?> descripcion = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => CargasCapitalCompanion(
                id: id,
                servidorId: servidorId,
                usuarioId: usuarioId,
                monto: monto,
                descripcion: descripcion,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> servidorId = const Value.absent(),
                required int usuarioId,
                required double monto,
                Value<String?> descripcion = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
              }) => CargasCapitalCompanion.insert(
                id: id,
                servidorId: servidorId,
                usuarioId: usuarioId,
                monto: monto,
                descripcion: descripcion,
                creadoEn: creadoEn,
                sincronizado: sincronizado,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CargasCapitalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CargasCapitalTable,
      CargaCapital,
      $$CargasCapitalTableFilterComposer,
      $$CargasCapitalTableOrderingComposer,
      $$CargasCapitalTableAnnotationComposer,
      $$CargasCapitalTableCreateCompanionBuilder,
      $$CargasCapitalTableUpdateCompanionBuilder,
      (
        CargaCapital,
        BaseReferences<_$AppDatabase, $CargasCapitalTable, CargaCapital>,
      ),
      CargaCapital,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db, _db.clientes);
  $$PrestamosTableTableManager get prestamos =>
      $$PrestamosTableTableManager(_db, _db.prestamos);
  $$PrestamosExtrasTableTableManager get prestamosExtras =>
      $$PrestamosExtrasTableTableManager(_db, _db.prestamosExtras);
  $$CuotasTableTableManager get cuotas =>
      $$CuotasTableTableManager(_db, _db.cuotas);
  $$PagosTableTableManager get pagos =>
      $$PagosTableTableManager(_db, _db.pagos);
  $$CambiosPendientesTableTableManager get cambiosPendientes =>
      $$CambiosPendientesTableTableManager(_db, _db.cambiosPendientes);
  $$CargasCapitalTableTableManager get cargasCapital =>
      $$CargasCapitalTableTableManager(_db, _db.cargasCapital);
}
