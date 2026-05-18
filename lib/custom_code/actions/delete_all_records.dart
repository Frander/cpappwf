import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';

Future<void> deleteAllRecords(String databasePath, String tableName) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  try {
    await globalDb.executeOperation((db) async {
      // Verificar si la tabla existe
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );

      if (tableExists.isEmpty) {
        debugPrint('La tabla $tableName no existe en la base de datos.');
        return;
      }

      // Eliminar todos los registros de la tabla
      final deletedRows = await db.delete(tableName);

      debugPrint('$deletedRows registros eliminados de la tabla $tableName.');
    });
  } catch (e) {
    debugPrint('Error al intentar eliminar registros de la tabla $tableName: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
