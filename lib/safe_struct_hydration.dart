// Hidratación y serialización tolerantes a errores **campo a campo**.
// El patrón estándar de FlutterFlow es todo-o-nada: si un solo campo del
// JSON persistido está corrupto, XxxStruct.fromSerializableMap lanza y el
// struct entero queda en su valor por defecto. Aquí cada campo va en su
// propio try/catch: si uno falla, el resto se conserva y el nombre del
// campo problemático queda registrado en clickpalm_crash.log.
import 'dart:convert';

import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'release_log.dart';

// ─── Helpers internos ────────────────────────────────────────────────────────

void _tryField(String tag, void Function() apply) {
  try {
    apply();
  } catch (e, st) {
    releaseLog('hydrate $tag', e, st);
  }
}

void _tryPut(
  String tag,
  Map<String, dynamic> out,
  String key,
  dynamic Function() compute,
) {
  try {
    final v = compute();
    if (v != null) out[key] = v;
  } catch (e, st) {
    releaseLog('serialize $tag.$key', e, st);
  }
}

String _safeEncode(String tag, Map<String, dynamic> map) {
  try {
    return json.encode(map);
  } catch (e, st) {
    releaseLog('serialize $tag.json.encode', e, st);
    return '{}';
  }
}

/// Decodifica un JSON ignorando contenido corrupto. Si la cadena no es un
/// objeto válido, retorna un mapa vacío y registra el error.
Map<String, dynamic> safeJsonDecodeMap(String tag, String raw) {
  if (raw.isEmpty) return <String, dynamic>{};
  try {
    final v = json.decode(raw);
    if (v is Map) return v.cast<String, dynamic>();
    releaseLog('hydrate $tag.jsonDecode: not a Map (got ${v.runtimeType})');
    return <String, dynamic>{};
  } catch (e, st) {
    releaseLog('hydrate $tag.jsonDecode', e, st);
    return <String, dynamic>{};
  }
}

// ─── UsersStruct ─────────────────────────────────────────────────────────────

UsersStruct safeHydrateUsers(Map<String, dynamic> data) {
  final r = UsersStruct();
  _tryField('Users.id_user', () {
    final v = deserializeParam<int>(data['id_user'], ParamType.int, false);
    if (v != null) r.idUser = v;
  });
  _tryField('Users.id_company', () {
    final v = deserializeParam<int>(data['id_company'], ParamType.int, false);
    if (v != null) r.idCompany = v;
  });
  _tryField('Users.operID', () {
    final v =
        deserializeParam<String>(data['operID'], ParamType.String, false);
    if (v != null) r.operID = v;
  });
  _tryField('Users.name_user', () {
    final v =
        deserializeParam<String>(data['name_user'], ParamType.String, false);
    if (v != null) r.nameUser = v;
  });
  _tryField('Users.email', () {
    final v = deserializeParam<String>(data['email'], ParamType.String, false);
    if (v != null) r.email = v;
  });
  _tryField('Users.code_user', () {
    final v =
        deserializeParam<String>(data['code_user'], ParamType.String, false);
    if (v != null) r.codeUser = v;
  });
  _tryField('Users.state_user', () {
    final v =
        deserializeParam<String>(data['state_user'], ParamType.String, false);
    if (v != null) r.stateUser = v;
  });
  _tryField('Users.rol_user', () {
    final v =
        deserializeParam<String>(data['rol_user'], ParamType.String, false);
    if (v != null) r.rolUser = v;
  });
  _tryField('Users.created_at', () {
    final v =
        deserializeParam<String>(data['created_at'], ParamType.String, false);
    if (v != null) r.createdAt = v;
  });
  _tryField('Users.modifiedAt', () {
    final v =
        deserializeParam<String>(data['modifiedAt'], ParamType.String, false);
    if (v != null) r.modifiedAt = v;
  });
  return r;
}

