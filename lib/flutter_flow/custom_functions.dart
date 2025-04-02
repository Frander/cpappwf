import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';

String concatenateStrings(
  String string1,
  String string2,
) {
  return '$string1$string2';
}

String removeLastCharacter(String input) {
  if (input.isNotEmpty) {
    return input.substring(0, input.length - 1);
  }
  return input; // Devuelve la cadena original si está vacía.
}

bool validateLocationFormat(String response) {
  // Expresión regular para validar el formato "LAT:XXXXX;LON:XXXXX;ALT:XXXXXX"
  final RegExp regex =
      RegExp(r'^LAT:-?\d+(\.\d+)?;LON:-?\d+(\.\d+)?;ALT:-?\d+(\.\d+)?$');

  // Verificar si la respuesta coincide con el formato
  return regex.hasMatch(response);
}

bool hasMoreThanAnHourPassed(
  DateTime dateStart,
  DateTime dateFinish,
) {
// Calcula la diferencia entre las fechas
  Duration difference = dateFinish.difference(dateStart);

  // Extrae días, horas y minutos
  int days = difference.inDays;
  int hours = difference.inHours % 24; // Horas restantes después de días
  int minutes = difference.inMinutes % 60; // Minutos restantes después de horas

  // Imprime el tiempo transcurrido (opcional para depuración)
  debugPrint("Han pasado $days días, $hours horas y $minutes minutos.");

  // Retorna true si ha pasado más de 1 hora
  return difference.inHours >= 1;
}

dynamic convertVisitsToJson(List<VisitsStruct> visitsList) {
// Se utiliza el método toMap() que ya tienes implementado en la clase
  final List<Map<String, dynamic>> listOfMaps =
      visitsList.map((visit) => visit.toMap()).toList();

  // Se convierte la lista de mapas a una cadena JSON
  return jsonEncode(listOfMaps);
}

List<String> extractFieldFromJson(
  dynamic jsonString,
  String fieldName,
) {
  try {
    // Decodificar el JSON en una lista de mapas
    List<dynamic> jsonList = json.decode(jsonString);

    // Extraer los valores del campo especificado
    return jsonList.map<String>((item) => item[fieldName].toString()).toList();
  } catch (e) {
    print("Error parsing JSON: $e");
    return [];
  }
}

List<String> extractFieldFromActivities(
  ActivitiesStruct activities,
  String fieldName,
) {
  try {
    return activities.activitiesStatus.map<String>((item) {
      var value = item.statusName;
      return value.toString();
    }).toList();
  } catch (e) {
    print("Error extracting field: $e");
    return [];
  }
}

String listToCommaSeparatedString(List<String> items) {
  return items.join(',');
}

VisitsStruct createVisitsObject(
  int idVisit,
  int idCompany,
  int idActivity,
  int idHeadquarter,
  int idProduct,
  int idUser,
  int idDevice,
  int idStatus,
  List<String>? locationsAdd,
  DateTime? createdAt,
  String? locationDefault,
) {
  return VisitsStruct(
    idVisit: idVisit,
    idCompany: idCompany,
    idActivity: idActivity,
    idHeadquarter: idHeadquarter,
    idProduct: idProduct,
    idUser: idUser,
    idDevice: idDevice,
    idStatus: idStatus,
    locationsAdd: locationsAdd ?? [], // Si es null, asigna una lista vacía
    createdAt:
        createdAt ?? DateTime.now(), // Si es null, asigna la fecha actual
    locationDefault:
        locationDefault ?? '', // Si es null, asigna una cadena vacía
  );
}

DateTime convertToDotNetDateTime(DateTime date) {
  return date.toUtc();
}

String getActivityName(
  List<ActivitiesStruct> activities,
  int idActivity,
) {
  // Buscar el primer elemento en la lista que tenga el idActivity proporcionado
  final activity = activities.firstWhere(
    (activity) => activity.idActivity == idActivity,
    orElse: () =>
        ActivitiesStruct(nameActivity: ''), // Devolver un objeto vacío
  );

  // Si se encuentra la actividad, devolver su nameActivity; de lo contrario, devolver una cadena vacía
  return activity.nameActivity;
}

String? getStatusName(
  List<ActivitiesStatusStruct> activitiesStatusList,
  int idActivityStatus,
) {
  // Buscar el primer objeto en la lista que tenga el idActivityStatus proporcionado
  final activityStatus = activitiesStatusList.firstWhere(
    (activityStatus) => activityStatus.idActivityStatus == idActivityStatus,
    orElse: () =>
        ActivitiesStatusStruct(statusName: ''), // Devolver un objeto vacío
  );

  // Si se encuentra el objeto, devolver su statusName; de lo contrario, devolver una cadena vacía
  return activityStatus.statusName;
}

String convertToMarkdown(
  String title,
  List<String> items,
) {
  // Convertir el título a negrita y un tamaño más grande con Markdown
  String markdownTitle = '# **$title**\n\n';

  // Convertir cada elemento de la lista en un ítem de Markdown
  String markdownItems = items.map((item) => '- $item').join('\n');

  // Combinar título y elementos
  return '$markdownTitle$markdownItems';
}

ActivitiesStatusStruct? findActivityStatusById(
  List<ActivitiesStruct> activities,
  int idStatus,
) {
  // Recorrer todas las actividades en busca de un status específico
  for (var activity in activities) {
    // Buscar dentro de la lista de statuses de cada actividad
    final status = activity.activitiesStatus.firstWhere(
      (status) => status.idActivityStatus == idStatus,
      orElse: () =>
          ActivitiesStatusStruct(), // Si no se encuentra, devuelve un objeto vacío
    );

    // Si el objeto encontrado no es vacío, retornarlo
    if (status.idActivityStatus != 0) {
      return status;
    }
  }

  // Si no se encontró, devolver null
  return null;
}
