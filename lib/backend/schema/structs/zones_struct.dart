// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ZonesStruct extends BaseStruct {
  ZonesStruct({
    int? idZone,
    int? idCompany,
    String? createdAt,
    String? nameZone,
    int? difficulty,
    String? stateZone,
  })  : _idZone = idZone,
        _idCompany = idCompany,
        _createdAt = createdAt,
        _nameZone = nameZone,
        _difficulty = difficulty,
        _stateZone = stateZone;

  // "id_zone" field.
  int? _idZone;
  int get idZone => _idZone ?? 0;
  set idZone(int? val) => _idZone = val;

  void incrementIdZone(int amount) => idZone = idZone + amount;

  bool hasIdZone() => _idZone != null;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "name_zone" field.
  String? _nameZone;
  String get nameZone => _nameZone ?? '';
  set nameZone(String? val) => _nameZone = val;

  bool hasNameZone() => _nameZone != null;

  // "difficulty" field.
  int? _difficulty;
  int get difficulty => _difficulty ?? 0;
  set difficulty(int? val) => _difficulty = val;

  void incrementDifficulty(int amount) => difficulty = difficulty + amount;

  bool hasDifficulty() => _difficulty != null;

  // "state_zone" field.
  String? _stateZone;
  String get stateZone => _stateZone ?? '';
  set stateZone(String? val) => _stateZone = val;

  bool hasStateZone() => _stateZone != null;

  static ZonesStruct fromMap(Map<String, dynamic> data) => ZonesStruct(
        idZone: castToType<int>(data['id_zone']),
        idCompany: castToType<int>(data['id_company']),
        createdAt: data['created_at'] as String?,
        nameZone: data['name_zone'] as String?,
        difficulty: castToType<int>(data['difficulty']),
        stateZone: data['state_zone'] as String?,
      );

  static ZonesStruct? maybeFromMap(dynamic data) =>
      data is Map ? ZonesStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_zone': _idZone,
        'id_company': _idCompany,
        'created_at': _createdAt,
        'name_zone': _nameZone,
        'difficulty': _difficulty,
        'state_zone': _stateZone,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_zone': serializeParam(
          _idZone,
          ParamType.int,
        ),
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'name_zone': serializeParam(
          _nameZone,
          ParamType.String,
        ),
        'difficulty': serializeParam(
          _difficulty,
          ParamType.int,
        ),
        'state_zone': serializeParam(
          _stateZone,
          ParamType.String,
        ),
      }.withoutNulls;

  static ZonesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ZonesStruct(
        idZone: deserializeParam(
          data['id_zone'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
        nameZone: deserializeParam(
          data['name_zone'],
          ParamType.String,
          false,
        ),
        difficulty: deserializeParam(
          data['difficulty'],
          ParamType.int,
          false,
        ),
        stateZone: deserializeParam(
          data['state_zone'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ZonesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ZonesStruct &&
        idZone == other.idZone &&
        idCompany == other.idCompany &&
        createdAt == other.createdAt &&
        nameZone == other.nameZone &&
        difficulty == other.difficulty &&
        stateZone == other.stateZone;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([idZone, idCompany, createdAt, nameZone, difficulty, stateZone]);
}

ZonesStruct createZonesStruct({
  int? idZone,
  int? idCompany,
  String? createdAt,
  String? nameZone,
  int? difficulty,
  String? stateZone,
}) =>
    ZonesStruct(
      idZone: idZone,
      idCompany: idCompany,
      createdAt: createdAt,
      nameZone: nameZone,
      difficulty: difficulty,
      stateZone: stateZone,
    );