String safeSerializeUsers(UsersStruct v) {
  final m = <String, dynamic>{};
  _tryPut('Users', m, 'id_user',
      () => serializeParam(v.hasIdUser() ? v.idUser : null, ParamType.int));
  _tryPut(
      'Users',
      m,
      'id_company',
      () =>
          serializeParam(v.hasIdCompany() ? v.idCompany : null, ParamType.int));
  _tryPut('Users', m, 'operID',
      () => serializeParam(v.hasOperID() ? v.operID : null, ParamType.String));
  _tryPut(
      'Users',
      m,
      'name_user',
      () => serializeParam(
          v.hasNameUser() ? v.nameUser : null, ParamType.String));
  _tryPut('Users', m, 'email',
      () => serializeParam(v.hasEmail() ? v.email : null, ParamType.String));
  _tryPut(
      'Users',
      m,
      'created_at',
      () => serializeParam(
          v.hasCreatedAt() ? v.createdAt : null, ParamType.String));
  _tryPut(
      'Users',
      m,
      'modifiedAt',
      () => serializeParam(
          v.hasModifiedAt() ? v.modifiedAt : null, ParamType.String));
  return _safeEncode('Users', m);
}

// ─── CompaniesStruct ─────────────────────────────────────────────────────────

CompaniesStruct safeHydrateCompanies(Map<String, dynamic> data) {
  final r = CompaniesStruct();
  _tryField('Companies.id_company', () {
    final v = deserializeParam<int>(data['id_company'], ParamType.int, false);
    if (v != null) r.idCompany = v;
  });
  _tryField('Companies.name_company', () {
    final v = deserializeParam<String>(
        data['name_company'], ParamType.String, false);
    if (v != null) r.nameCompany = v;
  });
  _tryField('Companies.business_name', () {
    final v = deserializeParam<String>(
        data['business_name'], ParamType.String, false);
    if (v != null) r.businessName = v;
  });
  _tryField('Companies.nit', () {
    final v = deserializeParam<String>(data['nit'], ParamType.String, false);
    if (v != null) r.nit = v;
  });
  _tryField('Companies.address', () {
    final v =
        deserializeParam<String>(data['address'], ParamType.String, false);
    if (v != null) r.address = v;
  });
  _tryField('Companies.telePhone', () {
    final v =
        deserializeParam<String>(data['telePhone'], ParamType.String, false);
    if (v != null) r.telePhone = v;
  });
  _tryField('Companies.latitude_extractor', () {
    final v = deserializeParam<double>(
        data['latitude_extractor'], ParamType.double, false);
    if (v != null) r.latitudeExtractor = v;
  });
  _tryField('Companies.longitude_extractor', () {
    final v = deserializeParam<double>(
        data['longitude_extractor'], ParamType.double, false);
    if (v != null) r.longitudeExtractor = v;
  });
  return r;
}

String safeSerializeCompanies(CompaniesStruct v) {
  final m = <String, dynamic>{};
  _tryPut(
      'Companies',
      m,
      'id_company',
      () =>
          serializeParam(v.hasIdCompany() ? v.idCompany : null, ParamType.int));
  _tryPut(
      'Companies',
      m,
      'name_company',
      () => serializeParam(
          v.hasNameCompany() ? v.nameCompany : null, ParamType.String));
  _tryPut(
      'Companies',
      m,
      'business_name',
      () => serializeParam(
          v.hasBusinessName() ? v.businessName : null, ParamType.String));
  _tryPut('Companies', m, 'nit',
      () => serializeParam(v.hasNit() ? v.nit : null, ParamType.String));
  _tryPut(
      'Companies',
      m,
      'address',
      () =>
          serializeParam(v.hasAddress() ? v.address : null, ParamType.String));
  _tryPut(
      'Companies',
      m,
      'telePhone',
      () => serializeParam(
          v.hasTelePhone() ? v.telePhone : null, ParamType.String));
  _tryPut(
      'Companies',
      m,
      'latitude_extractor',
      () => serializeParam(
          v.hasLatitudeExtractor() ? v.latitudeExtractor : null,
          ParamType.double));
  _tryPut(
      'Companies',
      m,
      'longitude_extractor',
      () => serializeParam(
          v.hasLongitudeExtractor() ? v.longitudeExtractor : null,
          ParamType.double));
  return _safeEncode('Companies', m);
}

