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
import 'backup_storage_paths.dart'; // findAllBackupFolders()

// ============================================================================
// MODELO: INFORMACIÓN DE BACKUP DISPONIBLE
// ============================================================================

class BackupInfo {
  final String backupPath;
  final String backupName;
  final DateTime createdDate;
  final String dbPath;
  final String configJsonPath;
  final bool isValid;

  BackupInfo({
    required this.backupPath,
    required this.backupName,
    required this.createdDate,
    required this.dbPath,
    required this.configJsonPath,
    required this.isValid,
  });

  String get formattedDate => createdDate.toString().split('.')[0];
}

// ============================================================================
// ACCIÓN: BUSCAR BACKUPS DISPONIBLES EN UN DISPOSITIVO NUEVO
// ============================================================================

/// Busca backups disponibles en la carpeta Documents/Backups
/// Retorna la información del backup más reciente (si existe)
Future<Map<String, dynamic>> checkAndRestoreBackup() async {
  try {
    debugPrint('🔍 Buscando backups disponibles en todas las rutas...');

    // Busca en TODAS las rutas públicas accesibles (no solo Documents)
    final backupDirs = await findAllBackupFolders();

    if (backupDirs.isEmpty) {
      debugPrint('⚠️ No se encontraron carpetas de backup en ninguna ruta');
      return {
        'hasBackup': false,
        'backupList': [],
        'message': 'No se encontraron backups',
      };
    }

    // Validar cada backup y recopilar información
    List<Map<String, dynamic>> validBackups = [];

    for (var backupDir in backupDirs) {
      try {
        final backupName = path.basename(backupDir.path);
        final dbPath = path.join(backupDir.path, 'clickpalm_database.db');
        final configJsonPath = path.join(backupDir.path, 'backup_config.json');

        // Verificar que existan los archivos necesarios
        final dbExists = await File(dbPath).exists();
        final configExists = await File(configJsonPath).exists();

        if (dbExists && configExists) {
          // Extraer fecha del nombre de la carpeta (Backup_yyyy_MM_dd__HH_mm)
          final dateStr = backupName.replaceAll('Backup_', '');
          final createdDate = _parseDateFromBackupName(dateStr);

          validBackups.add({
            'backupPath': backupDir.path,
            'backupName': backupName,
            'createdDate': createdDate?.toIso8601String() ?? '',
            'formattedDate': createdDate != null
                ? createdDate.toString().split('.')[0]
                : 'Fecha desconocida',
            'dbPath': dbPath,
            'configJsonPath': configJsonPath,
            'isValid': true,
          });

          debugPrint('✅ Backup válido encontrado: $backupName');
        }
      } catch (e) {
        debugPrint('⚠️ Error procesando backup: $e');
        continue;
      }
    }

    if (validBackups.isEmpty) {
      return {
        'hasBackup': false,
        'backupList': [],
        'message': 'No se encontraron backups válidos',
      };
    }

    // Ordenar por fecha (más reciente primero)
    validBackups.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdDate'] ?? '');
      final dateB = DateTime.tryParse(b['createdDate'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });

    final mostRecentBackup = validBackups.first;

    debugPrint('✅ Se encontraron ${validBackups.length} backups válidos');
    debugPrint('🔝 Backup más reciente: ${mostRecentBackup['backupName']}');

    return {
      'hasBackup': true,
      'backupList': validBackups,
      'mostRecent': mostRecentBackup,
      'totalFound': validBackups.length,
      'message': 'Backup disponible para restauración',
    };
  } catch (e, stackTrace) {
    debugPrint('❌ Error buscando backups: $e');
    debugPrint('Stack: $stackTrace');
    return {
      'hasBackup': false,
      'backupList': [],
      'error': e.toString(),
      'message': 'Error al buscar backups: $e',
    };
  }
}

// ============================================================================
// ACCIÓN: RESTAURAR BACKUP COMPLETO
// ============================================================================

/// Restaura un backup proporcionando la ruta de la carpeta del backup
Future<Map<String, dynamic>> restoreBackupData(String backupPath) async {
  try {
    debugPrint('🔄 Iniciando restauración desde: $backupPath');

    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) {
      throw Exception('La carpeta de backup no existe: $backupPath');
    }

    // 1. Restaurar la base de datos
    debugPrint('📦 Paso 1: Restaurando base de datos SQLite...');
    await _restoreDatabase(backupDir);

    // 2. Restaurar los AppStates desde el JSON
    debugPrint('⚙️ Paso 2: Restaurando configuraciones y estados...');
    await _restoreAppStates(backupDir);

    debugPrint('✅ Restauración completada exitosamente');

    return {
      'success': true,
      'message': 'Backup restaurado correctamente',
      'backupPath': backupPath,
    };
  } catch (e, stackTrace) {
    debugPrint('❌ Error restaurando backup: $e');
    debugPrint('Stack: $stackTrace');
    return {
      'success': false,
      'error': e.toString(),
      'message': 'Error al restaurar el backup: $e',
    };
  }
}

