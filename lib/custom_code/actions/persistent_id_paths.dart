// Helper compartido — NO es una FlutterFlow action, no se exporta en index.dart
// Usado por: get_persistent_id.dart, save_persistent_id.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

const _kTestFile    = 'storage_access_test.txt';
const _kTestContent = 'clickpalm_ok';

/// Devuelve un mapa ordenado { label → dirPath } de rutas con permisos
/// reales de escritura confirmados (write + read + delete del archivo real).
///
/// Orden de prioridad:
///   1. Rutas PÚBLICAS estándar (sobreviven desinstalación, visibles en explorador)
///   2. Rutas PRIVADAS de la app  (siempre accesibles, sin permisos extra)
Future<Map<String, String>> discoverWritablePaths() async {
  final candidates = await _buildCandidates();
  final result = <String, String>{};

  for (final entry in candidates.entries) {
    final ok = await _isWritable(entry.value);
    debugPrint(ok
        ? '✔️ [storage] ${entry.key}: ${entry.value}'
        : '✖️ [storage] ${entry.key}: ${entry.value}');
    if (ok) result[entry.key] = entry.value;
  }

  debugPrint('[storage] ${result.length} rutas accesibles de ${candidates.length} candidatas');
  return result;
}

// ---------------------------------------------------------------------------
// Candidatos — públicos primero, privados al final
// ---------------------------------------------------------------------------

Future<Map<String, String>> _buildCandidates() async {
  // Rutas públicas estándar — visibles en explorador de archivos del teléfono.
  // Android restringe Pictures/Music/DCIM pero Documents y Download son accesibles
  // para archivos genéricos en la mayoría de versiones.
  final paths = <String, String>{
    'Documents':    '/storage/emulated/0/Documents',
    'Download':     '/storage/emulated/0/Download',
    // Algunas ROMs/versiones más antiguas usan estas variantes
    'Downloads':    '/storage/emulated/0/Downloads',
    'Documentos':   '/storage/emulated/0/Documentos',
  };

  // Rutas privadas via path_provider — garantizadas sin permisos adicionales
  await _tryAdd(paths, 'AppData (externo)',
      () async => (await getExternalStorageDirectory())?.path);

  await _tryAdd(paths, 'AppDocuments (interno)',
      () async => (await getApplicationDocumentsDirectory()).path);

  await _tryAdd(paths, 'AppSupport (interno)',
      () async => (await getApplicationSupportDirectory()).path);

  await _tryAdd(paths, 'AppCache (interno)',
      () async => (await getApplicationCacheDirectory()).path);

  // Directorios externos adicionales (SD card, múltiples volúmenes)
  try {
    final extDirs = await getExternalStorageDirectories();
    if (extDirs != null) {
      for (int i = 0; i < extDirs.length; i++) {
        paths['Storage externo [$i]'] = extDirs[i].path;
      }
    }
  } catch (_) {}

  return paths;
}

Future<void> _tryAdd(
  Map<String, String> map,
  String label,
  Future<String?> Function() getter,
) async {
  try {
    final path = await getter();
    if (path != null && path.isNotEmpty) map[label] = path;
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Test real de escritura/lectura/borrado
// ---------------------------------------------------------------------------

Future<bool> _isWritable(String dirPath) async {
  final testPath = '$dirPath/$_kTestFile';
  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File(testPath);
    await file.writeAsString(_kTestContent, flush: true);
    final read = await file.readAsString();
    await file.delete();
    return read.trim() == _kTestContent;
  } catch (_) {
    return false;
  }
}
