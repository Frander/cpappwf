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

import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> syncVisitsv2(
  BuildContext context,
  List<VisitsNewsStruct> newsAdd,
  int idCompany,
  String idsHeadquarters,
  String imei,
  String authToken,
) async {
  try {
    debugPrint('=== Iniciando sincronización de visitas v2 ===');
    debugPrint('🏢 Company ID: $idCompany');
    debugPrint('🏪 Headquarters: $idsHeadquarters');
    debugPrint('📱 IMEI: $imei');

    // 1. LIMPIAR ARCHIVOS TEMPORALES ANTIGUOS
    await _cleanupOldTempFiles();

    // 2. PREPARAR LISTA DE NewsAdd
    final List<Map<String, dynamic>> newsAddJson = newsAdd.map((visitNews) {
      final map = visitNews.toMap();

      List<String> locationsFormatted = [];
      final locationsRaw = map['locations_add'] ?? map['locationsAdd'] ?? [];

      if (locationsRaw is List) {
        for (var loc in locationsRaw) {
          if (loc is String) {
            locationsFormatted.add(loc);
          }
        }
      }

      return {
        'id_new': map['id_new'] ?? map['idNew'] ?? 0,
        'id_device': map['id_device'] ?? map['idDevice'],
        'id_user': map['id_user'] ?? map['idUser'],
        'created_at': (visitNews.createdAt != null)
            ? visitNews.createdAt!.toUtc().toIso8601String()
            : DateTime.now().toUtc().toIso8601String(),
        'created_at_local': (visitNews.createdAt != null)
            ? visitNews.createdAt!.toIso8601String()
            : DateTime.now().toIso8601String(),
        'descripcion_new':
            map['descripcion_new'] ?? map['descripcionNew'] ?? '',
        'locations_add': locationsFormatted,
      };
    }).toList();

    // 3. OBTENER VISITS_ADD DESDE SQLITE
    debugPrint('🔄 Obteniendo visits_add desde SQLite...');
    final List<Map<String, dynamic>> visitsAddJson =
        await _getVisitsAddFromSQLite(idCompany);
    debugPrint('📊 Visits_add obtenidas: ${visitsAddJson.length}');

    // 4. CREAR JSON PARA SYNC
    final syncData = {
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'ids_headquarters': idsHeadquarters,
      'imei': imei,
      'id_user': FFAppState().userSelected.idUser, // ID del usuario seleccionado
      'news_add': newsAddJson,
      'visits_add': visitsAddJson,
    };

    debugPrint('📋 Datos preparados:');
    debugPrint('   - news_add: ${newsAddJson.length} registros');
    debugPrint('   - visits_add: ${visitsAddJson.length} registros');

    // Token mutable para permitir renovación en caso de 401
    String currentToken = authToken;
    bool tokenRenewed = false;

    // ==========================================================================
    // ESTRATEGIA 1: ENDPOINT MULTIPART CON ARCHIVOS COMPRIMIDOS (PRINCIPAL)
    // ==========================================================================
    debugPrint('');
    debugPrint('📤 Intento 1: Usando endpoint multipart (SyncVisitsAddMultipart)');

    int multipartStatus = await _syncWithMultipart(
      syncData,
      currentToken,
      idCompany,
      newsAddJson.length,
      visitsAddJson.length,
    );

    // Si recibimos 401, renovar token y reintentar
    if (multipartStatus == 401) {
      debugPrint('🔑 Token expirado (401) en estrategia 1. Renovando token...');
      final newToken = await _renewAuthToken(imei);
      if (newToken != null) {
        currentToken = newToken;
        tokenRenewed = true;
        debugPrint('🔁 Reintentando estrategia 1 con token renovado...');
        multipartStatus = await _syncWithMultipart(
          syncData,
          currentToken,
          idCompany,
          newsAddJson.length,
          visitsAddJson.length,
        );
      }
    }

    if (multipartStatus == 200 || multipartStatus == 202) {
      debugPrint('✅ Sincronización multipart exitosa');
      await _cleanupSQLiteDataAfterSync();
      return true;
    }

    // ==========================================================================
    // ESTRATEGIA 2: ENDPOINT JSON SIMPLE (FALLBACK)
    // ==========================================================================
    debugPrint('');
    debugPrint('⚠️ Endpoint multipart falló, iniciando FALLBACK JSON simple...');
    debugPrint('📤 Intento 2: Usando endpoint simple JSON (SyncVisitsAdd)');

    int jsonStatus = await _syncWithSimpleJson(
      syncData,
      currentToken,
      newsAddJson.length,
      visitsAddJson.length,
    );

    // Si recibimos 401 y aún no renovamos el token, renovar y reintentar
    if (jsonStatus == 401 && !tokenRenewed) {
      debugPrint('🔑 Token expirado (401) en estrategia 2. Renovando token...');
      final newToken = await _renewAuthToken(imei);
      if (newToken != null) {
        currentToken = newToken;
        tokenRenewed = true;
        debugPrint('🔁 Reintentando estrategia 2 con token renovado...');
        jsonStatus = await _syncWithSimpleJson(
          syncData,
          currentToken,
          newsAddJson.length,
          visitsAddJson.length,
        );
      }
    }

    if (jsonStatus == 200 || jsonStatus == 202) {
      debugPrint('✅ Sincronización JSON exitosa');
      await _cleanupSQLiteDataAfterSync();
      return true;
    }

    debugPrint('❌ Ambas estrategias de sincronización fallaron');
    return false;

  } catch (e, stackTrace) {
    debugPrint('⚠️ EXCEPCIÓN GENERAL en syncVisitsv2: $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
  }
}

/// Renueva el token usando POST /Users/RenewToken.
/// Retorna el nuevo token, o null si falla.
Future<String?> _renewAuthToken(String imei) async {
  try {
    const String url = 'https://api.clickpalm.com/Users/RenewToken';
    debugPrint('🔑 Llamando a POST /Users/RenewToken...');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type_login': 'IMEI',
        'username': imei,
        'password': imei,
      }),
    );

    debugPrint('📥 RenewToken Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = data['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        debugPrint('✅ Token renovado exitosamente');
        // Actualizar el token en el estado global
        final dynamic current = FFAppState().loginResponse;
        if (current is Map) {
          final updated = Map<String, dynamic>.from(current);
          updated['token'] = newToken;
          FFAppState().loginResponse = updated;
        }
        return newToken;
      }
    }

    debugPrint('❌ Error al renovar token: ${response.statusCode} - ${response.body}');
    return null;
  } catch (e) {
    debugPrint('⚠️ Excepción en _renewAuthToken: $e');
    return null;
  }
}

