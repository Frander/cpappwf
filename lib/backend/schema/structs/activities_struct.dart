// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivitiesStruct extends BaseStruct {
  ActivitiesStruct({
    int? idActivity,
    String? nameActivity,
    String? groupActivity,
    String? unity,
    int? cycle,
    int? effectivityUnitys,
    int? effectivityVisits,
    String? typeEffectivity,
    String? moduleActivity,
    bool? isSync,
    bool? isSyncFull,
    bool? trackingHeadquarter,
  })  : _idActivity = idActivity,
        _nameActivity = nameActivity,
        _groupActivity = groupActivity,
        _unity = unity,
        _cycle = cycle,
        _effectivityUnitys = effectivityUnitys,
        _effectivityVisits = effectivityVisits,
        _typeEffectivity = typeEffectivity,
        _moduleActivity = moduleActivity,
        _isSync = isSync,
        _isSyncFull = isSyncFull,
        _trackingHeadquarter = trackingHeadquarter;

  // "id_activity" field.
  int? _idActivity;
  int get idActivity => _idActivity ?? 0;
  set idActivity(int? val) => _idActivity = val;

  void incrementIdActivity(int amount) => idActivity = idActivity + amount;

  bool hasIdActivity() => _idActivity != null;

  // "name_activity" field.
  String? _nameActivity;
  String get nameActivity => _nameActivity ?? '';
  set nameActivity(String? val) => _nameActivity = val;

  bool hasNameActivity() => _nameActivity != null;

  // "group_activity" field.
  String? _groupActivity;
  String get groupActivity => _groupActivity ?? '';
  set groupActivity(String? val) => _groupActivity = val;

  bool hasGroupActivity() => _groupActivity != null;

  // "unity" field.
  String? _unity;
  String get unity => _unity ?? '';
  set unity(String? val) => _unity = val;

  bool hasUnity() => _unity != null;

  // "cycle" field.
  int? _cycle;
  int get cycle => _cycle ?? 0;
  set cycle(int? val) => _cycle = val;

  void incrementCycle(int amount) => cycle = cycle + amount;

  bool hasCycle() => _cycle != null;

  // "effectivity_unitys" field.
  int? _effectivityUnitys;
  int get effectivityUnitys => _effectivityUnitys ?? 0;
  set effectivityUnitys(int? val) => _effectivityUnitys = val;

  void incrementEffectivityUnitys(int amount) =>
      effectivityUnitys = effectivityUnitys + amount;

  bool hasEffectivityUnitys() => _effectivityUnitys != null;

  // "effectivity_visits" field.
  int? _effectivityVisits;
  int get effectivityVisits => _effectivityVisits ?? 0;
  set effectivityVisits(int? val) => _effectivityVisits = val;

  void incrementEffectivityVisits(int amount) =>
      effectivityVisits = effectivityVisits + amount;

  bool hasEffectivityVisits() => _effectivityVisits != null;

  // "type_effectivity" field.
  String? _typeEffectivity;
  String get typeEffectivity => _typeEffectivity ?? '';
  set typeEffectivity(String? val) => _typeEffectivity = val;

  bool hasTypeEffectivity() => _typeEffectivity != null;

  // "module_activity" field.
  String? _moduleActivity;
  String get moduleActivity => _moduleActivity ?? '';
  set moduleActivity(String? val) => _moduleActivity = val;

  bool hasModuleActivity() => _moduleActivity != null;

  // "is_sync_full" field.
  bool? _isSyncFull;
  bool get isSyncFull => _isSyncFull ?? false;
  set isSyncFull(bool? val) => _isSyncFull = val;

  bool hasIsSyncFull() => _isSyncFull != null;

  // "is_sync" field.
  bool? _isSync;
  bool get isSync => _isSync ?? false;
  set isSync(bool? val) => _isSync = val;

  bool hasIsSync() => _isSync != null;

  // "tracking_headquarter" field.
  bool? _trackingHeadquarter;
  bool get trackingHeadquarter => _trackingHeadquarter ?? false;
  set trackingHeadquarter(bool? val) => _trackingHeadquarter = val;

  bool hasTrackingHeadquarter() => _trackingHeadquarter != null;

  static ActivitiesStruct fromMap(Map<String, dynamic> data) =>
      ActivitiesStruct(
        idActivity: castToType<int>(data['id_activity']),
        nameActivity: data['name_activity'] as String?,
        groupActivity: data['group_activity'] as String?,
        unity: data['unity'] as String?,
        cycle: castToType<int>(data['cycle']),
        effectivityUnitys: castToType<int>(data['effectivity_unitys']),
        effectivityVisits: castToType<int>(data['effectivity_visits']),
        typeEffectivity: data['type_effectivity'] as String?,
        moduleActivity: data['module_activity'] as String?,
        isSync: data['is_sync'] == 1 || data['is_sync'] == true,
        isSyncFull: data['is_sync_full'] == 1 || data['is_sync_full'] == true,
        trackingHeadquarter: data['tracking_headquarter'] == 1 || data['tracking_headquarter'] == true,
      );

  static ActivitiesStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivitiesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_activity': _idActivity,
        'name_activity': _nameActivity,
        'group_activity': _groupActivity,
        'unity': _unity,
        'cycle': _cycle,
        'effectivity_unitys': _effectivityUnitys,
        'effectivity_visits': _effectivityVisits,
        'type_effectivity': _typeEffectivity,
        'module_activity': _moduleActivity,
        'is_sync': _isSync,
        'is_sync_full': _isSyncFull,
        'tracking_headquarter': _trackingHeadquarter,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_activity': serializeParam(
          _idActivity,
          ParamType.int,
        ),
        'name_activity': serializeParam(
          _nameActivity,
          ParamType.String,
        ),
        'group_activity': serializeParam(
          _groupActivity,
          ParamType.String,
        ),
        'unity': serializeParam(
          _unity,
          ParamType.String,
        ),
        'cycle': serializeParam(
          _cycle,
          ParamType.int,
        ),
        'effectivity_unitys': serializeParam(
          _effectivityUnitys,
          ParamType.int,
        ),
        'effectivity_visits': serializeParam(
          _effectivityVisits,
          ParamType.int,
        ),
        'type_effectivity': serializeParam(
          _typeEffectivity,
          ParamType.String,
        ),
        'module_activity': serializeParam(
          _moduleActivity,
          ParamType.String,
        ),
        'is_sync': serializeParam(
          _isSync,
          ParamType.bool,
        ),
        'is_sync_full': serializeParam(
          _isSyncFull,
          ParamType.bool,
        ),
        'tracking_headquarter': serializeParam(
          _trackingHeadquarter,
          ParamType.bool,
        ),
      }.withoutNulls;

  static ActivitiesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ActivitiesStruct(
        idActivity: deserializeParam(
          data['id_activity'],
          ParamType.int,
          false,
        ),
        nameActivity: deserializeParam(
          data['name_activity'],
          ParamType.String,
          false,
        ),
        groupActivity: deserializeParam(
          data['group_activity'],
          ParamType.String,
          false,
        ),
        unity: deserializeParam(
          data['unity'],
          ParamType.String,
          false,
        ),
        cycle: deserializeParam(
          data['cycle'],
          ParamType.int,
          false,
        ),
        effectivityUnitys: deserializeParam(
          data['effectivity_unitys'],
          ParamType.int,
          false,
        ),
        effectivityVisits: deserializeParam(
          data['effectivity_visits'],
          ParamType.int,
          false,
        ),
        typeEffectivity: deserializeParam(
          data['type_effectivity'],
          ParamType.String,
          false,
        ),
        moduleActivity: deserializeParam(
          data['module_activity'],
          ParamType.String,
          false,
        ),
        isSync: deserializeParam(
          data['is_sync'],
          ParamType.bool,
          false,
        ),
        isSyncFull: deserializeParam(
          data['is_sync_full'],
          ParamType.bool,
          false,
        ),
        trackingHeadquarter: deserializeParam(
          data['tracking_headquarter'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'ActivitiesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ActivitiesStruct &&
        idActivity == other.idActivity &&
        nameActivity == other.nameActivity &&
        groupActivity == other.groupActivity &&
        unity == other.unity &&
        cycle == other.cycle &&
        effectivityUnitys == other.effectivityUnitys &&
        effectivityVisits == other.effectivityVisits &&
        typeEffectivity == other.typeEffectivity &&
        moduleActivity == other.moduleActivity &&
        isSync == other.isSync &&
        isSyncFull == other.isSyncFull &&
        trackingHeadquarter == other.trackingHeadquarter;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idActivity,
        nameActivity,
        groupActivity,
        unity,
        cycle,
        effectivityUnitys,
        effectivityVisits,
        typeEffectivity,
        moduleActivity,
        isSync,
        isSyncFull,
        trackingHeadquarter
      ]);
}

ActivitiesStruct createActivitiesStruct({
  int? idActivity,
  String? nameActivity,
  String? groupActivity,
  String? unity,
  int? cycle,
  int? effectivityUnitys,
  int? effectivityVisits,
  String? typeEffectivity,
  String? moduleActivity,
  bool? isSync,
  bool? isSyncFull,
  bool? trackingHeadquarter,
}) =>
    ActivitiesStruct(
      idActivity: idActivity,
      nameActivity: nameActivity,
      groupActivity: groupActivity,
      unity: unity,
      cycle: cycle,
      effectivityUnitys: effectivityUnitys,
      effectivityVisits: effectivityVisits,
      typeEffectivity: typeEffectivity,
      moduleActivity: moduleActivity,
      isSync: isSync,
      isSyncFull: isSyncFull,
      trackingHeadquarter: trackingHeadquarter,
    );
