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
  const String url =
      'https://api.clickpalm.com/Sync_times/SyncVisitsAddMultipart';
  try {
    debugPrint('=== Iniciando sincronización de visitas v2 ===');
    debugPrint('🏢 Company ID: $idCompany');
    debugPrint('🏪 Headquarters: $idsHeadquarters');
    debugPrint('📱 IMEI: $imei');

    // 1. LIMPIAR ARCHIVOS TEMPORALES ANTIGUOS
    await _cleanupOldTempFiles();

    // 2. OBTENER RUTA PARA ARCHIVOS TEMPORALES
    final String tempFolderPath = await _getTempFolderPath();
    debugPrint('📂 Temp folder: $tempFolderPath');

    // 3. OBTENER VISITAS DESDE SQLITE Y CREAR JSON COMPRIMIDO
    debugPrint('🔄 Obteniendo visitas desde SQLite...');
    final List<int> visitsCompressed =
        await _getVisitsFromSQLiteAndCompress(tempFolderPath, idCompany);
    debugPrint('📊 Visitas comprimidas: ${visitsCompressed.length} bytes');

    // 4. OBTENER GEOLOCALIZACIONES DESDE SQLITE Y CREAR CSV COMPRIMIDO
    final String csvFolderPath = await _getCSVFolderPath();
    debugPrint('📂 CSV folder: $csvFolderPath');
    debugPrint('🔄 Obteniendo geolocalizaciones desde SQLite...');
    final List<int> locationCompressed =
        await _getLocationTrackingFromSQLiteAndCompress(csvFolderPath);
    debugPrint('📊 Locations comprimidas: ${locationCompressed.length} bytes');

    // 5. PREPARAR LISTA DE NewsAdd
    final List<Map<String, dynamic>> newsAddJson = newsAdd.map((visitNews) {
      final map = visitNews.toMap();

      // Mantener formato completo de ubicaciones (LAT:X;LON:Y;ALT:Z;ERH:W)
      List<String> locationsFormatted = [];
      final locationsRaw = map['locations_add'] ?? map['locationsAdd'] ?? [];

      if (locationsRaw is List) {
        for (var loc in locationsRaw) {
          if (loc is String) {
            // Agregar directamente el string sin convertir formato
            locationsFormatted.add(loc);
          }
        }
      }

      return {
        'id_new': map['id_new'] ?? map['idNew'] ?? 0,
        'id_device': map['id_device'] ?? map['idDevice'],
        'id_user': map['id_user'] ?? map['idUser'],
        'created_at': (visitNews.createdAt != null)
            ? visitNews.createdAt!.toIso8601String()
            : DateTime.now().toIso8601String(),
        'descripcion_new':
            map['descripcion_new'] ?? map['descripcionNew'] ?? '',
        'locations_add': locationsFormatted,
      };
    }).toList();

    // 6. OBTENER VISITS_ADD DESDE SQLITE (PARA EL JSON, NO PARA COMPRIMIR)
    debugPrint('🔄 Obteniendo visits_add desde SQLite...');
    final List<Map<String, dynamic>> visitsAddJson =
        await _getVisitsAddFromSQLite(idCompany);
    debugPrint('📊 Visits_add obtenidas: ${visitsAddJson.length}');

    // NOTA: NO convertir coordenadas - mantener formato completo LAT:X;LON:Y;ALT:Z;ERH:W
    // El formato completo es requerido por el backend para tener toda la información
    // de altitud y error horizontal
    /*
    for (var visit in visitsAddJson) {
      if (visit['location_default'] != null &&
          visit['location_default'] is String) {
        visit['location_default'] =
            _convertLocationToSimpleFormat(visit['location_default']);
      }

      if (visit['locations_add'] != null && visit['locations_add'] is List) {
        visit['locations_add'] = (visit['locations_add'] as List)
            .map((loc) => _convertLocationToSimpleFormat(loc.toString()))
            .toList();
      }
    }
    */

    // 7. CREAR JSON PARA SyncModelJson
    final syncData = {
      'created_at': DateTime.now().toIso8601String(),
      'ids_headquarters': idsHeadquarters,
      'imei': imei,
      'news_add': newsAddJson,
      'visits_add': visitsAddJson,
    };

    // 7.1. GUARDAR JSON COMPLETO (cuerpo exacto enviado al API)
    try {
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String jsonFilePath = '$tempFolderPath/visits_$timestamp.json';
      final String syncDataJsonString =
          JsonEncoder.withIndent('  ').convert(syncData);
      final File jsonFile = File(jsonFilePath);
      await jsonFile.writeAsString(syncDataJsonString);
      debugPrint('💾 JSON completo del API guardado en: $jsonFilePath');
      debugPrint('   - Tamaño: ${syncDataJsonString.length} caracteres');
    } catch (e) {
      debugPrint('⚠️ Error guardando JSON completo: $e');
    }

    // 8. CREAR REQUEST MULTIPART
    debugPrint('📤 Creando request multipart...');
    var request = http.MultipartRequest('POST', Uri.parse(url));

    // Agregar Authorization header
    request.headers['Authorization'] = 'Bearer $authToken';

    // Agregar campo JSON
    final String syncModelJsonString = jsonEncode(syncData);
    request.fields['SyncModelJson'] = syncModelJsonString;

    debugPrint('📋 SyncModelJson creado:');
    debugPrint('   - Tamaño: ${syncModelJsonString.length} caracteres');
    debugPrint('   - news_add: ${newsAddJson.length} registros');
    debugPrint('   - visits_add: ${visitsAddJson.length} registros');

    // Debug: Imprimir contenido completo del SyncModelJson (sin campos comprimidos)
    debugPrint('📤 ===== CONTENIDO ENVIADO AL API =====');
    try {
      final Map<String, dynamic> syncDataParsed =
          jsonDecode(syncModelJsonString);

      // Crear una copia para debug excluyendo campos comprimidos
      final Map<String, dynamic> debugData = Map.from(syncDataParsed);
      debugData.remove('visits_add_compressed');
      debugData.remove('location_tracking_compressed');

      // Formatear con indentación para mejor legibilidad
      final String prettyJson = JsonEncoder.withIndent('  ').convert(debugData);
      debugPrint(prettyJson);

      // Debug adicional: Verificar visits_details de la primera visita
      if (debugData['visits_add'] != null &&
          debugData['visits_add'] is List &&
          debugData['visits_add'].isNotEmpty) {
        final firstVisit = debugData['visits_add'][0];
        debugPrint('');
        debugPrint('🔍 VERIFICACIÓN - Primera visita en visits_add:');
        debugPrint('   id_visit: ${firstVisit['id_visit']}');
        debugPrint('   id_company: ${firstVisit['id_company']}');
        if (firstVisit['visits_details'] != null &&
            firstVisit['visits_details'] is List) {
          debugPrint(
              '   visits_details: ${firstVisit['visits_details'].length} detalles');
          if (firstVisit['visits_details'].isNotEmpty) {
            debugPrint('   Primer detalle:');
            final firstDetail = firstVisit['visits_details'][0];
            debugPrint(
                '      id_visit_detail: ${firstDetail['id_visit_detail']}');
            debugPrint('      id_visit: ${firstDetail['id_visit']}');
            debugPrint(
                '      id_activity_status: ${firstDetail['id_activity_status']}');
            debugPrint('      status_option: ${firstDetail['status_option']}');
            debugPrint(
                '      status_response: ${firstDetail['status_response']}');
          } else {
            debugPrint('   ⚠️ visits_details está VACÍO');
          }
        } else {
          debugPrint('   ⚠️ visits_details es NULL o no es una lista');
        }
      }

      debugPrint('📤 ===== FIN CONTENIDO ENVIADO =====');
    } catch (e) {
      debugPrint('⚠️ Error al formatear JSON para debug: $e');
    }

    // 9. AGREGAR ARCHIVOS COMPRIMIDOS
    int filesAdded = 0;

    // Agregar archivo JSON comprimido de visitas
    if (visitsCompressed.isNotEmpty) {
      final String visitsFilename =
          'visits_${DateTime.now().millisecondsSinceEpoch}.json.gz';

      request.files.add(
        http.MultipartFile.fromBytes(
          'VisitsCompressed',
          visitsCompressed,
          filename: visitsFilename,
          contentType: MediaType('application', 'gzip'),
        ),
      );

      filesAdded++;
      debugPrint('✅ Archivo VisitsCompressed agregado:');
      debugPrint('   - Nombre: $visitsFilename');
      debugPrint('   - Tamaño: ${visitsCompressed.length} bytes');
    } else {
      debugPrint('⚠️ NO se agregó VisitsCompressed (array vacío)');
    }

    // Agregar archivo CSV comprimido de geolocalizaciones
    if (locationCompressed.isNotEmpty) {
      final String csvFilename =
          'locations_${DateTime.now().millisecondsSinceEpoch}.csv.gz';

      request.files.add(
        http.MultipartFile.fromBytes(
          'LocationsCompressed',
          locationCompressed,
          filename: csvFilename,
          contentType: MediaType('application', 'gzip'),
        ),
      );

      filesAdded++;
      debugPrint('✅ Archivo LocationsCompressed agregado:');
      debugPrint('   - Nombre: $csvFilename');
      debugPrint('   - Tamaño: ${locationCompressed.length} bytes');
    } else {
      debugPrint('⚠️ NO se agregó LocationsCompressed (array vacío)');
    }

    debugPrint('📦 Total de archivos agregados: $filesAdded');
    debugPrint('📋 Campos en request: ${request.fields.keys.join(", ")}');
    debugPrint(
        '📁 Archivos en request: ${request.files.map((f) => f.field).join(", ")}');

    // 10. ENVIAR REQUEST
    debugPrint('🚀 Enviando sincronización...');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    debugPrint('📥 Respuesta recibida:');
    debugPrint('   - Status Code: ${response.statusCode}');
    debugPrint('   - Body: $responseBody');

    // 11. PROCESAR RESPUESTA
    if (response.statusCode == 200 || response.statusCode == 202) {
      debugPrint('✅ Sincronización exitosa');

      // Limpiar datos tras sincronización exitosa
      await _cleanupSQLiteDataAfterSync();
      return true;
    } else {
      debugPrint('❌ Error en sincronización');
      debugPrint('   Status: ${response.statusCode}');
      debugPrint('   Response: $responseBody');
      return false;
    }
  } catch (e, stackTrace) {
    debugPrint('⚠️ EXCEPCIÓN GENERAL en syncVisitsv2: $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
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

        vd.Id_visit_detail as detail_id,
        vd.Id_activity_status as detail_activity_status,
        vd.Status_option as detail_status_option,
        vd.Status_response as detail_status_response,

        vl.Id as location_id,
        vl.Latitude as location_latitude,
        vl.Longitude as location_longitude,
        vl.Altitude as location_altitude,
        vl.HorizontalError as location_horizontal_error
      FROM Visits v
      LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
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
            '      detail_status_option: ${row['detail_status_option']}');
        debugPrint(
            '      detail_status_response: ${row['detail_status_response']}');
        debugPrint('      location_id: ${row['location_id']}');
      }
    }

    final Map<int, Map<String, dynamic>> visitsMap = {};

    for (final row in rawData) {
      final int visitId = row['id_visit'];

      if (!visitsMap.containsKey(visitId)) {
        visitsMap[visitId] = {
          'created_at': row['created_at'],
          'id_visit': row['id_visit'],
          'id_company': row['id_company'],
          'id_activity': row['id_activity'],
          'id_headquarter': row['id_headquarter'],
          'id_product': row['id_product'],
          'id_user': row['id_user'],
          'id_device': row['id_device'],
          'visits_details': <Map<String, dynamic>>[],
          'locations_add': <String>[],
          'location_default':
              'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}',
          '_details_ids': <int>{},
          '_location_ids': <int>{},
        };
      }

      final visit = visitsMap[visitId]!;

      if (row['detail_id'] != null) {
        final int detailId = row['detail_id'];
        if (!visit['_details_ids'].contains(detailId)) {
          visit['_details_ids'].add(detailId);
          visit['visits_details'].add({
            'id_visit_detail':
                0, // Siempre 0 para que el API lo trate como nuevo
            'id_visit': 0, // Siempre 0 para que EF asigne el ID correcto
            'id_activity_status': row['detail_activity_status'],
            'status_option': row['detail_status_option'] ?? '',
            'status_response': row['detail_status_response'] ?? '',
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
        }
      }
    }

    await db.close();

    final List<Map<String, dynamic>> visitsFormatted =
        visitsMap.values.map((visit) {
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
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String basePath = '${externalDir.path}/ClickPalmData';
  final String tempPath = '$basePath/sync_files';
  final Directory tempDir = Directory(tempPath);

  if (!await tempDir.exists()) {
    await tempDir.create(recursive: true);
  }

  return tempPath;
}

Future<String> _getCSVFolderPath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String basePath = '${externalDir.path}/ClickPalmData';
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

        vd.Id_visit_detail as detail_id,
        vd.Id_activity_status as detail_activity_status,
        vd.Status_option as detail_status_option,
        vd.Status_response as detail_status_response,

        vl.Id as location_id,
        vl.Latitude as location_latitude,
        vl.Longitude as location_longitude,
        vl.Altitude as location_altitude,
        vl.HorizontalError as location_horizontal_error
      FROM Visits v
      LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
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
            '      detail_status_option: ${row['detail_status_option']}');
        debugPrint(
            '      detail_status_response: ${row['detail_status_response']}');
      }
    }

    final Map<int, Map<String, dynamic>> visitsMap = {};

    for (final row in rawData) {
      final int visitId = row['id_visit'];

      if (!visitsMap.containsKey(visitId)) {
        visitsMap[visitId] = {
          'created_at': row['created_at'],
          'id_visit': row['id_visit'],
          'id_company': row['id_company'],
          'id_activity': row['id_activity'],
          'id_headquarter': row['id_headquarter'],
          'id_product': row['id_product'],
          'id_user': row['id_user'],
          'id_device': row['id_device'],
          'visits_details': <Map<String, dynamic>>[],
          'locations_add': <String>[],
          'location_default':
              'LAT:${row['Latitude']};LON:${row['Longitude']};ALT:${row['Altitude']};ERH:${row['Error_horizontal']}',
          '_details_ids': <int>{},
          '_location_ids': <int>{},
        };
      }

      final visit = visitsMap[visitId]!;

      if (row['detail_id'] != null) {
        final int detailId = row['detail_id'];
        if (!visit['_details_ids'].contains(detailId)) {
          visit['_details_ids'].add(detailId);
          visit['visits_details'].add({
            'id_visit_detail':
                0, // Siempre 0 para que el API lo trate como nuevo
            'id_visit': 0, // Siempre 0 para que EF asigne el ID correcto
            'id_activity_status': row['detail_activity_status'],
            'status_option': row['detail_status_option'] ?? '',
            'status_response': row['detail_status_response'] ?? '',
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
        }
      }
    }

    final List<Map<String, dynamic>> visitsWithDetails =
        visitsMap.values.map((visit) {
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
      csvContent.writeln(
          '${location['Id_company']},${location['Imei']},${location['Latitude']},${location['Longitude']},${location['Altitude']},${location['HorizontalError']},${location['CreatedAt']},${location['SyncedAt']},${location['batch_id'] ?? ''}');
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
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String basePath = '${externalDir.path}/ClickPalmData';
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

    // 5. Limpiar Products_coordinates
    final int deletedProductCoords = await db.delete('Products_coordinates');
    debugPrint(
        '   ✅ Eliminadas $deletedProductCoords coordenadas de productos');

    // 6. Limpiar Products
    final int deletedProducts = await db.delete('Products');
    debugPrint('   ✅ Eliminados $deletedProducts productos');

    // 7. Limpiar Headquarters_coordinates (zonas de exclusión)
    final int deletedHQCoords = await db.delete('Headquarters_coordinates');
    debugPrint('   ✅ Eliminadas $deletedHQCoords coordenadas de exclusión');

    // 8. Limpiar Types_points
    final int deletedTypes = await db.delete('Types_points');
    debugPrint('   ✅ Eliminados $deletedTypes tipos de puntos');

    // 9. Limpiar Virtual_points
    final int deletedVirtualPoints = await db.delete('Virtual_points');
    debugPrint('   ✅ Eliminados $deletedVirtualPoints puntos virtuales');

    // 10. Limpiar Headquarters_polygons
    final int deletedPolygons = await db.delete('Headquarters_polygons');
    debugPrint('   ✅ Eliminados $deletedPolygons polígonos de lotes');

    // 11. Limpiar Headquarters
    final int deletedHeadquarters = await db.delete('Headquarters');
    debugPrint('   ✅ Eliminados $deletedHeadquarters lotes (headquarters)');

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
    debugPrint('      ✅ Products, Headquarters, Virtual_points');
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
