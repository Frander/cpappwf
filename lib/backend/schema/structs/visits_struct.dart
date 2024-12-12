// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VisitsStruct extends BaseStruct {
  VisitsStruct({
    int? idVisit,
    int? idCompany,
    int? idActivity,
    int? idHeadquarter,
    int? idProduct,
    int? idBulk,
    int? idUser,
    int? idDevice,
    int? idStatus,
    String? createdAt,
    double? battery,
  })  : _idVisit = idVisit,
        _idCompany = idCompany,
        _idActivity = idActivity,
        _idHeadquarter = idHeadquarter,
        _idProduct = idProduct,
        _idBulk = idBulk,
        _idUser = idUser,
        _idDevice = idDevice,
        _idStatus = idStatus,
        _createdAt = createdAt,
        _battery = battery;

  // "Id_visit" field.
  int? _idVisit;
  int get idVisit => _idVisit ?? 0;
  set idVisit(int? val) => _idVisit = val;

  void incrementIdVisit(int amount) => idVisit = idVisit + amount;

  bool hasIdVisit() => _idVisit != null;

  // "Id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "Id_activity" field.
  int? _idActivity;
  int get idActivity => _idActivity ?? 0;
  set idActivity(int? val) => _idActivity = val;

  void incrementIdActivity(int amount) => idActivity = idActivity + amount;

  bool hasIdActivity() => _idActivity != null;

  // "Id_headquarter" field.
  int? _idHeadquarter;
  int get idHeadquarter => _idHeadquarter ?? 0;
  set idHeadquarter(int? val) => _idHeadquarter = val;

  void incrementIdHeadquarter(int amount) =>
      idHeadquarter = idHeadquarter + amount;

  bool hasIdHeadquarter() => _idHeadquarter != null;

  // "Id_product" field.
  int? _idProduct;
  int get idProduct => _idProduct ?? 0;
  set idProduct(int? val) => _idProduct = val;

  void incrementIdProduct(int amount) => idProduct = idProduct + amount;

  bool hasIdProduct() => _idProduct != null;

  // "Id_bulk" field.
  int? _idBulk;
  int get idBulk => _idBulk ?? 0;
  set idBulk(int? val) => _idBulk = val;

  void incrementIdBulk(int amount) => idBulk = idBulk + amount;

  bool hasIdBulk() => _idBulk != null;

  // "Id_user" field.
  int? _idUser;
  int get idUser => _idUser ?? 0;
  set idUser(int? val) => _idUser = val;

  void incrementIdUser(int amount) => idUser = idUser + amount;

  bool hasIdUser() => _idUser != null;

  // "Id_device" field.
  int? _idDevice;
  int get idDevice => _idDevice ?? 0;
  set idDevice(int? val) => _idDevice = val;

  void incrementIdDevice(int amount) => idDevice = idDevice + amount;

  bool hasIdDevice() => _idDevice != null;

  // "Id_status" field.
  int? _idStatus;
  int get idStatus => _idStatus ?? 0;
  set idStatus(int? val) => _idStatus = val;

  void incrementIdStatus(int amount) => idStatus = idStatus + amount;

  bool hasIdStatus() => _idStatus != null;

  // "Created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "Battery" field.
  double? _battery;
  double get battery => _battery ?? 0.0;
  set battery(double? val) => _battery = val;

  void incrementBattery(double amount) => battery = battery + amount;

  bool hasBattery() => _battery != null;

  static VisitsStruct fromMap(Map<String, dynamic> data) => VisitsStruct(
        idVisit: castToType<int>(data['Id_visit']),
        idCompany: castToType<int>(data['Id_company']),
        idActivity: castToType<int>(data['Id_activity']),
        idHeadquarter: castToType<int>(data['Id_headquarter']),
        idProduct: castToType<int>(data['Id_product']),
        idBulk: castToType<int>(data['Id_bulk']),
        idUser: castToType<int>(data['Id_user']),
        idDevice: castToType<int>(data['Id_device']),
        idStatus: castToType<int>(data['Id_status']),
        createdAt: data['Created_at'] as String?,
        battery: castToType<double>(data['Battery']),
      );

  static VisitsStruct? maybeFromMap(dynamic data) =>
      data is Map ? VisitsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'Id_visit': _idVisit,
        'Id_company': _idCompany,
        'Id_activity': _idActivity,
        'Id_headquarter': _idHeadquarter,
        'Id_product': _idProduct,
        'Id_bulk': _idBulk,
        'Id_user': _idUser,
        'Id_device': _idDevice,
        'Id_status': _idStatus,
        'Created_at': _createdAt,
        'Battery': _battery,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'Id_visit': serializeParam(
          _idVisit,
          ParamType.int,
        ),
        'Id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'Id_activity': serializeParam(
          _idActivity,
          ParamType.int,
        ),
        'Id_headquarter': serializeParam(
          _idHeadquarter,
          ParamType.int,
        ),
        'Id_product': serializeParam(
          _idProduct,
          ParamType.int,
        ),
        'Id_bulk': serializeParam(
          _idBulk,
          ParamType.int,
        ),
        'Id_user': serializeParam(
          _idUser,
          ParamType.int,
        ),
        'Id_device': serializeParam(
          _idDevice,
          ParamType.int,
        ),
        'Id_status': serializeParam(
          _idStatus,
          ParamType.int,
        ),
        'Created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'Battery': serializeParam(
          _battery,
          ParamType.double,
        ),
      }.withoutNulls;

  static VisitsStruct fromSerializableMap(Map<String, dynamic> data) =>
      VisitsStruct(
        idVisit: deserializeParam(
          data['Id_visit'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['Id_company'],
          ParamType.int,
          false,
        ),
        idActivity: deserializeParam(
          data['Id_activity'],
          ParamType.int,
          false,
        ),
        idHeadquarter: deserializeParam(
          data['Id_headquarter'],
          ParamType.int,
          false,
        ),
        idProduct: deserializeParam(
          data['Id_product'],
          ParamType.int,
          false,
        ),
        idBulk: deserializeParam(
          data['Id_bulk'],
          ParamType.int,
          false,
        ),
        idUser: deserializeParam(
          data['Id_user'],
          ParamType.int,
          false,
        ),
        idDevice: deserializeParam(
          data['Id_device'],
          ParamType.int,
          false,
        ),
        idStatus: deserializeParam(
          data['Id_status'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['Created_at'],
          ParamType.String,
          false,
        ),
        battery: deserializeParam(
          data['Battery'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'VisitsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is VisitsStruct &&
        idVisit == other.idVisit &&
        idCompany == other.idCompany &&
        idActivity == other.idActivity &&
        idHeadquarter == other.idHeadquarter &&
        idProduct == other.idProduct &&
        idBulk == other.idBulk &&
        idUser == other.idUser &&
        idDevice == other.idDevice &&
        idStatus == other.idStatus &&
        createdAt == other.createdAt &&
        battery == other.battery;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idVisit,
        idCompany,
        idActivity,
        idHeadquarter,
        idProduct,
        idBulk,
        idUser,
        idDevice,
        idStatus,
        createdAt,
        battery
      ]);
}

VisitsStruct createVisitsStruct({
  int? idVisit,
  int? idCompany,
  int? idActivity,
  int? idHeadquarter,
  int? idProduct,
  int? idBulk,
  int? idUser,
  int? idDevice,
  int? idStatus,
  String? createdAt,
  double? battery,
}) =>
    VisitsStruct(
      idVisit: idVisit,
      idCompany: idCompany,
      idActivity: idActivity,
      idHeadquarter: idHeadquarter,
      idProduct: idProduct,
      idBulk: idBulk,
      idUser: idUser,
      idDevice: idDevice,
      idStatus: idStatus,
      createdAt: createdAt,
      battery: battery,
    );
