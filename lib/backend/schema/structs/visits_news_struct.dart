// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VisitsNewsStruct extends BaseStruct {
  VisitsNewsStruct({
    int? idNew,
    DateTime? createdAt,
    String? descripcionNew,
    List<String>? locationsAdd,
  })  : _idNew = idNew,
        _createdAt = createdAt,
        _descripcionNew = descripcionNew,
        _locationsAdd = locationsAdd;

  // "id_new" field.
  int? _idNew;
  int get idNew => _idNew ?? 0;
  set idNew(int? val) => _idNew = val;

  void incrementIdNew(int amount) => idNew = idNew + amount;

  bool hasIdNew() => _idNew != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "descripcion_new" field.
  String? _descripcionNew;
  String get descripcionNew => _descripcionNew ?? '';
  set descripcionNew(String? val) => _descripcionNew = val;

  bool hasDescripcionNew() => _descripcionNew != null;

  // "locations_add" field.
  List<String>? _locationsAdd;
  List<String> get locationsAdd => _locationsAdd ?? const [];
  set locationsAdd(List<String>? val) => _locationsAdd = val;

  void updateLocationsAdd(Function(List<String>) updateFn) {
    updateFn(_locationsAdd ??= []);
  }

  bool hasLocationsAdd() => _locationsAdd != null;

  static VisitsNewsStruct fromMap(Map<String, dynamic> data) =>
      VisitsNewsStruct(
        idNew: castToType<int>(data['id_new']),
        createdAt: data['created_at'] as DateTime?,
        descripcionNew: data['descripcion_new'] as String?,
        locationsAdd: getDataList(data['locations_add']),
      );

  static VisitsNewsStruct? maybeFromMap(dynamic data) => data is Map
      ? VisitsNewsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_new': _idNew,
        'created_at': _createdAt,
        'descripcion_new': _descripcionNew,
        'locations_add': _locationsAdd,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_new': serializeParam(
          _idNew,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'descripcion_new': serializeParam(
          _descripcionNew,
          ParamType.String,
        ),
        'locations_add': serializeParam(
          _locationsAdd,
          ParamType.String,
          isList: true,
        ),
      }.withoutNulls;

  static VisitsNewsStruct fromSerializableMap(Map<String, dynamic> data) =>
      VisitsNewsStruct(
        idNew: deserializeParam(
          data['id_new'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.DateTime,
          false,
        ),
        descripcionNew: deserializeParam(
          data['descripcion_new'],
          ParamType.String,
          false,
        ),
        locationsAdd: deserializeParam<String>(
          data['locations_add'],
          ParamType.String,
          true,
        ),
      );

  @override
  String toString() => 'VisitsNewsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is VisitsNewsStruct &&
        idNew == other.idNew &&
        createdAt == other.createdAt &&
        descripcionNew == other.descripcionNew &&
        listEquality.equals(locationsAdd, other.locationsAdd);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([idNew, createdAt, descripcionNew, locationsAdd]);
}

VisitsNewsStruct createVisitsNewsStruct({
  int? idNew,
  DateTime? createdAt,
  String? descripcionNew,
}) =>
    VisitsNewsStruct(
      idNew: idNew,
      createdAt: createdAt,
      descripcionNew: descripcionNew,
    );
