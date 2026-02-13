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
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Estructura para representar información de versión de Android
class AndroidVersionInfo {
  final int apiLevel;
  final bool isAndroid10Plus; 
  final bool isAndroid11Plus;
  final bool isAndroid13Plus;

  AndroidVersionInfo({
    required this.apiLevel,
    required this.isAndroid10Plus,
    required this.isAndroid11Plus,
    required this.isAndroid13Plus,
  });

  @override
  String toString() => 'Android API $apiLevel';
}

/// Clase auxiliar para representar una ubicación de almacenamiento
class StorageLocation {
  final String path;
  final String name;
  final int priority; // 1=prioritario, 2=alternativo, 3=fallback
  final bool requiresPermission;
  bool accessible = false;

  StorageLocation({
    required this.path,
    required this.name,
    required this.priority,
    required this.requiresPermission,
  });
}

Future<bool> savePersistentId(BuildContext context, String deviceId) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  const String fileName = 'persistent_id.txt';

  try {
    // 1. Obtener información de versión de Android
    final versionInfo = await _getAndroidVersionInfo();
    debugPrint(
        '📱 Ejecutando en ${versionInfo} (API: ${versionInfo.apiLevel})');

    // 2. Obtener las ubicaciones de almacenamiento
    List<StorageLocation> locations =
        await _getStorageLocations(versionInfo);

    // 3. Solicitar permisos necesarios
    await _requestPermissionsForVersion(versionInfo);

    // 4. Verificar accesibilidad de cada ubicación
    await _checkAccessibility(locations);

    // 5. Guardar en todas las ubicaciones accesibles (ordenadas por prioridad)
    locations.sort((a, b) => a.priority.compareTo(b.priority));

    int successCount = 0;
    int failCount = 0;

    for (var location in locations) {
      if (!location.accessible) {
        debugPrint(
            '⏭️ Ubicación no accesible: ${location.name} (${location.path})');
        failCount++;
        continue;
      }

      try {
        final dir = Directory(location.path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final filePath = '${location.path}/$fileName';
        final file = File(filePath);

        await file.writeAsString(deviceId, flush: true);
        debugPrint('✅ ID guardado en ${location.name}: $deviceId');
        successCount++;
      } catch (e) {
        debugPrint('❌ Error guardando en ${location.name}: $e');
        failCount++;
      }
    }

    debugPrint('📊 Resultado: $successCount exitosos, $failCount fallidos');

    // Retornar true si al menos una ubicación fue exitosa
    if (successCount > 0) {
      debugPrint('✅ Guardado completado exitosamente');
      return true;
    } else {
      debugPrint('❌ No se pudo guardar en ninguna ubicación');
      return false;
    }
  } catch (e) {
    debugPrint('❌ Error crítico: $e');
    return false;
  }
}

/// Obtiene información sobre la versión de Android
Future<AndroidVersionInfo> _getAndroidVersionInfo() async {
  final deviceInfo = await _getDeviceInfo();
  final release = int.tryParse(deviceInfo['release'] ?? '0') ?? 0;

  return AndroidVersionInfo(
    apiLevel: release,
    isAndroid10Plus: release >= 10,
    isAndroid11Plus: release >= 11,
    isAndroid13Plus: release >= 13,
  );
}

/// Obtiene información del dispositivo
Future<Map<String, dynamic>> _getDeviceInfo() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    
    // androidInfo.version.release contiene la versión de Android como string (ej: "13")
    final release = androidInfo.version.release;
    debugPrint('📱 Device Android Release: $release');
    
    return {'release': release};
  } catch (e) {
    debugPrint('⚠️ Error obteniendo info del dispositivo: $e');
    // Fallback a Android 10 como valor seguro
    return {'release': '10'};
  }
}

/// Solicita los permisos necesarios según la versión de Android
Future<void> _requestPermissionsForVersion(AndroidVersionInfo info) async {
  try {
    if (info.isAndroid13Plus) {
      // Android 13+: permisos granulares
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else if (info.isAndroid11Plus) {
      // Android 11-12: permisos de almacenamiento
      await [
        Permission.storage,
      ].request();
    } else if (info.isAndroid10Plus) {
      // Android 10: permisos de almacenamiento
      await [
        Permission.storage,
      ].request();
    }
  } catch (e) {
    debugPrint('⚠️ Error solicitando permisos: $e');
  }
}

/// Obtiene las ubicaciones de almacenamiento según la versión de Android
Future<List<StorageLocation>> _getStorageLocations(
    AndroidVersionInfo info) async {
  List<StorageLocation> locations = [];

  try {
    const publicRoot = '/storage/emulated/0';

    if (info.isAndroid11Plus) {
      // Android 11+: Scoped Storage obligatorio
      // Las rutas públicas son limitadas

      // 1. Documents (PRIORITARIO)
      locations.add(StorageLocation(
        path: '$publicRoot/Documents',
        name: 'Documents',
        priority: 1,
        requiresPermission: true,
      ));

      // 2. Download (ALTERNATIVO)
      locations.add(StorageLocation(
        path: '$publicRoot/Download',
        name: 'Downloads',
        priority: 2,
        requiresPermission: true,
      ));

      // 3. Directorio privado de la app (FALLBACK - siempre accesible)
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        locations.add(StorageLocation(
          path: appDir.path,
          name: 'AppData',
          priority: 3,
          requiresPermission: false,
        ));
      }

      // 4. Cache de la app (último recurso)
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir != null) {
        locations.add(StorageLocation(
          path: cacheDir.path,
          name: 'AppCache',
          priority: 4,
          requiresPermission: false,
        ));
      }
    } else {
      // Android 10: Legacy External Storage aún funciona pero con limitaciones

      // 1. Documents
      locations.add(StorageLocation(
        path: '$publicRoot/Documents',
        name: 'Documents',
        priority: 1,
        requiresPermission: true,
      ));

      // 2. Download
      locations.add(StorageLocation(
        path: '$publicRoot/Download',
        name: 'Downloads',
        priority: 2,
        requiresPermission: true,
      ));

      // 3. Directorio privado de la app
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        locations.add(StorageLocation(
          path: appDir.path,
          name: 'AppData',
          priority: 3,
          requiresPermission: false,
        ));
      }
    }
  } catch (e) {
    debugPrint('❌ Error obteniendo ubicaciones: $e');
  }

  return locations;
}

/// Verifica la accesibilidad de cada ubicación
Future<void> _checkAccessibility(List<StorageLocation> locations) async {
  for (var location in locations) {
    try {
      final dir = Directory(location.path);
      
      // Verificar si el directorio existe
      if (await dir.exists()) {
        // Intentar escribir un archivo de prueba
        final testFile = File('${location.path}/.access_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        
        location.accessible = true;
        debugPrint(
            '✔️ Ubicación accesible: ${location.name} (${location.path})');
      } else {
        // Intentar crear el directorio
        try {
          await dir.create(recursive: true);
          
          // Verificar escribir después de crear
          final testFile = File('${location.path}/.access_test');
          await testFile.writeAsString('test');
          await testFile.delete();
          
          location.accessible = true;
          debugPrint(
              '✔️ Ubicación creada y accesible: ${location.name} (${location.path})');
        } catch (createError) {
          debugPrint(
              '❌ No se puede crear/acceder a ${location.name}: $createError');
          location.accessible = false;
        }
      }
    } catch (e) {
      debugPrint(
          '❌ Error verificando accesibilidad de ${location.name}: $e');
      location.accessible = false;
    }
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