// ============================================================================
// FUNCIÓN PRIVADA: RESTAURAR BASE DE DATOS
// ============================================================================

Future<void> _restoreDatabase(Directory backupDir) async {
  try {
    final backupDbPath = path.join(backupDir.path, 'clickpalm_database.db');
    final backupDbFile = File(backupDbPath);

    if (!await backupDbFile.exists()) {
      throw Exception('Base de datos de backup no encontrada');
    }

    // Obtener la ruta de destino de la BD
    final appState = FFAppState();
    String dbDestPath = appState.pathDatabase;

    if (dbDestPath.isEmpty) {
      final dbDir = await getApplicationDocumentsDirectory();
      dbDestPath = path.join(dbDir.path, 'clickpalm_database.db');
    }

    final dbDestFile = File(dbDestPath);

    // Si existe una BD anterior, crear respaldo
    if (await dbDestFile.exists()) {
      final backupOldDb = File('$dbDestPath.old');
      await dbDestFile.copy(backupOldDb.path);
      debugPrint('✅ BD anterior respaldada en: ${backupOldDb.path}');
      await dbDestFile.delete();
    }

    // Copiar la BD del backup al destino
    await backupDbFile.copy(dbDestPath);

    final dbSize = await backupDbFile.length();
    debugPrint('✅ Base de datos restaurada: ${(dbSize / 1024 / 1024).toStringAsFixed(2)} MB');
  } catch (e) {
    debugPrint('❌ Error restaurando base de datos: $e');
    throw Exception('No se pudo restaurar la base de datos: $e');
  }
}

// ============================================================================
// FUNCIÓN PRIVADA: RESTAURAR APPSTATES DESDE JSON
// ============================================================================

