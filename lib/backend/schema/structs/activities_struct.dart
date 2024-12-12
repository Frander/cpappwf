// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivitiesStruct extends BaseStruct {
  ActivitiesStruct({
    int? idActivity,
    int? idCompany,
    String? createdAt,
    String? nameActivity,
    String? descripcionActivity,
    String? groupActivity,
    String? unity,
    int? cycle,
    double? effectivityVisits,
    String? moduleActivity,
    String? typeEffectivity,
    int? effectivityUnitys,
  })  : _idActivity = idActivity,
        _idCompany = idCompany,
        _createdAt = createdAt,
        _nameActivity = nameActivity,
        _descripcionActivity = descripcionActivity,
        _groupActivity = groupActivity,
        _unity = unity,
        _cycle = cycle,
        _effectivityVisits = effectivityVisits,
        _moduleActivity = moduleActivity,
        _typeEffectivity = typeEffectivity,
        _effectivityUnitys = effectivityUnitys;

  // "Id_activity" field.
  int? _idActivity;
  int get idActivity => _idActivity ?? 0;
  set idActivity(int? val) => _idActivity = val;

  void incrementIdActivity(int amount) => idActivity = idActivity + amount;

  bool hasIdActivity() => _idActivity != null;

  // "Id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "Created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "Name_activity" field.
  String? _nameActivity;
  String get nameActivity => _nameActivity ?? '';
  set nameActivity(String? val) => _nameActivity = val;

  bool hasNameActivity() => _nameActivity != null;

  // "Descripcion_activity" field.
  String? _descripcionActivity;
  String get descripcionActivity => _descripcionActivity ?? '';
  set descripcionActivity(String? val) => _descripcionActivity = val;

  bool hasDescripcionActivity() => _descripcionActivity != null;

  // "Group_activity" field.
  String? _groupActivity;
  String get groupActivity => _groupActivity ?? '';
  set groupActivity(String? val) => _groupActivity = val;

  bool hasGroupActivity() => _groupActivity != null;

  // "Unity" field.
  String? _unity;
  String get unity => _unity ?? '';
  set unity(String? val) => _unity = val;

  bool hasUnity() => _unity != null;

  // "Cycle" field.
  int? _cycle;
  int get cycle => _cycle ?? 0;
  set cycle(int? val) => _cycle = val;

  void incrementCycle(int amount) => cycle = cycle + amount;

  bool hasCycle() => _cycle != null;

  // "EffectivityVisits" field.
  double? _effectivityVisits;
  double get effectivityVisits => _effectivityVisits ?? 0.0;
  set effectivityVisits(double? val) => _effectivityVisits = val;

  void incrementEffectivityVisits(double amount) =>
      effectivityVisits = effectivityVisits + amount;

  bool hasEffectivityVisits() => _effectivityVisits != null;

  // "Module_activity" field.
  String? _moduleActivity;
  String get moduleActivity => _moduleActivity ?? '';
  set moduleActivity(String? val) => _moduleActivity = val;

  bool hasModuleActivity() => _moduleActivity != null;

  // "Type_effectivity" field.
  String? _typeEffectivity;
  String get typeEffectivity => _typeEffectivity ?? '';
  set typeEffectivity(String? val) => _typeEffectivity = val;

  bool hasTypeEffectivity() => _typeEffectivity != null;

  // "EffectivityUnitys" field.
  int? _effectivityUnitys;
  int get effectivityUnitys => _effectivityUnitys ?? 0;
  set effectivityUnitys(int? val) => _effectivityUnitys = val;

  void incrementEffectivityUnitys(int amount) =>
      effectivityUnitys = effectivityUnitys + amount;

  bool hasEffectivityUnitys() => _effectivityUnitys != null;

  static ActivitiesStruct fromMap(Map<String, dynamic> data) =>
      ActivitiesStruct(
        idActivity: castToType<int>(data['Id_activity']),
        idCompany: castToType<int>(data['Id_company']),
        createdAt: data['Created_at'] as String?,
        nameActivity: data['Name_activity'] as String?,
        descripcionActivity: data['Descripcion_activity'] as String?,
        groupActivity: data['Group_activity'] as String?,
        unity: data['Unity'] as String?,
        cycle: castToType<int>(data['Cycle']),
        effectivityVisits: castToType<double>(data['EffectivityVisits']),
        moduleActivity: data['Module_activity'] as String?,
        typeEffectivity: data['Type_effectivity'] as String?,
        effectivityUnitys: castToType<int>(data['EffectivityUnitys']),
      );

  static ActivitiesStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivitiesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'Id_activity': _idActivity,
        'Id_company': _idCompany,
        'Created_at': _createdAt,
        'Name_activity': _nameActivity,
        'Descripcion_activity': _descripcionActivity,
        'Group_activity': _groupActivity,
        'Unity': _unity,
        'Cycle': _cycle,
        'EffectivityVisits': _effectivityVisits,
        'Module_activity': _moduleActivity,
        'Type_effectivity': _typeEffectivity,
        'EffectivityUnitys': _effectivityUnitys,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'Id_activity': serializeParam(
          _idActivity,
          ParamType.int,
        ),
        'Id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'Created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'Name_activity': serializeParam(
          _nameActivity,
          ParamType.String,
        ),
        'Descripcion_activity': serializeParam(
          _descripcionActivity,
          ParamType.String,
        ),
        'Group_activity': serializeParam(
          _groupActivity,
          ParamType.String,
        ),
        'Unity': serializeParam(
          _unity,
          ParamType.String,
        ),
        'Cycle': serializeParam(
          _cycle,
          ParamType.int,
        ),
        'EffectivityVisits': serializeParam(
          _effectivityVisits,
          ParamType.double,
        ),
        'Module_activity': serializeParam(
          _moduleActivity,
          ParamType.String,
        ),
        'Type_effectivity': serializeParam(
          _typeEffectivity,
          ParamType.String,
        ),
        'EffectivityUnitys': serializeParam(
          _effectivityUnitys,
          ParamType.int,
        ),
      }.withoutNulls;

  static ActivitiesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ActivitiesStruct(
        idActivity: deserializeParam(
          data['Id_activity'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['Id_company'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['Created_at'],
          ParamType.String,
          false,
        ),
        nameActivity: deserializeParam(
          data['Name_activity'],
          ParamType.String,
          false,
        ),
        descripcionActivity: deserializeParam(
          data['Descripcion_activity'],
          ParamType.String,
          false,
        ),
        groupActivity: deserializeParam(
          data['Group_activity'],
          ParamType.String,
          false,
        ),
        unity: deserializeParam(
          data['Unity'],
          ParamType.String,
          false,
        ),
        cycle: deserializeParam(
          data['Cycle'],
          ParamType.int,
          false,
        ),
        effectivityVisits: deserializeParam(
          data['EffectivityVisits'],
          ParamType.double,
          false,
        ),
        moduleActivity: deserializeParam(
          data['Module_activity'],
          ParamType.String,
          false,
        ),
        typeEffectivity: deserializeParam(
          data['Type_effectivity'],
          ParamType.String,
          false,
        ),
        effectivityUnitys: deserializeParam(
          data['EffectivityUnitys'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ActivitiesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ActivitiesStruct &&
        idActivity == other.idActivity &&
        idCompany == other.idCompany &&
        createdAt == other.createdAt &&
        nameActivity == other.nameActivity &&
        descripcionActivity == other.descripcionActivity &&
        groupActivity == other.groupActivity &&
        unity == other.unity &&
        cycle == other.cycle &&
        effectivityVisits == other.effectivityVisits &&
        moduleActivity == other.moduleActivity &&
        typeEffectivity == other.typeEffectivity &&
        effectivityUnitys == other.effectivityUnitys;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idActivity,
        idCompany,
        createdAt,
        nameActivity,
        descripcionActivity,
        groupActivity,
        unity,
        cycle,
        effectivityVisits,
        moduleActivity,
        typeEffectivity,
        effectivityUnitys
      ]);
}

ActivitiesStruct createActivitiesStruct({
  int? idActivity,
  int? idCompany,
  String? createdAt,
  String? nameActivity,
  String? descripcionActivity,
  String? groupActivity,
  String? unity,
  int? cycle,
  double? effectivityVisits,
  String? moduleActivity,
  String? typeEffectivity,
  int? effectivityUnitys,
}) =>
    ActivitiesStruct(
      idActivity: idActivity,
      idCompany: idCompany,
      createdAt: createdAt,
      nameActivity: nameActivity,
      descripcionActivity: descripcionActivity,
      groupActivity: groupActivity,
      unity: unity,
      cycle: cycle,
      effectivityVisits: effectivityVisits,
      moduleActivity: moduleActivity,
      typeEffectivity: typeEffectivity,
      effectivityUnitys: effectivityUnitys,
    );