// ─── DevicesStruct ───────────────────────────────────────────────────────────

DevicesStruct safeHydrateDevices(Map<String, dynamic> data) {
  final r = DevicesStruct();
  _tryField('Devices.id_device', () {
    final v = deserializeParam<int>(data['id_device'], ParamType.int, false);
    if (v != null) r.idDevice = v;
  });
  _tryField('Devices.id_company', () {
    final v = deserializeParam<int>(data['id_company'], ParamType.int, false);
    if (v != null) r.idCompany = v;
  });
  _tryField('Devices.device_name', () {
    final v = deserializeParam<String>(
        data['device_name'], ParamType.String, false);
    if (v != null) r.deviceName = v;
  });
  _tryField('Devices.cellPhone', () {
    final v =
        deserializeParam<String>(data['cellPhone'], ParamType.String, false);
    if (v != null) r.cellPhone = v;
  });
  _tryField('Devices.serial_id', () {
    final v =
        deserializeParam<String>(data['serial_id'], ParamType.String, false);
    if (v != null) r.serialId = v;
  });
  _tryField('Devices.imeI1', () {
    final v = deserializeParam<String>(data['imeI1'], ParamType.String, false);
    if (v != null) r.imeI1 = v;
  });
  _tryField('Devices.imeI2', () {
    final v = deserializeParam<String>(data['imeI2'], ParamType.String, false);
    if (v != null) r.imeI2 = v;
  });
  _tryField('Devices.model', () {
    final v = deserializeParam<String>(data['model'], ParamType.String, false);
    if (v != null) r.model = v;
  });
  _tryField('Devices.state', () {
    final v = deserializeParam<String>(data['state'], ParamType.String, false);
    if (v != null) r.state = v;
  });
  return r;
}

String safeSerializeDevices(DevicesStruct v) {
  final m = <String, dynamic>{};
  _tryPut('Devices', m, 'id_device',
      () => serializeParam(v.hasIdDevice() ? v.idDevice : null, ParamType.int));
  _tryPut(
      'Devices',
      m,
      'id_company',
      () =>
          serializeParam(v.hasIdCompany() ? v.idCompany : null, ParamType.int));
  _tryPut(
      'Devices',
      m,
      'device_name',
      () => serializeParam(
          v.hasDeviceName() ? v.deviceName : null, ParamType.String));
  _tryPut(
      'Devices',
      m,
      'cellPhone',
      () => serializeParam(
          v.hasCellPhone() ? v.cellPhone : null, ParamType.String));
  _tryPut(
      'Devices',
      m,
      'serial_id',
      () => serializeParam(
          v.hasSerialId() ? v.serialId : null, ParamType.String));
  _tryPut('Devices', m, 'imeI1',
      () => serializeParam(v.hasImeI1() ? v.imeI1 : null, ParamType.String));
  _tryPut('Devices', m, 'imeI2',
      () => serializeParam(v.hasImeI2() ? v.imeI2 : null, ParamType.String));
  _tryPut('Devices', m, 'model',
      () => serializeParam(v.hasModel() ? v.model : null, ParamType.String));
  _tryPut('Devices', m, 'state',
      () => serializeParam(v.hasState() ? v.state : null, ParamType.String));
  return _safeEncode('Devices', m);
}

// ─── ActivitiesStruct ────────────────────────────────────────────────────────

