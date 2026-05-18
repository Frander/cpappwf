// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';
import 'package:sqflite/sqflite.dart';

/// Elimina todos los registros STEP de la tabla Visits_details
/// Los registros STEP tienen Id_activity_status = 0 y no deben estar en la base de datos
Future<int> cleanupStepRecords() async {
  try {
    debugPrint('=== Iniciando limpieza de registros STEP ===');

    // Usa el singleton global en lugar de abrir conexión aislada
    return await globalDb.executeOperation((db) async {
      // Contar registros STEP antes de eliminar
      final countBefore = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Visits_details WHERE Id_activity_status = 0',
      );
      final recordsToDelete = Sqflite.firstIntValue(countBefore) ?? 0;

      debugPrint('📊 Registros STEP encontrados: $recordsToDelete');

      if (recordsToDelete == 0) {
        debugPrint('✅ No hay registros STEP para eliminar');
        return 0;
      }

      // Eliminar registros STEP
      debugPrint('🗑️ Eliminando registros con Id_activity_status = 0...');
      final deletedCount = await db.rawDelete(
        'DELETE FROM Visits_details WHERE Id_activity_status = 0',
      );

      debugPrint('✅ $deletedCount registros STEP eliminados exitosamente');

      // Verificar después de eliminar
      final countAfter = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Visits_details WHERE Id_activity_status = 0',
      );
      final remainingRecords = Sqflite.firstIntValue(countAfter) ?? 0;

      if (remainingRecords > 0) {
        debugPrint('⚠️ Aún quedan $remainingRecords registros STEP');
      } else {
        debugPrint('✅ Todos los registros STEP han sido eliminados');
      }

      debugPrint('=== Limpieza completada ===');
      return deletedCount;
    });
  } catch (e) {
    debugPrint('❌ Error en cleanupStepRecords: $e');
    return -1;
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