/// Sincronización con endpoint JSON simple (SIN archivos comprimidos).
/// Retorna el HTTP status code, o -1 en caso de excepción.
Future<int> _syncWithSimpleJson(
  Map<String, dynamic> syncData,
  String authToken,
  int newsCount,
  int visitsCount,
) async {
  try {
    const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

    debugPrint('🚀 Iniciando sincronización con endpoint JSON simple...');

    final String jsonBody = jsonEncode(syncData);

    debugPrint('📤 ===== PAYLOAD ENVIADO AL API (JSON) =====');
    debugPrint('   - URL: $url');
    debugPrint('   - News: $newsCount');
    debugPrint('   - Visits: $visitsCount');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonBody,
    ).timeout(const Duration(seconds: 90));

    debugPrint('📥 ===== RESPUESTA DEL API (JSON) =====');
    debugPrint('   - Status Code: ${response.statusCode}');
    debugPrint('   - Body: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 202) {
      debugPrint('❌ Error en endpoint JSON:');
      debugPrint('   Status: ${response.statusCode}');
      debugPrint('   Response: ${response.body}');
    }

    return response.statusCode;
  } catch (e) {
    debugPrint('⚠️ Excepción en _syncWithSimpleJson: $e');
    return -1;
  }
}

/// Sincronización con endpoint multipart (CON archivos comprimidos).
/// Retorna el HTTP status code, o -1 en caso de excepción.
Future<int> _syncWithMultipart(
  Map<String, dynamic> syncData,
  String authToken,
  int idCompany,
  int newsCount,
  int visitsCount,
) async {
  try {
    const String url =
        'https://api.clickpalm.com/Sync_times/SyncVisitsAddMultipart';

    debugPrint('🚀 Iniciando sincronización con endpoint multipart...');

    // Obtener archivos comprimidos
    final String tempFolderPath = await _getTempFolderPath();
    final String csvFolderPath = await _getCSVFolderPath();

    debugPrint('🔄 Generando archivos comprimidos...');
    final List<int> visitsCompressed =
        await _getVisitsFromSQLiteAndCompress(tempFolderPath, idCompany);
    final List<int> locationCompressed =
        await _getLocationTrackingFromSQLiteAndCompress(csvFolderPath);

    debugPrint('📊 Archivos comprimidos generados:');
    debugPrint('   - Visitas: ${visitsCompressed.length} bytes');
    debugPrint('   - Locations: ${locationCompressed.length} bytes');

    // Crear request multipart
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $authToken';

    // Agregar JSON
    final String syncModelJsonString = jsonEncode(syncData);
    request.fields['SyncModelJson'] = syncModelJsonString;

    // Agregar archivos comprimidos
    if (visitsCompressed.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'VisitsCompressed',
          visitsCompressed,
          filename: 'visits_${DateTime.now().millisecondsSinceEpoch}.json.gz',
          contentType: MediaType('application', 'gzip'),
        ),
      );
      debugPrint('✅ Archivo VisitsCompressed agregado');
    }

    if (locationCompressed.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'LocationsCompressed',
          locationCompressed,
          filename: 'locations_${DateTime.now().millisecondsSinceEpoch}.csv.gz',
          contentType: MediaType('application', 'gzip'),
        ),
      );
      debugPrint('✅ Archivo LocationsCompressed agregado');
    }

    debugPrint('📤 ===== PAYLOAD ENVIADO AL API (MULTIPART) =====');
    debugPrint('   - URL: $url');
    debugPrint('   - News: $newsCount');
    debugPrint('   - Visits: $visitsCount');
    debugPrint('   - Archivos: ${request.files.length}');

    // Enviar request
    final response = await request.send().timeout(const Duration(seconds: 90));
    final responseBody = await response.stream.bytesToString();

    debugPrint('📥 ===== RESPUESTA DEL API (MULTIPART) =====');
    debugPrint('   - Status Code: ${response.statusCode}');
    debugPrint('   - Body: $responseBody');

    if (response.statusCode != 200 && response.statusCode != 202) {
      debugPrint('❌ Error en endpoint multipart:');
      debugPrint('   Status: ${response.statusCode}');
      debugPrint('   Response: $responseBody');
    }

    return response.statusCode;
  } catch (e) {
    debugPrint('⚠️ Excepción en _syncWithMultipart: $e');
    return -1;
  }
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

String _convertLocationToSimpleFormat(String location) {
  if (location.contains('LAT:') && location.contains('LON:')) {
    final latMatch = RegExp(r'LAT:([-\d.]+)').firstMatch(location);
    final lonMatch = RegExp(r'LON:([-\d.]+)').firstMatch(location);

    if (latMatch != null && lonMatch != null) {
      return '${latMatch.group(1)},${lonMatch.group(1)}';
    }
  }

  return location;
}

