import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/global_db_singleton.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future updateVisitSQLite(VisitsStruct visitsStruct) async {
  await globalDb.executeOperation((db) async {
    final generatedId = await db.rawInsert('''
      INSERT OR REPLACE INTO Visits (
        Id_company, Id_activity, Id_headquarter, Id_product,
        Id_bulk, Id_user, Id_device, Id_status, Created_at,
        Battery, Latitude, Longitude, Altitude, Error_horizontal, Status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      visitsStruct.idCompany,
      visitsStruct.idActivity,
      visitsStruct.idHeadquarter,
      visitsStruct.idProduct,
      0, // Id_bulk — no existe en VisitsStruct
      visitsStruct.idUser,
      visitsStruct.idDevice,
      visitsStruct.idStatus,
      visitsStruct.createdAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      0,   // Battery
      0.0, // Latitude
      0.0, // Longitude
      0.0, // Altitude
      0.0, // Error_horizontal
      0,   // Status
    ]);

    debugPrint('updateVisitSQLite: Visit insertada con ID $generatedId');

    for (final detail in visitsStruct.visitsDetails) {
      await db.rawInsert('''
        INSERT OR REPLACE INTO Visits_details (
          Id_visit, Id_activity_status, Status_option, Status_response
        ) VALUES (?, ?, ?, ?)
      ''', [
        generatedId,
        detail.idActivityStatus,
        detail.statusOption.trim(),
        detail.statusResponse.trim(),
      ]);
    }
  });
}
