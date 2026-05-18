// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivitiesStatusStruct extends BaseStruct {
  ActivitiesStatusStruct({
    int? idActivityStatus,
    String? typeStatus,
    int? orderStatus,
    String? defaultStatus,
    String? nameStatus,
    String? factor,
    String? status,
  })  : _idActivityStatus = idActivityStatus,
        _typeStatus = typeStatus,
        _orderStatus = orderStatus,
        _defaultStatus = defaultStatus,
        _nameStatus = nameStatus,
        _factor = factor,
        _status = status;

  // "id_activity_status" field.
  int? _idActivityStatus;
  int get idActivityStatus => _idActivityStatus ?? 0;
  set idActivityStatus(int? val) => _idActivityStatus = val;

  void incrementIdActivityStatus(int amount) =>
      idActivityStatus = idActivityStatus + amount;

  bool hasIdActivityStatus() => _idActivityStatus != null;

  // "typeStatus" field.
  String? _typeStatus;
  String get typeStatus => _typeStatus ?? '';
  set typeStatus(String? val) => _typeStatus = val;

  bool hasTypeStatus() => _typeStatus != null;

  // "orderStatus" field.
  int? _orderStatus;
  int get orderStatus => _orderStatus ?? 0;
  set orderStatus(int? val) => _orderStatus = val;

  void incrementOrderStatus(int amount) => orderStatus = orderStatus + amount;

  bool hasOrderStatus() => _orderStatus != null;

  // "default_status" field.
  String? _defaultStatus;
  String get defaultStatus => _defaultStatus ?? '';
  set defaultStatus(String? val) => _defaultStatus = val;

  bool hasDefaultStatus() => _defaultStatus != null;

  // "nameStatus" field.
  String? _nameStatus;
  String get nameStatus => _nameStatus ?? '';
  set nameStatus(String? val) => _nameStatus = val;

  bool hasNameStatus() => _nameStatus != null;

  // "factor" field.
  String? _factor;
  String get factor => _factor ?? '';
  set factor(String? val) => _factor = val;

  bool hasFactor() => _factor != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  static ActivitiesStatusStruct fromMap(Map<String, dynamic> data) =>
      ActivitiesStatusStruct(
        idActivityStatus: castToType<int>(data['id_activity_status']),
        typeStatus: data['typeStatus'] as String?,
        orderStatus: castToType<int>(data['orderStatus']),
        defaultStatus: data['default_status'] as String?,
        nameStatus: data['nameStatus'] as String?,
        factor: data['factor'] as String?,
        status: data['status'] as String?,
      );

  static ActivitiesStatusStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivitiesStatusStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_activity_status': _idActivityStatus,
        'typeStatus': _typeStatus,
        'orderStatus': _orderStatus,
        'default_status': _defaultStatus,
        'nameStatus': _nameStatus,
        'factor': _factor,
        'status': _status,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_activity_status': serializeParam(
          _idActivityStatus,
          ParamType.int,
        ),
        'typeStatus': serializeParam(
          _typeStatus,
          ParamType.String,
        ),
        'orderStatus': serializeParam(
          _orderStatus,
          ParamType.int,
        ),
        'default_status': serializeParam(
          _defaultStatus,
          ParamType.String,
        ),
        'nameStatus': serializeParam(
          _nameStatus,
          ParamType.String,
        ),
        'factor': serializeParam(
          _factor,
          ParamType.String,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
      }.withoutNulls;

  static ActivitiesStatusStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      ActivitiesStatusStruct(
        idActivityStatus: deserializeParam(
          data['id_activity_status'],
          ParamType.int,
          false,
        ),
        typeStatus: deserializeParam(
          data['typeStatus'],
          ParamType.String,
          false,
        ),
        orderStatus: deserializeParam(
          data['orderStatus'],
          ParamType.int,
          false,
        ),
        defaultStatus: deserializeParam(
          data['default_status'],
          ParamType.String,
          false,
        ),
        nameStatus: deserializeParam(
          data['nameStatus'],
          ParamType.String,
          false,
        ),
        factor: deserializeParam(
          data['factor'],
          ParamType.String,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ActivitiesStatusStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ActivitiesStatusStruct &&
        idActivityStatus == other.idActivityStatus &&
        typeStatus == other.typeStatus &&
        orderStatus == other.orderStatus &&
        defaultStatus == other.defaultStatus &&
        nameStatus == other.nameStatus &&
        factor == other.factor &&
        status == other.status;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idActivityStatus,
        typeStatus,
        orderStatus,
        defaultStatus,
        nameStatus,
        factor,
        status
      ]);
}

ActivitiesStatusStruct createActivitiesStatusStruct({
  int? idActivityStatus,
  String? typeStatus,
  int? orderStatus,
  String? defaultStatus,
  String? nameStatus,
  String? factor,
  String? status,
}) =>
    ActivitiesStatusStruct(
      idActivityStatus: idActivityStatus,
      typeStatus: typeStatus,
      orderStatus: orderStatus,
      defaultStatus: defaultStatus,
      nameStatus: nameStatus,
      factor: factor,
      status: status,
    );
