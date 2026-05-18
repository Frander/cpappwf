// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';

Future<List<UsersStruct>> searchUsersSqlite(String searchText) async {
  return await globalDb.executeOperation((db) async {
    // Asegurar que la columna last_used existe (migración automática)
    await globalDb.ensureUsersLastUsedColumn();

    final List<Map<String, dynamic>> queryResult;

    if (searchText.trim().isEmpty) {
      queryResult = await db.rawQuery('''
        SELECT
          Id_user      as id_user,
          Id_company   as id_company,
          Oper_id      as operID,
          Name_user    as name_user,
          Email        as email,
          Code_user    as code_user,
          State_user   as state_user,
          Rol_user     as rol_user,
          Created_at   as created_at,
          Modified_at  as modifiedAt
        FROM Users
        ORDER BY last_used DESC, Name_user ASC
      ''');
    } else {
      final searchPattern = '%${searchText.trim()}%';
      queryResult = await db.rawQuery('''
        SELECT
          Id_user      as id_user,
          Id_company   as id_company,
          Oper_id      as operID,
          Name_user    as name_user,
          Email        as email,
          Code_user    as code_user,
          State_user   as state_user,
          Rol_user     as rol_user,
          Created_at   as created_at,
          Modified_at  as modifiedAt
        FROM Users
        WHERE Name_user LIKE ? OR Oper_id LIKE ? OR Code_user LIKE ?
        ORDER BY last_used DESC, Name_user ASC
        LIMIT 50
      ''', [searchPattern, searchPattern, searchPattern]);
    }

    return queryResult.map((map) => UsersStruct.fromMap(map)).toList();
  });
}
