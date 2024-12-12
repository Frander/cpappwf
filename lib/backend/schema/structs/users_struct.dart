// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersStruct extends BaseStruct {
  UsersStruct({
    int? idUser,
    int? idCompany,
    int? operID,
    String? nameUser,
    String? email,
    String? createdAt,
    String? modifiedAt,
  })  : _idUser = idUser,
        _idCompany = idCompany,
        _operID = operID,
        _nameUser = nameUser,
        _email = email,
        _createdAt = createdAt,
        _modifiedAt = modifiedAt;

  // "Id_user" field.
  int? _idUser;
  int get idUser => _idUser ?? 0;
  set idUser(int? val) => _idUser = val;

  void incrementIdUser(int amount) => idUser = idUser + amount;

  bool hasIdUser() => _idUser != null;

  // "Id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "OperID" field.
  int? _operID;
  int get operID => _operID ?? 0;
  set operID(int? val) => _operID = val;

  void incrementOperID(int amount) => operID = operID + amount;

  bool hasOperID() => _operID != null;

  // "Name_user" field.
  String? _nameUser;
  String get nameUser => _nameUser ?? '';
  set nameUser(String? val) => _nameUser = val;

  bool hasNameUser() => _nameUser != null;

  // "Email" field.
  String? _email;
  String get email => _email ?? '';
  set email(String? val) => _email = val;

  bool hasEmail() => _email != null;

  // "Created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "ModifiedAt" field.
  String? _modifiedAt;
  String get modifiedAt => _modifiedAt ?? '';
  set modifiedAt(String? val) => _modifiedAt = val;

  bool hasModifiedAt() => _modifiedAt != null;

  static UsersStruct fromMap(Map<String, dynamic> data) => UsersStruct(
        idUser: castToType<int>(data['Id_user']),
        idCompany: castToType<int>(data['Id_company']),
        operID: castToType<int>(data['OperID']),
        nameUser: data['Name_user'] as String?,
        email: data['Email'] as String?,
        createdAt: data['Created_at'] as String?,
        modifiedAt: data['ModifiedAt'] as String?,
      );

  static UsersStruct? maybeFromMap(dynamic data) =>
      data is Map ? UsersStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'Id_user': _idUser,
        'Id_company': _idCompany,
        'OperID': _operID,
        'Name_user': _nameUser,
        'Email': _email,
        'Created_at': _createdAt,
        'ModifiedAt': _modifiedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'Id_user': serializeParam(
          _idUser,
          ParamType.int,
        ),
        'Id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'OperID': serializeParam(
          _operID,
          ParamType.int,
        ),
        'Name_user': serializeParam(
          _nameUser,
          ParamType.String,
        ),
        'Email': serializeParam(
          _email,
          ParamType.String,
        ),
        'Created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'ModifiedAt': serializeParam(
          _modifiedAt,
          ParamType.String,
        ),
      }.withoutNulls;

  static UsersStruct fromSerializableMap(Map<String, dynamic> data) =>
      UsersStruct(
        idUser: deserializeParam(
          data['Id_user'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['Id_company'],
          ParamType.int,
          false,
        ),
        operID: deserializeParam(
          data['OperID'],
          ParamType.int,
          false,
        ),
        nameUser: deserializeParam(
          data['Name_user'],
          ParamType.String,
          false,
        ),
        email: deserializeParam(
          data['Email'],
          ParamType.String,
          false,
        ),
        createdAt: deserializeParam(
          data['Created_at'],
          ParamType.String,
          false,
        ),
        modifiedAt: deserializeParam(
          data['ModifiedAt'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'UsersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UsersStruct &&
        idUser == other.idUser &&
        idCompany == other.idCompany &&
        operID == other.operID &&
        nameUser == other.nameUser &&
        email == other.email &&
        createdAt == other.createdAt &&
        modifiedAt == other.modifiedAt;
  }

  @override
  int get hashCode => const ListEquality().hash(
      [idUser, idCompany, operID, nameUser, email, createdAt, modifiedAt]);
}

UsersStruct createUsersStruct({
  int? idUser,
  int? idCompany,
  int? operID,
  String? nameUser,
  String? email,
  String? createdAt,
  String? modifiedAt,
}) =>
    UsersStruct(
      idUser: idUser,
      idCompany: idCompany,
      operID: operID,
      nameUser: nameUser,
      email: email,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
