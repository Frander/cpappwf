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

Future<bool> savePersistentId(BuildContext context, String deviceId) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  const String fileName = 'persistent_id.txt';

  try {
    // 1. Obtener ruta segura y persistente
    final String docsPath = await _getBestDocumentsPath();
    final Directory dir = Directory(docsPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String filePath = '$docsPath/$fileName';
    final File file = File(filePath);

    // 2. Guardar el ID del dispositivo
    await file.writeAsString(deviceId, flush: true);

    debugPrint('✅ ID de dispositivo guardado correctamente: $deviceId');
    return true;
  } catch (e) {
    debugPrint('❌ Error guardando ID de dispositivo: $e');
    return false;
  }
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
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
