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

int countJsonItems(dynamic jsonData) {
  try {
    if (jsonData is List) {
      return jsonData.length;
    }
    return 0;
  } catch (e) {
    // En caso de error, retornar 0
    return 0;
  }
}

dynamic filterByModuleActivity(
  dynamic jsonData,
  String moduleToFilter,
) {
  try {
    if (jsonData is List) {
      // Filtrar los elementos donde module_activity coincide con el parámetro
      final filteredList = jsonData.where((item) {
        // Verificar si el item es un Map y contiene module_activity
        if (item is Map<String, dynamic>) {
          final module = item['module_activity'] as String?;
          return module != null && module == moduleToFilter;
        }
        return false;
      }).toList();

      return filteredList; // Esto es un List<dynamic>, pero se devuelve como dynamic
    }
    return []; // Devuelve una lista vacía como dynamic
  } catch (e) {
    // En caso de error, retornar lista vacía como dynamic
    return [];
  }
}

String concatHeadquartersNames(List<HeadquartersStruct> headquartersList) {
  // Si la lista es null o está vacía, devolvemos cadena vacía
  if (headquartersList == null || headquartersList.isEmpty) {
    return '';
  }
  // Extraemos los name_headquarter, filtramos nulls y strings vacíos,
  // y luego unimos con ' - '
  final validNames = headquartersList
      .map((hq) => hq.nameHeadquarter) // String?
      .where((name) => name != null && name.isNotEmpty) // filtra null y ''
      .map((name) => name!) // cast a String no-null
      .toList();

  return validNames.join(' - ');
}

dynamic sortJsonByOrder(dynamic jsonData) {
  try {
    if (jsonData is List) {
      // Crear una copia de la lista para no modificar la original
      final sortedList = List.from(jsonData);

      // Ordenar por el campo "orden"
      sortedList.sort((a, b) {
        final orderA = a['orden'] as int? ?? 0;
        final orderB = b['orden'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      return sortedList;
    }
    return jsonData; // Si no es una lista, devolver el dato original
  } catch (e) {
    // En caso de error, devolver el dato original
    return jsonData;
  }
}

List<UsersStruct> filterUsersByName(
  List<UsersStruct> usersList,
  String filterName,
) {
// Si filterName está vacío, devolver toda la lista sin filtrar
  if (filterName.isEmpty) {
    return usersList.toList(); // Retorna una nueva lista (inmutable)
  }

  // Filtrar la lista por name_user (case insensitive)
  return usersList
      .where((user) =>
          user.nameUser?.toLowerCase().contains(filterName.toLowerCase()) ??
          false)
      .toList();
}

List<HeadquartersStruct> filterHeadquartersByName(
  List<HeadquartersStruct> headquartersList,
  String filterName,
) {
// Si filterName está vacío, devolver toda la lista sin filtrar
  if (filterName.isEmpty) {
    return headquartersList.toList(); // Retorna una nueva lista (inmutable)
  }

  // Filtrar la lista por name_headquarter (case insensitive)
  return headquartersList
      .where((hq) =>
          hq.nameHeadquarter
              ?.toLowerCase()
              .contains(filterName.toLowerCase()) ??
          false)
      .toList();
}

String concatenateHeadquarterIds(List<HeadquartersStruct> headquartersList) {
// Extrae todos los id_headquarter de la lista y los convierte a String
  List<String> ids = headquartersList
      .map((headquarter) => headquarter.idHeadquarter.toString())
      .toList();

  // Une los IDs con comas
  String result = ids.join(',');

  return result;
}

dynamic groupVisitsByActivityAndStatus(
  List<VisitsStruct> visits,
  dynamic activitiesJson,
) {
  try {
    // Convertir el JSON de actividades a una lista de mapas si es necesario
    final List<dynamic> activitiesList = activitiesJson is String
        ? jsonDecode(activitiesJson)
        : activitiesJson as List<dynamic>;

    // Mapa para buscar actividades por ID
    final Map<int, dynamic> activitiesMap = {};
    for (final activity in activitiesList) {
      activitiesMap[activity['id_activity'] as int] = activity;
    }

    // Agrupar y contar visitas
    final Map<int, Map<int, int>> counts = {};

    for (final visit in visits) {
      counts
          .putIfAbsent(visit.idActivity, () => {})
          .update(visit.idStatus, (count) => count + 1, ifAbsent: () => 1);
    }

    // Construir el resultado
    final List<dynamic> result = [];

    counts.forEach((activityId, statusCounts) {
      final activity = activitiesMap[activityId];
      if (activity == null) return;

      final List<dynamic> statuses = [];

      statusCounts.forEach((statusId, count) {
        final status = (activity['activity_status'] as List?)?.firstWhere(
          (s) => s['id_activity_status'] == statusId,
          orElse: () => {'status_name': 'Estado $statusId'},
        );

        statuses.add({
          'status_name': status['status_name'],
          'conteo': count.toString(),
        });
      });

      // Ordenar estados por conteo descendente
      statuses.sort(
          (a, b) => int.parse(b['conteo']).compareTo(int.parse(a['conteo'])));

      result.add({
        'name_activity': activity['name_activity'],
        'activity_status': statuses,
      });
    });

    // Ordenar por nombre de actividad
    result.sort((a, b) =>
        (a['name_activity'] as String).compareTo(b['name_activity'] as String));

    return result;
  } catch (e) {
    print('Error processing visits: $e');
    return [];
  }
}
