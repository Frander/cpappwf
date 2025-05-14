// ignore_for_file: unnecessary_getters_setters


import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VisitsStruct extends BaseStruct {
  VisitsStruct({
    int? idVisit,
    int? idCompany,
    int? idActivity,
    int? idHeadquarter,
    int? idProduct,
    int? idUser,
    int? idDevice,
    List<String>? locationsAdd,
    String? locationDefault,
    int? idStatus,
    DateTime? createdAt,
    List<ActivitiesStatusStruct>? statusAdd,
  })  : _idVisit = idVisit,
        _idCompany = idCompany,
        _idActivity = idActivity,
        _idHeadquarter = idHeadquarter,
        _idProduct = idProduct,
        _idUser = idUser,
        _idDevice = idDevice,
        _locationsAdd = locationsAdd,
        _locationDefault = locationDefault,
        _idStatus = idStatus,
        _createdAt = createdAt,
        _statusAdd = statusAdd;

  // "id_visit" field.
  int? _idVisit;
  int get idVisit => _idVisit ?? 0;
  set idVisit(int? val) => _idVisit = val;

  void incrementIdVisit(int amount) => idVisit = idVisit + amount;

  bool hasIdVisit() => _idVisit != null;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "id_activity" field.
  int? _idActivity;
  int get idActivity => _idActivity ?? 0;
  set idActivity(int? val) => _idActivity = val;

  void incrementIdActivity(int amount) => idActivity = idActivity + amount;

  bool hasIdActivity() => _idActivity != null;

  // "id_headquarter" field.
  int? _idHeadquarter;
  int get idHeadquarter => _idHeadquarter ?? 0;
  set idHeadquarter(int? val) => _idHeadquarter = val;

  void incrementIdHeadquarter(int amount) =>
      idHeadquarter = idHeadquarter + amount;

  bool hasIdHeadquarter() => _idHeadquarter != null;

  // "id_product" field.
  int? _idProduct;
  int get idProduct => _idProduct ?? 0;
  set idProduct(int? val) => _idProduct = val;

  void incrementIdProduct(int amount) => idProduct = idProduct + amount;

  bool hasIdProduct() => _idProduct != null;

  // "id_user" field.
  int? _idUser;
  int get idUser => _idUser ?? 0;
  set idUser(int? val) => _idUser = val;

  void incrementIdUser(int amount) => idUser = idUser + amount;

  bool hasIdUser() => _idUser != null;

  // "id_device" field.
  int? _idDevice;
  int get idDevice => _idDevice ?? 0;
  set idDevice(int? val) => _idDevice = val;

  void incrementIdDevice(int amount) => idDevice = idDevice + amount;

  bool hasIdDevice() => _idDevice != null;

  // "locations_add" field.
  List<String>? _locationsAdd;
  List<String> get locationsAdd => _locationsAdd ?? const [];
  set locationsAdd(List<String>? val) => _locationsAdd = val;

  void updateLocationsAdd(Function(List<String>) updateFn) {
    updateFn(_locationsAdd ??= []);
  }

  bool hasLocationsAdd() => _locationsAdd != null;

  // "location_default" field.
  String? _locationDefault;
  String get locationDefault => _locationDefault ?? '';
  set locationDefault(String? val) => _locationDefault = val;

  bool hasLocationDefault() => _locationDefault != null;

  // "id_status" field.
  int? _idStatus;
  int get idStatus => _idStatus ?? 0;
  set idStatus(int? val) => _idStatus = val;

  void incrementIdStatus(int amount) => idStatus = idStatus + amount;

  bool hasIdStatus() => _idStatus != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "Status_add" field.
  List<ActivitiesStatusStruct>? _statusAdd;
  List<ActivitiesStatusStruct> get statusAdd => _statusAdd ?? const [];
  set statusAdd(List<ActivitiesStatusStruct>? val) => _statusAdd = val;

  void updateStatusAdd(Function(List<ActivitiesStatusStruct>) updateFn) {
    updateFn(_statusAdd ??= []);
  }

  bool hasStatusAdd() => _statusAdd != null;

  static VisitsStruct fromMap(Map<String, dynamic> data) => VisitsStruct(
        idVisit: castToType<int>(data['id_visit']),
        idCompany: castToType<int>(data['id_company']),
        idActivity: castToType<int>(data['id_activity']),
        idHeadquarter: castToType<int>(data['id_headquarter']),
        idProduct: castToType<int>(data['id_product']),
        idUser: castToType<int>(data['id_user']),
        idDevice: castToType<int>(data['id_device']),
        locationsAdd: getDataList(data['locations_add']),
        locationDefault: data['location_default'] as String?,
        idStatus: castToType<int>(data['id_status']),
        createdAt: data['created_at'] as DateTime?,
        statusAdd: getStructList(
          data['Status_add'],
          ActivitiesStatusStruct.fromMap,
        ),
      );

  static VisitsStruct? maybeFromMap(dynamic data) =>
      data is Map ? VisitsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_visit': _idVisit,
        'id_company': _idCompany,
        'id_activity': _idActivity,
        'id_headquarter': _idHeadquarter,
        'id_product': _idProduct,
        'id_user': _idUser,
        'id_device': _idDevice,
        'locations_add': _locationsAdd,
        'location_default': _locationDefault,
        'id_status': _idStatus,
        'created_at': _createdAt,
        'Status_add': _statusAdd?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_visit': serializeParam(
          _idVisit,
          ParamType.int,
        ),
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'id_activity': serializeParam(
          _idActivity,
          ParamType.int,
        ),
        'id_headquarter': serializeParam(
          _idHeadquarter,
          ParamType.int,
        ),
        'id_product': serializeParam(
          _idProduct,
          ParamType.int,
        ),
        'id_user': serializeParam(
          _idUser,
          ParamType.int,
        ),
        'id_device': serializeParam(
          _idDevice,
          ParamType.int,
        ),
        'locations_add': serializeParam(
          _locationsAdd,
          ParamType.String,
          isList: true,
        ),
        'location_default': serializeParam(
          _locationDefault,
          ParamType.String,
        ),
        'id_status': serializeParam(
          _idStatus,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'Status_add': serializeParam(
          _statusAdd,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static VisitsStruct fromSerializableMap(Map<String, dynamic> data) =>
      VisitsStruct(
        idVisit: deserializeParam(
          data['id_visit'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        idActivity: deserializeParam(
          data['id_activity'],
          ParamType.int,
          false,
        ),
        idHeadquarter: deserializeParam(
          data['id_headquarter'],
          ParamType.int,
          false,
        ),
        idProduct: deserializeParam(
          data['id_product'],
          ParamType.int,
          false,
        ),
        idUser: deserializeParam(
          data['id_user'],
          ParamType.int,
          false,
        ),
        idDevice: deserializeParam(
          data['id_device'],
          ParamType.int,
          false,
        ),
        locationsAdd: deserializeParam<String>(
          data['locations_add'],
          ParamType.String,
          true,
        ),
        locationDefault: deserializeParam(
          data['location_default'],
          ParamType.String,
          false,
        ),
        idStatus: deserializeParam(
          data['id_status'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.DateTime,
          false,
        ),
        statusAdd: deserializeStructParam<ActivitiesStatusStruct>(
          data['Status_add'],
          ParamType.DataStruct,
          true,
          structBuilder: ActivitiesStatusStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'VisitsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is VisitsStruct &&
        idVisit == other.idVisit &&
        idCompany == other.idCompany &&
        idActivity == other.idActivity &&
        idHeadquarter == other.idHeadquarter &&
        idProduct == other.idProduct &&
        idUser == other.idUser &&
        idDevice == other.idDevice &&
        listEquality.equals(locationsAdd, other.locationsAdd) &&
        locationDefault == other.locationDefault &&
        idStatus == other.idStatus &&
        createdAt == other.createdAt &&
        listEquality.equals(statusAdd, other.statusAdd);
  }

  @override
  int get hashCode => const ListEquality().hash([
        idVisit,
        idCompany,
        idActivity,
        idHeadquarter,
        idProduct,
        idUser,
        idDevice,
        locationsAdd,
        locationDefault,
        idStatus,
        createdAt,
        statusAdd
      ]);
}

VisitsStruct createVisitsStruct({
  int? idVisit,
  int? idCompany,
  int? idActivity,
  int? idHeadquarter,
  int? idProduct,
  int? idUser,
  int? idDevice,
  String? locationDefault,
  int? idStatus,
  DateTime? createdAt,
}) =>
    VisitsStruct(
      idVisit: idVisit,
      idCompany: idCompany,
      idActivity: idActivity,
      idHeadquarter: idHeadquarter,
      idProduct: idProduct,
      idUser: idUser,
      idDevice: idDevice,
      locationDefault: locationDefault,
      idStatus: idStatus,
      createdAt: createdAt,
    );
