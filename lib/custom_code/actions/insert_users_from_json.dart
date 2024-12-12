// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> insertUsersFromJson(String jsonString) async {
  // Parsear el JSON en una lista de objetos.
  final List<dynamic> usersList = jsonDecode(jsonString);

  // Obtener la base de datos SQLite.
  final database = await openDatabase(
    join(await getDatabasesPath(), 'ClickPalmLocalBD.db'),
    version: 1,
    onOpen: (db) async {
      // Comprobar si la tabla `Users` existe.
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='Users'");
      if (tableExists.isEmpty) {
        // Si la tabla no existe, retornar y no continuar.
        return;
      }
    },
  );

  // Iniciar una transacción para realizar múltiples inserciones.
  await database.transaction((txn) async {
    for (final user in usersList) {
      // Insertar cada usuario en la tabla `Users`.
      await txn.insert(
        'Users',
        {
          'Id_user': user['id_user'],
          'Id_company': user['id_company'],
          'OperID': user['operID'],
          'Name_user': user['name_user'],
          'Email': user['email']
        },
        conflictAlgorithm:
            ConflictAlgorithm.replace, // Reemplazar si existe el ID.
      );
    }
  });

  // Cerrar la base de datos (opcional, pero recomendado).
  await database.close();
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
