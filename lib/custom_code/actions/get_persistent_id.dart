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

    // 2. Obtener ruta segura y persistente
    final String docsPath = await _getBestDocumentsPath();
    final Directory dir = Directory(docsPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String filePath = '$docsPath/$fileName';
    final File file = File(filePath);

    // 3. Si ya existe, leerlo
    if (await file.exists()) {
      final String savedId = await file.readAsString();
      if (savedId.trim().isNotEmpty) {
        debugPrint('UUID recuperado: $savedId');
        return savedId.trim();
      }
    }

    // 4. Generar nuevo número de 10 dígitos
    final String newId = _generate10DigitNumber(random);

    // 5. Guardar en la ruta persistente
    await file.writeAsString(newId, flush: true);

    debugPrint('Nuevo número generado y guardado: $newId');
    return newId;
  } catch (e) {
    debugPrint('Error crítico en getPersistentId: $e');
    return _generate10DigitNumber(random); // fallback en memoria
  }
}

String _generate10DigitNumber(Random random) {
  final buffer = StringBuffer();
  buffer.write(1 + random.nextInt(9)); // Primer dígito 1-9
  for (var i = 0; i < 9; i++) {
    buffer.write(random.nextInt(10)); // 9 dígitos 0-9
  }
  return buffer.toString();
}

Future<String> _getBestDocumentsPath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String path =
      '${externalDir.path}/ClickPalmData'; // Carpeta personalizada
  final Directory targetDir = Directory(path);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return targetDir.path;
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