Future<List<Map<String, dynamic>>> _getVisitsAddFromSQLite(
    int idCompany) async {
  try {
    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    debugPrint('🔍 Ejecutando query visits_add con Id_company = $idCompany');

    final List<Map<String, dynamic>> rawData = await db.rawQuery('''
      SELECT
        v.Id_visit as id_visit,
        v.Id_company as id_company,
        v.Id_activity as id_activity,
        v.Id_headquarter as id_headquarter,
        v.Id_product as id_product,
        v.Id_user as id_user,
        v.Id_device as id_device,
        v.Created_at as created_at,
        v.Latitude,
        v.Longitude,
        v.Altitude,
        v.Error_horizontal,
        v.Rfid as rfid,

        vd.Id_visit_detail as detail_id,
        vd.Id_activity_status as detail_activity_status,
        vd.Status_option as detail_status_option,
        vd.Status_response as detail_status_response,

        ast.Type_status as detail_type_status,

        vl.Id as location_id,
        vl.Latitude as location_latitude,
        vl.Longitude as location_longitude,
        vl.Altitude as location_altitude,
        vl.HorizontalError as location_horizontal_error
      FROM Visits v
      LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
      LEFT JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
      LEFT JOIN Visits_locations vl ON v.Id_visit = vl.Id_visit
      WHERE v.Id_company = ?
      ORDER BY v.Created_at DESC, vd.Id_visit_detail ASC, vl.Id ASC
    ''', [idCompany]);

    debugPrint('🔍 Query visits_add: ${rawData.length} filas obtenidas');

    // Debug: Imprimir primeras 3 filas para ver qué trae el query
    if (rawData.isNotEmpty) {
      debugPrint('📊 Primeras filas del query:');
      for (int i = 0; i < rawData.length && i < 3; i++) {
        final row = rawData[i];
        debugPrint('   Fila $i:');
        debugPrint('      id_visit: ${row['id_visit']}');
        debugPrint('      id_company: ${row['id_company']}');
        debugPrint('      id_activity: ${row['id_activity']}');
        debugPrint('      detail_id: ${row['detail_id']}');
        debugPrint(
            '      detail_activity_status: ${row['detail_activity_status']}');
        debugPrint(
            '      detail_type_status: ${row['detail_type_status']}');
        debugPrint(
            '      detail_status_option: ${row['detail_status_option']}');
        final statusResponse = row['detail_status_response'] ?? '';
        debugPrint(
            '      detail_status_response: ${statusResponse.length > 100 ? statusResponse.substring(0, 100) + "..." : statusResponse}');
        debugPrint('      location_id: ${row['location_id']}');
      }
    }

    final Map<int, Map<String, dynamic>> visitsMap = {};

    for (final row in rawData) {
      final int visitId = row['id_visit'];

      if (!visitsMap.containsKey(visitId)) {
        // Parsear y validar created_at
        String createdAt;
        String createdAtLocal;
        try {
          final rawCreatedAt = row['created_at'];
          if (rawCreatedAt != null && rawCreatedAt.toString().isNotEmpty) {
            // Intentar parsear la fecha
            final parsedDate = DateTime.tryParse(rawCreatedAt.toString());
            if (parsedDate != null && parsedDate.year > 1900) {
              // Fecha válida
              createdAt = parsedDate.toUtc().toIso8601String();
              createdAtLocal = parsedDate.toIso8601String();
            } else {
              // Fecha inválida, usar fecha actual
              final now = DateTime.now();
              createdAt = now.toUtc().toIso8601String();
              createdAtLocal = now.toIso8601String();
              debugPrint('⚠️ Fecha inválida para visita $visitId, usando fecha actual');
            }
          } else {
            // Campo vacío, usar fecha actual
            final now = DateTime.now();
            createdAt = now.toUtc().toIso8601String();
            createdAtLocal = now.toIso8601String();
            debugPrint('⚠️ Campo created_at vacío para visita $visitId, usando fecha actual');
          }
        } catch (e) {
          // Error parseando, usar fecha actual
          final now = DateTime.now();
          createdAt = now.toUtc().toIso8601String();
          createdAtLocal = now.toIso8601String();
          debugPrint('⚠️ Error parseando created_at para visita $visitId: $e, usando fecha actual');
        }

        visitsMap[visitId] = {
          'created_at': createdAt,
          'created_at_local': createdAtLocal,
          'id_visit': row['id_visit'],
          'id_company': row['id_company'],
          'id_activity': row['id_activity'],
          'id_headquarter': row['id_headquarter'],
          'id_product': row['id_product'],
          'id_user': row['id_user'],
          'id_device': row['id_device'],
          'rfid': row['rfid'], // RFID del TAG NFC o código QR
          'visits_details': <Map<String, dynamic>>[],
          'locations_add': <String>[],
          'location_default':
              'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}',
          '_locations_raw': <Map<String, double>>[],
          '_details_ids': <int>{},
          '_location_ids': <int>{},
        };
      }

      final visit = visitsMap[visitId]!;

      if (row['detail_id'] != null) {
        final int detailId = row['detail_id'];
        if (!visit['_details_ids'].contains(detailId)) {
          visit['_details_ids'].add(detailId);

          // Obtener status_response y type_status
          String statusResponse = row['detail_status_response'] ?? '';
          final String typeStatus = (row['detail_type_status'] ?? '').toString().toLowerCase();

          // ⚠️ DESHABILITADO: No convertir a base64
          // Los archivos de media deben enviarse como multipart, no como base64 en JSON
          // El backend espera referencias "media_X" en status_response y archivos multipart separados
          /*
          if (statusResponse.isNotEmpty) {
            if (typeStatus == 'photo') {
              statusResponse = _compressPhotoBase64(statusResponse);
            } else if (typeStatus == 'video') {
              statusResponse = await _convertVideoToBase64(statusResponse);
            }
          }
          */

          // Para archivos de media, dejar la ruta tal cual temporalmente
          // TODO: Implementar sistema de referencias "media_X" + multipart
          if ((typeStatus == 'photo' || typeStatus == 'video') && statusResponse.isNotEmpty) {
            debugPrint('⚠️ ADVERTENCIA: Archivo $typeStatus con ruta local no será sincronizado correctamente: ${statusResponse.substring(0, 100)}');
            debugPrint('⚠️ Se requiere implementar sistema de referencias multipart para este archivo');
          }

          visit['visits_details'].add({
            'id_visit_detail':
                0, // Siempre 0 para que el API lo trate como nuevo
            'id_visit': 0, // Siempre 0 para que EF asigne el ID correcto
            'id_activity_status': row['detail_activity_status'],
            'status_option': row['detail_status_option'] ?? '',
            'status_response': statusResponse,
          });
        }
      }

      if (row['location_id'] != null) {
        final int locationId = row['location_id'];
        if (!visit['_location_ids'].contains(locationId)) {
          visit['_location_ids'].add(locationId);
          final String locationString = _formatLocationString(
            row['location_latitude']?.toDouble() ?? 0.0,
            row['location_longitude']?.toDouble() ?? 0.0,
            row['location_altitude']?.toDouble() ?? 0.0,
            row['location_horizontal_error']?.toDouble() ?? 0.0,
          );
          visit['locations_add'].add(locationString);
          (visit['_locations_raw'] as List<Map<String, double>>).add({
            'lat': row['location_latitude']?.toDouble() ?? 0.0,
            'lon': row['location_longitude']?.toDouble() ?? 0.0,
            'alt': row['location_altitude']?.toDouble() ?? 0.0,
            'err': row['location_horizontal_error']?.toDouble() ?? 0.0,
          });
        }
      }
    }

    await db.close();

    final List<Map<String, dynamic>> visitsFormatted =
        visitsMap.values.map((visit) {
      final rawList = visit['_locations_raw'] as List<Map<String, double>>;
      if (rawList.isNotEmpty) {
        visit['location_default'] = _computeWeightedLocation(rawList);
      }
      visit.remove('_locations_raw');
      visit.remove('_details_ids');
      visit.remove('_location_ids');
      return visit;
    }).toList();

    debugPrint('✅ Visits_add procesadas: ${visitsFormatted.length}');

    // Debug: Imprimir primer visit formateado para verificar estructura
    if (visitsFormatted.isNotEmpty) {
      debugPrint('📊 Primera visita formateada:');
      final firstVisit = visitsFormatted.first;
      debugPrint('   id_visit: ${firstVisit['id_visit']}');
      debugPrint('   id_company: ${firstVisit['id_company']}');
      debugPrint('   id_activity: ${firstVisit['id_activity']}');
      debugPrint(
          '   visits_details (${firstVisit['visits_details'].length} detalles):');
      if (firstVisit['visits_details'].isNotEmpty) {
        final firstDetail = firstVisit['visits_details'][0];
        debugPrint(
            '      [0] id_visit_detail: ${firstDetail['id_visit_detail']} (siempre 0)');
        debugPrint(
            '          id_visit: ${firstDetail['id_visit']} (siempre 0)');
        debugPrint(
            '          id_activity_status: ${firstDetail['id_activity_status']}');
        debugPrint('          status_option: ${firstDetail['status_option']}');
        debugPrint(
            '          status_response: ${firstDetail['status_response']}');
      }
      debugPrint(
          '   locations_add (${firstVisit['locations_add'].length} coords)');
    }

    return visitsFormatted;
  } catch (e) {
    debugPrint('❌ Error en _getVisitsAddFromSQLite: $e');
    return [];
  }
}

