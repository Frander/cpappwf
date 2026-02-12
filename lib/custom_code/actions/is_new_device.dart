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
import 'package:path/path.dart' as path;

// ============================================================================
// ACCIÓN: DETECTAR SI ES UN DISPOSITIVO NUEVO
// ============================================================================

/// Detecta si el dispositivo es nuevo (no existe persistent_id.txt)
Future<bool> isNewDevice() async {
  try {
    const String fileName = 'persistent_id.txt';

    if (!Platform.isAndroid) {
      return false;
    }

    // Verificar permisos
    final storageDir = await getApplicationDocumentsDirectory();

    // Ubicaciones a verificar (orden de prioridad)
    final locations = [
      path.join(storageDir.path, fileName),
      path.join('/storage/emulated/0', fileName),
      path.join('/storage/emulated/0/Documents', fileName),
    ];

    // Si el archivo existe en CUALQUIER ubicación, NO es nuevo dispositivo
    for (var location in locations) {
      final file = File(location);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          debugPrint('✅ Dispositivo EXISTENTE - ID encontrado en: $location');
          return false;
        }
      }
    }

    debugPrint('🆕 DISPOSITIVO NUEVO - No se encontró persistent_id.txt');
    return true;
  } catch (e) {
    debugPrint('⚠️ Error detectando si es dispositivo nuevo: $e');
    return false;
  }
}
