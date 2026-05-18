import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';
import 'package:sqflite/sqflite.dart';

Future<void> productsInsertData(
    String databasePath, String tableName, List<ProductsStruct> data) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  await globalDb.executeOperation((db) async {
    // Verificar si la tabla existe
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );

    // Si la tabla no existe, crearla dinámicamente
    if (tableExists.isEmpty) {
      if (data.isEmpty) {
        throw Exception("No hay datos para crear la tabla $tableName.");
      }

      final firstUser = data.first.toMap();
      if (firstUser.isEmpty) {
        throw Exception(
            "El mapa de datos está vacío. No se puede crear la tabla $tableName.");
      }

      final fields = firstUser.keys
          .map((key) => "$key ${_getSqlType(firstUser[key])}")
          .join(", ");
      debugPrint('Campos detectados para la tabla $tableName: $fields');

      await db.execute("CREATE TABLE $tableName ($fields)");
      debugPrint('Tabla $tableName creada con campos: $fields');
    }

    // Insertar los registros en la tabla
    for (final product in data) {
      await db.insert(
        tableName,
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    debugPrint('Datos insertados en la tabla $tableName');
  });
}

String _getSqlType(dynamic value) {
  if (value == null) return 'TEXT'; // Valor predeterminado para valores nulos
  if (value is int) return 'INTEGER';
  if (value is double) return 'REAL';
  if (value is String) return 'TEXT';
  if (value is bool) return 'INTEGER'; // SQLite no tiene un tipo booleano
  return 'TEXT'; // Tipo por defecto
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