Future<String> _getTempFolderPath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  final String tempPath = '$basePath/sync_files';
  final Directory tempDir = Directory(tempPath);

  if (!await tempDir.exists()) {
    await tempDir.create(recursive: true);
  }

  return tempPath;
}

Future<String> _getCSVFolderPath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  final String csvPath = '$basePath/csv_exports';
  final Directory csvDir = Directory(csvPath);

  if (!await csvDir.exists()) {
    await csvDir.create(recursive: true);
  }

  return csvPath;
}

Future<void> _cleanupOldTempFiles() async {
  try {
    final DateTime sevenDaysAgo =
        DateTime.now().subtract(const Duration(days: 7));

    await _cleanupFolderFiles(await _getTempFolderPath(), sevenDaysAgo, 'JSON');
    await _cleanupFolderFiles(await _getCSVFolderPath(), sevenDaysAgo, 'CSV');
  } catch (e) {
    debugPrint('Error limpiando archivos temporales: $e');
  }
}

Future<void> _cleanupFolderFiles(
    String folderPath, DateTime cutoffDate, String fileType) async {
  try {
    final Directory folder = Directory(folderPath);
    if (await folder.exists()) {
      final List<FileSystemEntity> files = folder.listSync();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          final FileStat stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('✅ Eliminados $deletedCount archivos $fileType antiguos');
      }
    }
  } catch (e) {
    debugPrint('Error limpiando carpeta $fileType: $e');
  }
}

