// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReadGeoStruct extends BaseStruct {
  ReadGeoStruct({
    double? latitude,
    double? longitude,
    double? altitude,
    double? errorHorizontal,
    DateTime? dateHourRead,
    String? method,
    double? speed,
    int? battery,
  })  : _latitude = latitude,
        _longitude = longitude,
        _altitude = altitude,
        _errorHorizontal = errorHorizontal,
        _dateHourRead = dateHourRead,
        _method = method,
        _speed = speed,
        _battery = battery;

  // "latitude" field.
  double? _latitude;
  double get latitude => _latitude ?? 0.0;
  set latitude(double? val) => _latitude = val;

  void incrementLatitude(double amount) => latitude = latitude + amount;

  bool hasLatitude() => _latitude != null;

  // "longitude" field.
  double? _longitude;
  double get longitude => _longitude ?? 0.0;
  set longitude(double? val) => _longitude = val;

  void incrementLongitude(double amount) => longitude = longitude + amount;

  bool hasLongitude() => _longitude != null;

  // "altitude" field.
  double? _altitude;
  double get altitude => _altitude ?? 0.0;
  set altitude(double? val) => _altitude = val;

  void incrementAltitude(double amount) => altitude = altitude + amount;

  bool hasAltitude() => _altitude != null;

  // "errorHorizontal" field.
  double? _errorHorizontal;
  double get errorHorizontal => _errorHorizontal ?? 0.0;
  set errorHorizontal(double? val) => _errorHorizontal = val;

  void incrementErrorHorizontal(double amount) =>
      errorHorizontal = errorHorizontal + amount;

  bool hasErrorHorizontal() => _errorHorizontal != null;

  // "dateHourRead" field.
  DateTime? _dateHourRead;
  DateTime? get dateHourRead => _dateHourRead;
  set dateHourRead(DateTime? val) => _dateHourRead = val;

  bool hasDateHourRead() => _dateHourRead != null;

  // "method" field — origen del punto ('LITE' | 'UKF_IMU' | 'UNKNOWN').
  String? _method;
  String get method => _method ?? 'UNKNOWN';
  set method(String? val) => _method = val;

  bool hasMethod() => _method != null;

  // "speed" field.
  double? _speed;
  double get speed => _speed ?? 0.0;
  set speed(double? val) => _speed = val;
  bool hasSpeed() => _speed != null;

  // "battery" field.
  int? _battery;
  int get battery => _battery ?? 0;
  set battery(int? val) => _battery = val;
  bool hasBattery() => _battery != null;

  static ReadGeoStruct fromMap(Map<String, dynamic> data) => ReadGeoStruct(
        latitude: castToType<double>(data['latitude']),
        longitude: castToType<double>(data['longitude']),
        altitude: castToType<double>(data['altitude']),
        errorHorizontal: castToType<double>(data['errorHorizontal']),
        dateHourRead: data['dateHourRead'] as DateTime?,
        method: data['method'] as String?,
        speed: castToType<double>(data['speed']),
        battery: castToType<int>(data['battery']),
      );

  static ReadGeoStruct? maybeFromMap(dynamic data) =>
      data is Map ? ReadGeoStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'latitude': _latitude,
        'longitude': _longitude,
        'altitude': _altitude,
        'errorHorizontal': _errorHorizontal,
        'dateHourRead': _dateHourRead,
        'method': _method,
        'speed': _speed,
        'battery': _battery,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'latitude': serializeParam(
          _latitude,
          ParamType.double,
        ),
        'longitude': serializeParam(
          _longitude,
          ParamType.double,
        ),
        'altitude': serializeParam(
          _altitude,
          ParamType.double,
        ),
        'errorHorizontal': serializeParam(
          _errorHorizontal,
          ParamType.double,
        ),
        'dateHourRead': serializeParam(
          _dateHourRead,
          ParamType.DateTime,
        ),
        'method': serializeParam(
          _method,
          ParamType.String,
        ),
        'speed': serializeParam(
          _speed,
          ParamType.double,
        ),
        'battery': serializeParam(
          _battery,
          ParamType.int,
        ),
      }.withoutNulls;

  static ReadGeoStruct fromSerializableMap(Map<String, dynamic> data) =>
      ReadGeoStruct(
        latitude: deserializeParam(
          data['latitude'],
          ParamType.double,
          false,
        ),
        longitude: deserializeParam(
          data['longitude'],
          ParamType.double,
          false,
        ),
        altitude: deserializeParam(
          data['altitude'],
          ParamType.double,
          false,
        ),
        errorHorizontal: deserializeParam(
          data['errorHorizontal'],
          ParamType.double,
          false,
        ),
        dateHourRead: deserializeParam(
          data['dateHourRead'],
          ParamType.DateTime,
          false,
        ),
        method: deserializeParam(
          data['method'],
          ParamType.String,
          false,
        ),
        speed: deserializeParam(
          data['speed'],
          ParamType.double,
          false,
        ),
        battery: deserializeParam(
          data['battery'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ReadGeoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ReadGeoStruct &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        altitude == other.altitude &&
        errorHorizontal == other.errorHorizontal &&
        dateHourRead == other.dateHourRead &&
        method == other.method &&
        speed == other.speed &&
        battery == other.battery;
  }

  @override
  int get hashCode => const ListEquality().hash(
      [latitude, longitude, altitude, errorHorizontal, dateHourRead, method, speed, battery]);
}

ReadGeoStruct createReadGeoStruct({
  double? latitude,
  double? longitude,
  double? altitude,
  double? errorHorizontal,
  DateTime? dateHourRead,
  String? method,
  double? speed,
  int? battery,
}) =>
    ReadGeoStruct(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      errorHorizontal: errorHorizontal,
      dateHourRead: dateHourRead,
      method: method,
      speed: speed,
      battery: battery,
    );
