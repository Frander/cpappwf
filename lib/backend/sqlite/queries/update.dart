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

/// BEGIN INSERTUSER
Future performInsertUser(
  Database database, {
  int? idUser,
  int? idCompany,
  String? operId,
  String? nameUser,
  String? email,
  String? createdAt,
  String? modifiedAt,
}) {
  final query = '''
INSERT INTO Users (
    Id_user,
    Id_company,
    OperID,
    Name_user,
    Email,
    Created_at,
    ModifiedAt
) VALUES (
    $idUser,
    $idCompany,
    $operId,
    '$nameUser',
    '$email',
    '$createdAt',
    '$modifiedAt'
);

''';
  return database.rawQuery(query);
}

/// END INSERTUSER