Future<List<int>> _getVisitsFromSQLiteAndCompress(
    String tempPath, int idCompany) async {
  try {
    debugPrint('🚀 Iniciando compresión de visitas...');

    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    final List<Map<String, dynamic>> rawData = await db.rawQuery('''
      SELECT
        v.Id_visit as id_visit,
        v.Id_company as id_company,
        v.Id_activity as id_activity,
        v.Id_headquarter as id_headquarter,
        v.Id_product as id_product,
        v.Id_user as id_user,
        v.Id_device as id_device,
        v.Created_at as created_at,
        v.Latitude,
        v.Longitude,
        v.Altitude,
        v.Error_horizontal,
        v.Rfid as rfid,

        vd.Id_visit_detail as detail_id,
        vd.Id_activity_status as detail_activity_status,
        vd.Status_option as detail_status_option,
        vd.Status_response as detail_status_response,

        ast.Type_status as detail_type_status,

        vl.Id as location_id,
        vl.Latitude as location_latitude,
        vl.Longitude as location_longitude,
        vl.Altitude as location_altitude,
        vl.HorizontalError as location_horizontal_error
      FROM Visits v
      LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
      LEFT JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
      LEFT JOIN Visits_locations vl ON v.Id_visit = vl.Id_visit
      WHERE v.Id_company = ?
      ORDER BY v.Created_at DESC, vd.Id_visit_detail ASC, vl.Id ASC
    ''', [idCompany]);

    debugPrint('🔍 Query compresión: ${rawData.length} filas obtenidas');

    // Debug: Imprimir primeras filas del query para verificar estructura
    if (rawData.isNotEmpty) {
      debugPrint('📊 DEBUG - Primeras 3 filas del query de compresión:');
      for (int i = 0; i < rawData.length && i < 3; i++) {
        final row = rawData[i];
        debugPrint('   Fila $i:');
        debugPrint('      id_visit: ${row['id_visit']}');
        debugPrint('      detail_id: ${row['detail_id']}');
        debugPrint(
            '      detail_activity_status: ${row['detail_activity_status']}');
        debugPrint(
            '      detail_type_status: ${row['detail_type_status']}');
        debugPrint(
            '      detail_status_option: ${row['detail_status_option']}');
        final statusResponse = row['detail_status_response'] ?? '';
        debugPrint(
            '      detail_status_response: ${statusResponse.length > 100 ? statusResponse.substring(0, 100) + "..." : statusResponse}');
      }
    }

    final Map<int, Map<String, dynamic>> visitsMap = {};

    for (final row in rawData) {
      final int visitId = row['id_visit'];

      if (!visitsMap.containsKey(visitId)) {
        // Parsear y validar created_at
        String createdAt;
        String createdAtLocal;
        try {
          final rawCreatedAt = row['created_at'];
          if (rawCreatedAt != null && rawCreatedAt.toString().isNotEmpty) {
            // Intentar parsear la fecha
            final parsedDate = DateTime.tryParse(rawCreatedAt.toString());
            if (parsedDate != null && parsedDate.year > 1900) {
              // Fecha válida
              createdAt = parsedDate.toUtc().toIso8601String();
              createdAtLocal = parsedDate.toIso8601String();
            } else {
              // Fecha inválida, usar fecha actual
              final now = DateTime.now();
              createdAt = now.toUtc().toIso8601String();
              createdAtLocal = now.toIso8601String();
              debugPrint('⚠️ Fecha inválida para visita $visitId, usando fecha actual');
            }
          } else {
            // Campo vacío, usar fecha actual
            final now = DateTime.now();
            createdAt = now.toUtc().toIso8601String();
            createdAtLocal = now.toIso8601String();
            debugPrint('⚠️ Campo created_at vacío para visita $visitId, usando fecha actual');
          }
        } catch (e) {
          // Error parseando, usar fecha actual
          final now = DateTime.now();
          createdAt = now.toUtc().toIso8601String();
          createdAtLocal = now.toIso8601String();
          debugPrint('⚠️ Error parseando created_at para visita $visitId: $e, usando fecha actual');
        }

        visitsMap[visitId] = {
          'created_at': createdAt,
          'created_at_local': createdAtLocal,
          'id_visit': row['id_visit'],
          'id_company': row['id_company'],
          'id_activity': row['id_activity'],
          'id_headquarter': row['id_headquarter'],
          'id_product': row['id_product'],
          'id_user': row['id_user'],
          'id_device': row['id_device'],
          'rfid': row['rfid'], // RFID del TAG NFC o código QR
          'visits_details': <Map<String, dynamic>>[],
          'locations_add': <String>[],
          'location_default':
              'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}',
          '_locations_raw': <Map<String, double>>[],
          '_details_ids': <int>{},
          '_location_ids': <int>{},
        };
      }

      final visit = visitsMap[visitId]!;

      if (row['detail_id'] != null) {
        final int detailId = row['detail_id'];
        if (!visit['_details_ids'].contains(detailId)) {
          visit['_details_ids'].add(detailId);

          // Obtener status_response y type_status
          String statusResponse = row['detail_status_response'] ?? '';
          final String typeStatus = (row['detail_type_status'] ?? '').toString().toLowerCase();

          // ⚠️ DESHABILITADO: No convertir a base64
          // Los archivos de media deben enviarse como multipart, no como base64 en JSON
          // El backend espera referencias "media_X" en status_response y archivos multipart separados
          /*
          if (statusResponse.isNotEmpty) {
            if (typeStatus == 'photo') {
              statusResponse = _compressPhotoBase64(statusResponse);
            } else if (typeStatus == 'video') {
              statusResponse = await _convertVideoToBase64(statusResponse);
            }
          }
          */

          // Para archivos de media, dejar la ruta tal cual temporalmente
          // TODO: Implementar sistema de referencias "media_X" + multipart
          if ((typeStatus == 'photo' || typeStatus == 'video') && statusResponse.isNotEmpty) {
            debugPrint('⚠️ ADVERTENCIA: Archivo $typeStatus con ruta local no será sincronizado correctamente: ${statusResponse.substring(0, 100)}');
            debugPrint('⚠️ Se requiere implementar sistema de referencias multipart para este archivo');
          }

          visit['visits_details'].add({
            'id_visit_detail':
                0, // Siempre 0 para que el API lo trate como nuevo
            'id_visit': 0, // Siempre 0 para que EF asigne el ID correcto
            'id_activity_status': row['detail_activity_status'],
            'status_option': row['detail_status_option'] ?? '',
            'status_response': statusResponse,
          });
        }
      }

      if (row['location_id'] != null) {
        final int locationId = row['location_id'];
        if (!visit['_location_ids'].contains(locationId)) {
          visit['_location_ids'].add(locationId);
          final String locationString = _formatLocationString(
            row['location_latitude']?.toDouble() ?? 0.0,
            row['location_longitude']?.toDouble() ?? 0.0,
            row['location_altitude']?.toDouble() ?? 0.0,
            row['location_horizontal_error']?.toDouble() ?? 0.0,
          );
          visit['locations_add'].add(locationString);
          (visit['_locations_raw'] as List<Map<String, double>>).add({
            'lat': row['location_latitude']?.toDouble() ?? 0.0,
            'lon': row['location_longitude']?.toDouble() ?? 0.0,
            'alt': row['location_altitude']?.toDouble() ?? 0.0,
            'err': row['location_horizontal_error']?.toDouble() ?? 0.0,
          });
        }
      }
    }

    final List<Map<String, dynamic>> visitsWithDetails =
        visitsMap.values.map((visit) {
      final rawList = visit['_locations_raw'] as List<Map<String, double>>;
      if (rawList.isNotEmpty) {
        visit['location_default'] = _computeWeightedLocation(rawList);
      }
      visit.remove('_locations_raw');
      visit.remove('_details_ids');
      visit.remove('_location_ids');
      return visit;
    }).toList();

    await db.close();

    debugPrint('📊 Visitas para comprimir: ${visitsWithDetails.length}');

    if (visitsWithDetails.isEmpty) {
      debugPrint('⚠️ No hay visitas para comprimir');
      return [];
    }

    // Generar JSON
    final String jsonContent = jsonEncode(visitsWithDetails);
    debugPrint('📄 JSON generado: ${jsonContent.length} caracteres');

    // Debug: Imprimir primera visita para verificar estructura
    if (visitsWithDetails.isNotEmpty) {
      debugPrint('🔍 DEBUG - Primera visita en JSON comprimido:');
      final firstVisit = visitsWithDetails.first;
      debugPrint('   id_visit: ${firstVisit['id_visit']}');
      debugPrint('   visits_details: ${firstVisit['visits_details']}');
      if (firstVisit['visits_details'] != null &&
          firstVisit['visits_details'].isNotEmpty) {
        debugPrint(
            '   ✅ Tiene ${firstVisit['visits_details'].length} detalles');
        debugPrint('   Primer detalle: ${firstVisit['visits_details'][0]}');
      } else {
        debugPrint('   ⚠️ visits_details está VACÍO');
      }
    }

    // Comprimir con GZIP
    final List<int> jsonBytes = utf8.encode(jsonContent);
    final List<int> compressed = gzip.encode(jsonBytes);
    debugPrint('🗜️ Compresión completada: ${compressed.length} bytes');

    debugPrint('✅ Compresión de visitas exitosa');
    debugPrint('   - Original: ${jsonBytes.length} bytes');
    debugPrint('   - Comprimido: ${compressed.length} bytes');
    debugPrint(
        '   - Ratio: ${((1 - compressed.length / jsonBytes.length) * 100).toStringAsFixed(1)}% reducción');

    return compressed;
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR en _getVisitsFromSQLiteAndCompress: $e');
    debugPrint('Stack trace: $stackTrace');
    return [];
  }
}

