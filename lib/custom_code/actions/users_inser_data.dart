import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';
import 'package:sqflite/sqflite.dart';

Future<void> usersInserData(
    String databasePath, String tableName, List<UsersStruct> data) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  await globalDb.executeOperation((db) async {
    // Verificar si la tabla existe
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );

    // Si la tabla no existe, crearla dinámicamente
    if (tableExists.isEmpty) {
      // Obtén los campos dinámicamente desde el método toMap del primer elemento
      final firstUser = data.first.toMap();
      final fields = firstUser.keys
          .map((key) => "$key ${_getSqlType(firstUser[key])}")
          .join(", ");
      await db.execute("CREATE TABLE $tableName ($fields)");
      debugPrint('Tabla $tableName creada con campos: $fields');
    } else {
      // Si la tabla existe, eliminar todos los registros primero
      await db.delete(tableName);
      debugPrint('Todos los registros existentes en $tableName fueron eliminados');
    }

    // Insertar los registros en la tabla
    for (final user in data) {
      await db.insert(
        tableName,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    debugPrint('Datos insertados en la tabla $tableName');
  });
}

// Función auxiliar para determinar el tipo de dato SQL basado en los valores de toMap
String _getSqlType(dynamic value) {
  if (value is int) return 'INTEGER';
  if (value is double) return 'REAL';
  if (value is String) return 'TEXT';
  if (value is bool) return 'INTEGER'; // SQLite no tiene un tipo booleano
  return 'TEXT'; // Tipo por defecto
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
