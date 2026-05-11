// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';

/// Actualiza un registro de Visits_details identificado por (Id_visit, Id_activity_status).
/// Retorna el número de filas afectadas.
Future<int> updateVisitDetailInSQLite(
  int idVisit,
  int idActivityStatus,
  String statusOption,
  String statusResponse,
) async {
  if (idVisit <= 0 || idActivityStatus <= 0) {
    debugPrint('⚠️ updateVisitDetailInSQLite: parámetros inválidos '
        '(idVisit=$idVisit, idActivityStatus=$idActivityStatus)');
    return 0;
  }

  final dbPath = FFAppState().pathDatabase;
  if (dbPath.isEmpty) {
    debugPrint('⚠️ updateVisitDetailInSQLite: pathDatabase vacío');
    return 0;
  }

  try {
    final db = await openDatabase(dbPath);
    final affected = await db.update(
      'Visits_details',
      {
        'Status_option': statusOption,
        'Status_response': statusResponse,
      },
      where: 'Id_visit = ? AND Id_activity_status = ?',
      whereArgs: [idVisit, idActivityStatus],
    );
    debugPrint('✏️ updateVisitDetailInSQLite: Id_visit=$idVisit '
        'Id_activity_status=$idActivityStatus → $affected filas afectadas '
        '(option="$statusOption", response="$statusResponse")');
    return affected;
  } catch (e) {
    debugPrint('❌ updateVisitDetailInSQLite error: $e');
    return 0;
  }
}