Future<List<int>> _getLocationTrackingFromSQLiteAndCompress(
    String tempPath) async {
  try {
    debugPrint('🚀 Iniciando compresión de locations...');

    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    final List<Map<String, dynamic>> locations = await db.query(
      'Location_tracking',
      orderBy: 'CreatedAt ASC',
    );

    await db.close();

    debugPrint('🔍 Locations obtenidas: ${locations.length}');

    if (locations.isEmpty) {
      debugPrint('⚠️ No hay geolocalizaciones para sincronizar');
      return [];
    }

    // Generar CSV
    final StringBuffer csvContent = StringBuffer();
    //csvContent.writeln(
    //'Id_company,Imei,Latitude,Longitude,Altitude,HorizontalError,CreatedAt,SyncedAt,batch_id');

    for (final location in locations) {
      // Formato CSV con 15 campos (orden esperado por servidor):
      // 1.Id_company, 2.Imei, 3.Latitude, 4.Longitude, 5.Altitude, 6.HorizontalError,
      // 7.CreatedAt, 8.SyncedAt, 9.Batch_id, 10.Id_user(opcional), 11.Id_activity(opcional),
      // 12.Date_start(opcional), 13.Date_finish(opcional), 14.Evaluated_radius(opcional), 15.Point_count(opcional)
      csvContent.writeln(
          '${location['Id_company']},${location['Imei']},${location['Latitude']},${location['Longitude']},${location['Altitude']},${location['HorizontalError']},${location['CreatedAt']},${location['SyncedAt']},${location['batch_id'] ?? ''},${location['Id_user'] ?? ''},${location['Id_activity'] ?? ''},${location['date_start'] ?? ''},${location['date_finish'] ?? ''},${location['evaluated_radius'] ?? ''},${location['point_count'] ?? 1}');
    }

    debugPrint('📄 CSV generado: ${csvContent.length} caracteres');

    // Guardar CSV
    final String timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String csvFilePath = '$tempPath/location_$timestamp.csv';
    final File csvFile = File(csvFilePath);
    await csvFile.writeAsString(csvContent.toString());
    debugPrint('💾 CSV guardado en: $csvFilePath');

    // Comprimir con GZIP
    final List<int> csvBytes = utf8.encode(csvContent.toString());
    final List<int> compressed = gzip.encode(csvBytes);
    debugPrint('🗜️ Compresión completada: ${compressed.length} bytes');

    // Guardar archivo comprimido
    final String gzFilePath = '$csvFilePath.gz';
    final File gzFile = File(gzFilePath);
    await gzFile.writeAsBytes(compressed);
    debugPrint('💾 Archivo .gz guardado en: $gzFilePath');

    debugPrint('✅ Compresión de locations exitosa');
    debugPrint('   - Original: ${csvBytes.length} bytes');
    debugPrint('   - Comprimido: ${compressed.length} bytes');
    debugPrint(
        '   - Ratio: ${((1 - compressed.length / csvBytes.length) * 100).toStringAsFixed(1)}% reducción');

    return compressed;
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR en _getLocationTrackingFromSQLiteAndCompress: $e');
    debugPrint('Stack trace: $stackTrace');
    return [];
  }
}

Future<String> _getDatabasePath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}

