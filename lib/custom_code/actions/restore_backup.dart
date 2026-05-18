// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'backup_storage_paths.dart'; // getBackupsRootDirectory(), findAllBackupFolders()

// ============================================================================
// ACCIÓN: RESTAURAR BACKUP COMPLETO
// ============================================================================

/// Restaura un backup completo:
/// - Copia de la base de datos SQLite
/// - Restaura los app states persistentes desde JSON
Future<Map<String, dynamic>> restoreBackup(String backupPath) async {
  try {
    final backupDir = Directory(backupPath);

    // Validar que la carpeta existe
    if (!await backupDir.exists()) {
      return {
        'success': false,
        'error': 'Carpeta de backup no encontrada',
        'message': 'La carpeta de backup no existe: $backupPath'
      };
    }

    debugPrint('🔄 Iniciando restauración desde: $backupPath');

    // 1. Restaurar la base de datos
    await _restoreDatabase(backupDir);

    // 2. Restaurar los app states
    await _restoreAppStates(backupDir);

    debugPrint('✅ Restauración completada exitosamente');

    return {
      'success': true,
      'backupPath': backupPath,
      'message': 'Backup restaurado exitosamente',
      'requiresAppRestart': true
    };
  } catch (e) {
    debugPrint('❌ Error restaurando backup: $e');
    return {
      'success': false,
      'error': e.toString(),
      'message': 'Error al restaurar backup: $e'
    };
  }
}

// ============================================================================
// FUNCIÓN: RESTAURAR BASE DE DATOS SQLITE
// ============================================================================

