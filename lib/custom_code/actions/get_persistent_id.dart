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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:flutter/services.dart';

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

Future<String> getPersistentId(BuildContext context) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  const String fileName = 'persistent_id.txt';
  final Random random = Random();

  try {
    // 1. Verificar y solicitar permisos
    final hasPermissions = await _checkAndRequestStoragePermissions(context);
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // 2. Obtener las 3 ubicaciones de almacenamiento
    List<StorageLocation> locations = await _getStorageLocations();

    // 3. Buscar archivo en todas las ubicaciones
    String? foundId;
    String? foundLocation;

    for (var location in locations) {
      if (!location.accessible) continue;

      final filePath = '${location.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          foundId = content.trim();
          foundLocation = location.name;
          debugPrint('✅ ID encontrado en ${location.name}: $foundId');
          break;
        }
      }
    }

    // 4. Si se encontró el ID, sincronizar a las demás ubicaciones
    if (foundId != null) {
      debugPrint('🔄 Sincronizando ID desde $foundLocation a otras ubicaciones...');
      await _syncIdToAllLocations(foundId, locations);
      return foundId;
    }

    // 5. No se encontró en ninguna ubicación, generar nuevo ID
    final newId = _generate10DigitNumber(random);
    debugPrint('🆕 Generando nuevo ID: $newId');

    // 6. Guardar en todas las ubicaciones
    await _syncIdToAllLocations(newId, locations);

    return newId;
  } catch (e) {
    debugPrint('Error crítico en getPersistentId: $e');
    return _generate10DigitNumber(random); // fallback en memoria
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

/// Sincroniza el ID a todas las ubicaciones accesibles
Future<void> _syncIdToAllLocations(
    String id, List<StorageLocation> locations) async {
  const fileName = 'persistent_id.txt';
  int successCount = 0;
  int failCount = 0;

  for (var location in locations) {
    if (!location.accessible) {
      debugPrint('⚠️ Saltando ${location.name} - no accesible');
      continue;
    }

    try {
      final dir = Directory(location.path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '${location.path}/$fileName';
      final file = File(filePath);

      // Escribir o actualizar el archivo
      if (!await file.exists()) {
        await file.writeAsString(id, flush: true);
        debugPrint('✅ ID sincronizado a ${location.name}');
        successCount++;
      } else {
        final existingContent = await file.readAsString();
        if (existingContent.trim() != id.trim()) {
          await file.writeAsString(id, flush: true);
          debugPrint('✅ ID actualizado en ${location.name}');
          successCount++;
        } else {
          debugPrint('ℹ️ ID ya existe en ${location.name}');
          successCount++;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al sincronizar a ${location.name}: $e');
      failCount++;
    }
  }

  debugPrint('📊 Sincronización completa: $successCount exitosos, $failCount fallidos');
}

String _generate10DigitNumber(Random random) {
  final buffer = StringBuffer();
  buffer.write(1 + random.nextInt(9)); // Primer dígito 1-9
  for (var i = 0; i < 9; i++) {
    buffer.write(random.nextInt(10)); // 9 dígitos 0-9
  }
  return buffer.toString();
}

Future<bool> _checkAndRequestStoragePermissions(BuildContext context) async {
  try {
    if (!Platform.isAndroid) return false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    if (sdkVersion >= 33) {
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

      if (photosStatus.isGranted && videosStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialog(
        context,
        'La aplicación necesita acceso a tus fotos y videos para guardar un identificador único.',
      );
      if (!shouldContinue) return false;

      final result = await [
        Permission.photos,
        Permission.videos,
      ].request();

      return result[Permission.photos]?.isGranted == true &&
          result[Permission.videos]?.isGranted == true;
    }

    if (sdkVersion >= 30) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialog(
        context,
        'Para continuar, se requiere permiso para gestionar el almacenamiento externo.',
      );
      if (!shouldContinue) return false;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    // Android 6 - 10
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    await _showPermissionExplanationDialog(
      context,
      'Se necesita permiso para acceder al almacenamiento externo.',
    );

    final result = await Permission.storage.request();
    return result.isGranted;
  } catch (e) {
    debugPrint('Error solicitando permisos: $e');
    return false;
  }
}

Future<bool> _showPermissionExplanationDialog(
    BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