ActivitiesStruct safeHydrateActivities(Map<String, dynamic> data) {
  final r = ActivitiesStruct();
  _tryField('Activities.id_activity', () {
    final v = deserializeParam<int>(data['id_activity'], ParamType.int, false);
    if (v != null) r.idActivity = v;
  });
  _tryField('Activities.name_activity', () {
    final v = deserializeParam<String>(
        data['name_activity'], ParamType.String, false);
    if (v != null) r.nameActivity = v;
  });
  _tryField('Activities.group_activity', () {
    final v = deserializeParam<String>(
        data['group_activity'], ParamType.String, false);
    if (v != null) r.groupActivity = v;
  });
  _tryField('Activities.unity', () {
    final v = deserializeParam<String>(data['unity'], ParamType.String, false);
    if (v != null) r.unity = v;
  });
  _tryField('Activities.cycle', () {
    final v = deserializeParam<int>(data['cycle'], ParamType.int, false);
    if (v != null) r.cycle = v;
  });
  _tryField('Activities.effectivity_unitys', () {
    final v = deserializeParam<int>(
        data['effectivity_unitys'], ParamType.int, false);
    if (v != null) r.effectivityUnitys = v;
  });
  _tryField('Activities.effectivity_visits', () {
    final v = deserializeParam<int>(
        data['effectivity_visits'], ParamType.int, false);
    if (v != null) r.effectivityVisits = v;
  });
  _tryField('Activities.type_effectivity', () {
    final v = deserializeParam<String>(
        data['type_effectivity'], ParamType.String, false);
    if (v != null) r.typeEffectivity = v;
  });
  _tryField('Activities.module_activity', () {
    final v = deserializeParam<String>(
        data['module_activity'], ParamType.String, false);
    if (v != null) r.moduleActivity = v;
  });
  _tryField('Activities.is_sync', () {
    final v = deserializeParam<bool>(data['is_sync'], ParamType.bool, false);
    if (v != null) r.isSync = v;
  });
  _tryField('Activities.is_sync_full', () {
    final v =
        deserializeParam<bool>(data['is_sync_full'], ParamType.bool, false);
    if (v != null) r.isSyncFull = v;
  });
  _tryField('Activities.tracking_headquarter', () {
    final v = deserializeParam<bool>(
        data['tracking_headquarter'], ParamType.bool, false);
    if (v != null) r.trackingHeadquarter = v;
  });
  return r;
}

String safeSerializeActivities(ActivitiesStruct v) {
  final m = <String, dynamic>{};
  _tryPut(
      'Activities',
      m,
      'id_activity',
      () => serializeParam(
          v.hasIdActivity() ? v.idActivity : null, ParamType.int));
  _tryPut(
      'Activities',
      m,
      'name_activity',
      () => serializeParam(
          v.hasNameActivity() ? v.nameActivity : null, ParamType.String));
  _tryPut(
      'Activities',
      m,
      'group_activity',
      () => serializeParam(
          v.hasGroupActivity() ? v.groupActivity : null, ParamType.String));
  _tryPut('Activities', m, 'unity',
      () => serializeParam(v.hasUnity() ? v.unity : null, ParamType.String));
  _tryPut('Activities', m, 'cycle',
      () => serializeParam(v.hasCycle() ? v.cycle : null, ParamType.int));
  _tryPut(
      'Activities',
      m,
      'effectivity_unitys',
      () => serializeParam(
          v.hasEffectivityUnitys() ? v.effectivityUnitys : null,
          ParamType.int));
  _tryPut(
      'Activities',
      m,
      'effectivity_visits',
      () => serializeParam(
          v.hasEffectivityVisits() ? v.effectivityVisits : null,
          ParamType.int));
  _tryPut(
      'Activities',
      m,
      'type_effectivity',
      () => serializeParam(
          v.hasTypeEffectivity() ? v.typeEffectivity : null, ParamType.String));
  _tryPut(
      'Activities',
      m,
      'module_activity',
      () => serializeParam(
          v.hasModuleActivity() ? v.moduleActivity : null, ParamType.String));
  _tryPut('Activities', m, 'is_sync',
      () => serializeParam(v.hasIsSync() ? v.isSync : null, ParamType.bool));
  _tryPut(
      'Activities',
      m,
      'is_sync_full',
      () => serializeParam(
          v.hasIsSyncFull() ? v.isSyncFull : null, ParamType.bool));
  _tryPut(
      'Activities',
      m,
      'tracking_headquarter',
      () => serializeParam(
          v.hasTrackingHeadquarter() ? v.trackingHeadquarter : null,
          ParamType.bool));
  return _safeEncode('Activities', m);
}

