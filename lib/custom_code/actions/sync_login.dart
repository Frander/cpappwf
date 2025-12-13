// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// Sincroniza los datos del endpoint Login hacia SQLite
/// Estrategia: DELETE+INSERT para garantizar sincronización exacta con el servidor
///
/// Parámetros:
/// - [context]: BuildContext de Flutter
/// - [username]: Nombre de usuario (solo usado si loginResponseJson es inválido)
/// - [password]: Contraseña (solo usado si loginResponseJson es inválido)
/// - [loginResponseJson]: (OPCIONAL) JSON de respuesta del Login ya obtenido.
///   Si es válido, se usa directamente; si no, se llama al endpoint.
Future<bool> syncLogin(
  BuildContext context,
  String username,
  String password,
  dynamic loginResponseJson,
) async {
  try {
    debugPrint('=== Iniciando sincronización de Login ===');

    Map<String, dynamic>? loginData;
    String? authToken;

    // 1. Validar si se proporcionó loginResponseJson
    if (loginResponseJson != null) {
      debugPrint('📦 JSON de Login proporcionado, validando...');
      loginData = _validateAndParseLoginJson(loginResponseJson);

      if (loginData != null) {
        debugPrint('✅ JSON de Login válido, usando datos proporcionados');
        debugPrint(
            '   👤 Usuario: ${loginData['user']?['name_user'] ?? 'N/A'}');
        debugPrint(
            '   🏢 Company: ${loginData['company']?['name_company'] ?? 'N/A'}');
        // Extraer el token del JSON proporcionado
        authToken = loginData['token'];
      } else {
        debugPrint(
            '⚠️ JSON de Login inválido o vacío, llamando al endpoint...');
      }
    } else {
      debugPrint('📡 No se proporcionó JSON, llamando al endpoint...');
    }

    // 2. Si no hay loginData válido, llamar al endpoint
    if (loginData == null) {
      debugPrint('📡 Llamando a POST /Users/Login...');
      debugPrint('   👤 Usuario: $username');
      loginData = await _callLoginAPI(username, password);
      if (loginData == null) {
        debugPrint('❌ Error: No se pudo obtener datos del Login');
        return false;
      }
      debugPrint('✅ Datos del Login obtenidos desde el API');
      // Extraer el token de la respuesta del API
      authToken = loginData['token'];
    }

    // Validar que tengamos un token
    if (authToken == null || authToken.isEmpty) {
      debugPrint('❌ Error: No se pudo obtener el token de autenticación');
      return false;
    }
    debugPrint('🔑 Token obtenido: ${authToken.substring(0, 20)}...');

    // 3. Llamar al endpoint TypesPoints
    debugPrint('📡 Llamando a GET /TypesPoints...');
    final typesPointsData = await _callTypesPointsAPI(authToken);
    if (typesPointsData == null) {
      debugPrint('❌ Error: No se pudo obtener TypesPoints');
      return false;
    }
    debugPrint('✅ TypesPoints obtenidos: ${typesPointsData.length} tipos');

    // 4. Sincronizar en SQLite con transacción
    debugPrint('💾 Sincronizando datos en SQLite...');
    final syncSuccess =
        await _syncLoginDataToSQLite(loginData, typesPointsData);
    if (!syncSuccess) {
      debugPrint('❌ Error en sincronización a SQLite');
      return false;
    }

    debugPrint('✅ Sincronización de Login completada exitosamente');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ EXCEPCIÓN en syncLogin: $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
  }
}

// ============================================================================
// VALIDACIÓN DE JSON
// ============================================================================

