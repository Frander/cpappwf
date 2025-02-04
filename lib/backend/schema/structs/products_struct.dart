// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ProductsStruct extends BaseStruct {
  ProductsStruct({
    int? idProduct,
    int? idHeadquarter,
    String? rfid,
    String? stateProduct,
    String? descriptionProduct,
    String? locationRaw,
    int? line,
    int? palm,
  })  : _idProduct = idProduct,
        _idHeadquarter = idHeadquarter,
        _rfid = rfid,
        _stateProduct = stateProduct,
        _descriptionProduct = descriptionProduct,
        _locationRaw = locationRaw,
        _line = line,
        _palm = palm;

  // "id_product" field.
  int? _idProduct;
  int get idProduct => _idProduct ?? 0;
  set idProduct(int? val) => _idProduct = val;

  void incrementIdProduct(int amount) => idProduct = idProduct + amount;

  bool hasIdProduct() => _idProduct != null;

  // "id_headquarter" field.
  int? _idHeadquarter;
  int get idHeadquarter => _idHeadquarter ?? 0;
  set idHeadquarter(int? val) => _idHeadquarter = val;

  void incrementIdHeadquarter(int amount) =>
      idHeadquarter = idHeadquarter + amount;

  bool hasIdHeadquarter() => _idHeadquarter != null;

  // "rfid" field.
  String? _rfid;
  String get rfid => _rfid ?? '';
  set rfid(String? val) => _rfid = val;

  bool hasRfid() => _rfid != null;

  // "state_product" field.
  String? _stateProduct;
  String get stateProduct => _stateProduct ?? '';
  set stateProduct(String? val) => _stateProduct = val;

  bool hasStateProduct() => _stateProduct != null;

  // "description_product" field.
  String? _descriptionProduct;
  String get descriptionProduct => _descriptionProduct ?? '';
  set descriptionProduct(String? val) => _descriptionProduct = val;

  bool hasDescriptionProduct() => _descriptionProduct != null;

  // "location_raw" field.
  String? _locationRaw;
  String get locationRaw => _locationRaw ?? '';
  set locationRaw(String? val) => _locationRaw = val;

  bool hasLocationRaw() => _locationRaw != null;

  // "line" field.
  int? _line;
  int get line => _line ?? 0;
  set line(int? val) => _line = val;

  void incrementLine(int amount) => line = line + amount;

  bool hasLine() => _line != null;

  // "palm" field.
  int? _palm;
  int get palm => _palm ?? 0;
  set palm(int? val) => _palm = val;

  void incrementPalm(int amount) => palm = palm + amount;

  bool hasPalm() => _palm != null;

  static ProductsStruct fromMap(Map<String, dynamic> data) => ProductsStruct(
        idProduct: castToType<int>(data['id_product']),
        idHeadquarter: castToType<int>(data['id_headquarter']),
        rfid: data['rfid'] as String?,
        stateProduct: data['state_product'] as String?,
        descriptionProduct: data['description_product'] as String?,
        locationRaw: data['location_raw'] as String?,
        line: castToType<int>(data['line']),
        palm: castToType<int>(data['palm']),
      );

  static ProductsStruct? maybeFromMap(dynamic data) =>
      data is Map ? ProductsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_product': _idProduct,
        'id_headquarter': _idHeadquarter,
        'rfid': _rfid,
        'state_product': _stateProduct,
        'description_product': _descriptionProduct,
        'location_raw': _locationRaw,
        'line': _line,
        'palm': _palm,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_product': serializeParam(
          _idProduct,
          ParamType.int,
        ),
        'id_headquarter': serializeParam(
          _idHeadquarter,
          ParamType.int,
        ),
        'rfid': serializeParam(
          _rfid,
          ParamType.String,
        ),
        'state_product': serializeParam(
          _stateProduct,
          ParamType.String,
        ),
        'description_product': serializeParam(
          _descriptionProduct,
          ParamType.String,
        ),
        'location_raw': serializeParam(
          _locationRaw,
          ParamType.String,
        ),
        'line': serializeParam(
          _line,
          ParamType.int,
        ),
        'palm': serializeParam(
          _palm,
          ParamType.int,
        ),
      }.withoutNulls;

  static ProductsStruct fromSerializableMap(Map<String, dynamic> data) =>
      ProductsStruct(
        idProduct: deserializeParam(
          data['id_product'],
          ParamType.int,
          false,
        ),
        idHeadquarter: deserializeParam(
          data['id_headquarter'],
          ParamType.int,
          false,
        ),
        rfid: deserializeParam(
          data['rfid'],
          ParamType.String,
          false,
        ),
        stateProduct: deserializeParam(
          data['state_product'],
          ParamType.String,
          false,
        ),
        descriptionProduct: deserializeParam(
          data['description_product'],
          ParamType.String,
          false,
        ),
        locationRaw: deserializeParam(
          data['location_raw'],
          ParamType.String,
          false,
        ),
        line: deserializeParam(
          data['line'],
          ParamType.int,
          false,
        ),
        palm: deserializeParam(
          data['palm'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ProductsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ProductsStruct &&
        idProduct == other.idProduct &&
        idHeadquarter == other.idHeadquarter &&
        rfid == other.rfid &&
        stateProduct == other.stateProduct &&
        descriptionProduct == other.descriptionProduct &&
        locationRaw == other.locationRaw &&
        line == other.line &&
        palm == other.palm;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idProduct,
        idHeadquarter,
        rfid,
        stateProduct,
        descriptionProduct,
        locationRaw,
        line,
        palm
      ]);
}

ProductsStruct createProductsStruct({
  int? idProduct,
  int? idHeadquarter,
  String? rfid,
  String? stateProduct,
  String? descriptionProduct,
  String? locationRaw,
  int? line,
  int? palm,
}) =>
    ProductsStruct(
      idProduct: idProduct,
      idHeadquarter: idHeadquarter,
      rfid: rfid,
      stateProduct: stateProduct,
      descriptionProduct: descriptionProduct,
      locationRaw: locationRaw,
      line: line,
      palm: palm,
    );
