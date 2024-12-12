import '/backend/sqlite/queries/sqlite_row.dart';
import 'package:sqflite/sqflite.dart';

Future<List<T>> _readQuery<T>(
  Database database,
  String query,
  T Function(Map<String, dynamic>) create,
) =>
    database.rawQuery(query).then((r) => r.map((e) => create(e)).toList());

/// BEGIN GETALLUSERS
Future<List<GetAllUsersRow>> performGetAllUsers(
  Database database,
) {
  const query = '''
select * from Users
''';
  return _readQuery(database, query, (d) => GetAllUsersRow(d));
}

class GetAllUsersRow extends SqliteRow {
  GetAllUsersRow(super.data);

  int get idUser => data['Id_user'] as int;
  int get idCompany => data['Id_company'] as int;
  String get operID => data['OperID'] as String;
  String get nameUser => data['Name_user'] as String;
  String? get email => data['Email'] as String?;
}

/// END GETALLUSERS