/// Valida y parsea el JSON de respuesta del Login
/// Retorna Map<String, dynamic> si es válido, null si es inválido
Map<String, dynamic>? _validateAndParseLoginJson(dynamic loginResponseJson) {
  try {
    // Caso 1: Ya es un Map (dynamic desde AppState o parámetro)
    if (loginResponseJson is Map<String, dynamic>) {
      return _validateLoginDataStructure(loginResponseJson);
    }

    // Caso 2: Es un String JSON (necesita parseo)
    if (loginResponseJson is String) {
      if (loginResponseJson.trim().isEmpty) {
        debugPrint('⚠️ JSON vacío');
        return null;
      }

      try {
        final Map<String, dynamic> parsed = jsonDecode(loginResponseJson);
        return _validateLoginDataStructure(parsed);
      } catch (e) {
        debugPrint('⚠️ Error al parsear JSON string: $e');
        return null;
      }
    }

    // Caso 3: Tipo no soportado
    debugPrint(
        '⚠️ Tipo de loginResponseJson no soportado: ${loginResponseJson.runtimeType}');
    return null;
  } catch (e) {
    debugPrint('⚠️ Error en _validateAndParseLoginJson: $e');
    return null;
  }
}

/// Valida la estructura del Map de loginData
/// Verifica que tenga los campos mínimos requeridos
Map<String, dynamic>? _validateLoginDataStructure(
    Map<String, dynamic> loginData) {
  try {
    // Validar campos críticos que DEBEN existir
    if (loginData['company'] == null) {
      debugPrint('⚠️ Campo "company" no encontrado en loginData');
      return null;
    }

    // El API usa "user_default", "device_default", "activity_default"
    // pero internamente los renombramos a "user", "device", "activity" para compatibilidad
    if (loginData['user_default'] != null && loginData['user'] == null) {
      debugPrint('   🔄 Normalizando "user_default" → "user"');
      loginData['user'] = loginData['user_default'];
    }

    if (loginData['device_default'] != null && loginData['device'] == null) {
      debugPrint('   🔄 Normalizando "device_default" → "device"');
      loginData['device'] = loginData['device_default'];
    }

    if (loginData['activity_default'] != null &&
        loginData['activity'] == null) {
      debugPrint('   🔄 Normalizando "activity_default" → "activity"');
      loginData['activity'] = loginData['activity_default'];
    }

    // Debug: Mostrar campos disponibles en el nivel superior
    debugPrint('   📋 Campos del JSON: ${loginData.keys.toList()}');

    // Ahora validar que existan los campos normalizados
    if (loginData['user'] == null) {
      debugPrint('⚠️ Campo "user" o "user_default" no encontrado en loginData');
      return null;
    }

    if (loginData['device'] == null) {
      debugPrint(
          '⚠️ Campo "device" o "device_default" no encontrado en loginData');
      return null;
    }

    // Validar que company tenga id_company
    final company = loginData['company'];
    if (company is! Map || company['id_company'] == null) {
      debugPrint('⚠️ Campo "company.id_company" inválido');
      return null;
    }

    // Validar que user tenga id_user (puede ser 0 o vacío en user_default)
    final user = loginData['user'];
    if (user is! Map) {
      debugPrint('⚠️ Campo "user" no es un Map');
      return null;
    }

    // Validar que device tenga id_device (puede ser 0 o vacío en device_default)
    final device = loginData['device'];
    if (device is! Map) {
      debugPrint('⚠️ Campo "device" no es un Map');
      return null;
    }

    // Si llegamos aquí, el JSON es válido
    debugPrint('✅ Estructura de loginData válida');
    debugPrint('   - Company ID: ${company['id_company']}');
    debugPrint('   - User: ${user['name_user'] ?? 'N/A'}');
    debugPrint('   - Device: ${device['device_name'] ?? 'N/A'}');

    // Validar campos opcionales (advertir si faltan pero no rechazar)
    if (loginData['headquarters'] == null ||
        (loginData['headquarters'] is List &&
            (loginData['headquarters'] as List).isEmpty)) {
      debugPrint('⚠️ Advertencia: "headquarters" vacío o nulo');
    }

    if (loginData['products'] == null ||
        (loginData['products'] is List &&
            (loginData['products'] as List).isEmpty)) {
      debugPrint('⚠️ Advertencia: "products" vacío o nulo');
    }

    if (loginData['activities'] == null ||
        (loginData['activities'] is List &&
            (loginData['activities'] as List).isEmpty)) {
      debugPrint('⚠️ Advertencia: "activities" vacío o nulo');
    }

    return loginData;
  } catch (e) {
    debugPrint('⚠️ Error validando estructura de loginData: $e');
    return null;
  }
}

