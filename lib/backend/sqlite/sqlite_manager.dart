import 'package:flutter/foundation.dart';

import '/backend/sqlite/init.dart';
import '/custom_code/platform_utils.dart';
import 'queries/read.dart';
import 'queries/update.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Empaqueta libsqlite3 nativa para desktop (Linux/Windows/macOS) para que
// sqflite_common_ffi no dependa de que el sistema tenga libsqlite3 instalado.
// ignore: unused_import
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
export 'queries/read.dart';
export 'queries/update.dart';

class SQLiteManager {
  SQLiteManager._();

  static SQLiteManager? _instance;
  static SQLiteManager get instance => _instance ??= SQLiteManager._();

  static late Database _database;
  Database get database => _database;

  static Future initialize() async {
    if (kIsWeb) {
      return;
    }
    if (Platforms.isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await initializeDatabaseFromDbFile(
      'click_palm_local_b_d_n_e_w',
      'ClickPalmLocalBDV2.db',
    );
  }

  /// START READ QUERY CALLS

  Future<List<GetAllUsersRow>> getAllUsers() => performGetAllUsers(
        _database,
      );

  Future<List<SelectAllGeoRow>> selectAllGeo() => performSelectAllGeo(
        _database,
      );

  Future<List<GetCountVisitRow>> getCountVisit() => performGetCountVisit(
        _database,
      );

  Future<List<GetHeadquarterWeightsRow>> getHeadquarterWeights({
    required int headquarterId,
    required int year,
    required int month,
  }) =>
      performGetHeadquarterWeights(
        _database,
        headquarterId: headquarterId,
        year: year,
        month: month,
      );

  /// END READ QUERY CALLS

  /// START UPDATE QUERY CALLS

  Future deleteAllUsers() => performDeleteAllUsers(
        _database,
      );

  Future addReadGeo({
    double? latitude,
    double? longitude,
    double? altitude,
    double? errorHorizontal,
    String? dateHourRead,
  }) =>
      performAddReadGeo(
        _database,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        errorHorizontal: errorHorizontal,
        dateHourRead: dateHourRead,
      );

  /// END UPDATE QUERY CALLS
}
