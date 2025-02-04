import 'package:sqflite/sqflite.dart';

/// BEGIN DELETEALLUSERS
Future performDeleteAllUsers(
  Database database,
) {
  const query = '''
DELETE FROM Users
''';
  return database.rawQuery(query);
}

/// END DELETEALLUSERS
