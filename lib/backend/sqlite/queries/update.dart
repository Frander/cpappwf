import 'package:sqflite/sqflite.dart';

/// BEGIN DELETEALLUSERS
Future performDeleteAllUsers(
  Database database,
) {
  final query = '''
DELETE FROM Users
''';
  return database.rawQuery(query);
}

/// END DELETEALLUSERS

/// BEGIN ADDREADGEO
Future performAddReadGeo(
  Database database, {
  double? latitude,
  double? longitude,
  double? altitude,
  double? errorHorizontal,
  String? dateHourRead,
}) {
  final query = '''
Insert into ReadGeo (latitude,longitude,altitude,errorHorizontal,dateHourRead) values (${latitude}, ${longitude}, ${altitude}, ${errorHorizontal}, '${dateHourRead}')
''';
  return database.rawQuery(query);
}

/// END ADDREADGEO