// ============================================================================
// LLAMADAS AL API
// ============================================================================

/// Llama al endpoint POST /Users/Login
Future<Map<String, dynamic>?> _callLoginAPI(
  String username,
  String password,
) async {
  try {
    const String url = 'https://api.clickpalm.com/Users/Login';

    final Map<String, dynamic> requestBody = {
      'user_name': username,
      'pass_word': password,
      'type_login': 'IMEI',
    };

    debugPrint('📤 Login Request Body:');
    debugPrint('   user_name: $username');
    debugPrint('   type_login: IMEI');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('📥 Login Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('✅ Login exitoso');
      return data;
    } else {
      debugPrint('❌ Error en Login API: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('❌ Excepción en _callLoginAPI: $e');
    return null;
  }
}

/// Llama al endpoint GET /TypesPoints
Future<List<Map<String, dynamic>>?> _callTypesPointsAPI(
    String authToken) async {
  try {
    const String url = 'https://api.clickpalm.com/TypesPoints';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    debugPrint('📥 TypesPoints Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      debugPrint('❌ Error en TypesPoints API: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('❌ Excepción en _callTypesPointsAPI: $e');
    return null;
  }
}

// ============================================================================
// SINCRONIZACIÓN A SQLITE
// ============================================================================

/// Sincroniza los datos del Login a SQLite usando una transacción
Future<bool> _syncLoginDataToSQLite(
  Map<String, dynamic> loginData,
  List<Map<String, dynamic>> typesPointsData,
) async {
  try {
    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    // Usar transacción para garantizar atomicidad
    await db.transaction((txn) async {
      debugPrint('🔄 Iniciando transacción de sincronización...');

      // PASO 1: Limpiar todas las tablas de Login (excepto Headquarters)
      await _cleanLoginDataTables(txn);

      // PASO 2: Insertar Types_points PRIMERO (sin dependencias)
      await _insertTypesPoints(txn, typesPointsData);

      // PASO 3: Insertar Company
      await _insertCompany(txn, loginData['company']);

      // PASO 4: Insertar Zones + Zones_polygons
      if (loginData['zones'] != null) {
        await _insertZones(txn, loginData['zones']);
      }

      // PASO 5: Insertar Users (marcar default)
      if (loginData['users'] != null) {
        await _insertUsers(
          txn,
          loginData['users'],
          loginData['user']?['id_user'],
        );
      }

      // PASO 6: Insertar Devices (marcar default)
      if (loginData['devices'] != null) {
        await _insertDevices(
          txn,
          loginData['devices'],
          loginData['device']?['id_device'],
        );
      }

      // PASO 7: Insertar Activities + Steps + Status (marcar default)
      if (loginData['activities'] != null) {
        await _insertActivities(
          txn,
          loginData['activities'],
          loginData['activity']?['id_activity'],
        );
      }

      // PASO 8: MERGE Headquarters + Polygons (preservar datos locales)
      if (loginData['headquarters'] != null) {
        await _mergeHeadquarters(txn, loginData['headquarters']);
      }

      // PASO 8.1: Insertar Headquarters_weights desde objeto principal del JSON
      if (loginData['headquarters_weights'] != null) {
        await _insertHeadquartersWeights(txn, loginData['headquarters_weights']);
      }

      // PASO 9: Insertar Products + Coordinates
      if (loginData['products'] != null) {
        await _insertProducts(txn, loginData['products']);
      }

      // PASO 10: Insertar News
      if (loginData['news'] != null) {
        await _insertNews(txn, loginData['news']);
      }

      // PASO 11: Insertar Login_sessions (tracking)
      await _insertLoginSession(txn, loginData);

      debugPrint('✅ Transacción completada exitosamente');
    });

    await db.close();

    // PASO 12: Actualizar AppState
    _updateAppState(loginData);

    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ Error en _syncLoginDataToSQLite: $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
  }
}

// ============================================================================
// LIMPIEZA DE DATOS
// ============================================================================

/// Limpia todas las tablas de Login (estrategia DELETE+INSERT)
/// NOTA: NO elimina Headquarters (se hace MERGE para preservar datos locales)
Future<void> _cleanLoginDataTables(Transaction txn) async {
  debugPrint('🧹 Limpiando tablas de Login...');

  // Orden inverso de dependencias (FK constraints)
  await txn.delete('Login_sessions');
  await txn.delete('News');
  // NO eliminar Products - sync_install_module es el dueño de estos datos
  // await txn.delete('Products_coordinates'); // ✅ COMENTADO: Preservar products instalados
  // await txn.delete('Products');              // ✅ COMENTADO: Preservar products instalados
  await txn.delete('Headquarters_weights');
  // NO eliminar Headquarters, Headquarters_polygons (MERGE con INSERT OR IGNORE)
  await txn.delete('Activities_status');
  await txn.delete('Activities_steps');
  await txn.delete('Activities');
  await txn.delete('Devices');
  await txn.delete('Users');
  await txn.delete('Zones_polygons');
  await txn.delete('Zones');
  await txn.delete('Companies');
  // Types_points se borra y recrea porque sync_login es el dueño de esta tabla
  // El endpoint /TypesPoints tiene la lista completa y oficial
  // sync_install_module solo usa ConflictAlgorithm.replace para los que vienen anidados
  await txn.delete('Types_points');

  debugPrint('   ✅ Tablas limpiadas');
}

// ============================================================================
// FUNCIONES DE INSERCIÓN
// ============================================================================

/// Inserta Types_points desde GET /TypesPoints usando Batch
Future<void> _insertTypesPoints(
  Transaction txn,
  List<Map<String, dynamic>> typesPoints,
) async {
  debugPrint('📝 Insertando Types_points con Batch...');

  final batch = txn.batch();
  for (final type in typesPoints) {
    batch.insert('Types_points', {
      'Id_type_point': type['id_type_point'],
      'Name_type': type['name_type'],
      'Color_type': type['color_type'],
      'Order_type': type['order_type'],
      'Virtual_points_count': type['virtual_points_count'] ?? 0,
    });
  }
  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertados ${typesPoints.length} tipos de puntos');
}

/// Inserta la Company
Future<void> _insertCompany(
  Transaction txn,
  Map<String, dynamic>? company,
) async {
  if (company == null) {
    debugPrint('⚠️ No hay Company para insertar');
    return;
  }

  debugPrint('📝 Insertando Company...');

  await txn.insert('Companies', {
    'Id_company': company['id_company'],
    'Name_company': company['name_company'],
    'Business_name': company['business_name'],
    'Nit': company['nit'],
    'Address': company['address'],
    'Telephone': company['telephone'],
    'Id_zone_default': company['id_zone_default'],
    'Created_at': company['created_at'],
  });

  debugPrint('   ✅ Company insertada: ${company['name_company']}');
}

/// Inserta Zones + Zones_polygons usando Batch
Future<void> _insertZones(
  Transaction txn,
  List<dynamic> zones,
) async {
  debugPrint('📝 Insertando Zones con Batch...');

  final batch = txn.batch();
  int zonesCount = 0;
  int polygonsCount = 0;

  for (final zone in zones) {
    // Insertar zona
    batch.insert('Zones', {
      'Id_zone': zone['id_zone'],
      'Id_company': zone['id_company'],
      'Name_zone': zone['name_zone'],
      'Difficulty': zone['difficulty'] ?? 0,
      'State_zone': zone['state_zone'],
      'Created_at': zone['created_at'],
    });
    zonesCount++;

    // Insertar polígonos de la zona
    if (zone['zones_polygons'] != null) {
      for (final polygon in zone['zones_polygons']) {
        batch.insert('Zones_polygons', {
          'Id_zone_polygon': polygon['id_zone_polygon'],
          'Id_zone': zone['id_zone'],
          'Latitude': polygon['latitude'],
          'Longitude': polygon['longitude'],
          'Created_at': polygon['created_at'],
        });
        polygonsCount++;
      }
    }
  }
  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertadas $zonesCount zonas');
  debugPrint('   ✅ Insertados $polygonsCount polígonos de zonas');
}

/// Inserta Users y marca el usuario por defecto usando Batch
Future<void> _insertUsers(
  Transaction txn,
  List<dynamic> users,
  int? defaultUserId,
) async {
  debugPrint('📝 Insertando Users con Batch...');

  final batch = txn.batch();
  String? defaultUserName;

  for (final user in users) {
    final bool isDefault = (user['id_user'] == defaultUserId);
    if (isDefault) {
      defaultUserName = user['name_user'];
    }

    batch.insert('Users', {
      'Id_user': user['id_user'],
      'Id_company': user['id_company'],
      'Oper_id': user['operID'],
      'Name_user': user['name_user'],
      'Email': user['email'],
      'Created_at': user['created_at'],
      'Modified_at': user['modifiedAt'],
      'Is_default': isDefault ? 1 : 0,
    });
  }
  await batch.commit(noResult: true);

  if (defaultUserName != null) {
    debugPrint('   🎯 Usuario por defecto: $defaultUserName');
  }
  debugPrint('   ✅ Insertados ${users.length} usuarios');
}

/// Inserta Devices y marca el dispositivo por defecto usando Batch
Future<void> _insertDevices(
  Transaction txn,
  List<dynamic> devices,
  int? defaultDeviceId,
) async {
  debugPrint('📝 Insertando Devices con Batch...');

  final batch = txn.batch();
  String? defaultDeviceName;

  for (final device in devices) {
    final bool isDefault = (device['id_device'] == defaultDeviceId);
    if (isDefault) {
      defaultDeviceName = device['device_name'];
    }

    batch.insert('Devices', {
      'Id_device': device['id_device'],
      'Id_company': device['id_company'],
      'Device_name': device['device_name'],
      'Cell_phone': device['cellPhone'],
      'Serial_id': device['serial_id'],
      'Imei1': device['imeI1'],
      'Imei2': device['imeI2'],
      'Model': device['model'],
      'State': device['state'],
      'Is_default': isDefault ? 1 : 0,
    });
  }
  await batch.commit(noResult: true);

  if (defaultDeviceName != null) {
    debugPrint('   🎯 Dispositivo por defecto: $defaultDeviceName');
  }
  debugPrint('   ✅ Insertados ${devices.length} dispositivos');
}

/// Inserta Activities + Steps + Status y marca la actividad por defecto usando Batch
Future<void> _insertActivities(
  Transaction txn,
  List<dynamic> activities,
  int? defaultActivityId,
) async {
  debugPrint('📝 Insertando Activities con Batch...');
  debugPrint('   📊 Total activities desde API: ${activities.length}');

  // Recolectar todos los datos antes de insertar
  final List<Map<String, dynamic>> activitiesData = [];
  final List<Map<String, dynamic>> stepsData = [];
  final Set<int> statusIds = {}; // Para evitar duplicados
  final List<Map<String, dynamic>> statusData = [];
  String? defaultActivityName;

  for (final activity in activities) {
    final bool isDefault = (activity['id_activity'] == defaultActivityId);
    if (isDefault) {
      defaultActivityName = activity['name_activity'];
    }

    // Agregar actividad
    activitiesData.add({
      'Id_activity': activity['id_activity'],
      'Id_company': activity['id_company'],
      'Id_activity_parent': activity['id_activity_parent'],
      'Name_activity': activity['name_activity'],
      'Group_activity': activity['group_activity'],
      'Unity': activity['unity'],
      'Type_activity': activity['type_activity'],
      'Type_effectivity': activity['type_effectivity'],
      'Cycle': activity['cycle'],
      'Effectivity_unitys': activity['effectivity_unitys'],
      'Effectivity_visits': activity['effectivity_visits'],
      'Module_activity': activity['module_activity'],
      'Description_activity': activity['description_activity'],
      'Created_at': activity['created_at'],
      'Is_default': isDefault ? 1 : 0,
    });

    // Recolectar steps de la actividad
    if (activity['activity_steps'] != null) {
      for (final step in activity['activity_steps']) {
        stepsData.add({
          'Id_activity_step': step['id_activity_step'],
          'Id_activity': step['id_activity'],
          'Type_step': step['type_step'],
          'Order_step': step['order_step'],
          'Default_value': step['default_value'],
          'Unity': step['unity'],
          'Calculation': step['calculation'],
          'Name_step': step['name_step'],
          'Status': step['status'],
          'Is_required': step['is_required'] == true ? 1 : 0,
        });

        // Recolectar status padre del step
        if (step['activity_step_parent'] != null) {
          _collectStatusRecursive(step['activity_step_parent'], statusIds, statusData);
        }

        // Recolectar status hijos del step
        if (step['activities_status'] != null) {
          for (final childStatus in step['activities_status']) {
            _collectStatusRecursive(childStatus, statusIds, statusData);
          }
        }
      }
    }

    // Recolectar status directos de la actividad
    if (activity['activity_status'] != null) {
      for (final status in activity['activity_status']) {
        _collectStatusRecursive(status, statusIds, statusData);
      }
    }
  }

  // Insertar todo con Batch
  final batch = txn.batch();

  // Insertar activities
  for (final data in activitiesData) {
    batch.insert('Activities', data);
  }

  // Insertar steps
  for (final data in stepsData) {
    batch.insert('Activities_steps', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Insertar status
  for (final data in statusData) {
    batch.insert('Activities_status', data, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  await batch.commit(noResult: true);

  if (defaultActivityName != null) {
    debugPrint('   🎯 Actividad por defecto: $defaultActivityName');
  }
  debugPrint('   ✅ Insertadas ${activitiesData.length} actividades');
  debugPrint('   ✅ Insertados ${stepsData.length} pasos de actividades');
  debugPrint('   ✅ Insertados ${statusData.length} estados de actividades');
}

/// Recolecta status recursivamente sin duplicados (para Batch)
void _collectStatusRecursive(
  Map<String, dynamic> status,
  Set<int> statusIds,
  List<Map<String, dynamic>> statusData,
) {
  final idActivityStatus = status['id_activity_status'];
  if (idActivityStatus == null || statusIds.contains(idActivityStatus)) {
    return; // Ya existe o es inválido
  }

  statusIds.add(idActivityStatus);
  statusData.add({
    'Id_activity_status': idActivityStatus,
    'Id_activity': status['id_activity'],
    'Id_activity_step_parent': status['id_activity_step_parent'],
    'Id_activity_status_parent': status['id_activity_status_parent'],
    'Type_status': status['type_status'],
    'Order_status': status['order_status'],
    'Default_status': status['default_status'],
    'Status_name': status['status_name'],
    'Color': status['color'],
    'Peso': status['peso'],
    'Castigo': status['castigo'],
    'Boton': status['boton'],
    'Factor': status['factor'],
    'Status': status['status'],
  });

  // Recolectar recursivamente los status hijos
  if (status['activities_status_childs'] != null) {
    for (final childStatus in status['activities_status_childs']) {
      if (childStatus is Map<String, dynamic>) {
        _collectStatusRecursive(childStatus, statusIds, statusData);
      }
    }
  }
}

/// MERGE Headquarters + Polygons usando Batch (preserva datos locales)
Future<void> _mergeHeadquarters(
  Transaction txn,
  List<dynamic> headquarters,
) async {
  debugPrint('📝 Haciendo MERGE de Headquarters con Batch...');

  // Recolectar datos
  final List<Map<String, dynamic>> hqData = [];
  final List<Map<String, dynamic>> polygonsData = [];
  final Set<int> hqIdsToDeletePolygons = {};

  for (final hq in headquarters) {
    final hqId = hq['id_headquarter'];

    // Agregar headquarters
    hqData.add({
      'Id_headquarter': hqId,
      'Id_zone': hq['id_zone'],
      'Created_at': hq['created_at'],
      'Name_headquarter': hq['name_headquarter'],
      'Density_headquarter': hq['density_headquarter'],
      'Seed_time': hq['seed_time'],
      'State_headquarter': hq['state_headquarter'],
      'Area_headquarter': hq['area_headquarter'],
      'Polygon': hq['polygon'],
      'Centroid_coordinate': hq['centroid_coordinate'],
    });

    // Marcar para eliminar polígonos antiguos
    hqIdsToDeletePolygons.add(hqId);

    // Recolectar polígonos válidos
    if (hq['headquarters_polygons'] != null) {
      for (final polygon in hq['headquarters_polygons']) {
        if (polygon['latitude'] != null && polygon['longitude'] != null) {
          polygonsData.add({
            'Id_headquarter_polygon': polygon['id_headquarter_polygon'],
            'Id_headquarter': hqId,
            'Latitude': polygon['latitude'],
            'Longitude': polygon['longitude'],
            'Created_at': polygon['created_at'],
          });
        }
      }
    }
  }

  // Eliminar polígonos antiguos (esto debe hacerse antes del batch insert)
  for (final hqId in hqIdsToDeletePolygons) {
    await txn.delete(
      'Headquarters_polygons',
      where: 'Id_headquarter = ?',
      whereArgs: [hqId],
    );
  }

  // Insertar todo con Batch
  final batch = txn.batch();

  for (final data in hqData) {
    batch.insert('Headquarters', data, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  for (final data in polygonsData) {
    batch.insert('Headquarters_polygons', data);
  }

  await batch.commit(noResult: true);

  debugPrint('   ✅ MERGE de ${hqData.length} lotes (headquarters)');
  debugPrint('   ✅ Insertados ${polygonsData.length} polígonos de lotes');
}

/// Inserta Headquarters_weights desde el objeto principal del JSON
Future<void> _insertHeadquartersWeights(
  Transaction txn,
  List<dynamic> weights,
) async {
  debugPrint('📝 Insertando Headquarters_weights desde objeto principal...');

  if (weights.isEmpty) {
    debugPrint('   ⚠️ No hay weights para insertar');
    return;
  }

  // Limpiar tabla antes de insertar
  await txn.delete('Headquarters_weights');

  final batch = txn.batch();

  for (final weight in weights) {
    batch.insert(
      'Headquarters_weights',
      {
        'Id_headquarter_weight': weight['id_headquarter_weight'],
        'Id_headquarter': weight['id_headquarter'],
        'Id_company': weight['id_company'],
        'Date_year': weight['date_year'],
        'Date_month': weight['date_month'],
        'Weight': weight['weight'],
        'Created_at': weight['created_at'],
        'Modified_at': weight['modified_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertados ${weights.length} pesos de lotes (headquarters_weights)');
}

/// Inserta Products + Coordinates usando Batch
Future<void> _insertProducts(
  Transaction txn,
  List<dynamic> products,
) async {
  debugPrint('📝 Insertando Products con Batch...');

  final List<Map<String, dynamic>> productsData = [];
  final List<Map<String, dynamic>> coordinatesData = [];

  for (final product in products) {
    productsData.add({
      'Id_product': product['id_product'],
      'Id_headquarter': product['id_headquarter'],
      'Id_company': product['id_company'],
      'Id_type': product['id_type'],
      'Created_at': product['created_at'],
      'Modified_at': product['modified_at'],
      'Type_product': product['type_product'],
      'Name_product': product['name_product'],
      'Rfid': product['rfid'],
      'State_product': product['state_product'],
      'Description_product': product['description_product'],
      'Location_raw': product['location_raw'],
      'Line': product['line'],
      'Palm': product['palm'],
    });

    // Recolectar coordenadas del producto
    if (product['products_coordinates'] != null) {
      for (final coord in product['products_coordinates']) {
        coordinatesData.add({
          'Id_product_coordenate': coord['id_product_coordinate'],
          'Id_product': coord['id_product'],
          'Latitude': coord['latitude'],
          'Longitude': coord['longitude'],
        });
      }
    }
  }

  // Insertar todo con Batch
  final batch = txn.batch();

  for (final data in productsData) {
    batch.insert('Products', data);
  }

  for (final data in coordinatesData) {
    batch.insert('Products_coordinates', data);
  }

  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertados ${productsData.length} productos');
  debugPrint('   ✅ Insertadas ${coordinatesData.length} coordenadas de productos');
}

/// Inserta News usando Batch
Future<void> _insertNews(
  Transaction txn,
  List<dynamic> news,
) async {
  debugPrint('📝 Insertando News con Batch...');

  final batch = txn.batch();
  for (final newItem in news) {
    batch.insert('News', {
      'Id_new': newItem['id_new'],
      'Id_company': newItem['id_company'],
      'Name_new': newItem['name_new'],
      'Descripcion_activity': newItem['descripcion_activity'],
      'Order_display': newItem['order_display'] ?? 0,
    });
  }
  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertadas ${news.length} noticias');
}

/// Inserta Login_sessions para tracking
Future<void> _insertLoginSession(
  Transaction txn,
  Map<String, dynamic> loginData,
) async {
  debugPrint('📝 Insertando Login_session...');

  await txn.insert('Login_sessions', {
    'Token': loginData['token'],
    'Products_raw': jsonEncode(loginData['products'] ?? []),
    'Created_at': DateTime.now().toIso8601String(),
    'Synced_at': DateTime.now().toIso8601String(),
    'Id_user': loginData['user']?['id_user'],
    'Id_device': loginData['device']?['id_device'],
    'Id_activity': loginData['activity']?['id_activity'],
  });

  debugPrint('   ✅ Login_session insertada');
}

// ============================================================================
// ACTUALIZAR APPSTATE
// ============================================================================

/// Actualiza AppState con los datos del Login
void _updateAppState(Map<String, dynamic> loginData) {
  debugPrint('🔄 Actualizando AppState...');

  try {
    FFAppState().update(() {
      // Guardar respuesta completa del Login
      FFAppState().loginResponse = loginData;

      // Usuario por defecto
      if (loginData['user'] != null) {
        try {
          FFAppState().userSelected = UsersStruct.fromMap(loginData['user']);
          debugPrint(
              '   ✅ Usuario seleccionado: ${loginData['user']['name_user']}');
        } catch (e) {
          debugPrint('   ⚠️ Error al parsear userSelected: $e');
        }
      }

      // Company por defecto
      if (loginData['company'] != null) {
        try {
          FFAppState().companyDefault =
              CompaniesStruct.fromMap(loginData['company']);
          debugPrint('   ✅ Company: ${loginData['company']['name_company']}');
        } catch (e) {
          debugPrint('   ⚠️ Error al parsear companyDefault: $e');
        }
      }

      // Dispositivo por defecto
      if (loginData['device'] != null) {
        try {
          FFAppState().deviceDefault =
              DevicesStruct.fromMap(loginData['device']);
          debugPrint('   ✅ Dispositivo: ${loginData['device']['device_name']}');
        } catch (e) {
          debugPrint('   ⚠️ Error al parsear deviceDefault: $e');
        }
      }

      // Actividad por defecto - COMENTADO PARA PRESERVAR EL VALOR EXISTENTE
      // NO SE DEBE LIMPIAR al iniciar la aplicación
      /*
      if (loginData['activity'] != null) {
        try {
          FFAppState().activityDefault =
              ActivitiesStruct.fromMap(loginData['activity']);
          debugPrint(
              '   ✅ Actividad: ${loginData['activity']['name_activity']}');
        } catch (e) {
          debugPrint('   ⚠️ Error al parsear activityDefault: $e');
        }
      }
      */
      debugPrint('   ℹ️  activityDefault NO se modifica (se preserva el valor guardado)');
    });

    debugPrint('   ✅ AppState actualizado');
  } catch (e) {
    debugPrint('⚠️ Error actualizando AppState: $e');
  }
}

// ============================================================================
// UTILIDADES
// ============================================================================

/// Obtiene la ruta de la base de datos SQLite
Future<String> _getDatabasePath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String basePath = '${externalDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}
