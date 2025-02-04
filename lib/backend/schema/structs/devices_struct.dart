// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DevicesStruct extends BaseStruct {
  DevicesStruct({
    int? idDevice,
    int? idCompany,
    String? deviceName,
    String? cellPhone,
    String? serialId,
    String? imeI1,
    String? imeI2,
    String? model,
    String? state,
  })  : _idDevice = idDevice,
        _idCompany = idCompany,
        _deviceName = deviceName,
        _cellPhone = cellPhone,
        _serialId = serialId,
        _imeI1 = imeI1,
        _imeI2 = imeI2,
        _model = model,
        _state = state;

  // "id_device" field.
  int? _idDevice;
  int get idDevice => _idDevice ?? 0;
  set idDevice(int? val) => _idDevice = val;

  void incrementIdDevice(int amount) => idDevice = idDevice + amount;

  bool hasIdDevice() => _idDevice != null;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "device_name" field.
  String? _deviceName;
  String get deviceName => _deviceName ?? '';
  set deviceName(String? val) => _deviceName = val;

  bool hasDeviceName() => _deviceName != null;

  // "cellPhone" field.
  String? _cellPhone;
  String get cellPhone => _cellPhone ?? '';
  set cellPhone(String? val) => _cellPhone = val;

  bool hasCellPhone() => _cellPhone != null;

  // "serial_id" field.
  String? _serialId;
  String get serialId => _serialId ?? '';
  set serialId(String? val) => _serialId = val;

  bool hasSerialId() => _serialId != null;

  // "imeI1" field.
  String? _imeI1;
  String get imeI1 => _imeI1 ?? '';
  set imeI1(String? val) => _imeI1 = val;

  bool hasImeI1() => _imeI1 != null;

  // "imeI2" field.
  String? _imeI2;
  String get imeI2 => _imeI2 ?? '';
  set imeI2(String? val) => _imeI2 = val;

  bool hasImeI2() => _imeI2 != null;

  // "model" field.
  String? _model;
  String get model => _model ?? '';
  set model(String? val) => _model = val;

  bool hasModel() => _model != null;

  // "state" field.
  String? _state;
  String get state => _state ?? '';
  set state(String? val) => _state = val;

  bool hasState() => _state != null;

  static DevicesStruct fromMap(Map<String, dynamic> data) => DevicesStruct(
        idDevice: castToType<int>(data['id_device']),
        idCompany: castToType<int>(data['id_company']),
        deviceName: data['device_name'] as String?,
        cellPhone: data['cellPhone'] as String?,
        serialId: data['serial_id'] as String?,
        imeI1: data['imeI1'] as String?,
        imeI2: data['imeI2'] as String?,
        model: data['model'] as String?,
        state: data['state'] as String?,
      );

  static DevicesStruct? maybeFromMap(dynamic data) =>
      data is Map ? DevicesStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_device': _idDevice,
        'id_company': _idCompany,
        'device_name': _deviceName,
        'cellPhone': _cellPhone,
        'serial_id': _serialId,
        'imeI1': _imeI1,
        'imeI2': _imeI2,
        'model': _model,
        'state': _state,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_device': serializeParam(
          _idDevice,
          ParamType.int,
        ),
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'device_name': serializeParam(
          _deviceName,
          ParamType.String,
        ),
        'cellPhone': serializeParam(
          _cellPhone,
          ParamType.String,
        ),
        'serial_id': serializeParam(
          _serialId,
          ParamType.String,
        ),
        'imeI1': serializeParam(
          _imeI1,
          ParamType.String,
        ),
        'imeI2': serializeParam(
          _imeI2,
          ParamType.String,
        ),
        'model': serializeParam(
          _model,
          ParamType.String,
        ),
        'state': serializeParam(
          _state,
          ParamType.String,
        ),
      }.withoutNulls;

  static DevicesStruct fromSerializableMap(Map<String, dynamic> data) =>
      DevicesStruct(
        idDevice: deserializeParam(
          data['id_device'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        deviceName: deserializeParam(
          data['device_name'],
          ParamType.String,
          false,
        ),
        cellPhone: deserializeParam(
          data['cellPhone'],
          ParamType.String,
          false,
        ),
        serialId: deserializeParam(
          data['serial_id'],
          ParamType.String,
          false,
        ),
        imeI1: deserializeParam(
          data['imeI1'],
          ParamType.String,
          false,
        ),
        imeI2: deserializeParam(
          data['imeI2'],
          ParamType.String,
          false,
        ),
        model: deserializeParam(
          data['model'],
          ParamType.String,
          false,
        ),
        state: deserializeParam(
          data['state'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'DevicesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is DevicesStruct &&
        idDevice == other.idDevice &&
        idCompany == other.idCompany &&
        deviceName == other.deviceName &&
        cellPhone == other.cellPhone &&
        serialId == other.serialId &&
        imeI1 == other.imeI1 &&
        imeI2 == other.imeI2 &&
        model == other.model &&
        state == other.state;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idDevice,
        idCompany,
        deviceName,
        cellPhone,
        serialId,
        imeI1,
        imeI2,
        model,
        state
      ]);
}

DevicesStruct createDevicesStruct({
  int? idDevice,
  int? idCompany,
  String? deviceName,
  String? cellPhone,
  String? serialId,
  String? imeI1,
  String? imeI2,
  String? model,
  String? state,
}) =>
    DevicesStruct(
      idDevice: idDevice,
      idCompany: idCompany,
      deviceName: deviceName,
      cellPhone: cellPhone,
      serialId: serialId,
      imeI1: imeI1,
      imeI2: imeI2,
      model: model,
      state: state,
    );
