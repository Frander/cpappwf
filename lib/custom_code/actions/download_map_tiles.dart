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
import 'package:http/http.dart' as http;

Future<String?> downloadMapTiles(BuildContext context) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  const String pmtilesUrl =
      'https://clickpalmv2.s3.us-west-2.amazonaws.com/Resources/colombia.pmtiles';
  const String fileName = 'colombia.pmtiles';

  try {
    // 1. Verificar y solicitar permisos
    final hasPermissions = await _checkAndRequestStoragePermissions(context);
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // 2. Obtener ruta persistente
    final String docsPath = await _getBestDocumentsPath();
    final String filePath = '$docsPath/$fileName';
    final File file = File(filePath);

    // 3. Verificar si ya existe el archivo
    if (await file.exists()) {
      final int fileSize = await file.length();
      debugPrint('Archivo ya existe: $filePath (${fileSize} bytes)');

      // Verificar si el archivo no está corrupto (mayor a 1MB)
      if (fileSize > 1024 * 1024) {
        // Actualizar AppState con la ruta existente
        FFAppState().update(() {
          FFAppState().pathPmtiles = filePath;
        });

        debugPrint('PathPmtiles actualizado en AppState: $filePath');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Mapa ya descargado (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        return filePath;
      } else {
        debugPrint('Archivo corrupto o incompleto, re-descargando...');
        await file.delete();
      }
    }

    // 4. Mostrar diálogo de progreso
    if (context.mounted) {
      _showDownloadDialog(context);
    }

    // 5. Descargar archivo
    debugPrint('Iniciando descarga desde: $pmtilesUrl');

    final response = await http.get(Uri.parse(pmtilesUrl));

    if (response.statusCode == 200) {
      // 6. Guardar archivo
      await file.writeAsBytes(response.bodyBytes, flush: true);

      final int downloadedSize = response.bodyBytes.length;
      debugPrint('Descarga completada: $filePath (${downloadedSize} bytes)');

      // 7. Actualizar AppState con la nueva ruta
      FFAppState().update(() {
        FFAppState().pathPmtiles = filePath;
      });

      debugPrint('PathPmtiles actualizado en AppState: $filePath');

      // Cerrar diálogo
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Mapa descargado correctamente (${(downloadedSize / (1024 * 1024)).toStringAsFixed(2)} MB)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return filePath;
    } else {
      throw Exception('Error en descarga: HTTP ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error en downloadMapTiles: $e');

    // Cerrar diálogo si está abierto
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {
        // Ignorar si el diálogo ya está cerrado
      }
    }

    // Mostrar error
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar mapa: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    return null;
  }
}

void _showDownloadDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Descargando mapa de Colombia...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Esto puede tomar varios minutos\nNo cierres la aplicación',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Función para obtener la ruta persistente
Future<String> _getBestDocumentsPath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String path = '${baseDir.path}/ClickPalmData/Maps';
  final Directory targetDir = Directory(path);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return targetDir.path;
}

// Función para verificar permisos
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
        'La aplicación necesita acceso para guardar el mapa offline.',
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
        'Para descargar el mapa, se requiere permiso para gestionar el almacenamiento.',
      );
      if (!shouldContinue) return false;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    // Android 6 - 10
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    final shouldContinue = await _showPermissionExplanationDialog(
      context,
      'Se necesita permiso para descargar el mapa.',
    );
    if (!shouldContinue) return false;

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
