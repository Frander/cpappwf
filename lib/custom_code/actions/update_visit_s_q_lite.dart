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

Future updateVisitSQLite(VisitsStruct visitsStruct) async {
  // Add your function code here!
  final db = SQLiteManager.instance.database;

  // Preparar los datos del visit
  Map<String, dynamic> visitData = {
    'createdAt': visitsStruct.createdAt?.toIso8601String() ??
        DateTime.now().toIso8601String(),
    'idStatus': visitsStruct.idStatus,
    'idCompany': visitsStruct.idCompany,
    'idActivity': visitsStruct.idActivity,
    'idHeadquarter': visitsStruct.idHeadquarter,
    'idProduct': visitsStruct.idProduct,
    'idUser': visitsStruct.idUser,
    'idDevice': visitsStruct.idDevice,
    'locationDefault': visitsStruct.locationDefault,
  };

  // Insertar visit y obtener el ID generado
  // Insertar visit usando rawInsert
  int generatedId = await db.rawInsert('''
    INSERT OR REPLACE INTO Visit (
      createdAt, idStatus, idCompany, idActivity,
      idHeadquarter, idProduct, idUser, idDevice,
      locationDefault
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
    visitData['createdAt'],
    visitData['idStatus'],
    visitData['idCompany'],
    visitData['idActivity'],
    visitData['idHeadquarter'],
    visitData['idProduct'],
    visitData['idUser'],
    visitData['idDevice'],
    visitData['locationDefault'],
  ]);

  print('Visit insertado con ID autogenerado: $generatedId');

  // 2. INSERTAR VISIT DETAILS SI EXISTEN
  if (visitsStruct.visitsDetails.isNotEmpty) {
    for (VisitsDetailsStruct detail in visitsStruct.visitsDetails) {
      await db.rawInsert('''
        INSERT OR REPLACE INTO VisitDetail (
          idVisit, idActivityStatus, statusOption, statusResponse,
          idStepParent, rememberStatus, defaultStatus
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        generatedId, // Usar el idVisit del struct principal
        detail.idActivityStatus,
        detail.statusOption?.trim() ?? '',
        detail.statusResponse?.trim() ?? '',
        detail.idStepParent,
        detail.rememberStatus,
        detail.defaultStatus?.trim() ?? '',
      ]);
    }
    print(
        '${visitsStruct.visitsDetails.length} VisitDetails insertados para idVisit: ${visitsStruct.idVisit}');
  }

  // Procesar locationsAdd si existe
  if (visitsStruct.locationsAdd != null &&
      visitsStruct.locationsAdd!.isNotEmpty) {
    String dateHour = visitsStruct.createdAt?.toIso8601String() ??
        DateTime.now().toIso8601String();

    for (String locationStr in visitsStruct.locationsAdd!) {
      // Variables con valores por defecto
      double lat = 0.0;
      double lon = 0.0;
      double alt = 0.0;
      double erh = 0.0;

      // Dividir por punto y coma
      List<String> parts = locationStr.split(';');

      // Procesar cada parte
      for (String part in parts) {
        List<String> keyValue = part.split(':');

        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          String valueStr = keyValue[1].trim();

          switch (key) {
            case 'LAT':
              lat = double.tryParse(valueStr) ?? 0.0;
              break;
            case 'LON':
              lon = double.tryParse(valueStr) ?? 0.0;
              break;
            case 'ALT':
              alt = double.tryParse(valueStr) ?? 0.0;
              break;
            case 'ERH':
              erh = double.tryParse(valueStr) ?? 0.0;
              break;
          }
        }
      }

      // Insertar en VisitLocation
      await db.rawInsert('''
        INSERT INTO VisitLocation (
          idVisit, latitude, longitude, altitude, errorHorizontal, dateHourRead
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        generatedId, // ID autogenerado del Visit
        lat,
        lon,
        alt,
        erh,
        dateHour,
      ]);
    }

    print('${visitsStruct.locationsAdd!.length} VisitLocations insertadas');
  }
}
