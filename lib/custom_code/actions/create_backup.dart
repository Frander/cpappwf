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

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '/app_state.dart'; // Para acceder al FFAppState
import 'package:intl/intl.dart';
import 'backup_storage_paths.dart'; // getBackupsRootDirectory()

// ============================================================================
// ACCIÓN: CREAR BACKUP COMPLETO
// ============================================================================

/// Crea un backup completo con:
/// - Copia de la base de datos SQLite
/// - Archivo JSON con los app states persistentes
/// - Carpeta con formato: Backup_2026_02_11__19_04
Future<Map<String, dynamic>> createBackup() async {
  try {
    // Generar fecha y hora actual
    final now = DateTime.now();
    final dateTimeFormat = DateFormat('yyyy_MM_dd__HH_mm');
    final formattedDateTime = dateTimeFormat.format(now);
    final backupFolderName = 'Backup_$formattedDateTime';

    debugPrint('📦 Iniciando backup: $backupFolderName');

    // 1. Obtener la carpeta de Backups en la mejor ruta pública disponible
    final backupsRootDir = await getBackupsRootDirectory();

    // 2. Crear la carpeta del backup con fecha/hora
    final backupDir = Directory(path.join(backupsRootDir.path, backupFolderName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
      debugPrint('✅ Carpeta de backup creada: ${backupDir.path}');
    }

    // 4. Copiar la base de datos SQLite
    await _backupDatabase(backupDir);

    // 5. Crear el archivo JSON con app states persistentes
    await _createBackupConfigJson(backupDir, now);

    // 6. Crear archivo de información del backup
    await _createBackupInfoFile(backupDir, now);

    debugPrint('✅ Backup completado exitosamente');

    return {
      'success': true,
      'backupPath': backupDir.path,
      'backupName': backupFolderName,
      'timestamp': now.toIso8601String(),
      'message': 'Backup creado exitosamente en: $backupFolderName'
    };
  } catch (e) {
    debugPrint('❌ Error creando backup: $e');
    return {
      'success': false,
      'error': e.toString(),
      'message': 'Error al crear el backup: $e'
    };
  }
}

// ============================================================================
// FUNCIÓN: BACKUP DE LA BASE DE DATOS SQLITE
// ============================================================================

Future<void> _backupDatabase(Directory backupDir) async {
  try {
    // Obtener la ruta de la base de datos desde el app state
    final appState = FFAppState();
    String dbPath = appState.pathDatabase;

    // Si no está configurada, usar la ruta por defecto
    if (dbPath.isEmpty) {
      final dbDir = await getApplicationDocumentsDirectory();
      dbPath = path.join(dbDir.path, 'clickpalm_database.db');
    }

    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Base de datos no encontrada en: $dbPath');
    }

    // Copiar el archivo de BD al backup
    final backupDbPath = path.join(backupDir.path, 'clickpalm_database.db');
    await dbFile.copy(backupDbPath);

    // Obtener tamaño
    final dbSize = await dbFile.length();
    debugPrint('✅ BD SQLite copiada: ${(dbSize / 1024 / 1024).toStringAsFixed(2)} MB');
  } catch (e) {
    debugPrint('❌ Error haciendo backup de BD: $e');
    throw Exception('No se pudo hacer backup de la BD: $e');
  }
}

// ============================================================================
// FUNCIÓN: CREAR JSON DE CONFIGURACIONES
// ============================================================================

