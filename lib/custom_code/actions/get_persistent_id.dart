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
import 'dart:math';
import 'persistent_id_paths.dart';

/// Lee el IMEI/ID persistido del dispositivo.
///
/// Flujo:
///   1. Descubre todas las rutas accesibles (públicas primero).
///   2. Recorre cada una buscando persistent_id.txt.
///   3. Si lo encuentra → propaga a rutas donde falte → retorna ID.
///   4. Si no encuentra → genera ID nuevo → guarda en todas → retorna ID.
Future<String> getPersistentId(BuildContext context) async {
  if (!Platform.isAndroid) return _generateId();

  const fileName = 'persistent_id.txt';

  debugPrint('🔍 [getPersistentId] Detectando rutas accesibles...');
  final paths = await discoverWritablePaths();

  if (paths.isEmpty) {
    debugPrint('⚠️ [getPersistentId] Sin rutas accesibles — retornando ID en memoria');
    return _generateId();
  }

  // ── 1. Buscar el archivo en todas las rutas ──────────────────────────────
  String? foundId;
  String? foundLabel;

  for (final entry in paths.entries) {
    final label    = entry.key;
    final filePath = '${entry.value}/$fileName';

    debugPrint('🗂️ [getPersistentId] Buscando en $label: $filePath');
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isNotEmpty) {
          foundId    = content;
          foundLabel = label;
          debugPrint('✅ [getPersistentId] IMEI encontrado en $label: $content');
          break;
        } else {
          debugPrint('📄 [getPersistentId] Archivo vacío en $label');
        }
      } else {
        debugPrint('📭 [getPersistentId] No existe en $label');
      }
    } catch (e) {
      debugPrint('❌ [getPersistentId] Error leyendo $label: $e');
    }
  }

  // ── 2a. Encontrado → propagar a rutas donde falta ───────────────────────
  if (foundId != null) {
    await _propagate(foundId, paths, fileName, skipLabel: foundLabel);
    return foundId;
  }

  // ── 2b. No encontrado → generar y guardar en todas ──────────────────────
  final newId = _generateId();
  debugPrint('🆕 [getPersistentId] Sin IMEI previo — generando: $newId');
  await _propagate(newId, paths, fileName);
  return newId;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Escribe el ID en las rutas donde no existe o donde el contenido difiere.
Future<void> _propagate(
  String id,
  Map<String, String> paths,
  String fileName, {
  String? skipLabel,
}) async {
  for (final entry in paths.entries) {
    if (entry.key == skipLabel) continue;
    final filePath = '${entry.value}/$fileName';
    try {
      final dir = Directory(entry.value);
      if (!await dir.exists()) await dir.create(recursive: true);

      final file    = File(filePath);
      final current = await file.exists() ? (await file.readAsString()).trim() : '';
      if (current != id) {
        await file.writeAsString(id, flush: true);
        debugPrint('🔄 [getPersistentId] Propagado a ${entry.key}: $filePath');
      }
    } catch (e) {
      debugPrint('⚠️ [getPersistentId] No se pudo propagar a ${entry.key}: $e');
    }
  }
}

String _generateId() {
  final r = Random();
  final buf = StringBuffer();
  buf.write(1 + r.nextInt(9));
  for (var i = 0; i < 9; i++) {
    buf.write(r.nextInt(10));
  }
  return buf.toString();
}
