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
    double? densityHeadquarter,
    String? seedTime,
    int? areaHeadquarter,
    String? polygon,
    String? stateHeadquarter,
  })  : _idHeadquarter = idHeadquarter,
        _idZone = idZone,
        _createdAt = createdAt,
        _nameHeadquarter = nameHeadquarter,
        _densityHeadquarter = densityHeadquarter,
        _seedTime = seedTime,
        _areaHeadquarter = areaHeadquarter,
        _polygon = polygon,
        _stateHeadquarter = stateHeadquarter;

  // "Id_headquarter" field.
  int? _idHeadquarter;
  int get idHeadquarter => _idHeadquarter ?? 0;
  set idHeadquarter(int? val) => _idHeadquarter = val;

  void incrementIdHeadquarter(int amount) =>
      idHeadquarter = idHeadquarter + amount;

  bool hasIdHeadquarter() => _idHeadquarter != null;

  // "Id_zone" field.
  int? _idZone;
  int get idZone => _idZone ?? 0;
  set idZone(int? val) => _idZone = val;

  void incrementIdZone(int amount) => idZone = idZone + amount;

  bool hasIdZone() => _idZone != null;

  // "Created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "Name_headquarter" field.
  String? _nameHeadquarter;
  String get nameHeadquarter => _nameHeadquarter ?? '';
  set nameHeadquarter(String? val) => _nameHeadquarter = val;

  bool hasNameHeadquarter() => _nameHeadquarter != null;

  // "Density_headquarter" field.
  double? _densityHeadquarter;
  double get densityHeadquarter => _densityHeadquarter ?? 0.0;
  set densityHeadquarter(double? val) => _densityHeadquarter = val;

  void incrementDensityHeadquarter(double amount) =>
      densityHeadquarter = densityHeadquarter + amount;

  bool hasDensityHeadquarter() => _densityHeadquarter != null;

  // "Seed_time" field.
  String? _seedTime;
  String get seedTime => _seedTime ?? '';
  set seedTime(String? val) => _seedTime = val;

  bool hasSeedTime() => _seedTime != null;

  // "Area_headquarter" field.
  int? _areaHeadquarter;
  int get areaHeadquarter => _areaHeadquarter ?? 0;
  set areaHeadquarter(int? val) => _areaHeadquarter = val;

  void incrementAreaHeadquarter(int amount) =>
      areaHeadquarter = areaHeadquarter + amount;

  bool hasAreaHeadquarter() => _areaHeadquarter != null;

  // "Polygon" field.
  String? _polygon;
  String get polygon => _polygon ?? '';
  set polygon(String? val) => _polygon = val;

  bool hasPolygon() => _polygon != null;

  // "State_headquarter" field.
  String? _stateHeadquarter;
  String get stateHeadquarter => _stateHeadquarter ?? '';
  set stateHeadquarter(String? val) => _stateHeadquarter = val;

  bool hasStateHeadquarter() => _stateHeadquarter != null;

  static HeadquartersStruct fromMap(Map<String, dynamic> data) =>
      HeadquartersStruct(
        idHeadquarter: castToType<int>(data['Id_headquarter']),
        idZone: castToType<int>(data['Id_zone']),
        createdAt: data['Created_at'] as String?,
        nameHeadquarter: data['Name_headquarter'] as String?,
        densityHeadquarter: castToType<double>(data['Density_headquarter']),
        seedTime: data['Seed_time'] as String?,
        areaHeadquarter: castToType<int>(data['Area_headquarter']),
        polygon: data['Polygon'] as String?,
        stateHeadquarter: data['State_headquarter'] as String?,
      );

  static HeadquartersStruct? maybeFromMap(dynamic data) => data is Map
      ? HeadquartersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'Id_headquarter': _idHeadquarter,
        'Id_zone': _idZone,
        'Created_at': _createdAt,
        'Name_headquarter': _nameHeadquarter,
        'Density_headquarter': _densityHeadquarter,
        'Seed_time': _seedTime,
        'Area_headquarter': _areaHeadquarter,
        'Polygon': _polygon,
        'State_headquarter': _stateHeadquarter,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'Id_headquarter': serializeParam(
          _idHeadquarter,
          ParamType.int,
        ),
        'Id_zone': serializeParam(
          _idZone,
          ParamType.int,
        ),
        'Created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'Name_headquarter': serializeParam(
          _nameHeadquarter,
          ParamType.String,
        ),
        'Density_headquarter': serializeParam(
          _densityHeadquarter,
          ParamType.double,
        ),
        'Seed_time': serializeParam(
          _seedTime,
          ParamType.String,
        ),
        'Area_headquarter': serializeParam(
          _areaHeadquarter,
          ParamType.int,
        ),
        'Polygon': serializeParam(
          _polygon,
          ParamType.String,
        ),
        'State_headquarter': serializeParam(
          _stateHeadquarter,
          ParamType.String,
        ),
      }.withoutNulls;

  static HeadquartersStruct fromSerializableMap(Map<String, dynamic> data) =>
      HeadquartersStruct(
        idHeadquarter: deserializeParam(
          data['Id_headquarter'],
          ParamType.int,
          false,
        ),
        idZone: deserializeParam(
          data['Id_zone'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['Created_at'],
          ParamType.String,
          false,
        ),
        nameHeadquarter: deserializeParam(
          data['Name_headquarter'],
          ParamType.String,
          false,
        ),
        densityHeadquarter: deserializeParam(
          data['Density_headquarter'],
          ParamType.double,
          false,
        ),
        seedTime: deserializeParam(
          data['Seed_time'],
          ParamType.String,
          false,
        ),
        areaHeadquarter: deserializeParam(
          data['Area_headquarter'],
          ParamType.int,
          false,
        ),
        polygon: deserializeParam(
          data['Polygon'],
          ParamType.String,
          false,
        ),
        stateHeadquarter: deserializeParam(
          data['State_headquarter'],
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
        areaHeadquarter == other.areaHeadquarter &&
        polygon == other.polygon &&
        stateHeadquarter == other.stateHeadquarter;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idHeadquarter,
        idZone,
        createdAt,
        nameHeadquarter,
        densityHeadquarter,
        seedTime,
        areaHeadquarter,
        polygon,
        stateHeadquarter
      ]);
}

HeadquartersStruct createHeadquartersStruct({
  int? idHeadquarter,
  int? idZone,
  String? createdAt,
  String? nameHeadquarter,
  double? densityHeadquarter,
  String? seedTime,
  int? areaHeadquarter,
  String? polygon,
  String? stateHeadquarter,
}) =>
    HeadquartersStruct(
      idHeadquarter: idHeadquarter,
      idZone: idZone,
      createdAt: createdAt,
      nameHeadquarter: nameHeadquarter,
      densityHeadquarter: densityHeadquarter,
      seedTime: seedTime,
      areaHeadquarter: areaHeadquarter,
      polygon: polygon,
      stateHeadquarter: stateHeadquarter,
    );
