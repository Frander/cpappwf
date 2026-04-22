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

Future<VisitsStruct> createVisitsObjectAction(
  int idVisit,
  int idCompany,
  int idActivity,
  int idHeadquarter,
  int idProduct,
  int idUser,
  int idDevice,
  int idStatus,
  List<String> locationsAdd,
  DateTime createdAt,
  String? locationDefault,
  List<VisitsDetailsStruct> visitsDetails,
) async {
  /// MODIFY CODE ONLY BELOW THIS LINE

  // CREAR TABLA VISITAS SI NO EXISTE (CON ID AUTOGENERADO)
  // CREAR TABLA VISITS_DETAILS
  // CREAR TABLA VISITS_LOCATIONS
  // AGREGAR LA VISITA A LAS TABLAS CORRESPONDIENTES

  final visitsStruct = VisitsStruct(
    createdAt: createdAt,
    idStatus: idStatus,
    idVisit: idVisit,
    idCompany: idCompany,
    idActivity: idActivity,
    idHeadquarter: idHeadquarter,
    idProduct: idProduct,
    idUser: idUser,
    idDevice: idDevice,
    locationDefault: locationDefault,
    visitsDetails: visitsDetails,
    locationsAdd: locationsAdd,
  );

  // Si necesitas hacer alguna operación asíncrona, puedes agregarla aquí
  // Por ejemplo: await someAsyncOperation();

  return visitsStruct;

  /// MODIFY CODE ONLY ABOVE THIS LINE
}
