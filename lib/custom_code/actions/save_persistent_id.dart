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

/// Clase auxiliar para representar una ubicación de almacenamiento
class StorageLocation {
  final String path;
  final String name;
  final bool accessible;

  StorageLocation({
    required this.path,
    required this.name,
    required this.accessible,
  });
}

Future<bool> savePersistentId(BuildContext context, String deviceId) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  const String fileName = 'persistent_id.txt';

  try {
    // 1. Obtener las 3 ubicaciones de almacenamiento
    List<StorageLocation> locations = await _getStorageLocations();

    // 2. Guardar en todas las ubicaciones
    int successCount = 0;
    int failCount = 0;

    for (var location in locations) {
      if (!location.accessible) {
        debugPrint('⚠️ Ubicación no accesible: ${location.name}');
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

    debugPrint('📊 Guardado completo: $successCount exitosos, $failCount fallidos');

    // Retornar true si al menos una ubicación fue exitosa
    return successCount > 0;
  } catch (e) {
    debugPrint('❌ Error crítico guardando ID de dispositivo: $e');
    return false;
  }
}

/// Obtiene las ubicaciones de almacenamiento PÚBLICAS con verificación de accesibilidad
/// Android 11+ no permite crear carpetas personalizadas en la raíz, solo carpetas estándar
Future<List<StorageLocation>> _getStorageLocations() async {
  List<StorageLocation> locations = [];

  try {
    const publicRoot = '/storage/emulated/0';

    // 1. Documents pública (PRIORITARIA - visible en explorador de archivos)
    const docsPath = '$publicRoot/Documents';
    locations.add(StorageLocation(
      path: docsPath,
      name: 'Documents',
      accessible: await _isLocationAccessible(docsPath),
    ));

    // 2. Download pública (respaldo - visible en explorador de archivos)
    const downloadsPath = '$publicRoot/Download';
    locations.add(StorageLocation(
      path: downloadsPath,
      name: 'Download',
      accessible: await _isLocationAccessible(downloadsPath),
    ));

    // 3. Fallback: directorio privado de la app (siempre accesible)
    final appDir = await getExternalStorageDirectory();
    if (appDir != null) {
      locations.add(StorageLocation(
        path: appDir.path,
        name: 'AppData',
        accessible: await _isLocationAccessible(appDir.path),
      ));
    }
  } catch (e) {
    debugPrint('❌ Error obteniendo ubicaciones de almacenamiento: $e');
  }

  return locations;
}

/// Verifica si una ubicación de almacenamiento es accesible
Future<bool> _isLocationAccessible(String path) async {
  try {
    final dir = Directory(path);
    // Intentar crear el directorio si no existe
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Verificar si podemos leer/escribir
    return await dir.exists();
  } catch (e) {
    debugPrint('⚠️ Ubicación no accesible: $path - $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
