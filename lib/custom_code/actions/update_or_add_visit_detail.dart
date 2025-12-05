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

Future<List<VisitsDetailsStruct>> updateOrAddVisitDetail(
  List<VisitsDetailsStruct> visitsList,
  int idActivityStatus,
  int idStepParent,
  String statusOption,
  String statusResponse,
  bool rememberStatus,
  String defaultStatus,
  int? auxStep,
) async {
  // LOG: Parámetros de entrada
  print('🔍 === INICIO DE FUNCIÓN2 updateOrAddVisitDetail ===');
  print('📥 Parámetros recibidos:');
  print('   - idActivityStatus: $idActivityStatus');
  print('   - idStepParent: $idStepParent');
  print('   - statusOption: "$statusOption"');
  print('   - statusResponse: "$statusResponse"');
  print('   - rememberStatus: $rememberStatus');
  print('   - defaultStatus: "$defaultStatus"');

  // Validar que la lista no sea nula
  if (visitsList == null) {
    visitsList = [];
  }

  // LOG: Contenido de la lista actual
  print('📋 Lista actual tiene ${visitsList.length} elementos:');
  for (int i = 0; i < visitsList.length; i++) {
    VisitsDetailsStruct visit = visitsList[i];
    print(
        '   [$i] idActivityStatus: ${visit.idActivityStatus}, idStepParent: ${visit.idStepParent}, statusOption: "${visit.statusOption}", rememberStatus: ${visit.rememberStatus}');
  }

  // Validar parámetros requeridos
  if (idActivityStatus <= 0) {
    print('❌ Error: idActivityStatus debe ser mayor a 0');
    return visitsList;
  }

  // Crear una copia de la lista original
  List<VisitsDetailsStruct> updatedList = List.from(visitsList);

  try {
    // LOG: Tipo de búsqueda
    if (idStepParent == 0) {
      print('🔎 Búsqueda por idActivityStatus (porque idStepParent = 0)');
      print('🔍 Buscando registro con idActivityStatus = $idActivityStatus');
    } else {
      print('🔎 Búsqueda por idStepParent (porque idStepParent ≠ 0)');
      print('🔍 Buscando registro con idStepParent = $idStepParent');
    }

    // Buscar registro existente paso a paso para debugging
    print('🔍 Buscando en la lista...');
    int existingIndex = -1;

    for (int i = 0; i < updatedList.length; i++) {
      VisitsDetailsStruct visit = updatedList[i];
      bool found = false;

      if (idStepParent == 0) {
        // Buscar por idActivityStatus
        found = visit.idActivityStatus == idActivityStatus;
        print(
            '   [$i] Comparando idActivityStatus: ${visit.idActivityStatus} == $idActivityStatus? $found');
      } else {
        // Buscar por idStepParent
        found = visit.idStepParent == idStepParent;
        print(
            '   [$i] Comparando idStepParent: ${visit.idStepParent} == $idStepParent? $found');
      }

      if (found) {
        existingIndex = i;
        print('   ✅ ¡COINCIDENCIA ENCONTRADA en índice $i!');
        if (idStepParent != 0) {
          print(
              '   📝 Se actualizará idActivityStatus de ${visit.idActivityStatus} a $idActivityStatus');
        }
        break;
      } else {
        print('   ❌ No coincide');
      }
    }

    print('🎯 Resultado de búsqueda: existingIndex = $existingIndex');

    if (existingIndex != -1) {
      // Actualizar registro existente
      VisitsDetailsStruct existingVisit = updatedList[existingIndex];

      VisitsDetailsStruct updatedVisit = VisitsDetailsStruct(
          idVisitDetail: 0, // Siempre será 0
          idVisit: 0, // Siempre será 0
          idActivityStatus: idActivityStatus,
          statusOption: statusOption.trim(),
          statusResponse: statusResponse.trim(),
          idStepParent: idStepParent,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus.trim(),
          auxStep: auxStep);

      updatedList[existingIndex] = updatedVisit;

      print(
          '✅ Registro actualizado exitosamente - idActivityStatus: $idActivityStatus, idStepParent: $idStepParent');
    } else {
      // Crear nuevo registro
      VisitsDetailsStruct newVisit = VisitsDetailsStruct(
          idVisitDetail: 0, // Siempre será 0
          idVisit: 0, // Siempre será 0
          idActivityStatus: idActivityStatus,
          statusOption: statusOption.trim(),
          statusResponse: statusResponse.trim(),
          idStepParent: idStepParent,
          rememberStatus: rememberStatus,
          defaultStatus: defaultStatus.trim(),
          auxStep: auxStep);

      updatedList.add(newVisit);

      print(
          '✅ Nuevo registro creado exitosamente - idActivityStatus: $idActivityStatus, idStepParent: $idStepParent');
    }
  } catch (e) {
    print('❌ Error al procesar el registro: $e');
    return visitsList; // Retornar la lista original en caso de error
  }

  return updatedList;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
