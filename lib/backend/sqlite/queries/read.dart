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

  int get idUser => data['idUser'] as int;
  int get idCompany => data['idCompany'] as int;
  String get operID => data['operID'] as String;
  String get nameUser => data['nameUser'] as String;
  String get email => data['email'] as String;
}

/// END GETALLUSERS

/// BEGIN SELECTALLGEO
Future<List<SelectAllGeoRow>> performSelectAllGeo(
  Database database,
) {
  const query = '''
select * from ReadGeo
''';
  return _readQuery(database, query, (d) => SelectAllGeoRow(d));
}

class SelectAllGeoRow extends SqliteRow {
  SelectAllGeoRow(super.data);
}

/// END SELECTALLGEO

/// BEGIN GETCOUNTVISIT
Future<List<GetCountVisitRow>> performGetCountVisit(
  Database database,
) {
  const query = '''
SELECT COUNT(*) as count2 FROM Visits
''';
  return _readQuery(database, query, (d) => GetCountVisitRow(d));
}

class GetCountVisitRow extends SqliteRow {
  GetCountVisitRow(super.data);

  int get count2 => data['count2'] as int;
}

/// END GETCOUNTVISIT

/// BEGIN GETHEADQUARTERWEIGHTS
Future<List<GetHeadquarterWeightsRow>> performGetHeadquarterWeights(
  Database database, {
  required int headquarterId,
  required int year,
  required int month,
}) {
  final query = '''
SELECT * FROM Headquarters_weights
WHERE Id_headquarter = $headquarterId
  AND Date_year = $year
  AND Date_month = $month
LIMIT 1
''';
  return _readQuery(database, query, (d) => GetHeadquarterWeightsRow(d));
}

class GetHeadquarterWeightsRow extends SqliteRow {
  GetHeadquarterWeightsRow(super.data);

  int get idHeadquarterWeight => data['Id_headquarter_weight'] as int;
  int get idHeadquarter => data['Id_headquarter'] as int;
  int get idCompany => data['Id_company'] as int;
  int get dateYear => data['Date_year'] as int;
  int get dateMonth => data['Date_month'] as int;
  double get weight => (data['Weight'] as num).toDouble();
  String? get createdAt => data['Created_at'] as String?;
  String? get modifiedAt => data['Modified_at'] as String?;
}

/// END GETHEADQUARTERWEIGHTS

/// BEGIN GETUSEROPERADORPERMISSION
Future<List<GetUserOperadorPermissionRow>> performGetUserOperadorPermission(
  Database database, {
  required int userId,
}) {
  final query = '''
SELECT Name_permission
FROM Users_permissions
WHERE Id_user = $userId
  AND Name_permission = 'OPERADOR'
LIMIT 1
''';
  return _readQuery(database, query, (d) => GetUserOperadorPermissionRow(d));
}

class GetUserOperadorPermissionRow extends SqliteRow {
  GetUserOperadorPermissionRow(super.data);
  String get namePermission => data['Name_permission'] as String;
}
/// END GETUSEROPERADORPERMISSION

/// BEGIN GETSUPERVISORADMINUSERS
Future<List<GetSupervisorAdminUsersRow>> performGetSupervisorAdminUsers(
  Database database,
) {
  const query = '''
SELECT u.Id_user, u.Name_user, u.Oper_id
FROM Users u
INNER JOIN Users_permissions up ON u.Id_user = up.Id_user
WHERE up.Name_permission IN ('SUPERVISOR', 'ADMINISTRADOR')
  AND u.Oper_id IS NOT NULL
  AND u.Oper_id != ''
''';
  return _readQuery(database, query, (d) => GetSupervisorAdminUsersRow(d));
}

class GetSupervisorAdminUsersRow extends SqliteRow {
  GetSupervisorAdminUsersRow(super.data);
  int get idUser => data['Id_user'] as int;
  String get nameUser => (data['Name_user'] as String?) ?? '';
  String get operId => (data['Oper_id'] as String?) ?? '';
}
/// END GETSUPERVISORADMINUSERS
