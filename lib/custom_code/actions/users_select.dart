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

import '/backend/sqlite/global_db_singleton.dart';

Future<List<UsersStruct>> usersSelect(String databasePath, String typeSearch,
    String textSearch1, String textSearch2) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  return await globalDb.executeOperation((db) async {
    // Construir la consulta SQL basada en typeSearch
    String? whereClause;
    List<String>? whereArgs;

    if (typeSearch == "NAME_USER") {
      whereClause =
          "name_user LIKE ?"; // Buscar registros que coincidan con el patrón
      whereArgs = [
        "$textSearch1%"
      ]; // Busca nombres que comiencen con textSearch1
    }

    // Ejecutar la consulta SELECT
    final List<Map<String, dynamic>> queryResult = await db.query(
      'Users', // Tabla fija
      where: whereClause,
      whereArgs: whereArgs,
    );

    // Mapear los resultados a una lista de UsersStruct
    final List<UsersStruct> usersList =
        queryResult.map((map) => UsersStruct.fromMap(map)).toList();

    return usersList;
  });
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
