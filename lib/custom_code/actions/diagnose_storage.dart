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
import 'package:device_info_plus/device_info_plus.dart';

/// Diagnóstico completo de almacenamiento en Android.
/// Prueba TODAS las rutas conocidas con escritura/lectura real
/// y reporta cuáles tienen permisos suficientes.
Future<String> diagnoseStorage(BuildContext context) async {
  final buffer = StringBuffer();
  buffer.writeln('═══════════════════════════════════════');
  buffer.writeln('   DIAGNÓSTICO DE ALMACENAMIENTO');
  buffer.writeln('═══════════════════════════════════════');

  // Info del dispositivo
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final sdk = info.version.sdkInt;
    final release = info.version.release;
    buffer.writeln('📱 Android $release (API $sdk)');
    buffer.writeln('📱 Modelo: ${info.manufacturer} ${info.model}');
    buffer.writeln('');
  } catch (e) {
    buffer.writeln('⚠️ No se pudo obtener info del dispositivo: $e');
  }

  // Recopilar todas las rutas candidatas
  final Map<String, String> candidates = {};

  // ── Rutas del sistema vía path_provider ─────────────────────────────────
  try {
    final dir = await getApplicationDocumentsDirectory();
    candidates['AppDocuments (interno)'] = dir.path;
  } catch (e) {
    candidates['AppDocuments (interno)'] = 'ERROR: $e';
  }

  try {
    final dir = await getApplicationSupportDirectory();
    candidates['AppSupport (interno)'] = dir.path;
  } catch (e) {
    candidates['AppSupport (interno)'] = 'ERROR: $e';
  }

  try {
    final dir = await getApplicationCacheDirectory();
    candidates['AppCache (interno)'] = dir.path;
  } catch (e) {
    candidates['AppCache (interno)'] = 'ERROR: $e';
  }

  try {
    final dir = await getTemporaryDirectory();
    candidates['Temp'] = dir.path;
  } catch (e) {
    candidates['Temp'] = 'ERROR: $e';
  }

  try {
    final dir = await getExternalStorageDirectory();
    if (dir != null) candidates['AppData (externo)'] = dir.path;
  } catch (e) {
    candidates['AppData (externo)'] = 'ERROR: $e';
  }

  try {
    final dirs = await getExternalCacheDirectories();
    if (dirs != null) {
      for (int i = 0; i < dirs.length; i++) {
        candidates['AppCache externo [$i]'] = dirs[i].path;
      }
    }
  } catch (e) {
    candidates['AppCache externo'] = 'ERROR: $e';
  }

  try {
    final dirs = await getExternalStorageDirectories();
    if (dirs != null) {
      for (int i = 0; i < dirs.length; i++) {
        candidates['Storage externo [$i]'] = dirs[i].path;
      }
    }
  } catch (e) {
    candidates['Storage externo'] = 'ERROR: $e';
  }

  // ── Rutas públicas estándar ──────────────────────────────────────────────
  const publicRoot = '/storage/emulated/0';
  const publicPaths = {
    'Documents (público)': '$publicRoot/Documents',
    'Download (público)': '$publicRoot/Download',
    'Pictures (público)': '$publicRoot/Pictures',
    'Music (público)': '$publicRoot/Music',
    'Movies (público)': '$publicRoot/Movies',
    'DCIM (público)': '$publicRoot/DCIM',
    'Raíz SD emulada': publicRoot,
  };
  candidates.addAll(publicPaths);

  // ── Probar cada candidato ────────────────────────────────────────────────
  buffer.writeln('RESULTADOS:');
  buffer.writeln('───────────────────────────────────────');

  int accessible = 0;
  int blocked = 0;

  for (final entry in candidates.entries) {
    final label = entry.key;
    final rawPath = entry.value;

    if (rawPath.startsWith('ERROR:')) {
      buffer.writeln('❓ $label');
      buffer.writeln('   path_provider falló: $rawPath');
      buffer.writeln('');
      continue;
    }

    final result = await _testPath(rawPath);
    if (result.canWrite) {
      accessible++;
      buffer.writeln('✅ $label');
      buffer.writeln('   ${result.path}');
    } else {
      blocked++;
      buffer.writeln('🔴 $label');
      buffer.writeln('   ${result.path}');
      buffer.writeln('   └─ ${result.errorMsg}');
    }
    buffer.writeln('');
  }

  buffer.writeln('═══════════════════════════════════════');
  buffer.writeln('RESUMEN: $accessible accesibles, $blocked bloqueadas');
  buffer.writeln('═══════════════════════════════════════');

  final output = buffer.toString();

  // Imprimir línea por línea para que aparezca bien en logcat
  for (final line in output.split('\n')) {
    debugPrint(line);
  }

  return output;
}

class _PathTestResult {
  final String path;
  final bool canWrite;
  final String errorMsg;
  _PathTestResult({required this.path, required this.canWrite, this.errorMsg = ''});
}

Future<_PathTestResult> _testPath(String dirPath) async {
  const testFile = 'storage_test.txt';
  const testContent = 'clickpalm_storage_test';

  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('$dirPath/$testFile');

    // Escribir
    await file.writeAsString(testContent, flush: true);

    // Leer y verificar
    final read = await file.readAsString();
    if (read.trim() != testContent) {
      return _PathTestResult(path: dirPath, canWrite: false, errorMsg: 'Escritura inconsistente');
    }

    // Limpiar
    await file.delete();

    return _PathTestResult(path: dirPath, canWrite: true);
  } catch (e) {
    return _PathTestResult(path: dirPath, canWrite: false, errorMsg: e.toString());
  }
}
