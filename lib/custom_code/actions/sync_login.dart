// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

// ============================================================================
// FLAG: SINCRONIZACIÓN INCOMPLETA
// Si por cualquier motivo falla la inserción de datos básicos a SQLite,
// este flag persiste entre sesiones para forzar una re-sincronización completa
// en el próximo login (llamada al API en vez de usar datos cacheados).
// ============================================================================
const String _kSyncLoginIncompleteKey = 'sync_login_incomplete';

Future<bool> _isSyncLoginIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  final incomplete = prefs.getBool(_kSyncLoginIncompleteKey) ?? false;
  if (incomplete) {
    debugPrint('⚠️ FLAG ACTIVO: La sincronización anterior falló. Forzando re-sync completo desde la API.');
  }
  return incomplete;
}

Future<void> _setSyncLoginIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kSyncLoginIncompleteKey, true);
  debugPrint('🚩 FLAG SET: sync_login_incomplete=true — El próximo login forzará re-sync completo.');
}

Future<void> _clearSyncLoginIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kSyncLoginIncompleteKey);
  debugPrint('✅ FLAG CLEARED: sync_login_incomplete eliminado — Sincronización exitosa.');
}

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
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🚀 INICIANDO SINCRONIZACIÓN DE LOGIN (syncLogin)');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    Map<String, dynamic>? loginData;
    String? authToken;

    // 0. Verificar flag de sincronización incompleta anterior
    final forceFreshSync = await _isSyncLoginIncomplete();

    // 1. Validar si se proporcionó loginResponseJson
    //    Si el flag está activo, ignorar el JSON cacheado y forzar llamada al API
    if (!forceFreshSync && loginResponseJson != null) {
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
    } else if (forceFreshSync) {
      debugPrint('🔄 Re-sync forzado: ignorando JSON cacheado, llamando al API...');
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

    // 3. Extraer IDs (necesarios para todos los endpoints comprimidos)
    final idCompany = loginData['company']?['id_company'];
    final idDevice  = loginData['device']?['id_device'] ?? 0;

    if (idCompany == null) {
      debugPrint('❌ Error: id_company no encontrado en loginData');
      return false;
    }

    // 4. Llamar al endpoint Types_points comprimido con timeout
    debugPrint('📡 Llamando a GET /Users/login-data/types-points (GZIP)...');
    final statusRef = [0];
    List<Map<String, dynamic>>? typesPointsData =
        await _callTypesPointsAPI(authToken, idCompany, statusRef).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ Timeout al obtener TypesPoints (30s)');
        return null;
      },
    );

    // Si el token es inválido/expirado (401), intentar recuperación en dos pasos:
    // Paso A: RenewToken (más rápido, no requiere re-login completo)
    // Paso B: Re-login completo (si RenewToken no es suficiente para TypesPoints)
    if (typesPointsData == null && statusRef[0] == 401) {
      debugPrint('🔑 TypesPoints devolvió 401. Intentando recuperación...');

      // --- Paso A: RenewToken ---
      debugPrint('   [Paso A] Intentando RenewToken...');
      final renewedToken = await _renewAuthToken(username, password);
      if (renewedToken != null) {
        authToken = renewedToken;
        loginData['token'] = renewedToken;
        final statusRefA = [0];
        typesPointsData = await _callTypesPointsAPI(renewedToken, idCompany, statusRefA).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⏱️ Timeout TypesPoints tras RenewToken');
            return null;
          },
        );
        if (typesPointsData != null) {
          debugPrint('   ✅ TypesPoints OK tras RenewToken');
        } else {
          debugPrint('   ❌ TypesPoints sigue fallando tras RenewToken (status: ${statusRefA[0]})');
          debugPrint('   ℹ️ RenewToken puede no ser suficiente para este endpoint.');

          // --- Paso B: Re-login completo ---
          debugPrint('   [Paso B] Intentando re-login completo con /Users/Login...');
          final freshLoginData = await _callLoginAPI(username, password);
          if (freshLoginData != null) {
            final freshToken = freshLoginData['token'] as String?;
            if (freshToken != null && freshToken.isNotEmpty) {
              debugPrint('   ✅ Re-login exitoso. Reintentando TypesPoints...');
              authToken = freshToken;
              loginData['token'] = freshToken;
              typesPointsData = await _callTypesPointsAPI(freshToken, idCompany).timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  debugPrint('⏱️ Timeout TypesPoints tras re-login');
                  return null;
                },
              );
              if (typesPointsData != null) {
                debugPrint('   ✅ TypesPoints OK tras re-login completo');
              } else {
                debugPrint('   ❌ TypesPoints sigue fallando tras re-login. Posible problema del servidor.');
              }
            }
          } else {
            debugPrint('   ❌ Re-login falló. El servidor puede no estar accesible.');
          }
        }
      }
    }

    if (typesPointsData == null) {
      debugPrint('❌ Error: No se pudo obtener TypesPoints tras todos los intentos');
      return false;
    }
    debugPrint('✅ TypesPoints obtenidos: ${typesPointsData.length} tipos');

    debugPrint('🏢 Company ID: $idCompany | Device ID: $idDevice');

    // 5. Fetch en paralelo — solo Users y Devices (mínimo obligatorio para login).
    //    Activities, Headquarters, Zones, News, HQ_weights se sincronizan
    //    manualmente desde ModernSyncPage → "Sincronizar Datos Base".
    debugPrint('');
    debugPrint('📡 ========================================');
    debugPrint('📡 PASO 5: Fetching usuarios y dispositivos...');
    debugPrint('📡 ========================================');

    final listResults = await Future.wait([
      _fetchLoginDataList('users',   authToken, {'idCompany': idCompany.toString(), 'idDevice': idDevice.toString()}),
      _fetchLoginDataList('devices', authToken, {'idCompany': idCompany.toString()}),
    ]);

    final List<dynamic>? usersData   = listResults[0];
    final List<dynamic>? devicesData = listResults[1];

    debugPrint('📊 Resultados del fetch:');
    debugPrint('   Users:   ${usersData?.length ?? "❌ Error"}');
    debugPrint('   Devices: ${devicesData?.length ?? "❌ Error"}');

    // 6. Sincronizar en SQLite con transacción y timeout
    debugPrint('');
    debugPrint('💾 ========================================');
    debugPrint('💾 PASO 6: Sincronizando datos en SQLite');
    debugPrint('💾 ========================================');
    final syncSuccess = await _syncLoginDataToSQLite(
      loginData,
      typesPointsData,
      usersData:   usersData,
      devicesData: devicesData,
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        debugPrint('');
        debugPrint('⏱️ ❌ TIMEOUT al sincronizar en SQLite (60s)');
        debugPrint('⏱️ La operación tardó más de 60 segundos');
        debugPrint('');
        return false;
      },
    );
    if (!syncSuccess) {
      debugPrint('');
      debugPrint('❌ ========================================');
      debugPrint('❌ ERROR en sincronización a SQLite');
      debugPrint('❌ ========================================');
      debugPrint('');
      await _setSyncLoginIncomplete();
      return false;
    }

    await _clearSyncLoginIncomplete();

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('✅ SINCRONIZACIÓN DE LOGIN COMPLETADA EXITOSAMENTE');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ EXCEPCIÓN en syncLogin: $e');
    debugPrint('Stack trace: $stackTrace');
    await _setSyncLoginIncomplete();
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
      'username': username,
      'password': password,
      'type_login': 'IMEI',
    };

    debugPrint('📤 Login Request Body:');
    debugPrint('   username: $username');
    debugPrint('   type_login: IMEI');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ Timeout en _callLoginAPI (30s)');
        throw Exception('Login timeout');
      },
    );

    debugPrint('📥 Login Response Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
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

/// Renueva el token usando POST /Users/RenewToken.
/// Retorna el nuevo token, o null si falla.
/// [username] es el IMEI del dispositivo.
/// [password] es la contraseña usada en el login (vacía para login tipo IMEI).
Future<String?> _renewAuthToken(String username, [String password = '']) async {
  try {
    const String url = 'https://api.clickpalm.com/Users/RenewToken';
    debugPrint('🔑 Llamando a POST /Users/RenewToken...');
    debugPrint('   Type_login: IMEI');
    debugPrint('   Username: $username');
    debugPrint('   Password length: ${password.length}');

    final requestBody = {
      'Type_login': 'IMEI',
      'Username': username,
      'Password': password,
    };
    debugPrint('   Request body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏱️ Timeout en _renewAuthToken (30s)');
        throw Exception('RenewToken timeout');
      },
    );

    debugPrint('📥 RenewToken Status: ${response.statusCode}');
    debugPrint('   Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('   Response keys: ${data.keys.toList()}');
      final newToken = data['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        debugPrint('✅ Token renovado: ${newToken.substring(0, newToken.length > 30 ? 30 : newToken.length)}...');
        return newToken;
      }
      debugPrint('❌ RenewToken: campo "token" vacío o ausente en la respuesta');
    }

    debugPrint('❌ Error al renovar token: ${response.statusCode}');
    return null;
  } catch (e) {
    debugPrint('⚠️ Excepción en _renewAuthToken: $e');
    return null;
  }
}

