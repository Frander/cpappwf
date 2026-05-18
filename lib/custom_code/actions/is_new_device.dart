// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'persistent_id_paths.dart';

/// Detecta si el dispositivo es nuevo (no existe persistent_id.txt en ninguna ruta).
/// Usa las mismas rutas que get/save_persistent_id para coherencia total.
Future<bool> isNewDevice() async {
  if (!Platform.isAndroid) return false;

  const fileName = 'persistent_id.txt';

  try {
    final paths = await discoverWritablePaths();

    for (final entry in paths.entries) {
      final filePath = '${entry.value}/$fileName';
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final content = (await file.readAsString()).trim();
          if (content.isNotEmpty) {
            debugPrint('✅ [isNewDevice] Dispositivo EXISTENTE — ID en ${entry.key}: $content');
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [isNewDevice] Error leyendo ${entry.key}: $e');
      }
    }

    debugPrint('🆕 [isNewDevice] DISPOSITIVO NUEVO — persistent_id.txt no encontrado');
    return true;
  } catch (e) {
    debugPrint('⚠️ [isNewDevice] Error en detección: $e');
    return false;
  }
}