Future<void> _cleanupSQLiteDataAfterSync() async {
  try {
    debugPrint('🧹 Iniciando limpieza COMPLETA de datos sincronizados...');

    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);

    // 1. Limpiar Location_tracking - TODOS los registros hasta el momento de sincronización
    final DateTime syncTime = DateTime.now();
    final String syncTimeISO = syncTime.toIso8601String();

    final int deletedLocations = await db.rawDelete('''
      DELETE FROM Location_tracking
      WHERE CreatedAt <= ?
    ''', [syncTimeISO]);
    debugPrint(
        '   ✅ Eliminadas $deletedLocations geolocalizaciones (todas hasta la sincronización)');

    // 2. Obtener IDs de visitas antes de eliminar
    final List<Map<String, dynamic>> allVisits = await db.rawQuery('''
      SELECT Id_visit FROM Visits
    ''');

    if (allVisits.isNotEmpty) {
      final List<int> visitIds =
          allVisits.map((v) => v['Id_visit'] as int).toList();
      final String placeholders = visitIds.map((_) => '?').join(',');

      // Eliminar coordenadas de visitas
      final int deletedVisitLocations = await db.rawDelete('''
        DELETE FROM Visits_locations
        WHERE Id_visit IN ($placeholders)
      ''', visitIds);

      // Eliminar detalles de visitas
      final int deletedDetails = await db.rawDelete('''
        DELETE FROM Visits_details
        WHERE Id_visit IN ($placeholders)
      ''', visitIds);

      // Eliminar visitas
      final int deletedVisits = await db.delete('Visits');

      debugPrint('   ✅ Eliminadas $deletedVisits visitas');
      debugPrint('   ✅ Eliminados $deletedDetails detalles de visitas');
      debugPrint(
          '   ✅ Eliminadas $deletedVisitLocations coordenadas de visitas');
    } else {
      debugPrint('   ℹ️ No hay visitas para eliminar');
    }

    // 3. Limpiar Optimized_route_points (relacionados con rutas)
    final int deletedRoutePoints = await db.delete('Optimized_route_points');
    debugPrint(
        '   ✅ Eliminados $deletedRoutePoints puntos de rutas optimizadas');

    // 4. Limpiar Optimized_routes
    final int deletedRoutes = await db.delete('Optimized_routes');
    debugPrint('   ✅ Eliminadas $deletedRoutes rutas optimizadas');

    // 5-9. Tablas de datos base (Products, Headquarters_coordinates, Types_points,
    // Virtual_points, Products_coordinates) NO se tocan aquí — son propiedad
    // exclusiva de syncBaseData. Solo syncBaseData puede modificarlas.

    // 10. NO limpiar Headquarters_polygons - sync_login es el dueño de estos datos
    // Se preservan para que el módulo NFC (Centro de Administración) pueda
    // mostrar los lotes cercanos en el paso 4 de instalación de TAGs
    // await db.delete('Headquarters_polygons');

    // 11. NO limpiar Headquarters - sync_login es el dueño de estos datos
    // Se preservan para que el módulo NFC (Centro de Administración) pueda
    // mostrar los lotes cercanos en el paso 4 de instalación de TAGs
    // await db.delete('Headquarters');

    // 12. Limpiar Exclusion_zones_history (ya sincronizadas)
    final int deletedExclusionHistory =
        await db.delete('Exclusion_zones_history');
    debugPrint(
        '   ✅ Eliminadas $deletedExclusionHistory modificaciones de zonas de exclusión (ya sincronizadas)');

    await db.close();

    // Limpiar AppState - visitas en memoria
    debugPrint('🧹 Limpiando visitas del AppState...');

    // Primero limpiar directamente las variables
    FFAppState().visitCount = 0;
    FFAppState().visitsAdd = [];
    FFAppState().visitDetails = [];

    // Luego forzar la actualización y persistencia
    FFAppState().update(() {
      // Esto fuerza la persistencia del estado
    });

    // Verificar que se limpiaron correctamente
    debugPrint('   ✅ visitCount actualizado a: ${FFAppState().visitCount}');
    debugPrint(
        '   ✅ visitsAdd limpiado (${FFAppState().visitsAdd.length} elementos)');
    debugPrint(
        '   ✅ visitDetails limpiado (${FFAppState().visitDetails.length} elementos)');

    // Verificación adicional después de update()
    await Future.delayed(
        Duration(milliseconds: 500)); // Dar tiempo para que persista
    debugPrint('   🔍 VERIFICACIÓN POST-UPDATE:');
    debugPrint('      visitCount = ${FFAppState().visitCount}');
    debugPrint('      visitsAdd.length = ${FFAppState().visitsAdd.length}');
    debugPrint(
        '      visitDetails.length = ${FFAppState().visitDetails.length}');

    debugPrint('✅ Limpieza COMPLETA finalizada');
    debugPrint('   📊 Resumen de datos sincronizados y eliminados:');
    debugPrint('      ✅ Visits, Visits_details, Visits_locations');
    debugPrint('      ✅ Exclusion_zones_history (sincronizadas al servidor)');
    debugPrint('      ✅ Products, Virtual_points (Headquarters PRESERVADO para módulo NFC)');
    debugPrint('      ✅ Optimized_routes, Optimized_route_points');
    debugPrint('      ✅ Location_tracking (todos hasta la sincronización)');
    debugPrint('   ✅ AppState limpiado: visitCount, visitsAdd, visitDetails');
  } catch (e) {
    debugPrint('❌ Error en limpieza: $e');
  }
}

String _formatLocationString(
  double latitude,
  double longitude,
  double altitude,
  double horizontalError,
) {
  return 'LAT:${latitude.toStringAsFixed(8)};LON:${longitude.toStringAsFixed(8)};ALT:${altitude.toStringAsFixed(2)};ERH:${horizontalError.toStringAsFixed(2)}';
}

