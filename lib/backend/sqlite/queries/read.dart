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

/// BEGIN SELECTALLGEO
Future<List<SelectAllGeoRow>> performSelectAllGeo(
  Database database,
) {
  final query = '''
select * from ReadGeo
''';
  return _readQuery(database, query, (d) => SelectAllGeoRow(d));
}

class SelectAllGeoRow extends SqliteRow {
  SelectAllGeoRow(Map<String, dynamic> data) : super(data);
}

/// END SELECTALLGEO

/// BEGIN GETCOUNTVISIT
Future<List<GetCountVisitRow>> performGetCountVisit(
  Database database,
) {
  final query = '''
SELECT COUNT(*) as count2 FROM Visits
''';
  return _readQuery(database, query, (d) => GetCountVisitRow(d));
}

class GetCountVisitRow extends SqliteRow {
  GetCountVisitRow(Map<String, dynamic> data) : super(data);

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
  GetHeadquarterWeightsRow(Map<String, dynamic> data) : super(data);

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
