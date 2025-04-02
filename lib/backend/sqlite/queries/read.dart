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
  final query = '''
select * from Users
''';
  return _readQuery(database, query, (d) => GetAllUsersRow(d));
}

class GetAllUsersRow extends SqliteRow {
  GetAllUsersRow(Map<String, dynamic> data) : super(data);

  int get idUser => data['idUser'] as int;
  int get idCompany => data['idCompany'] as int;
  String get operID => data['operID'] as String;
  String get nameUser => data['nameUser'] as String;
  String get email => data['email'] as String;
}

/// END GETALLUSERS
