// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivitiesStatusStruct extends BaseStruct {
  ActivitiesStatusStruct({
    int? idActivityStatus,
    int? idActivity,
    String? statusName,
    int? boton,
    int? factor,
    double? peso,
    String? color,
    int? castigo,
    int? orden,
    String? status,
    String? typeStatus,
  })  : _idActivityStatus = idActivityStatus,
        _idActivity = idActivity,
        _statusName = statusName,
        _boton = boton,
        _factor = factor,
        _peso = peso,
        _color = color,
        _castigo = castigo,
        _orden = orden,
        _status = status,
        _typeStatus = typeStatus;

  // "id_activity_status" field.
  int? _idActivityStatus;
  int get idActivityStatus => _idActivityStatus ?? 0;
  set idActivityStatus(int? val) => _idActivityStatus = val;

  void incrementIdActivityStatus(int amount) =>
      idActivityStatus = idActivityStatus + amount;

  bool hasIdActivityStatus() => _idActivityStatus != null;

  // "id_activity" field.
  int? _idActivity;
  int get idActivity => _idActivity ?? 0;
  set idActivity(int? val) => _idActivity = val;

  void incrementIdActivity(int amount) => idActivity = idActivity + amount;

  bool hasIdActivity() => _idActivity != null;

  // "status_name" field.
  String? _statusName;
  String get statusName => _statusName ?? '';
  set statusName(String? val) => _statusName = val;

  bool hasStatusName() => _statusName != null;

  // "boton" field.
  int? _boton;
  int get boton => _boton ?? 0;
  set boton(int? val) => _boton = val;

  void incrementBoton(int amount) => boton = boton + amount;

  bool hasBoton() => _boton != null;

  // "factor" field.
  int? _factor;
  int get factor => _factor ?? 0;
  set factor(int? val) => _factor = val;

  void incrementFactor(int amount) => factor = factor + amount;

  bool hasFactor() => _factor != null;

  // "peso" field.
  double? _peso;
  double get peso => _peso ?? 0.0;
  set peso(double? val) => _peso = val;

  void incrementPeso(double amount) => peso = peso + amount;

  bool hasPeso() => _peso != null;

  // "color" field.
  String? _color;
  String get color => _color ?? '';
  set color(String? val) => _color = val;

  bool hasColor() => _color != null;

  // "castigo" field.
  int? _castigo;
  int get castigo => _castigo ?? 0;
  set castigo(int? val) => _castigo = val;

  void incrementCastigo(int amount) => castigo = castigo + amount;

  bool hasCastigo() => _castigo != null;

  // "orden" field.
  int? _orden;
  int get orden => _orden ?? 0;
  set orden(int? val) => _orden = val;

  void incrementOrden(int amount) => orden = orden + amount;

  bool hasOrden() => _orden != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  // "type_status" field.
  String? _typeStatus;
  String get typeStatus => _typeStatus ?? '';
  set typeStatus(String? val) => _typeStatus = val;

  bool hasTypeStatus() => _typeStatus != null;

  static ActivitiesStatusStruct fromMap(Map<String, dynamic> data) =>
      ActivitiesStatusStruct(
        idActivityStatus: castToType<int>(data['id_activity_status']),
        idActivity: castToType<int>(data['id_activity']),
        statusName: data['status_name'] as String?,
        boton: castToType<int>(data['boton']),
        factor: castToType<int>(data['factor']),
        peso: castToType<double>(data['peso']),
        color: data['color'] as String?,
        castigo: castToType<int>(data['castigo']),
        orden: castToType<int>(data['orden']),
        status: data['status'] as String?,
        typeStatus: data['type_status'] as String?,
      );

  static ActivitiesStatusStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivitiesStatusStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_activity_status': _idActivityStatus,
        'id_activity': _idActivity,
        'status_name': _statusName,
        'boton': _boton,
        'factor': _factor,
        'peso': _peso,
        'color': _color,
        'castigo': _castigo,
        'orden': _orden,
        'status': _status,
        'type_status': _typeStatus,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_activity_status': serializeParam(
          _idActivityStatus,
          ParamType.int,
        ),
        'id_activity': serializeParam(
          _idActivity,
          ParamType.int,
        ),
        'status_name': serializeParam(
          _statusName,
          ParamType.String,
        ),
        'boton': serializeParam(
          _boton,
          ParamType.int,
        ),
        'factor': serializeParam(
          _factor,
          ParamType.int,
        ),
        'peso': serializeParam(
          _peso,
          ParamType.double,
        ),
        'color': serializeParam(
          _color,
          ParamType.String,
        ),
        'castigo': serializeParam(
          _castigo,
          ParamType.int,
        ),
        'orden': serializeParam(
          _orden,
          ParamType.int,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'type_status': serializeParam(
          _typeStatus,
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
        idActivity: deserializeParam(
          data['id_activity'],
          ParamType.int,
          false,
        ),
        statusName: deserializeParam(
          data['status_name'],
          ParamType.String,
          false,
        ),
        boton: deserializeParam(
          data['boton'],
          ParamType.int,
          false,
        ),
        factor: deserializeParam(
          data['factor'],
          ParamType.int,
          false,
        ),
        peso: deserializeParam(
          data['peso'],
          ParamType.double,
          false,
        ),
        color: deserializeParam(
          data['color'],
          ParamType.String,
          false,
        ),
        castigo: deserializeParam(
          data['castigo'],
          ParamType.int,
          false,
        ),
        orden: deserializeParam(
          data['orden'],
          ParamType.int,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
        typeStatus: deserializeParam(
          data['type_status'],
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
        idActivity == other.idActivity &&
        statusName == other.statusName &&
        boton == other.boton &&
        factor == other.factor &&
        peso == other.peso &&
        color == other.color &&
        castigo == other.castigo &&
        orden == other.orden &&
        status == other.status &&
        typeStatus == other.typeStatus;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idActivityStatus,
        idActivity,
        statusName,
        boton,
        factor,
        peso,
        color,
        castigo,
        orden,
        status,
        typeStatus
      ]);
}

ActivitiesStatusStruct createActivitiesStatusStruct({
  int? idActivityStatus,
  int? idActivity,
  String? statusName,
  int? boton,
  int? factor,
  double? peso,
  String? color,
  int? castigo,
  int? orden,
  String? status,
  String? typeStatus,
}) =>
    ActivitiesStatusStruct(
      idActivityStatus: idActivityStatus,
      idActivity: idActivity,
      statusName: statusName,
      boton: boton,
      factor: factor,
      peso: peso,
      color: color,
      castigo: castigo,
      orden: orden,
      status: status,
      typeStatus: typeStatus,
    );
