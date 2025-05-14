// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class NewsStruct extends BaseStruct {
  NewsStruct({
    int? idNew,
    int? idCompany,
    String? nameNew,
    String? descripcionActivity,
    int? order,
  })  : _idNew = idNew,
        _idCompany = idCompany,
        _nameNew = nameNew,
        _descripcionActivity = descripcionActivity,
        _order = order;

  // "id_new" field.
  int? _idNew;
  int get idNew => _idNew ?? 0;
  set idNew(int? val) => _idNew = val;

  void incrementIdNew(int amount) => idNew = idNew + amount;

  bool hasIdNew() => _idNew != null;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "name_new" field.
  String? _nameNew;
  String get nameNew => _nameNew ?? '';
  set nameNew(String? val) => _nameNew = val;

  bool hasNameNew() => _nameNew != null;

  // "descripcion_activity" field.
  String? _descripcionActivity;
  String get descripcionActivity => _descripcionActivity ?? '';
  set descripcionActivity(String? val) => _descripcionActivity = val;

  bool hasDescripcionActivity() => _descripcionActivity != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  set order(int? val) => _order = val;

  void incrementOrder(int amount) => order = order + amount;

  bool hasOrder() => _order != null;

  static NewsStruct fromMap(Map<String, dynamic> data) => NewsStruct(
        idNew: castToType<int>(data['id_new']),
        idCompany: castToType<int>(data['id_company']),
        nameNew: data['name_new'] as String?,
        descripcionActivity: data['descripcion_activity'] as String?,
        order: castToType<int>(data['order']),
      );

  static NewsStruct? maybeFromMap(dynamic data) =>
      data is Map ? NewsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_new': _idNew,
        'id_company': _idCompany,
        'name_new': _nameNew,
        'descripcion_activity': _descripcionActivity,
        'order': _order,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_new': serializeParam(
          _idNew,
          ParamType.int,
        ),
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'name_new': serializeParam(
          _nameNew,
          ParamType.String,
        ),
        'descripcion_activity': serializeParam(
          _descripcionActivity,
          ParamType.String,
        ),
        'order': serializeParam(
          _order,
          ParamType.int,
        ),
      }.withoutNulls;

  static NewsStruct fromSerializableMap(Map<String, dynamic> data) =>
      NewsStruct(
        idNew: deserializeParam(
          data['id_new'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        nameNew: deserializeParam(
          data['name_new'],
          ParamType.String,
          false,
        ),
        descripcionActivity: deserializeParam(
          data['descripcion_activity'],
          ParamType.String,
          false,
        ),
        order: deserializeParam(
          data['order'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'NewsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is NewsStruct &&
        idNew == other.idNew &&
        idCompany == other.idCompany &&
        nameNew == other.nameNew &&
        descripcionActivity == other.descripcionActivity &&
        order == other.order;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([idNew, idCompany, nameNew, descripcionActivity, order]);
}

NewsStruct createNewsStruct({
  int? idNew,
  int? idCompany,
  String? nameNew,
  String? descripcionActivity,
  int? order,
}) =>
    NewsStruct(
      idNew: idNew,
      idCompany: idCompany,
      nameNew: nameNew,
      descripcionActivity: descripcionActivity,
      order: order,
    );