/// Calcula centroide ponderado por inverso del error horizontal al cuadrado.
/// Puntos con menor error tienen mayor peso.
String _computeWeightedLocation(List<Map<String, double>> points) {
  double totalWeight = 0;
  double wLat = 0, wLon = 0, wAlt = 0, wErr = 0;

  for (final p in points) {
    final err = p['err']!;
    final w = 1.0 / (err * err + 0.01);
    wLat += p['lat']! * w;
    wLon += p['lon']! * w;
    wAlt += p['alt']! * w;
    wErr += err * w;
    totalWeight += w;
  }

  final lat = wLat / totalWeight;
  final lon = wLon / totalWeight;
  final alt = wAlt / totalWeight;
  final err = wErr / totalWeight;

  return 'LAT:${lat.toStringAsFixed(8)};LON:${lon.toStringAsFixed(8)};ALT:${alt.toStringAsFixed(2)};ERH:${err.toStringAsFixed(2)}';
}

/// Comprime el contenido base64 de una foto con GZIP
/// Proceso:
/// 1. Decodifica base64 → bytes
/// 2. Comprime con GZIP
/// 3. Re-codifica a base64
String _compressPhotoBase64(String photoPathOrBase64) {
  try {
    if (photoPathOrBase64.isEmpty) {
      return photoPathOrBase64;
    }

    debugPrint('🗜️ Procesando foto para compresión...');

    Uint8List originalBytes;

    // Verificar si es una ruta de archivo
    if (photoPathOrBase64.startsWith('/') ||
        photoPathOrBase64.contains('/data/') ||
        photoPathOrBase64.contains('/cache/')) {
      // Es una ruta de archivo, leer el archivo
      debugPrint('   📂 Detectado como ruta de archivo');
      debugPrint('   📂 Ruta: ${photoPathOrBase64.length > 80 ? photoPathOrBase64.substring(0, 80) + "..." : photoPathOrBase64}');

      final File photoFile = File(photoPathOrBase64);
      if (!photoFile.existsSync()) {
        debugPrint('   ⚠️ Archivo no existe: $photoPathOrBase64');
        return photoPathOrBase64; // Retornar ruta original si no existe
      }

      // Leer bytes del archivo
      originalBytes = photoFile.readAsBytesSync();
      debugPrint('   ✅ Archivo leído: ${originalBytes.length} bytes (${(originalBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
    } else {
      // Es base64, decodificar
      debugPrint('   📄 Detectado como base64');

      // Remover prefijo data URI si existe (data:image/jpeg;base64,)
      String cleanBase64 = photoPathOrBase64;
      if (photoPathOrBase64.contains(',')) {
        final parts = photoPathOrBase64.split(',');
        if (parts.length > 1 && parts[0].contains('base64')) {
          cleanBase64 = parts[1];
          debugPrint('   ℹ️ Prefijo data URI removido');
        }
      }

      // Decodificar base64 a bytes
      debugPrint('   📄 Decodificando base64: ${photoPathOrBase64.length} caracteres');
      originalBytes = base64.decode(cleanBase64);
      debugPrint('   ✅ Base64 decodificado: ${originalBytes.length} bytes');
    }

    // Comprimir con GZIP
    debugPrint('   🗜️ Comprimiendo con GZIP...');
    final List<int> compressedBytes = gzip.encode(originalBytes);
    debugPrint('   ✅ Comprimido: ${compressedBytes.length} bytes');

    // Codificar a base64
    final String compressedBase64 = base64.encode(compressedBytes);
    debugPrint('   ✅ Convertido a base64: ${compressedBase64.length} caracteres');

    // Calcular ratio de compresión
    final double compressionRatio = (1 - compressedBytes.length / originalBytes.length) * 100;
    debugPrint('   ✅ Compresión: ${compressionRatio.toStringAsFixed(1)}% reducción');
    debugPrint('   📊 Original: ${originalBytes.length} bytes → Comprimido: ${compressedBytes.length} bytes');

    return compressedBase64;
  } catch (e) {
    debugPrint('⚠️ Error comprimiendo foto: $e');
    debugPrint('   Retornando contenido original sin comprimir');
    return photoPathOrBase64;
  }
}

/// Convierte un video desde ruta de archivo a base64 (SIN comprimir)
/// Los videos ya están comprimidos con codecs H.264/H.265, no requieren GZIP
///
/// Proceso:
/// 1. Lee el archivo de video desde la ruta
/// 2. Convierte bytes a base64
/// 3. Retorna base64 del video
Future<String> _convertVideoToBase64(String videoPath) async {
  try {
    // Verificar si es una ruta de archivo
    if (!videoPath.startsWith('/') && !videoPath.contains('/data/') && !videoPath.contains('/cache/')) {
      // No es una ruta, podría ser ya un base64 u otro formato
      debugPrint('⚠️ Video no parece ser una ruta de archivo, retornando sin cambios');
      return videoPath;
    }

    debugPrint('🎥 Convirtiendo video a base64...');
    debugPrint('   📂 Ruta: ${videoPath.length > 80 ? videoPath.substring(0, 80) + "..." : videoPath}');

    final File videoFile = File(videoPath);

    if (!videoFile.existsSync()) {
      debugPrint('   ⚠️ Archivo no existe: $videoPath');
      return videoPath; // Retornar ruta original si no existe
    }

    // Leer bytes del archivo
    final Uint8List videoBytes = await videoFile.readAsBytes();
    debugPrint('   ✅ Archivo leído: ${videoBytes.length} bytes (${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

    // Convertir a base64 (SIN comprimir, video ya está comprimido)
    final String videoBase64 = base64.encode(videoBytes);
    debugPrint('   ✅ Convertido a base64: ${videoBase64.length} caracteres');

    // Calcular tamaño final
    final double sizeMB = videoBase64.length / 1024 / 1024;
    debugPrint('   📊 Tamaño final: ${sizeMB.toStringAsFixed(2)} MB');

    return videoBase64;
  } catch (e) {
    debugPrint('⚠️ Error convirtiendo video a base64: $e');
    debugPrint('   Retornando ruta original: $videoPath');
    return videoPath; // Retornar ruta original en caso de error
  }
}