Future<void> _createBackupConfigJson(Directory backupDir, DateTime backupTime) async {
  try {
    final appState = FFAppState();

    // Crear map con todos los app states persistentes
    final backupData = {
      // Información del backup
      'backup_info': {
        'timestamp': backupTime.toIso8601String(),
        'formatted_date': DateFormat('dd/MM/yyyy').format(backupTime),
        'formatted_time': DateFormat('HH:mm:ss').format(backupTime),
      },

      // Estados persistentes BOOLEANOS
      'boolean_states': {
        'isSync': appState.isSync,
        'isCalibrateVoice': appState.isCalibrateVoice,
        'calibrateCompass': appState.calibrateCompass,
      },

      // Estados persistentes STRINGS
      'string_states': {
        'pathDatabase': appState.pathDatabase,
        'androidID': appState.androidID,
        'sp3NavFile': appState.sp3NavFile,
        'pathPmtiles': appState.pathPmtiles,
      },

      // Estados persistentes NÚMEROS
      'numeric_states': {
        'lastLineInstall': appState.lastLineInstall,
        'lastPalmInstall': appState.lastPalmInstall,
        'routeConfigStartLine': appState.routeConfigStartLine,
        'routeConfigStartPoint': appState.routeConfigStartPoint,
        'routeConfigMaxLines': appState.routeConfigMaxLines,
        'routeConfigMaxPoints': appState.routeConfigMaxPoints,
        'routeConfigPattern': appState.routeConfigPattern,
        'routeConfigErrorMargin': appState.routeConfigErrorMargin,
      },

      // Estados persistentes LISTAS (serializadas)
      'list_voice_calibration': appState.listVoiceCalibration ?? [],

      // Estados persistentes STRUCTS
      'user_selected': _serializeStruct(appState.userSelected.toMap()),
      'company_default': _serializeStruct(appState.companyDefault.toMap()),
      'device_default': _serializeStruct(appState.deviceDefault.toMap()),
      'activity_default': _serializeStruct(appState.activityDefault.toMap()),
      'activity_selected': _serializeStruct(appState.activitySelected.toMap()),
      'headquarter_selected': _serializeStruct(appState.headquarterSelected.toMap()),

      // LISTAS DE STRUCTS
      'headquarters_list': appState.headquartersList
          .map((h) => _serializeStruct(h.toMap()))
          .toList(),
      'products_list': appState.productsList
          .map((p) => _serializeStruct(p.toMap()))
          .toList(),
      'users_list': appState.usersList
          .map((u) => _serializeStruct(u.toMap()))
          .toList(),
      'zones_list': appState.zonesList
          .map((z) => _serializeStruct(z.toMap()))
          .toList(),
      'news_list': appState.newsList
          .map((n) => _serializeStruct(n.toMap()))
          .toList(),
      'news_selected': appState.newsSelected
          .map((n) => _serializeStruct(n.toMap()))
          .toList(),
      'news_add': appState.newsAdd
          .map((n) => _serializeStruct(n.toMap()))
          .toList(),
      'visits_add': appState.visitsAdd
          .map((v) => _serializeStruct(v.toMap()))
          .toList(),
      'headquarters_selected_list': appState.headquartersSelectedList
          .map((h) => _serializeStruct(h.toMap()))
          .toList(),
      'activities_status_selected': appState.activitiesStatusSelected
          .map((a) => _serializeStruct(a.toMap()))
          .toList(),
      'status_add': appState.StatusAdd
          .map((s) => _serializeStruct(s.toMap()))
          .toList(),
      'geo_locations_list': appState.geoLocationsList
          .map((g) => _serializeStruct(g.toMap()))
          .toList(),
      'visit_details': appState.visitDetails
          .map((v) => _serializeStruct(v.toMap()))
          .toList(),

      // JSON DINÁMICOS
      'login_response': appState.loginResponse ?? {},
      'activities_json': appState.activitiesJSON ?? {},
      'user_selected_json': appState.userSelectedJSON ?? {},
      'activity_selected_json': appState.activitySelectedJSON ?? {},
      'current_activity': appState.currentActivity ?? {},
    };

    // Guardar JSON con formato legible
    final jsonString = jsonEncode(backupData);
    final configFile = File(path.join(backupDir.path, 'backup_config.json'));
    await configFile.writeAsString(jsonString);

    final fileSize = await configFile.length();
    debugPrint('✅ Archivo de configuración creado: ${(fileSize / 1024).toStringAsFixed(2)} KB');
  } catch (e) {
    debugPrint('❌ Error creando JSON de configuración: $e');
    throw Exception('No se pudo crear archivo de configuración: $e');
  }
}

// ============================================================================
// FUNCIÓN: CREAR ARCHIVO DE INFORMACIÓN DEL BACKUP
// ============================================================================

Future<void> _createBackupInfoFile(Directory backupDir, DateTime backupTime) async {
  try {
    final appState = FFAppState();
    final deviceInfo = appState.deviceDefault;
    final userInfo = appState.userSelected;
    final companyInfo = appState.companyDefault;

    final infoText = '''
╔════════════════════════════════════════════════════════════════╗
║                   INFORMACIÓN DEL BACKUP                      ║
╚════════════════════════════════════════════════════════════════╝

FECHA Y HORA
───────────────────────────────────────────────────────────────
Fecha: ${DateFormat('dd/MM/yyyy').format(backupTime)}
Hora:  ${DateFormat('HH:mm:ss').format(backupTime)}
ISO:   ${backupTime.toIso8601String()}

DISPOSITIVO
───────────────────────────────────────────────────────────────
Nombre: ${deviceInfo.deviceName ?? 'No configurado'}
IMEI1: ${deviceInfo.imeI1 ?? 'No disponible'}
Model: ${deviceInfo.model ?? 'No disponible'}
Estado: ${deviceInfo.state ?? 'No configurado'}

USUARIO
───────────────────────────────────────────────────────────────
Nombre: ${userInfo.nameUser ?? 'No configurado'}
Email: ${userInfo.email ?? 'No configurado'}
Operador ID: ${userInfo.operID ?? 'No disponible'}

EMPRESA
───────────────────────────────────────────────────────────────
Nombre: ${companyInfo.nameCompany ?? 'No configurada'}
Razón Social: ${companyInfo.businessName ?? 'No disponible'}
NIT: ${companyInfo.nit ?? 'No disponible'}

CONTENIDO DEL BACKUP
───────────────────────────────────────────────────────────────
✓ Base de datos SQLite (clickpalm_database.db)
✓ Archivo de configuraciones (backup_config.json)
✓ Archivo de información (backup_info.txt)

RESTAURACIÓN
───────────────────────────────────────────────────────────────
Para restaurar estos datos:
1. Acceda a: Configuración > Copias de Seguridad
2. Seleccione la opción "Restaurar Backup"
3. Elija esta carpeta de backup
4. Confirme la restauración

NOTA: Se recomienda mantener este backup en un lugar seguro.
Puedes exportar esta carpeta a una unidad USB o nube.

═══════════════════════════════════════════════════════════════════
''';

    final infoFile = File(path.join(backupDir.path, 'backup_info.txt'));
    await infoFile.writeAsString(infoText);

    debugPrint('✅ Archivo de información creado');
  } catch (e) {
    debugPrint('⚠️ Advertencia creando archivo de información: $e');
    // No lanzar excepción, es opcional
  }
}

// ============================================================================
// FUNCIÓN AUXILIAR: SERIALIZAR STRUCTS
// ============================================================================

dynamic _serializeStruct(dynamic value) {
  if (value == null) return null;
  if (value is Map) return value;
  if (value is List) return value.map((e) => _serializeStruct(e)).toList();
  return value.toString();
}
