// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CompaniesStruct extends BaseStruct {
  CompaniesStruct({
    int? idCompany,
    String? nameCompany,
    String? businessName,
    String? nit,
    String? address,
    String? telePhone,
    double? latitudeExtractor,
    double? longitudeExtractor,
  })  : _idCompany = idCompany,
        _nameCompany = nameCompany,
        _businessName = businessName,
        _nit = nit,
        _address = address,
        _telePhone = telePhone,
        _latitudeExtractor = latitudeExtractor,
        _longitudeExtractor = longitudeExtractor;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "name_company" field.
  String? _nameCompany;
  String get nameCompany => _nameCompany ?? '';
  set nameCompany(String? val) => _nameCompany = val;

  bool hasNameCompany() => _nameCompany != null;

  // "business_name" field.
  String? _businessName;
  String get businessName => _businessName ?? '';
  set businessName(String? val) => _businessName = val;

  bool hasBusinessName() => _businessName != null;

  // "nit" field.
  String? _nit;
  String get nit => _nit ?? '';
  set nit(String? val) => _nit = val;

  bool hasNit() => _nit != null;

  // "address" field.
  String? _address;
  String get address => _address ?? '';
  set address(String? val) => _address = val;

  bool hasAddress() => _address != null;

  // "telePhone" field.
  String? _telePhone;
  String get telePhone => _telePhone ?? '';
  set telePhone(String? val) => _telePhone = val;

  bool hasTelePhone() => _telePhone != null;

  // "latitude_extractor" field.
  double? _latitudeExtractor;
  double get latitudeExtractor => _latitudeExtractor ?? 0.0;
  set latitudeExtractor(double? val) => _latitudeExtractor = val;

  bool hasLatitudeExtractor() => _latitudeExtractor != null;

  // "longitude_extractor" field.
  double? _longitudeExtractor;
  double get longitudeExtractor => _longitudeExtractor ?? 0.0;
  set longitudeExtractor(double? val) => _longitudeExtractor = val;

  bool hasLongitudeExtractor() => _longitudeExtractor != null;

  static CompaniesStruct fromMap(Map<String, dynamic> data) => CompaniesStruct(
        idCompany: castToType<int>(data['id_company']),
        nameCompany: data['name_company'] as String?,
        businessName: data['business_name'] as String?,
        nit: data['nit'] as String?,
        address: data['address'] as String?,
        telePhone: data['telePhone'] as String?,
        latitudeExtractor: castToType<double>(data['latitude_extractor']),
        longitudeExtractor: castToType<double>(data['longitude_extractor']),
      );

  static CompaniesStruct? maybeFromMap(dynamic data) => data is Map
      ? CompaniesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_company': _idCompany,
        'name_company': _nameCompany,
        'business_name': _businessName,
        'nit': _nit,
        'address': _address,
        'telePhone': _telePhone,
        'latitude_extractor': _latitudeExtractor,
        'longitude_extractor': _longitudeExtractor,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'name_company': serializeParam(
          _nameCompany,
          ParamType.String,
        ),
        'business_name': serializeParam(
          _businessName,
          ParamType.String,
        ),
        'nit': serializeParam(
          _nit,
          ParamType.String,
        ),
        'address': serializeParam(
          _address,
          ParamType.String,
        ),
        'telePhone': serializeParam(
          _telePhone,
          ParamType.String,
        ),
        'latitude_extractor': serializeParam(
          _latitudeExtractor,
          ParamType.double,
        ),
        'longitude_extractor': serializeParam(
          _longitudeExtractor,
          ParamType.double,
        ),
      }.withoutNulls;

  static CompaniesStruct fromSerializableMap(Map<String, dynamic> data) =>
      CompaniesStruct(
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        nameCompany: deserializeParam(
          data['name_company'],
          ParamType.String,
          false,
        ),
        businessName: deserializeParam(
          data['business_name'],
          ParamType.String,
          false,
        ),
        nit: deserializeParam(
          data['nit'],
          ParamType.String,
          false,
        ),
        address: deserializeParam(
          data['address'],
          ParamType.String,
          false,
        ),
        telePhone: deserializeParam(
          data['telePhone'],
          ParamType.String,
          false,
        ),
        latitudeExtractor: deserializeParam(
          data['latitude_extractor'],
          ParamType.double,
          false,
        ),
        longitudeExtractor: deserializeParam(
          data['longitude_extractor'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'CompaniesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CompaniesStruct &&
        idCompany == other.idCompany &&
        nameCompany == other.nameCompany &&
        businessName == other.businessName &&
        nit == other.nit &&
        address == other.address &&
        telePhone == other.telePhone &&
        latitudeExtractor == other.latitudeExtractor &&
        longitudeExtractor == other.longitudeExtractor;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([idCompany, nameCompany, businessName, nit, address, telePhone, latitudeExtractor, longitudeExtractor]);
}

CompaniesStruct createCompaniesStruct({
  int? idCompany,
  String? nameCompany,
  String? businessName,
  String? nit,
  String? address,
  String? telePhone,
  double? latitudeExtractor,
  double? longitudeExtractor,
}) =>
    CompaniesStruct(
      idCompany: idCompany,
      nameCompany: nameCompany,
      businessName: businessName,
      nit: nit,
      address: address,
      telePhone: telePhone,
      latitudeExtractor: latitudeExtractor,
      longitudeExtractor: longitudeExtractor,
    );
