// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
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
