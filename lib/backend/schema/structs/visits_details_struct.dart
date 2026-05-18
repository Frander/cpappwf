// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VisitsDetailsStruct extends BaseStruct {
  VisitsDetailsStruct({
    int? idVisitDetail,
    int? idVisit,
    int? idActivityStatus,
    String? statusOption,
    String? statusResponse,
    int? idStepParent,
    bool? rememberStatus,
    String? defaultStatus,
    String? typeStatus,
    int? auxStep,
  })  : _idVisitDetail = idVisitDetail,
        _idVisit = idVisit,
        _idActivityStatus = idActivityStatus,
        _statusOption = statusOption,
        _statusResponse = statusResponse,
        _idStepParent = idStepParent,
        _rememberStatus = rememberStatus,
        _defaultStatus = defaultStatus,
        _typeStatus = typeStatus,
        _auxStep = auxStep;

  // "id_visit_detail" field.
  int? _idVisitDetail;
  int get idVisitDetail => _idVisitDetail ?? 0;
  set idVisitDetail(int? val) => _idVisitDetail = val;

  void incrementIdVisitDetail(int amount) =>
      idVisitDetail = idVisitDetail + amount;

  bool hasIdVisitDetail() => _idVisitDetail != null;

  // "id_visit" field.
  int? _idVisit;
  int get idVisit => _idVisit ?? 0;
  set idVisit(int? val) => _idVisit = val;

  void incrementIdVisit(int amount) => idVisit = idVisit + amount;

  bool hasIdVisit() => _idVisit != null;

  // "id_activity_status" field.
  int? _idActivityStatus;
  int get idActivityStatus => _idActivityStatus ?? 0;
  set idActivityStatus(int? val) => _idActivityStatus = val;

  void incrementIdActivityStatus(int amount) =>
      idActivityStatus = idActivityStatus + amount;

  bool hasIdActivityStatus() => _idActivityStatus != null;

  // "status_option" field.
  String? _statusOption;
  String get statusOption => _statusOption ?? '';
  set statusOption(String? val) => _statusOption = val;

  bool hasStatusOption() => _statusOption != null;

  // "status_response" field.
  String? _statusResponse;
  String get statusResponse => _statusResponse ?? '';
  set statusResponse(String? val) => _statusResponse = val;

  bool hasStatusResponse() => _statusResponse != null;

  // "id_step_parent" field.
  int? _idStepParent;
  int get idStepParent => _idStepParent ?? 0;
  set idStepParent(int? val) => _idStepParent = val;

  void incrementIdStepParent(int amount) =>
      idStepParent = idStepParent + amount;

  bool hasIdStepParent() => _idStepParent != null;

  // "remember_status" field.
  bool? _rememberStatus;
  bool get rememberStatus => _rememberStatus ?? false;
  set rememberStatus(bool? val) => _rememberStatus = val;

  bool hasRememberStatus() => _rememberStatus != null;

  // "default_status" field.
  String? _defaultStatus;
  String get defaultStatus => _defaultStatus ?? '';
  set defaultStatus(String? val) => _defaultStatus = val;

  bool hasDefaultStatus() => _defaultStatus != null;

  // "type_status" field.
  String? _typeStatus;
  String get typeStatus => _typeStatus ?? '';
  set typeStatus(String? val) => _typeStatus = val;

  bool hasTypeStatus() => _typeStatus != null;

  // "auxStep" field.
  int? _auxStep;
  int get auxStep => _auxStep ?? 0;
  set auxStep(int? val) => _auxStep = val;

  void incrementAuxStep(int amount) => auxStep = auxStep + amount;

  bool hasAuxStep() => _auxStep != null;

  static VisitsDetailsStruct fromMap(Map<String, dynamic> data) =>
      VisitsDetailsStruct(
        idVisitDetail: castToType<int>(data['id_visit_detail']),
        idVisit: castToType<int>(data['id_visit']),
        idActivityStatus: castToType<int>(data['id_activity_status']),
        statusOption: data['status_option'] as String?,
        statusResponse: data['status_response'] as String?,
        idStepParent: castToType<int>(data['id_step_parent']),
        rememberStatus: data['remember_status'] as bool?,
        defaultStatus: data['default_status'] as String?,
        typeStatus: data['type_status'] as String?,
        auxStep: castToType<int>(data['auxStep']),
      );

  static VisitsDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? VisitsDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id_visit_detail': _idVisitDetail,
        'id_visit': _idVisit,
        'id_activity_status': _idActivityStatus,
        'status_option': _statusOption,
        'status_response': _statusResponse,
        'id_step_parent': _idStepParent,
        'remember_status': _rememberStatus,
        'default_status': _defaultStatus,
        'type_status': _typeStatus,
        'auxStep': _auxStep,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id_visit_detail': serializeParam(
          _idVisitDetail,
          ParamType.int,
        ),
        'id_visit': serializeParam(
          _idVisit,
          ParamType.int,
        ),
        'id_activity_status': serializeParam(
          _idActivityStatus,
          ParamType.int,
        ),
        'status_option': serializeParam(
          _statusOption,
          ParamType.String,
        ),
        'status_response': serializeParam(
          _statusResponse,
          ParamType.String,
        ),
        'id_step_parent': serializeParam(
          _idStepParent,
          ParamType.int,
        ),
        'remember_status': serializeParam(
          _rememberStatus,
          ParamType.bool,
        ),
        'default_status': serializeParam(
          _defaultStatus,
          ParamType.String,
        ),
        'type_status': serializeParam(
          _typeStatus,
          ParamType.String,
        ),
        'auxStep': serializeParam(
          _auxStep,
          ParamType.int,
        ),
      }.withoutNulls;

  static VisitsDetailsStruct fromSerializableMap(Map<String, dynamic> data) =>
      VisitsDetailsStruct(
        idVisitDetail: deserializeParam(
          data['id_visit_detail'],
          ParamType.int,
          false,
        ),
        idVisit: deserializeParam(
          data['id_visit'],
          ParamType.int,
          false,
        ),
        idActivityStatus: deserializeParam(
          data['id_activity_status'],
          ParamType.int,
          false,
        ),
        statusOption: deserializeParam(
          data['status_option'],
          ParamType.String,
          false,
        ),
        statusResponse: deserializeParam(
          data['status_response'],
          ParamType.String,
          false,
        ),
        idStepParent: deserializeParam(
          data['id_step_parent'],
          ParamType.int,
          false,
        ),
        rememberStatus: deserializeParam(
          data['remember_status'],
          ParamType.bool,
          false,
        ),
        defaultStatus: deserializeParam(
          data['default_status'],
          ParamType.String,
          false,
        ),
        typeStatus: deserializeParam(
          data['type_status'],
          ParamType.String,
          false,
        ),
        auxStep: deserializeParam(
          data['auxStep'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'VisitsDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is VisitsDetailsStruct &&
        idVisitDetail == other.idVisitDetail &&
        idVisit == other.idVisit &&
        idActivityStatus == other.idActivityStatus &&
        statusOption == other.statusOption &&
        statusResponse == other.statusResponse &&
        idStepParent == other.idStepParent &&
        rememberStatus == other.rememberStatus &&
        defaultStatus == other.defaultStatus &&
        typeStatus == other.typeStatus &&
        auxStep == other.auxStep;
  }

  @override
  int get hashCode => const ListEquality().hash([
        idVisitDetail,
        idVisit,
        idActivityStatus,
        statusOption,
        statusResponse,
        idStepParent,
        rememberStatus,
        defaultStatus,
        typeStatus,
        auxStep
      ]);
}

VisitsDetailsStruct createVisitsDetailsStruct({
  int? idVisitDetail,
  int? idVisit,
  int? idActivityStatus,
  String? statusOption,
  String? statusResponse,
  int? idStepParent,
  bool? rememberStatus,
  String? defaultStatus,
  String? typeStatus,
  int? auxStep,
}) =>
    VisitsDetailsStruct(
      idVisitDetail: idVisitDetail,
      idVisit: idVisit,
      idActivityStatus: idActivityStatus,
      statusOption: statusOption,
      statusResponse: statusResponse,
      idStepParent: idStepParent,
      rememberStatus: rememberStatus,
      defaultStatus: defaultStatus,
      typeStatus: typeStatus,
      auxStep: auxStep,
    );
