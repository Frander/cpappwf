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
import 'persistent_id_paths.dart';

/// Guarda el IMEI/ID en TODAS las rutas con permisos reales.
/// Se detectan dinámicamente — compatible con Android 6 hasta 16+.
/// Siempre sobreescribe para que el CTR seleccionado sea el definitivo.
Future<bool> savePersistentId(BuildContext context, String deviceId) async {
  if (!Platform.isAndroid) return false;

  const fileName = 'persistent_id.txt';

  debugPrint('💾 [savePersistentId] Detectando rutas accesibles...');
  final paths = await discoverWritablePaths();

  if (paths.isEmpty) {
    debugPrint('❌ [savePersistentId] No se encontró ninguna ruta accesible');
    return false;
  }

  int saved = 0;
  int failed = 0;

  for (final entry in paths.entries) {
    final label    = entry.key;
    final filePath = '${entry.value}/$fileName';
    try {
      final dir = Directory(entry.value);
      if (!await dir.exists()) await dir.create(recursive: true);

      await File(filePath).writeAsString(deviceId, flush: true);
      debugPrint('✅ [savePersistentId] $label → $filePath');
      saved++;
    } catch (e) {
      debugPrint('❌ [savePersistentId] $label → $filePath\n   └─ $e');
      failed++;
    }
  }

  debugPrint('📊 [savePersistentId] $saved guardados, $failed fallidos | valor: $deviceId');
  return saved > 0;
}
