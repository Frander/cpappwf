// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class HeadquartersStruct extends BaseStruct {
  HeadquartersStruct({
    int? idHeadquarter,
    int? idZone,
    String? createdAt,
    String? nameHeadquarter,
    int? densityHeadquarter,
    String? seedTime,
    String? stateHeadquarter,
    double? areaHeadquarter,
    String? polygon,
  })  : _idHeadquarter = idHeadquarter,
        _idZone = idZone,
        _createdAt = createdAt,
        _nameHeadquarter = nameHeadquarter,
        _densityHeadquarter = densityHeadquarter,
        _seedTime = seedTime,
        _stateHeadquarter = stateHeadquarter,
        _areaHeadquarter = areaHeadquarter,
        _polygon = polygon;

  // "id_headquarter" field.
  int? _idHeadquarter;
  int get idHeadquarter => _idHeadquarter ?? 0;
  set idHeadquarter(int? val) => _idHeadquarter = val;

  void incrementIdHeadquarter(int amount) =>
      idHeadquarter = idHeadquarter + amount;

  bool hasIdHeadquarter() => _idHeadquarter != null;

  // "id_zone" field.
  int? _idZone;
  int get idZone => _idZone ?? 0;
  set idZone(int? val) => _idZone = val;

  void incrementIdZone(int amount) => idZone = idZone + amount;

  bool hasIdZone() => _idZone != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "name_headquarter" field.
  String? _nameHeadquarter;
  String get nameHeadquarter => _nameHeadquarter ?? '';
  set nameHeadquarter(String? val) => _nameHeadquarter = val;

  bool hasNameHeadquarter() => _nameHeadquarter != null;

  // "density_headquarter" field.
  int? _densityHeadquarter;
  int get densityHeadquarter => _densityHeadquarter ?? 0;
  set densityHeadquarter(int? val) => _densityHeadquarter = val;

  void incrementDensityHeadquarter(int amount) =>
      densityHeadquarter = densityHeadquarter + amount;

  bool hasDensityHeadquarter() => _densityHeadquarter != null;

  // "seed_time" field.
  String? _seedTime;
  String get seedTime => _seedTime ?? '';
  set seedTime(String? val) => _seedTime = val;

  bool hasSeedTime() => _seedTime != null;

  // "state_headquarter" field.
  String? _stateHeadquarter;
  String get stateHeadquarter => _stateHeadquarter ?? '';
  set stateHeadquarter(String? val) => _stateHeadquarter = val;

  bool hasStateHeadquarter() => _stateHeadquarter != null;

  // "area_headquarter" field.
  double? _areaHeadquarter;
  double get areaHeadquarter => _areaHeadquarter ?? 0.0;
  set areaHeadquarter(double? val) => _areaHeadquarter = val;

  void incrementAreaHeadquarter(double amount) =>
      areaHeadquarter = areaHeadquarter + amount;

  bool hasAreaHeadquarter() => _areaHeadquarter != null;

  // "polygon" field.
  String? _polygon;
  String get polygon => _polygon ?? '';
  set polygon(String? val) => _polygon = val;

  bool hasPolygon() => _polygon != null;

  static HeadquartersStruct fromMap(Map<String, dynamic> data) =>
      HeadquartersStruct(
        idHeadquarter: castToType<int>(data['id_headquarter']),
        idZone: castToType<int>(data['id_zone']),
        createdAt: data['created_at'] as String?,
        nameHeadquarter: data['name_headquarter'] as String?,
        densityHeadquarter: castToType<int>(data['density_headquarter']),
        seedTime: data['seed_time'] as String?,
        stateHeadquarter: data['state_headquarter'] as String?,
        areaHeadquarter: castToType<double>(data['area_headquarter']),
        polygon: data['polygon'] as String?,
      );

  static HeadquartersStruct? maybeFromMap(dynamic data) => data is Map
      ? HeadquartersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_headquarter': _idHeadquarter,
        'id_zone': _idZone,
        'created_at': _createdAt,
        'name_headquarter': _nameHeadquarter,
        'density_headquarter': _densityHeadquarter,
        'seed_time': _seedTime,
        'state_headquarter': _stateHeadquarter,
        'area_headquarter': _areaHeadquarter,
        'polygon': _polygon,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_headquarter': serializeParam(
          _idHeadquarter,
          ParamType.int,
        ),
        'id_zone': serializeParam(
          _idZone,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'name_headquarter': serializeParam(
          _nameHeadquarter,
          ParamType.String,
        ),
        'density_headquarter': serializeParam(
          _densityHeadquarter,
          ParamType.int,
        ),
        'seed_time': serializeParam(
          _seedTime,
          ParamType.String,
        ),
        'state_headquarter': serializeParam(
          _stateHeadquarter,
          ParamType.String,
        ),
        'area_headquarter': serializeParam(
          _areaHeadquarter,
          ParamType.double,
        ),
        'polygon': serializeParam(
          _polygon,
          ParamType.String,
        ),
      }.withoutNulls;

  static HeadquartersStruct fromSerializableMap(Map<String, dynamic> data) =>
      HeadquartersStruct(
        idHeadquarter: deserializeParam(
          data['id_headquarter'],
          ParamType.int,
          false,
        ),
        idZone: deserializeParam(
          data['id_zone'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
        nameHeadquarter: deserializeParam(
          data['name_headquarter'],
          ParamType.String,
          false,
        ),
        densityHeadquarter: deserializeParam(
          data['density_headquarter'],
          ParamType.int,
          false,
        ),
        seedTime: deserializeParam(
          data['seed_time'],
          ParamType.String,
          false,
        ),
        stateHeadquarter: deserializeParam(
          data['state_headquarter'],
          ParamType.String,
          false,
        ),
        areaHeadquarter: deserializeParam(
          data['area_headquarter'],
          ParamType.double,
          false,
        ),
        polygon: deserializeParam(
          data['polygon'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'HeadquartersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is HeadquartersStruct &&
        idHeadquarter == other.idHeadquarter &&
        idZone == other.idZone &&
        createdAt == other.createdAt &&
        nameHeadquarter == other.nameHeadquarter &&
        densityHeadquarter == other.densityHeadquarter &&
        seedTime == other.seedTime &&
        stateHeadquarter == other.stateHeadquarter &&
        areaHeadquarter == other.areaHeadquarter &&
        polygon == other.polygon;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idHeadquarter,
        idZone,
        createdAt,
        nameHeadquarter,
        densityHeadquarter,
        seedTime,
        stateHeadquarter,
        areaHeadquarter,
        polygon
      ]);
}

HeadquartersStruct createHeadquartersStruct({
  int? idHeadquarter,
  int? idZone,
  String? createdAt,
  String? nameHeadquarter,
  int? densityHeadquarter,
  String? seedTime,
  String? stateHeadquarter,
  double? areaHeadquarter,
  String? polygon,
}) =>
    HeadquartersStruct(
      idHeadquarter: idHeadquarter,
      idZone: idZone,
      createdAt: createdAt,
      nameHeadquarter: nameHeadquarter,
      densityHeadquarter: densityHeadquarter,
      seedTime: seedTime,
      stateHeadquarter: stateHeadquarter,
      areaHeadquarter: areaHeadquarter,
      polygon: polygon,
    );
