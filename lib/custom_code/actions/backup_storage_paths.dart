// Helper compartido — NO es una FlutterFlow action, no se exporta en index.dart
// Usado por: create_backup.dart, restore_backup.dart, check_and_restore_backup.dart

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'persistent_id_paths.dart'; // discoverWritablePaths()

const _kBackupsFolder = 'Backups';

// ---------------------------------------------------------------------------
// API pública
// ---------------------------------------------------------------------------

/// Devuelve el directorio raíz de Backups en la mejor ruta pública disponible.
///
/// Usa [discoverWritablePaths] para confirmar acceso real de escritura antes de
/// elegir, priorizando rutas PÚBLICAS (Documents, Download…) que sobreviven
/// desinstalación sobre rutas privadas de la app.
///
/// Crea el directorio si no existe.
Future<Directory> getBackupsRootDirectory() async {
  final writablePaths = await discoverWritablePaths();

  if (writablePaths.isNotEmpty) {
    final bestLabel = writablePaths.keys.first;
    final bestBase  = writablePaths.values.first;
    final dir = Directory(path.join(bestBase, _kBackupsFolder));
    debugPrint('📁 [backup_paths] Ruta de backups → "$bestLabel": ${dir.path}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Última opción: ruta privada (se borra al desinstalar — advertencia explícita)
  debugPrint('⚠️ [backup_paths] Sin rutas públicas accesibles. '
      'Backups en ruta privada — NO sobrevivirán desinstalación.');
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory(path.join(appDir.path, _kBackupsFolder));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Busca carpetas de backup (Backup_*) en TODAS las rutas accesibles.
///
/// Útil al restaurar: el backup puede existir en una ruta distinta a la que
/// usa la instalación actual (p. ej. si Documents no era accesible antes y
/// el backup quedó en Download, o viceversa).
///
/// Retorna lista ordenada por fecha de modificación descendente (más reciente primero).
Future<List<Directory>> findAllBackupFolders() async {
  final writablePaths = await discoverWritablePaths();
  final found = <Directory>[];
  final seen  = <String>{};

  for (final basePath in writablePaths.values) {
    final backupsDir = Directory(path.join(basePath, _kBackupsFolder));
    if (!await backupsDir.exists()) continue;

    try {
      final subdirs = backupsDir
          .listSync()
          .whereType<Directory>()
          .where((d) => path.basename(d.path).startsWith('Backup_'))
          .toList();

      for (final dir in subdirs) {
        if (seen.add(dir.path)) found.add(dir);
      }
    } catch (e) {
      debugPrint('⚠️ [backup_paths] Error listando en $backupsDir: $e');
    }
  }

  // Ordenar por fecha de modificación descendente
  found.sort((a, b) {
    final mA = a.statSync().modified;
    final mB = b.statSync().modified;
    return mB.compareTo(mA);
  });

  debugPrint('🔍 [backup_paths] Carpetas de backup encontradas: ${found.length}');
  return found;
}