/// Llama al endpoint GET /Users/login-data/types-points (GZIP comprimido).
/// Retorna los datos, o null si falla.
/// [idCompany] es el ID de la empresa requerido por el nuevo endpoint.
/// [statusRef] es un contenedor de un elemento para exponer el HTTP status code al caller.
Future<List<Map<String, dynamic>>?> _callTypesPointsAPI(
    String authToken, int idCompany, [List<int>? statusRef]) async {
  try {
    final uri = Uri.parse('https://api.clickpalm.com/Users/login-data/types-points')
        .replace(queryParameters: {'idCompany': idCompany.toString()});

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $authToken'},
    );

    debugPrint('📥 TypesPoints Response Status: ${response.statusCode} | ${response.bodyBytes.length} bytes');
    statusRef?[0] = response.statusCode;

    if (response.statusCode == 200) {
      final List<dynamic>? data = _decodeGzipList(response.bodyBytes);
      if (data == null) {
        debugPrint('❌ TypesPoints: respuesta no es una lista');
        return null;
      }
      return data.cast<Map<String, dynamic>>();
    } else {
      debugPrint('❌ Error en TypesPoints API: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('❌ Excepción en _callTypesPointsAPI: $e');
    return null;
  }
}

// ============================================================================
// FETCH LISTAS CON GZIP
// ============================================================================

/// Llama a GET /Users/login-data/{endpoint}, descomprime la respuesta GZIP
/// y retorna la lista de elementos. Retorna null si falla (timeout, error HTTP,
/// error de descompresión). El fallo de un endpoint no aborta el sync completo.
Future<List<dynamic>?> _fetchLoginDataList(
  String endpoint,
  String authToken,
  Map<String, String> queryParams,
) async {
  try {
    final uri = Uri.parse('https://api.clickpalm.com/Users/login-data/$endpoint')
        .replace(queryParameters: queryParams);

    debugPrint('📡 GET /Users/login-data/$endpoint ...');
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $authToken'})
        .timeout(const Duration(seconds: 45));

    debugPrint('   → HTTP ${response.statusCode} | ${response.bodyBytes.length} bytes comprimidos');

    if (response.statusCode == 200) {
      final data = _decodeGzipList(response.bodyBytes);
      if (data != null) {
        debugPrint('   ✅ $endpoint: ${data.length} elementos');
        return data;
      }
      debugPrint('   ⚠️ $endpoint: la respuesta no es una lista');
      return null;
    }

    debugPrint('   ❌ $endpoint → HTTP ${response.statusCode}');
    return null;
  } catch (e) {
    debugPrint('   ❌ Error en $endpoint: $e');
    return null;
  }
}

// ============================================================================
// SINCRONIZACIÓN A SQLITE
// ============================================================================

/// Sincroniza los datos mínimos del Login a SQLite:
/// Types_points, Company, Users, Devices, Login_session.
/// Activities, Headquarters, Zones, News y HQ_weights son responsabilidad
/// de syncBaseData (sincronización manual desde ModernSyncPage).
Future<bool> _syncLoginDataToSQLite(
  Map<String, dynamic> loginData,
  List<Map<String, dynamic>> typesPointsData, {
  List<dynamic>? usersData,
  List<dynamic>? devicesData,
}) async {
  try {
    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    await db.transaction((txn) async {
      debugPrint('🔄 Iniciando transacción de sincronización...');

      // PASO 1: Limpiar solo las tablas que syncLogin gestiona
      await _cleanLoginDataTables(txn);

      // PASO 2: Types_points (sin dependencias, pequeño)
      await _insertTypesPoints(txn, typesPointsData);

      // PASO 3: Company (viene del JSON de login, no de endpoint separado)
      await _insertCompany(txn, loginData['company']);

      // PASO 4: Users (necesario para la pantalla de selección de usuario)
      if (usersData != null) {
        await _insertUsers(txn, usersData, loginData['user']?['id_user']);
      }

      // PASO 5: Devices (necesario para identificar el dispositivo actual)
      if (devicesData != null) {
        await _insertDevices(txn, devicesData, loginData['device']?['id_device']);
      }

      // PASO 6: Login_session (tracking)
      await _insertLoginSession(txn, loginData);

      debugPrint('✅ Transacción completada exitosamente');
    });

    await db.close();

    // Actualizar AppState (company, device, etc.)
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

/// Limpia SOLO las tablas que syncLogin gestiona (DELETE+INSERT).
/// Activities, Headquarters, Zones, News, HQ_weights son propiedad de
/// syncBaseData y NO se tocan aquí.
Future<void> _cleanLoginDataTables(Transaction txn) async {
  debugPrint('🧹 Limpiando tablas de Login...');

  // Orden inverso de dependencias (FK constraints)
  await txn.delete('Login_sessions');
  await txn.delete('Devices');
  await txn.delete('Users');
  await txn.delete('Companies');
  await txn.delete('Types_points');

  // NO tocar: Activities_status, Activities_steps, Activities,
  //           Headquarters_weights, News, Headquarters_polygons,
  //           Headquarters, Zones_polygons, Zones, Products, Products_coordinates,
  //           Virtual_points, Headquarters_coordinates
  // → Son propiedad exclusiva de syncBaseData.

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
    'Id_company':          company['id_company'],
    'Name_company':        company['name_company'],
    'Business_name':       company['business_name'],
    'Nit':                 company['nit'],
    'Address':             company['address'],
    'Telephone':           company['telephone'],
    'Id_zone_default':     company['id_zone_default'],
    'Latitude_extractor':  company['latitude_extractor'],
    'Longitude_extractor': company['longitude_extractor'],
    'Created_at':          company['created_at'],
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
      'Id_zone':          zone['id_zone'],
      'Id_company':       zone['id_company'],
      'Name_zone':        zone['name_zone'],
      'Description_zone': zone['description_zone'],
      'Color_zone':       zone['color_zone'],
      'Difficulty':       zone['difficulty'] ?? 0,
      'State_zone':       zone['state_zone'],
      'Created_at':       zone['created_at'],
    });
    zonesCount++;

    // Insertar polígonos de la zona
    if (zone['zones_polygons'] != null) {
      for (final polygon in zone['zones_polygons']) {
        batch.insert('Zones_polygons', {
          'Id_zone_polygon': polygon['id_zone_polygon'],
          'Id_zone':         zone['id_zone'],
          'Latitude':        polygon['latitude'],
          'Longitude':       polygon['longitude'],
          'Order_polygon':   polygon['order_polygon'] ?? 0,
          'Created_at':      polygon['created_at'],
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
      'Id_user':            user['id_user'],
      'Id_company':         user['id_company'],
      'Oper_id':            user['oper_id'],
      'Name_user':          user['name_user'],
      'Email':              user['email'],
      'Code_user':          user['code_user'],
      'State_user':         user['state_user'],
      'Rol_user':           user['rol_user'],
      'Created_at':         user['created_at'],
      'Modified_at':        user['modified_at'],
      'Is_default':         isDefault ? 1 : 0,
      'Is_active':          (user['is_active'] == true || user['is_active'] == 1) ? 1 : 0,
      'Phone_country_code': user['phone_country_code'],
      'Phone_number':       user['phone_number'],
      'User_name_login':    user['user_name_login'],
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
      'Cell_phone': device['cell_phone'],
      'Serial_id': device['serial_id'],
      'Imei1': device['imei1'],
      'Imei2': device['imei2'],
      'Model': device['model'],
      'State': device['state'],
      'Is_default': isDefault ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      'Is_sync': (activity['is_sync'] == true || activity['is_sync'] == 1) ? 1 : 0,
      'Is_sync_full': (activity['is_sync_full'] == true || activity['is_sync_full'] == 1) ? 1 : 0,
      'Tracking_headquarter': (activity['tracking_headquarter'] == true || activity['tracking_headquarter'] == 1) ? 1 : 0,
      'Read_default': activity['read_default'],
      'Color_activity': activity['color_activity'],
      'Icon_activity':  activity['icon_activity'],
      'Visits_number':  activity['visits_number'] ?? 0,
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
    'Id_activity_status':       idActivityStatus,
    'Id_activity':              status['id_activity'],
    'Id_activity_step_parent':  status['id_activity_step_parent'],
    'Id_activity_status_parent':status['id_activity_status_parent'],
    'Type_status':              status['type_status'],
    'Order_status':             status['order_status'],
    'Default_status':           status['default_status'],
    'Status_name':              status['status_name'],
    'Color':                    status['color'],
    'Peso':                     status['peso'],
    'Castigo':                  status['castigo'],
    'Boton':                    status['boton'],
    'Factor':                   status['factor'],
    'Status':                   status['status'],
    'Description_status':       status['description_status'],
    'Alternative_status':       status['alternative_status'],
    'Remember_status':          (status['remember_status'] == true) ? 1 : 0,
    'Tracking_constant':        (status['tracking_constant'] == true) ? 1 : 0,
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
  debugPrint('   📊 Registros recibidos del API: ${headquarters.length}');
  if (headquarters.isNotEmpty) {
    debugPrint('   🔍 Keys del primer HQ: ${(headquarters.first as Map).keys.toList()}');
    debugPrint('   🔍 Primer HQ: ${headquarters.first}');
  }

  // Recolectar datos
  final List<Map<String, dynamic>> hqData = [];
  final List<Map<String, dynamic>> polygonsData = [];
  final Set<int> hqIdsToDeletePolygons = {};

  for (final hq in headquarters) {
    final hqId = (hq['id_headquarter'] as num?)?.toInt();
    if (hqId == null) {
      debugPrint('   ⚠️ HQ sin id_headquarter, se omite. Keys: ${(hq as Map).keys.toList()}');
      continue;
    }

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
    // Fuente 1: lista headquarters_polygons
    final hqPolygons = hq['headquarters_polygons'] as List<dynamic>?;

    if (hqPolygons != null && hqPolygons.isNotEmpty) {
      for (final polygon in hqPolygons) {
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
    } else if (hq['polygon'] != null && (hq['polygon'] as String).isNotEmpty) {
      // Fuente 2 (fallback): parsear el campo string 'polygon'
      // Formato: [{"LAT":1.445,"LON":-78.689},...]
      try {
        final polygonString = hq['polygon'] as String;
        final List<dynamic> polygonList = jsonDecode(polygonString);
        final now = DateTime.now().toIso8601String();
        int tempId = hqId * 10000; // ID temporal basado en Id_headquarter

        for (final point in polygonList) {
          final lat = point['LAT'] as num?;
          final lon = point['LON'] as num?;

          if (lat != null && lon != null) {
            polygonsData.add({
              'Id_headquarter_polygon': tempId++,
              'Id_headquarter': hqId,
              'Latitude': lat.toDouble(),
              'Longitude': lon.toDouble(),
              'Created_at': now,
            });
          }
        }
        debugPrint('   📍 Parseados ${polygonList.length} vértices del campo polygon para HQ $hqId');
      } catch (e) {
        debugPrint('   ⚠️ Error parseando polygon string para HQ $hqId: $e');
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
  int idCompany,
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
        'Id_company': idCompany,
        'Date_year': weight['date_year'],
        'Date_month': weight['date_month'],
        'Weight': (weight['weight'] ?? 0).toDouble(),
        'Created_at': weight['created_at'],
        'Modified_at': weight['modified_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);

  debugPrint('   ✅ Insertados ${weights.length} pesos de lotes (headquarters_weights)');
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
      'Id_new':               newItem['id_new'],
      'Id_company':           newItem['id_company'],
      'Name_new':             newItem['title_new'],
      'Descripcion_activity': newItem['description_new'],
      'Order_display':        newItem['order_display'] ?? 0,
      'Url_image':            newItem['url_image'],
      'Type_new':             newItem['type_new'],
      'Created_at':           newItem['created_at'],
      'Modified_at':          newItem['modified_at'],
      'State_new':            newItem['state_new'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

/// Lee las Headquarters desde SQLite y las asigna a FFAppState().headquartersList.
/// Se llama después de la transacción, con la DB aún abierta.
Future<void> _loadHeadquartersToAppState(Database db) async {
  try {
    // Diagnóstico: total real en tabla
    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM Headquarters');
    final totalInTable = (countResult.first['cnt'] as int?) ?? 0;
    debugPrint('🔍 [loadHQ] Filas en tabla Headquarters: $totalInTable');

    if (totalInTable == 0) {
      debugPrint('⚠️ [loadHQ] Tabla Headquarters vacía — verifica que _mergeHeadquarters recibió datos');
      FFAppState().headquartersList = [];
      return;
    }

    final rows = await db.query(
      'Headquarters',
      columns: [
        'Id_headquarter',
        'Id_zone',
        'Created_at',
        'Name_headquarter',
        'Density_headquarter',
        'Seed_time',
        'State_headquarter',
        'Area_headquarter',
        'Polygon',
      ],
      orderBy: 'Name_headquarter ASC',
    );

    debugPrint('🔍 [loadHQ] Filas leídas por query: ${rows.length}');
    if (rows.isNotEmpty) {
      debugPrint('🔍 [loadHQ] Primera fila keys: ${rows.first.keys.toList()}');
      debugPrint('🔍 [loadHQ] Primera fila: ${rows.first}');
    }

    final list = rows.map((row) => HeadquartersStruct(
      idHeadquarter: row['Id_headquarter'] as int?,
      idZone:        row['Id_zone'] as int?,
      createdAt:     row['Created_at'] as String?,
      nameHeadquarter: row['Name_headquarter'] as String?,
      densityHeadquarter: row['Density_headquarter'] != null
          ? (row['Density_headquarter'] as num).toInt()
          : null,
      seedTime:      row['Seed_time'] as String?,
      stateHeadquarter: row['State_headquarter'] as String?,
      areaHeadquarter: row['Area_headquarter'] != null
          ? (row['Area_headquarter'] as num).toDouble()
          : null,
      polygon:       row['Polygon'] as String?,
    )).toList();

    FFAppState().headquartersList = list;
    debugPrint('✅ [loadHQ] headquartersList → ${list.length} lotes cargados al AppState');
    if (list.isNotEmpty) {
      debugPrint('   Primer lote: ${list.first.nameHeadquarter} (id: ${list.first.idHeadquarter})');
    }
  } catch (e, st) {
    debugPrint('❌ [loadHQ] Error: $e');
    debugPrint('   Stack: $st');
  }
}

/// Actualiza AppState con los datos del Login
void _updateAppState(Map<String, dynamic> loginData) {
  debugPrint('🔄 Actualizando AppState...');

  try {
    FFAppState().update(() {
      // Guardar respuesta completa del Login
      FFAppState().loginResponse = loginData;

      // userSelected NO se asigna automáticamente desde el API.
      // El usuario debe seleccionarlo manualmente en LoginPage.
      // (loginData['user'] contiene el user_default del servidor, pero
      //  sobreescribirlo aquí causaba que LoginPage saltara la selección manual)
      debugPrint('   ℹ️  userSelected NO se modifica (debe seleccionarse manualmente en LoginPage)');

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
// GZIP HELPERS
// ============================================================================

/// Detecta si los bytes corresponden a datos GZIP por magic bytes (0x1F 0x8B).
/// El cliente HTTP de Flutter (dart:io) descomprime automáticamente cuando
/// recibe Content-Encoding: gzip, por lo que bodyBytes puede llegar ya
/// descomprimido. Esta función evita el error "Filter error, bad data"
/// que ocurre al intentar descomprimir datos que ya son JSON plano.
bool _isGzip(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

/// Decodifica bodyBytes que puede ser GZIP o JSON plano, retornando una List.
/// Retorna null si el JSON resultante no es una lista.
List<dynamic>? _decodeGzipList(List<int> bodyBytes) {
  final List<int> jsonBytes = _isGzip(bodyBytes)
      ? gzip.decode(bodyBytes)
      : bodyBytes;
  final data = jsonDecode(utf8.decode(jsonBytes));
  return data is List ? data : null;
}

// ============================================================================
// NORMALIZACIÓN DE ACTIVITIES PARA EL FORMULARIO
// ============================================================================

/// El formulario lee los status de cada step como `activity_status` (singular),
/// pero el API devuelve `activities_status` (plural). También usa `status_childs`
/// pero el API devuelve `activities_status_childs`. Esta función añade alias
/// para que ambas convenciones funcionen sin tocar el formulario.
List<dynamic> _normalizeActivitiesForForm(List<dynamic> activities) {
  return activities.map((activity) {
    if (activity is! Map) return activity;
    final act = Map<String, dynamic>.from(activity);

    final steps = act['activity_steps'];
    if (steps is List) {
      act['activity_steps'] = steps.map((step) {
        if (step is! Map) return step;
        final s = Map<String, dynamic>.from(step);

        // Normalizar la lista de status del step (puede venir como 'activities_status' o 'activity_status')
        final raw = s['activities_status'] ?? s['activity_status'];
        final normalized = (raw is List) ? raw.map(_normalizeStatus).toList() : <dynamic>[];

        // El formulario usa AMBAS claves en distintas funciones — exponer las dos
        s['activities_status'] = normalized; // usado por _buildStepWidget (line 997)
        s['activity_status']   = normalized; // usado por _initializeDateTimeDefaults (line 718)

        return s;
      }).toList();
    }

    // Normalizar status raíz de la actividad
    final rootStatus = act['activity_status'];
    if (rootStatus is List) {
      act['activity_status'] = rootStatus.map(_normalizeStatus).toList();
    }

    return act;
  }).toList();
}

/// Añade alias `status_childs` → `activities_status_childs` en cada status
/// y aplica la normalización recursivamente a los hijos.
Map<String, dynamic> _normalizeStatus(dynamic status) {
  if (status is! Map) return {};
  final s = Map<String, dynamic>.from(status);

  // Normalizar hijos recursivamente (el formulario usa ambas claves)
  final childs = s['activities_status_childs'] ?? s['status_childs'];
  if (childs is List) {
    final normalized = childs.map(_normalizeStatus).toList();
    s['activities_status_childs'] = normalized;
    s['status_childs']            = normalized; // alias para el formulario
  } else {
    s['activities_status_childs'] = <dynamic>[];
    s['status_childs']            = <dynamic>[];
  }

  return s;
}

// ============================================================================
// UTILIDADES
// ============================================================================

/// Obtiene la ruta de la base de datos SQLite
Future<String> _getDatabasePath() async {
  late Directory baseDir;

  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }

  final String basePath = '${baseDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}