Future<void> _restoreAppStates(Directory backupDir) async {
  try {
    final configJsonPath = path.join(backupDir.path, 'backup_config.json');
    final configFile = File(configJsonPath);

    if (!await configFile.exists()) {
      throw Exception('Archivo de configuración no encontrado');
    }

    final jsonString = await configFile.readAsString();
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    final appState = FFAppState();

    // ===== RESTAURAR ESTADOS BOOLEANOS =====
    final booleanStates = backupData['boolean_states'] ?? {};
    if (booleanStates['isSync'] != null) {
      appState.isSync = booleanStates['isSync'] as bool;
    }
    if (booleanStates['isCalibrateVoice'] != null) {
      appState.isCalibrateVoice = booleanStates['isCalibrateVoice'] as bool;
    }
    if (booleanStates['calibrateCompass'] != null) {
      appState.calibrateCompass = booleanStates['calibrateCompass'] as bool;
    }
    debugPrint('✅ Estados booleanos restaurados');

    // ===== RESTAURAR ESTADOS STRING =====
    final stringStates = backupData['string_states'] ?? {};
    if (stringStates['pathDatabase'] != null) {
      appState.pathDatabase = stringStates['pathDatabase'] as String;
    }
    if (stringStates['androidID'] != null) {
      appState.androidID = stringStates['androidID'] as String;
    }
    if (stringStates['sp3NavFile'] != null) {
      appState.sp3NavFile = stringStates['sp3NavFile'] as String;
    }
    if (stringStates['pathPmtiles'] != null) {
      appState.pathPmtiles = stringStates['pathPmtiles'] as String;
    }
    debugPrint('✅ Estados string restaurados');

    // ===== RESTAURAR ESTADOS NUMÉRICOS =====
    final numericStates = backupData['numeric_states'] ?? {};
    if (numericStates['lastLineInstall'] != null) {
      appState.lastLineInstall = numericStates['lastLineInstall'] as int;
    }
    if (numericStates['lastPalmInstall'] != null) {
      appState.lastPalmInstall = numericStates['lastPalmInstall'] as int;
    }
    if (numericStates['routeConfigStartLine'] != null) {
      appState.routeConfigStartLine =
          numericStates['routeConfigStartLine'] as int;
    }
    if (numericStates['routeConfigStartPoint'] != null) {
      appState.routeConfigStartPoint =
          numericStates['routeConfigStartPoint'] as int;
    }
    if (numericStates['routeConfigMaxLines'] != null) {
      appState.routeConfigMaxLines = numericStates['routeConfigMaxLines'] as int;
    }
    if (numericStates['routeConfigMaxPoints'] != null) {
      appState.routeConfigMaxPoints =
          numericStates['routeConfigMaxPoints'] as int;
    }
    if (numericStates['routeConfigPattern'] != null) {
      appState.routeConfigPattern = numericStates['routeConfigPattern'] as int;
    }
    if (numericStates['routeConfigErrorMargin'] != null) {
      appState.routeConfigErrorMargin =
          numericStates['routeConfigErrorMargin'] as double;
    }
    debugPrint('✅ Estados numéricos restaurados');

    // ===== RESTAURAR LISTAS =====
    if (backupData['list_voice_calibration'] != null) {
      appState.listVoiceCalibration =
          List<String>.from(backupData['list_voice_calibration'] ?? []);
    }
    debugPrint('✅ Listas restauradas');

    // ===== RESTAURAR STRUCTS =====
    if (backupData['user_selected'] != null) {
      try {
        appState.userSelected = UsersStruct.fromSerializableMap(
            backupData['user_selected'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar user_selected: $e');
      }
    }

    if (backupData['company_default'] != null) {
      try {
        appState.companyDefault = CompaniesStruct.fromSerializableMap(
            backupData['company_default'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar company_default: $e');
      }
    }

    if (backupData['device_default'] != null) {
      try {
        appState.deviceDefault = DevicesStruct.fromSerializableMap(
            backupData['device_default'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar device_default: $e');
      }
    }

    if (backupData['activity_default'] != null) {
      try {
        appState.activityDefault = ActivitiesStruct.fromSerializableMap(
            backupData['activity_default'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar activity_default: $e');
      }
    }

    if (backupData['activity_selected'] != null) {
      try {
        appState.activitySelected = ActivitiesStruct.fromSerializableMap(
            backupData['activity_selected'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar activity_selected: $e');
      }
    }

    if (backupData['headquarter_selected'] != null) {
      try {
        appState.headquarterSelected = HeadquartersStruct.fromSerializableMap(
            backupData['headquarter_selected'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ No se pudo restaurar headquarter_selected: $e');
      }
    }

    debugPrint('✅ Structs individuales restaurados');

    // ===== RESTAURAR LISTAS DE STRUCTS =====
    if (backupData['headquarters_list'] != null) {
      appState.headquartersList = (backupData['headquarters_list'] as List)
          .map((item) => HeadquartersStruct.fromSerializableMap(
              item as Map<String, dynamic>))
          .toList();
    }

    if (backupData['products_list'] != null) {
      appState.productsList = (backupData['products_list'] as List)
          .map((item) =>
              ProductsStruct.fromSerializableMap(item as Map<String, dynamic>))
          .toList();
    }

    if (backupData['users_list'] != null) {
      appState.usersList = (backupData['users_list'] as List)
          .map((item) =>
              UsersStruct.fromSerializableMap(item as Map<String, dynamic>))
          .toList();
    }

    if (backupData['zones_list'] != null) {
      appState.zonesList = (backupData['zones_list'] as List)
          .map((item) =>
              ZonesStruct.fromSerializableMap(item as Map<String, dynamic>))
          .toList();
    }

    if (backupData['news_list'] != null) {
      appState.newsList = (backupData['news_list'] as List)
          .map((item) =>
              NewsStruct.fromSerializableMap(item as Map<String, dynamic>))
          .toList();
    }

    debugPrint('✅ Listas de structs restauradas');

    // ===== RESTAURAR JSONS DINÁMICOS =====
    if (backupData['login_response'] != null) {
      appState.loginResponse = backupData['login_response'] as Map<String, dynamic>;
    }

    if (backupData['activities_json'] != null) {
      appState.activitiesJSON = backupData['activities_json'];
    }

    if (backupData['user_selected_json'] != null) {
      appState.userSelectedJSON = backupData['user_selected_json'];
    }

    if (backupData['activity_selected_json'] != null) {
      appState.activitySelectedJSON = backupData['activity_selected_json'];
    }

    if (backupData['current_activity'] != null) {
      appState.currentActivity = backupData['current_activity'];
    }

    debugPrint('✅ JSONs dinámicos restaurados');

    // ===== NOTIFICAR CAMBIOS =====
    appState.update(() {});

    debugPrint('✅ App states completamente restaurados');
  } catch (e) {
    debugPrint('❌ Error restaurando app states: $e');
    throw Exception('No se pudieron restaurar los app states: $e');
  }
}

// ============================================================================
// FUNCIÓN PRIVADA: PARSEAR FECHA DEL NOMBRE DEL BACKUP
// ============================================================================

DateTime? _parseDateFromBackupName(String dateStr) {
  try {
    // Formato: yyyy_MM_dd__HH_mm
    // Convertir a: yyyy-MM-dd HH:mm
    final parts = dateStr.split('__');
    if (parts.length != 2) return null;

    final datePart = parts[0].replaceAll('_', '-');
    final timePart = parts[1].replaceAll('_', ':');

    return DateTime.parse('$datePart $timePart:00');
  } catch (e) {
    return null;
  }
}