Future<void> _restoreDatabase(Directory backupDir) async {
  try {
    final backupDbPath = path.join(backupDir.path, 'clickpalm_database.db');
    final backupDbFile = File(backupDbPath);

    if (!await backupDbFile.exists()) {
      throw Exception('Archivo de BD no encontrado en backup: $backupDbPath');
    }

    // Obtener la ruta de la BD actual
    final appState = FFAppState();
    String currentDbPath = appState.pathDatabase;

    if (currentDbPath.isEmpty) {
      final dbDir = await getApplicationDocumentsDirectory();
      currentDbPath = path.join(dbDir.path, 'clickpalm_database.db');
    }

    // Hacer backup de la BD actual antes de restaurar
    final currentDbFile = File(currentDbPath);
    if (await currentDbFile.exists()) {
      final backupDir2 = Directory(path.dirname(currentDbPath));
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final currentDbBackupPath = path.join(backupDir2.path, 'clickpalm_database_before_restore_$timestamp.db');
      await currentDbFile.copy(currentDbBackupPath);
      debugPrint('✅ BD actual respaldada en: $currentDbBackupPath');
    }

    // Restaurar la BD desde el backup
    await backupDbFile.copy(currentDbPath);

    final fileSize = await backupDbFile.length();
    debugPrint('✅ BD restaurada: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
  } catch (e) {
    debugPrint('❌ Error restaurando BD: $e');
    throw Exception('No se pudo restaurar la BD: $e');
  }
}

// ============================================================================
// FUNCIÓN: RESTAURAR APP STATES
// ============================================================================

Future<void> _restoreAppStates(Directory backupDir) async {
  try {
    final configFilePath = path.join(backupDir.path, 'backup_config.json');
    final configFile = File(configFilePath);

    if (!await configFile.exists()) {
      throw Exception('Archivo de configuración no encontrado: $configFilePath');
    }

    // Leer el JSON
    final jsonString = await configFile.readAsString();
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    final appState = FFAppState();

    // Restaurar estados BOOLEANOS
    if (backupData['boolean_states'] is Map) {
      final boolStates = backupData['boolean_states'] as Map<String, dynamic>;
      if (boolStates['isSync'] is bool) appState.isSync = boolStates['isSync'];
      if (boolStates['isCalibrateVoice'] is bool) appState.isCalibrateVoice = boolStates['isCalibrateVoice'];
      if (boolStates['calibrateCompass'] is bool) appState.calibrateCompass = boolStates['calibrateCompass'];
    }

    // Restaurar estados STRINGS
    if (backupData['string_states'] is Map) {
      final strStates = backupData['string_states'] as Map<String, dynamic>;
      if (strStates['pathDatabase'] is String) appState.pathDatabase = strStates['pathDatabase'];
      if (strStates['androidID'] is String) appState.androidID = strStates['androidID'];
      if (strStates['sp3NavFile'] is String) appState.sp3NavFile = strStates['sp3NavFile'];
      if (strStates['pathPmtiles'] is String) appState.pathPmtiles = strStates['pathPmtiles'];
    }

    // Restaurar estados NÚMEROS
    if (backupData['numeric_states'] is Map) {
      final numStates = backupData['numeric_states'] as Map<String, dynamic>;
      if (numStates['lastLineInstall'] is int) appState.lastLineInstall = numStates['lastLineInstall'];
      if (numStates['lastPalmInstall'] is int) appState.lastPalmInstall = numStates['lastPalmInstall'];
      if (numStates['routeConfigStartLine'] is int) appState.routeConfigStartLine = numStates['routeConfigStartLine'];
      if (numStates['routeConfigStartPoint'] is int) appState.routeConfigStartPoint = numStates['routeConfigStartPoint'];
      if (numStates['routeConfigMaxLines'] is int) appState.routeConfigMaxLines = numStates['routeConfigMaxLines'];
      if (numStates['routeConfigMaxPoints'] is int) appState.routeConfigMaxPoints = numStates['routeConfigMaxPoints'];
      if (numStates['routeConfigPattern'] is int) appState.routeConfigPattern = numStates['routeConfigPattern'];
      if (numStates['routeConfigErrorMargin'] is double) appState.routeConfigErrorMargin = numStates['routeConfigErrorMargin'];
    }

    // Restaurar lista de voces calibradas
    if (backupData['list_voice_calibration'] is List) {
      appState.listVoiceCalibration = List<String>.from(
        (backupData['list_voice_calibration'] as List).cast<String>()
      );
    }

    // Restaurar STRUCTS
    if (backupData['user_selected'] is Map) {
      try {
        appState.userSelected = UsersStruct.fromSerializableMap(
          Map<String, dynamic>.from(backupData['user_selected'] as Map)
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar userSelected: $e');
      }
    }

    if (backupData['company_default'] is Map) {
      try {
        appState.companyDefault = CompaniesStruct.fromSerializableMap(
          Map<String, dynamic>.from(backupData['company_default'] as Map)
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar companyDefault: $e');
      }
    }

    if (backupData['device_default'] is Map) {
      try {
        appState.deviceDefault = DevicesStruct.fromSerializableMap(
          Map<String, dynamic>.from(backupData['device_default'] as Map)
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar deviceDefault: $e');
      }
    }

    if (backupData['activity_default'] is Map) {
      try {
        appState.activityDefault = ActivitiesStruct.fromSerializableMap(
          Map<String, dynamic>.from(backupData['activity_default'] as Map)
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar activityDefault: $e');
      }
    }

    if (backupData['activity_selected'] is Map) {
      try {
        appState.activitySelected = ActivitiesStruct.fromSerializableMap(
          Map<String, dynamic>.from(backupData['activity_selected'] as Map)
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar activitySelected: $e');
      }
    }

    // Restaurar LISTAS de STRUCTS
    if (backupData['headquarters_list'] is List) {
      try {
        appState.headquartersList = (backupData['headquarters_list'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => HeadquartersStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar headquartersList: $e');
      }
    }

    if (backupData['products_list'] is List) {
      try {
        appState.productsList = (backupData['products_list'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ProductsStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar productsList: $e');
      }
    }

    if (backupData['users_list'] is List) {
      try {
        appState.usersList = (backupData['users_list'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => UsersStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar usersList: $e');
      }
    }

    if (backupData['zones_list'] is List) {
      try {
        appState.zonesList = (backupData['zones_list'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ZonesStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar zonesList: $e');
      }
    }

    if (backupData['news_list'] is List) {
      try {
        appState.newsList = (backupData['news_list'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => NewsStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar newsList: $e');
      }
    }

    if (backupData['visits_add'] is List) {
      try {
        appState.visitsAdd = (backupData['visits_add'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => VisitsStruct.fromSerializableMap(item))
            .toList();
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar visitsAdd: $e');
      }
    }

    // Restaurar JSON DINÁMICOS
    if (backupData['login_response'] is Map) {
      appState.loginResponse = backupData['login_response'];
    }

    if (backupData['activities_json'] is Map) {
      appState.activitiesJSON = backupData['activities_json'];
    }

    if (backupData['current_activity'] is Map) {
      appState.currentActivity = backupData['current_activity'];
    }

    debugPrint('✅ App states restaurados correctamente');
  } catch (e) {
    debugPrint('❌ Error restaurando app states: $e');
    throw Exception('No se pudo restaurar los estados: $e');
  }
}

// ============================================================================
// FUNCIÓN: LISTAR BACKUPS DISPONIBLES
// ============================================================================

/// Obtiene la lista de backups disponibles buscando en todas las rutas accesibles.
Future<List<Map<String, dynamic>>> listAvailableBackups() async {
  try {
    // Busca en TODAS las rutas públicas accesibles (ya ordenadas por fecha desc)
    final backupDirs = await findAllBackupFolders();

    final backups = <Map<String, dynamic>>[];

    for (final entry in backupDirs) {
      final folderName = path.basename(entry.path);
      final infoFile   = File(path.join(entry.path, 'backup_info.txt'));
      final configFile = File(path.join(entry.path, 'backup_config.json'));
      final dbFile     = File(path.join(entry.path, 'clickpalm_database.db'));

      final dbExists     = await dbFile.exists();
      final configExists = await configFile.exists();

      backups.add({
        'name':        folderName,
        'path':        entry.path,
        'hasDatabase': dbExists,
        'hasConfig':   configExists,
        'hasInfo':     await infoFile.exists(),
        'createdTime': entry.statSync().modified,
        'valid':       dbExists && configExists,
      });
    }

    return backups;
  } catch (e) {
    debugPrint('❌ Error listando backups: $e');
    return [];
  }
}

// ============================================================================
// FUNCIÓN: ELIMINAR BACKUP
// ============================================================================

Future<Map<String, dynamic>> deleteBackup(String backupPath) async {
  try {
    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) {
      return {
        'success': false,
        'error': 'Carpeta de backup no encontrada',
      };
    }

    // Eliminar la carpeta completa
    await backupDir.delete(recursive: true);

    debugPrint('✅ Backup eliminado: $backupPath');

    return {
      'success': true,
      'message': 'Backup eliminado correctamente',
    };
  } catch (e) {
    debugPrint('❌ Error eliminando backup: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