// ─── HeadquartersStruct ──────────────────────────────────────────────────────

HeadquartersStruct safeHydrateHeadquarters(Map<String, dynamic> data) {
  final r = HeadquartersStruct();
  _tryField('Headquarters.id_headquarter', () {
    final v =
        deserializeParam<int>(data['id_headquarter'], ParamType.int, false);
    if (v != null) r.idHeadquarter = v;
  });
  _tryField('Headquarters.id_zone', () {
    final v = deserializeParam<int>(data['id_zone'], ParamType.int, false);
    if (v != null) r.idZone = v;
  });
  _tryField('Headquarters.created_at', () {
    final v =
        deserializeParam<String>(data['created_at'], ParamType.String, false);
    if (v != null) r.createdAt = v;
  });
  _tryField('Headquarters.name_headquarter', () {
    final v = deserializeParam<String>(
        data['name_headquarter'], ParamType.String, false);
    if (v != null) r.nameHeadquarter = v;
  });
  _tryField('Headquarters.density_headquarter', () {
    final v = deserializeParam<int>(
        data['density_headquarter'], ParamType.int, false);
    if (v != null) r.densityHeadquarter = v;
  });
  _tryField('Headquarters.seed_time', () {
    final v =
        deserializeParam<String>(data['seed_time'], ParamType.String, false);
    if (v != null) r.seedTime = v;
  });
  _tryField('Headquarters.state_headquarter', () {
    final v = deserializeParam<String>(
        data['state_headquarter'], ParamType.String, false);
    if (v != null) r.stateHeadquarter = v;
  });
  _tryField('Headquarters.area_headquarter', () {
    final v = deserializeParam<double>(
        data['area_headquarter'], ParamType.double, false);
    if (v != null) r.areaHeadquarter = v;
  });
  _tryField('Headquarters.polygon', () {
    final v =
        deserializeParam<String>(data['polygon'], ParamType.String, false);
    if (v != null) r.polygon = v;
  });
  return r;
}

String safeSerializeHeadquarters(HeadquartersStruct v) {
  final m = <String, dynamic>{};
  _tryPut(
      'Headquarters',
      m,
      'id_headquarter',
      () => serializeParam(
          v.hasIdHeadquarter() ? v.idHeadquarter : null, ParamType.int));
  _tryPut('Headquarters', m, 'id_zone',
      () => serializeParam(v.hasIdZone() ? v.idZone : null, ParamType.int));
  _tryPut(
      'Headquarters',
      m,
      'created_at',
      () => serializeParam(
          v.hasCreatedAt() ? v.createdAt : null, ParamType.String));
  _tryPut(
      'Headquarters',
      m,
      'name_headquarter',
      () => serializeParam(
          v.hasNameHeadquarter() ? v.nameHeadquarter : null, ParamType.String));
  _tryPut(
      'Headquarters',
      m,
      'density_headquarter',
      () => serializeParam(
          v.hasDensityHeadquarter() ? v.densityHeadquarter : null,
          ParamType.int));
  _tryPut(
      'Headquarters',
      m,
      'seed_time',
      () => serializeParam(
          v.hasSeedTime() ? v.seedTime : null, ParamType.String));
  _tryPut(
      'Headquarters',
      m,
      'state_headquarter',
      () => serializeParam(v.hasStateHeadquarter() ? v.stateHeadquarter : null,
          ParamType.String));
  _tryPut(
      'Headquarters',
      m,
      'area_headquarter',
      () => serializeParam(
          v.hasAreaHeadquarter() ? v.areaHeadquarter : null,
          ParamType.double));
  _tryPut(
      'Headquarters',
      m,
      'polygon',
      () =>
          serializeParam(v.hasPolygon() ? v.polygon : null, ParamType.String));
  return _safeEncode('Headquarters', m);
}
