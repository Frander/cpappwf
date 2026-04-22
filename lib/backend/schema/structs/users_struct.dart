// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersStruct extends BaseStruct {
  UsersStruct({
    int? idUser,
    int? idCompany,
    String? operID,
    String? nameUser,
    String? email,
    String? codeUser,
    String? stateUser,
    String? rolUser,
    String? createdAt,
    String? modifiedAt,
  })  : _idUser = idUser,
        _idCompany = idCompany,
        _operID = operID,
        _nameUser = nameUser,
        _email = email,
        _codeUser = codeUser,
        _stateUser = stateUser,
        _rolUser = rolUser,
        _createdAt = createdAt,
        _modifiedAt = modifiedAt;

  // "id_user" field.
  int? _idUser;
  int get idUser => _idUser ?? 0;
  set idUser(int? val) => _idUser = val;

  void incrementIdUser(int amount) => idUser = idUser + amount;

  bool hasIdUser() => _idUser != null;

  // "id_company" field.
  int? _idCompany;
  int get idCompany => _idCompany ?? 0;
  set idCompany(int? val) => _idCompany = val;

  void incrementIdCompany(int amount) => idCompany = idCompany + amount;

  bool hasIdCompany() => _idCompany != null;

  // "operID" field.
  String? _operID;
  String get operID => _operID ?? '';
  set operID(String? val) => _operID = val;

  bool hasOperID() => _operID != null;

  // "name_user" field.
  String? _nameUser;
  String get nameUser => _nameUser ?? '';
  set nameUser(String? val) => _nameUser = val;

  bool hasNameUser() => _nameUser != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  set email(String? val) => _email = val;

  bool hasEmail() => _email != null;

  // "code_user" field.
  String? _codeUser;
  String get codeUser => _codeUser ?? '';
  set codeUser(String? val) => _codeUser = val;

  bool hasCodeUser() => _codeUser != null;

  // "state_user" field.
  String? _stateUser;
  String get stateUser => _stateUser ?? '';
  set stateUser(String? val) => _stateUser = val;

  bool hasStateUser() => _stateUser != null;

  // "rol_user" field.
  String? _rolUser;
  String get rolUser => _rolUser ?? '';
  set rolUser(String? val) => _rolUser = val;

  bool hasRolUser() => _rolUser != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "modifiedAt" field.
  String? _modifiedAt;
  String get modifiedAt => _modifiedAt ?? '';
  set modifiedAt(String? val) => _modifiedAt = val;

  bool hasModifiedAt() => _modifiedAt != null;

  static UsersStruct fromMap(Map<String, dynamic> data) => UsersStruct(
        idUser:    castToType<int>(data['id_user']),
        idCompany: castToType<int>(data['id_company']),
        operID:    data['operID']     as String?,
        nameUser:  data['name_user']  as String?,
        email:     data['email']      as String?,
        codeUser:  data['code_user']  as String?,
        stateUser: data['state_user'] as String?,
        rolUser:   data['rol_user']   as String?,
        createdAt: data['created_at'] as String?,
        modifiedAt: data['modifiedAt'] as String?,
      );

  static UsersStruct? maybeFromMap(dynamic data) =>
      data is Map ? UsersStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id_user':    _idUser,
        'id_company': _idCompany,
        'operID':     _operID,
        'name_user':  _nameUser,
        'email':      _email,
        'code_user':  _codeUser,
        'state_user': _stateUser,
        'rol_user':   _rolUser,
        'created_at': _createdAt,
        'modifiedAt': _modifiedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_user': serializeParam(
          _idUser,
          ParamType.int,
        ),
        'id_company': serializeParam(
          _idCompany,
          ParamType.int,
        ),
        'operID': serializeParam(
          _operID,
          ParamType.String,
        ),
        'name_user': serializeParam(
          _nameUser,
          ParamType.String,
        ),
        'email': serializeParam(
          _email,
          ParamType.String,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'modifiedAt': serializeParam(
          _modifiedAt,
          ParamType.String,
        ),
      }.withoutNulls;

  static UsersStruct fromSerializableMap(Map<String, dynamic> data) =>
      UsersStruct(
        idUser: deserializeParam(
          data['id_user'],
          ParamType.int,
          false,
        ),
        idCompany: deserializeParam(
          data['id_company'],
          ParamType.int,
          false,
        ),
        operID: deserializeParam(
          data['operID'],
          ParamType.String,
          false,
        ),
        nameUser: deserializeParam(
          data['name_user'],
          ParamType.String,
          false,
        ),
        email: deserializeParam(
          data['email'],
          ParamType.String,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
        modifiedAt: deserializeParam(
          data['modifiedAt'],
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
  String? operID,
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
