// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';

Future<void> deleteAllRecords(String databasePath, String tableName) async {
  // Abre la base de datos usando la ruta proporcionada
  final db = await openDatabase(databasePath);

  try {
    // Verificar si la tabla existe
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );

    if (tableExists.isEmpty) {
      print('La tabla $tableName no existe en la base de datos.');
      await db.close();
      return;
    }

    // Eliminar todos los registros de la tabla
    final deletedRows = await db.delete(tableName);

    print('$deletedRows registros eliminados de la tabla $tableName.');
  } catch (e) {
    print('Error al intentar eliminar registros de la tabla $tableName: $e');
  } finally {
    // Cerrar la base de datos después de la operación
    await db.close();
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
