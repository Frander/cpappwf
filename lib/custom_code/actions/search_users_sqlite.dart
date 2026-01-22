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

Future<List<UsersStruct>> searchUsersSqlite(String searchText) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  return await globalDb.executeOperation((db) async {
    // Si el texto de búsqueda está vacío, retornar lista vacía
    if (searchText.trim().isEmpty) {
      return [];
    }

    // Construir la consulta SQL para buscar por nombre o operID
    final searchPattern = '%${searchText.trim()}%';

    // Ejecutar la consulta SELECT con búsqueda en nombre y operID
    // Usar alias para que coincida con el mapeo de UsersStruct.fromMap()
    final List<Map<String, dynamic>> queryResult = await db.rawQuery('''
      SELECT
        Id_user as id_user,
        Id_company as id_company,
        Oper_id as operID,
        Name_user as name_user,
        Email as email,
        Created_at as created_at,
        Modified_at as modifiedAt
      FROM Users
      WHERE Name_user LIKE ? OR Oper_id LIKE ?
      ORDER BY Name_user ASC
      LIMIT 50
    ''', [searchPattern, searchPattern]);

    // Mapear los resultados a una lista de UsersStruct
    final List<UsersStruct> usersList =
        queryResult.map((map) => UsersStruct.fromMap(map)).toList();

    return usersList;
  });
}
