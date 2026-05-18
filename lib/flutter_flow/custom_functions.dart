import 'dart:convert';

import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';

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
  return input; // Devuelve la cadena original si está vacía.d
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
    debugPrint("Error parsing JSON: $e");
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
  List<String> locationsAdd,
  DateTime createdAt,
  String? locationDefault,
  List<VisitsDetailsStruct> visitsDetails,
) {
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

  return visitsStruct;
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
  if (headquartersList.isEmpty) {
    return '';
  }
  // Extraemos los name_headquarter, filtramos nulls y strings vacíos,
  // y luego unimos con ' - '
  final validNames = headquartersList
      .map((hq) => hq.nameHeadquarter) // String?
      .where((name) => name.isNotEmpty) // filtra null y ''
      .map((name) => name) // cast a String no-null
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
        final orderA = a['order_status'] as int? ?? 0;
        final orderB = b['order_status'] as int? ?? 0;
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
          user.nameUser.toLowerCase().contains(filterName.toLowerCase()) ??
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
              .toLowerCase()
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
    debugPrint('Error processing visits: $e');
    return [];
  }
}

String jsonDynamicToString(dynamic jsonData) {
  try {
    // Caso: null
    if (jsonData == null) {
      return 'null';
    }
    // Caso: Map o List
    else if (jsonData is Map<String, dynamic> || jsonData is List<dynamic>) {
      final encoded = jsonEncode(jsonData);
      return encoded;
    }
    // Caso: String — devolvemos el valor tal cual, SIN COMILLAS
    else if (jsonData is String) {
      return jsonData;
    }
    // Caso: otros tipos (num, bool, etc.)
    else {
      final encoded = jsonEncode(jsonData);
      return encoded;
    }
  } catch (e) {
    return 'null';
  }
}

bool isFieldList(
  dynamic jsonData,
  String fieldName,
) {
  if (jsonData is Map<String, dynamic> && jsonData.containsKey(fieldName)) {
    final value = jsonData[fieldName];
    if (value is List && value.isNotEmpty) {
      return true;
    }
  }
  return false;
}

List<String> filterAndFormatGeoReads(List<ReadGeoStruct> reads) {
  // Capturamos “ahora” una sola vez
  final now = DateTime.now();

  // 1) Filtrar ≤ 7 s y fecha no nula
  final recent = reads
      .where((g) =>
          g.dateHourRead != null &&
          !now.isBefore(g.dateHourRead!) && // evita valores futuros
          now.difference(g.dateHourRead!).inSeconds <= 7)
      .toList();

  // 2) Ordenar descendente (más nuevo primero)
  recent.sort((a, b) => b.dateHourRead!.compareTo(a.dateHourRead!));

  // 3) Quedarnos con los 10 primeros
  final limited = recent.take(10);

  // 4) Formatear a texto
  final formatted = limited.map((geo) {
    return 'LAT:${geo.latitude.toStringAsFixed(6)};'
        'LON:${geo.longitude.toStringAsFixed(6)};'
        'ALT:${geo.altitude.toStringAsFixed(2)};'
        'ERH:${geo.errorHorizontal.toStringAsFixed(2)}';
  }).toList();

  // Log opcional
  debugPrint('--- Lecturas recientes (${formatted.length}) ---');
  for (final line in formatted) {
    debugPrint(line);
  }

  return formatted;
}

bool checkIfFieldIsList(
  dynamic jsonData,
  String fieldName,
) {
// Si el json es null, retornar false
  if (jsonData == null) {
    return false;
  }

  // Verificar si el campo existe en el JSON
  if (!jsonData.containsKey(fieldName)) {
    return false;
  }

  // Obtener el valor del campo
  final fieldValue = jsonData[fieldName];

  // Si el valor es null, retornar false
  if (fieldValue == null) {
    return false;
  }

  // Verificar si el valor es una lista
  return fieldValue is List;
}

int countAllSteps(dynamic jsonData) {
  if (jsonData == null || jsonData is! List) return 0;

  int totalSteps = 0;

  for (final activity in jsonData) {
    // 1. Sumar SOLO los activity_status del objeto principal
    final activityStatus = activity['activity_status'];
    if (activityStatus is List) {
      totalSteps += activityStatus.length;
    }

    // 2. Sumar todos los activity_steps (principales + hijos recursivos)
    final activitySteps = activity['activity_steps'];
    if (activitySteps is List) {
      // Lista para procesar los steps (usamos DFS)
      final stepsToProcess = [...activitySteps];

      while (stepsToProcess.isNotEmpty) {
        final currentStep = stepsToProcess.removeLast();
        totalSteps++; // Contar el step actual

        // Agregar hijos para procesar después
        final childSteps = currentStep['activities_steps_childs'];
        if (childSteps is List) {
          stepsToProcess.addAll(childSteps);
        }
      }
    }
  }

  return totalSteps;
}

List<int> extractActivityStepParents(
  List<VisitsDetailsStruct> visitsDetails,
  dynamic jsonData,
) {
  List<int> result = [];

  // Helper function to recursively search for activity status in the JSON structure
  int? findActivityStepParent(dynamic node, int idActivityStatus) {
    if (node is Map) {
      // Check if this node is an activity_status with matching id
      if (node['id_activity_status'] == idActivityStatus) {
        return node['id_activity_step_parent'];
      }

      // Recursively check all values in the map
      for (var value in node.values) {
        var found = findActivityStepParent(value, idActivityStatus);
        if (found != null) return found;
      }
    } else if (node is List) {
      // Recursively check all elements in the list
      for (var element in node) {
        var found = findActivityStepParent(element, idActivityStatus);
        if (found != null) return found;
      }
    }

    return null;
  }

  // Process each visit detail
  for (var visitDetail in visitsDetails) {
    if (visitDetail.idActivityStatus > 0) {
      // Search through the JSON data (could be List or Map)
      var stepParent =
          findActivityStepParent(jsonData, visitDetail.idActivityStatus);
      if (stepParent != null) {
        result.add(stepParent);
      }
    }
  }

  return result;
}

bool idExistsInList(
  List<int> listOfIds,
  int idToFind,
) {
  return listOfIds.contains(idToFind);
}

int dynamicToInt(dynamic value) {
  if (value == null) return 0;

  // Ya es entero
  if (value is int) return value;

  // Double, num u otros numéricos
  if (value is num) return value.toInt();

  // String que contenga dígitos
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    return parsed ?? 0;
  }

  // Cualquier otro tipo no convertible
  return 0;
}

dynamic searchInActivitiesStatus(
  dynamic jsonData,
  String searchString,
) {
  try {
    // Verificar que el JSON no sea nulo y que el searchString no esté vacío
    if (jsonData == null || searchString.isEmpty) {
      return [];
    }

    // Convertir a Map si es necesario
    Map<String, dynamic> data;
    if (jsonData is String) {
      data = json.decode(jsonData);
    } else if (jsonData is Map<String, dynamic>) {
      data = jsonData;
    } else {
      return [];
    }

    // Lista para almacenar los resultados
    List<dynamic> matchingItems = [];

    // Función recursiva para buscar en activities_status
    void searchRecursively(List<dynamic>? activitiesStatusList) {
      if (activitiesStatusList == null) return;

      for (var item in activitiesStatusList) {
        if (item is Map<String, dynamic>) {
          // Verificar si el status_name contiene el string de búsqueda (case insensitive)
          String statusName = item['status_name']?.toString() ?? '';
          if (statusName.toLowerCase().contains(searchString.toLowerCase())) {
            // Agregar el item completo a los resultados
            matchingItems.add(item);
          }

          // Buscar recursivamente en activities_status_childs
          if (item['activities_status_childs'] != null) {
            searchRecursively(item['activities_status_childs']);
          }

          // Buscar en activities_steps_childs si existe
          if (item['activities_steps_childs'] != null) {
            List<dynamic> stepsChilds = item['activities_steps_childs'];
            for (var stepChild in stepsChilds) {
              if (stepChild is Map<String, dynamic> &&
                  stepChild['activities_status'] != null) {
                searchRecursively(stepChild['activities_status']);
              }
            }
          }
        }
      }
    }

    // Iniciar la búsqueda desde el nivel principal
    if (data['activities_status'] != null) {
      searchRecursively(data['activities_status']);
    }

    // Retornar solo el array de coincidencias
    return matchingItems;
  } catch (e) {
    // En caso de error, retornar estructura vacía
    debugPrint('Error en searchInActivitiesStatus: $e');
    return [];
  }
}

dynamic processVisitSummary(
  VisitsStruct visit,
  dynamic activityJson,
) {
  try {
    // Validaciones iniciales
    if (activityJson == null) {
      return {
        'Form': 'Error',
        'DateHour': '',
        'Results': [],
        'error': 'ActivityJson is null'
      };
    }

    // Convertir activityJson a Map si es necesario
    Map<String, dynamic> activity;
    if (activityJson is String) {
      activity = json.decode(activityJson);
    } else if (activityJson is Map<String, dynamic>) {
      activity = activityJson;
    } else {
      debugPrint('ERROR: Invalid activityJson format: ${activityJson.runtimeType}');
      return {
        'Form': 'Error',
        'DateHour': '',
        'Results': [],
        'error': 'Invalid activityJson format'
      };
    }

    // El JSON puede venir como lista o como objeto directo
    Map<String, dynamic> activityData;
    if (activity is List) {
      List<dynamic> activityList = activity as List<dynamic>;
      if (activityList.isEmpty) {
        return {
          'Form': 'Error',
          'DateHour': '',
          'Results': [],
          'error': 'Empty activity list'
        };
      }
      activityData = activityList[0] as Map<String, dynamic>;
    } else {
      // Si no es lista, es directamente el objeto de actividad
      activityData = activity;
    }

    // Crear mapas para acceso rápido
    Map<int, Map<String, dynamic>> statusMap = {};
    Map<int, String> stepMap =
        {}; // NUEVO: Mapa de id_activity_step -> name_step

    // Procesar activity_steps y crear stepMap
    if (activityData['activity_steps'] != null) {
      for (var step in activityData['activity_steps']) {
        int stepId = step['id_activity_step'];
        String stepName = step['name_step'];
        stepMap[stepId] = stepName;

        if (step['activities_status'] != null) {
          for (var status in step['activities_status']) {
            int statusId = status['id_activity_status'];
            statusMap[statusId] = {
              ...status,
              'step_name': stepName,
            };

            // AGREGADO: Procesar activities_steps_childs dentro de cada status
            if (status['activities_steps_childs'] != null) {
              for (var childStep in status['activities_steps_childs']) {
                int childStepId = childStep['id_activity_step'];
                String childStepName = childStep['name_step'];
                stepMap[childStepId] =
                    childStepName; // Agregar childStep al stepMap

                if (childStep['activities_status'] != null) {
                  for (var childStatus in childStep['activities_status']) {
                    int childStatusId = childStatus['id_activity_status'];
                    statusMap[childStatusId] = {
                      ...childStatus,
                      'step_name': childStepName,
                    };
                  }
                }
              }
            }
          }
        }

        if (step['activities_steps_childs'] != null) {
          for (var childStep in step['activities_steps_childs']) {
            int childStepId = childStep['id_activity_step'];
            String childStepName = childStep['name_step'];
            stepMap[childStepId] =
                childStepName; // AGREGADO: Agregar childStep al stepMap

            if (childStep['activities_status'] != null) {
              for (var childStatus in childStep['activities_status']) {
                int childStatusId = childStatus['id_activity_status'];
                statusMap[childStatusId] = {
                  ...childStatus,
                  'step_name': childStepName,
                };
              }
            }
          }
        }
      }
    }

    if (activityData['activity_status'] != null) {
      for (var status in activityData['activity_status']) {
        int statusId = status['id_activity_status'];
        statusMap[statusId] = {
          ...status,
          'step_name': status['status_name'],
        };
      }
    }

    // Procesar los detalles de la visita
    List<Map<String, dynamic>> results = [];

    if (visit.visitsDetails.isNotEmpty) {
      for (var visitDetail in visit.visitsDetails) {
        int activityStatusId = visitDetail.idActivityStatus;
        String response = visitDetail.statusResponse ?? '';
        int stepParentId = visitDetail.idStepParent ?? 0;

        if (response.isNotEmpty && response != '0' && response != 'false') {
          // Determinar stepName según idStepParent
          String stepName;
          if (stepParentId == 0) {
            // Si idStepParent es 0, buscar en activity_status
            stepName = statusMap[activityStatusId]?['status_name'] ?? 'Unknown';
          } else {
            // Usar stepParentId para obtener el step_name correcto
            stepName = stepMap[stepParentId] ?? 'Unknown';
          }

          // Obtener statusName del statusMap o usar response directamente
          String statusName = response;
          if (statusMap.containsKey(activityStatusId)) {
            var statusInfo = statusMap[activityStatusId];
            if (statusInfo?['type_status'] != 'number') {
              statusName = statusInfo?['status_name'] ?? response;
            }
          }

          results.add({
            'NameOption': stepName,
            'ValueOption': statusName,
          });
        }
      }
    }

    // Crear el JSON final con el nuevo formato
    Map<String, dynamic> finalResult = {
      'Form': activityData['name_activity'] ?? 'Unknown',
      'DateHour': '', // Se llenará abajo si existe la fecha
      'Results': results, // Siempre incluir Results, aunque sea vacío
    };

    if (visit.createdAt != null) {
      DateTime dateTime = visit.createdAt!;

      // Formatear fecha de manera legible
      List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];

      String day = dateTime.day.toString();
      String month = months[dateTime.month - 1];
      String year = dateTime.year.toString();

      int hour = dateTime.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;

      String minute = dateTime.minute.toString().padLeft(2, '0');

      finalResult['DateHour'] = '$month $day, $year $hour:$minute $period';
    }

    return finalResult;
  } catch (e) {
    return {
      'Form': 'Error',
      'DateHour': '',
      'Results': [],
      'error': 'Error processing visit summary: ${e.toString()}',
      'visit_id': visit.idVisit.toString() ?? 'unknown',
    };
  }
}

dynamic processMultipleVisitsSummary(
  List<VisitsStruct> visits,
  dynamic activityJson,
) {
  try {
    // Validaciones iniciales
    if (visits.isEmpty) {
      dynamic errorResult = {
        'Form': 'Error',
        'DateHour': '',
        'Results': [],
        'error': 'Visits list is null or empty'
      };

      return errorResult;
    }

    if (activityJson == null) {
      dynamic errorResult = {
        'Form': 'Error',
        'DateHour': '',
        'Results': [],
        'error': 'ActivityJson is null'
      };

      return errorResult;
    }

    // Convertir activityJson a Map si es necesario
    Map<String, dynamic> activity;
    if (activityJson is String) {
      activity = json.decode(activityJson);
    } else if (activityJson is Map<String, dynamic>) {
      activity = activityJson;
    } else {
      dynamic errorResult = {
        'Form': 'Error',
        'DateHour': '',
        'Results': [],
        'error': 'Invalid activityJson format'
      };

      return errorResult;
    }

    // El JSON puede venir como lista o como objeto directo
    Map<String, dynamic> activityData;
    if (activity is List) {
      List<dynamic> activityList = activity as List<dynamic>;
      if (activityList.isEmpty) {
        dynamic errorResult = {
          'Form': 'Error',
          'DateHour': '',
          'Results': [],
          'error': 'Empty activity list'
        };

        return errorResult;
      }
      activityData = activityList[0] as Map<String, dynamic>;
    } else {
      activityData = activity;
    }

    // Crear mapas para acceso rápido
    Map<int, Map<String, dynamic>> statusMap = {};
    Map<int, String> stepMap =
        {}; // NUEVO: Mapa de id_activity_step -> name_step

    // Procesar activity_steps y crear stepMap
    if (activityData['activity_steps'] != null) {
      for (var step in activityData['activity_steps']) {
        int stepId = step['id_activity_step'];
        String stepName = step['name_step'];
        stepMap[stepId] = stepName;

        if (step['activities_status'] != null) {
          for (var status in step['activities_status']) {
            int statusId = status['id_activity_status'];
            statusMap[statusId] = {
              ...status,
              'step_name': stepName,
            };

            // AGREGADO: Procesar activities_steps_childs dentro de cada status
            if (status['activities_steps_childs'] != null) {
              for (var childStep in status['activities_steps_childs']) {
                int childStepId = childStep['id_activity_step'];
                String childStepName = childStep['name_step'];
                stepMap[childStepId] =
                    childStepName; // Agregar childStep al stepMap

                if (childStep['activities_status'] != null) {
                  for (var childStatus in childStep['activities_status']) {
                    int childStatusId = childStatus['id_activity_status'];
                    statusMap[childStatusId] = {
                      ...childStatus,
                      'step_name': childStepName,
                    };
                  }
                }
              }
            }
          }
        }

        if (step['activities_steps_childs'] != null) {
          for (var childStep in step['activities_steps_childs']) {
            int childStepId = childStep['id_activity_step'];
            String childStepName = childStep['name_step'];
            stepMap[childStepId] =
                childStepName; // AGREGADO: Agregar childStep al stepMap

            if (childStep['activities_status'] != null) {
              for (var childStatus in childStep['activities_status']) {
                int childStatusId = childStatus['id_activity_status'];
                statusMap[childStatusId] = {
                  ...childStatus,
                  'step_name': childStepName,
                };
              }
            }
          }
        }
      }
    }

    if (activityData['activity_status'] != null) {
      for (var status in activityData['activity_status']) {
        int statusId = status['id_activity_status'];
        statusMap[statusId] = {
          ...status,
          'step_name': status['status_name'],
        };
      }
    }

    // Encontrar fecha más reciente
    DateTime? mostRecentDate;
    for (var visit in visits) {
      if (visit.createdAt != null) {
        if (mostRecentDate == null ||
            visit.createdAt!.isAfter(mostRecentDate)) {
          mostRecentDate = visit.createdAt;
        }
      }
    }

    String dateHour = '';
    if (mostRecentDate != null) {
      List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];

      String day = mostRecentDate.day.toString();
      String month = months[mostRecentDate.month - 1];
      String year = mostRecentDate.year.toString();

      int hour = mostRecentDate.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;

      String minute = mostRecentDate.minute.toString().padLeft(2, '0');
      dateHour = '$month $day, $year $hour:$minute $period';
    }

    // Verificar si es actividad especial 222 (Cargue de RFF)
    int activityId = activityData['id_activity'] ?? 0;

    if (activityId == 222) {
      // PROCESAMIENTO ESPECIAL PARA ACTIVIDAD 222 - MODIFICADO PARA AGRUPAR POR CAJA
      // NUEVA ESTRATEGIA: Primero recopilar TODA la información, luego crear tripletes
      String? globalRecolector;
      String? globalCortero;
      Map<String, int> totalRacimosPorCaja = {};
      Map<String, int> totalTusaPorCaja = {};
      Map<String, Set<String>> lotesPorCaja = {};
      Set<String> todasLasCajas = {};

      // PRIMERA PASADA: Recopilar toda la información
      for (int visitIndex = 0; visitIndex < visits.length; visitIndex++) {
        var visit = visits[visitIndex];
        debugPrint('=== PRIMERA PASADA - Visit $visitIndex ===');

        if (visit.visitsDetails.isNotEmpty) {
          for (int detailIndex = 0;
              detailIndex < visit.visitsDetails.length;
              detailIndex++) {
            var visitDetail = visit.visitsDetails[detailIndex];

            int activityStatusId = visitDetail.idActivityStatus;
            String response = visitDetail.statusResponse ?? '';
            int stepParentId = visitDetail.idStepParent ?? 0;

            debugPrint(
                '  Detail $detailIndex: StatusID=$activityStatusId, Response="$response", StepParent=$stepParentId');

            if (response.isNotEmpty && response != '0' && response != 'false') {
              // Determinar stepName según idStepParent
              String stepName;
              if (stepParentId == 0) {
                stepName =
                    statusMap[activityStatusId]?['status_name'] ?? 'Unknown';
                debugPrint(
                    '    Usando activity_status: stepName="$stepName" (idStepParent=0)');
              } else {
                stepName = stepMap[stepParentId] ?? 'Unknown';
                debugPrint(
                    '    Usando stepMap: stepName="$stepName" (idStepParent=$stepParentId)');
              }

              // Obtener statusName del statusMap o usar response directamente
              String statusName = response;
              if (statusMap.containsKey(activityStatusId)) {
                var statusInfo = statusMap[activityStatusId];
                if (statusInfo?['type_status'] != 'number') {
                  statusName = statusInfo?['status_name'] ?? response;
                }
              }

              debugPrint(
                  '    Resultado final: stepName="$stepName", statusName="$statusName"');

              // Identificar el tipo de información usando el stepName correcto
              switch (stepName) {
                case 'Recolector':
                  globalRecolector = statusName;
                  debugPrint('    → Recolector GLOBAL asignado: $globalRecolector');
                  break;
                case 'Cortero':
                  globalCortero = statusName;
                  debugPrint('    → Cortero GLOBAL asignado: $globalCortero');
                  break;
                case 'Lista de cajas':
                  todasLasCajas.add(statusName);
                  debugPrint('    → Caja GLOBAL agregada: $statusName');
                  break;
                default:
                  // Para lotes (Lotes Araki, Lotes Palmeiras, etc.)
                  if (stepName.contains('Lotes')) {
                    // Necesitamos asociar el lote con alguna caja, por ahora lo guardamos para todas
                    debugPrint('    → Lote GLOBAL agregado: $statusName');
                  }
                  break;
              }
            }
          }
        }
      }

      debugPrint('=== INFORMACIÓN GLOBAL RECOPILADA ===');
      debugPrint('Recolector global: $globalRecolector');
      debugPrint('Cortero global: $globalCortero');
      debugPrint('Todas las cajas: ${todasLasCajas.toList()}');

      // SEGUNDA PASADA: Procesar racimos, tusa y lotes por caja
      for (int visitIndex = 0; visitIndex < visits.length; visitIndex++) {
        var visit = visits[visitIndex];
        debugPrint('=== SEGUNDA PASADA - Visit $visitIndex ===');

        if (visit.visitsDetails.isNotEmpty) {
          String? cajaActual;
          int racimosVisita = 0;
          int tusaVisita = 0;
          Set<String> lotesVisita = {};

          // Primero, identificar la caja de esta visita
          for (var visitDetail in visit.visitsDetails) {
            int activityStatusId = visitDetail.idActivityStatus;
            String response = visitDetail.statusResponse ?? '';
            int stepParentId = visitDetail.idStepParent ?? 0;

            if (response.isNotEmpty && response != '0' && response != 'false') {
              String stepName;
              if (stepParentId == 0) {
                stepName =
                    statusMap[activityStatusId]?['status_name'] ?? 'Unknown';
              } else {
                stepName = stepMap[stepParentId] ?? 'Unknown';
              }

              String statusName = response;
              if (statusMap.containsKey(activityStatusId)) {
                var statusInfo = statusMap[activityStatusId];
                if (statusInfo?['type_status'] != 'number') {
                  statusName = statusInfo?['status_name'] ?? response;
                }
              }

              if (stepName == 'Lista de cajas') {
                cajaActual = statusName;
                debugPrint('  → Caja actual identificada: $cajaActual');
                break;
              }
            }
          }

          // Luego, recopilar racimos, tusa y lotes para esta caja
          for (var visitDetail in visit.visitsDetails) {
            int activityStatusId = visitDetail.idActivityStatus;
            String response = visitDetail.statusResponse ?? '';
            int stepParentId = visitDetail.idStepParent ?? 0;

            if (response.isNotEmpty && response != '0' && response != 'false') {
              String stepName;
              if (stepParentId == 0) {
                stepName =
                    statusMap[activityStatusId]?['status_name'] ?? 'Unknown';
              } else {
                stepName = stepMap[stepParentId] ?? 'Unknown';
              }

              switch (stepName) {
                case 'Número de racimos':
                  racimosVisita = int.tryParse(response) ?? 0;
                  debugPrint('  → Racimos para esta visita: $racimosVisita');
                  break;
                case 'Tusa':
                  tusaVisita = int.tryParse(response) ?? 0;
                  debugPrint('  → Tusa para esta visita: $tusaVisita');
                  break;
                default:
                  if (stepName.contains('Lotes')) {
                    String statusName = response;
                    if (statusMap.containsKey(activityStatusId)) {
                      var statusInfo = statusMap[activityStatusId];
                      if (statusInfo?['type_status'] != 'number') {
                        statusName = statusInfo?['status_name'] ?? response;
                      }
                    }
                    lotesVisita.add(statusName);
                    debugPrint('  → Lote para esta visita: $statusName');
                  }
                  break;
              }
            }
          }

          // Asignar los valores a la caja correspondiente
          if (cajaActual != null && cajaActual.isNotEmpty) {
            totalRacimosPorCaja[cajaActual] =
                (totalRacimosPorCaja[cajaActual] ?? 0) + racimosVisita;
            totalTusaPorCaja[cajaActual] =
                (totalTusaPorCaja[cajaActual] ?? 0) + tusaVisita;

            if (!lotesPorCaja.containsKey(cajaActual)) {
              lotesPorCaja[cajaActual] = <String>{};
            }
            lotesPorCaja[cajaActual]!.addAll(lotesVisita);

            debugPrint(
                '  → Asignado a caja "$cajaActual": Racimos=$racimosVisita, Tusa=$tusaVisita, Lotes=${lotesVisita.toList()}');
          } else if ((racimosVisita > 0 ||
                  tusaVisita > 0 ||
                  lotesVisita.isNotEmpty) &&
              todasLasCajas.isNotEmpty) {
            // Si hay datos pero no hay caja específica, distribuir entre todas las cajas
            debugPrint(
                '  → No hay caja específica, distribuyendo entre todas las cajas');
            for (String caja in todasLasCajas) {
              totalRacimosPorCaja[caja] = (totalRacimosPorCaja[caja] ?? 0) +
                  (racimosVisita ~/ todasLasCajas.length);
              totalTusaPorCaja[caja] = (totalTusaPorCaja[caja] ?? 0) +
                  (tusaVisita ~/ todasLasCajas.length);

              if (!lotesPorCaja.containsKey(caja)) {
                lotesPorCaja[caja] = <String>{};
              }
              lotesPorCaja[caja]!.addAll(lotesVisita);
            }
          }
        }
      }

      debugPrint('=== TOTALES POR CAJA ===');
      debugPrint('Racimos por caja: $totalRacimosPorCaja');
      debugPrint('Tusa por caja: $totalTusaPorCaja');
      debugPrint('Lotes por caja: $lotesPorCaja');

      // CREAR TRIPLETES FINALES
      Map<String, Map<String, dynamic>> tripletSummary = {};

      if (globalRecolector != null &&
          globalRecolector.isNotEmpty &&
          globalCortero != null &&
          globalCortero.isNotEmpty) {
        if (todasLasCajas.isNotEmpty) {
          for (String caja in todasLasCajas) {
            String tripletKey = '$globalRecolector|$globalCortero|$caja';

            tripletSummary[tripletKey] = {
              'Recolector': globalRecolector,
              'Cortero': globalCortero,
              'Caja': caja,
              'TotalRacimos': totalRacimosPorCaja[caja] ?? 0,
              'TotalTusa': totalTusaPorCaja[caja] ?? 0,
              'Lotes': lotesPorCaja[caja] ?? <String>{},
            };

            debugPrint('→ Triplete creado: $tripletKey');
            debugPrint('  Racimos: ${totalRacimosPorCaja[caja] ?? 0}');
            debugPrint('  Tusa: ${totalTusaPorCaja[caja] ?? 0}');
            debugPrint('  Lotes: ${(lotesPorCaja[caja] ?? <String>{}).toList()}');
          }
        } else {
          // Sin cajas específicas
          String tripletKey = '$globalRecolector|$globalCortero|Sin Caja';
          int totalRacimos =
              totalRacimosPorCaja.values.fold(0, (sum, val) => sum + val);
          int totalTusaGlobal =
              totalTusaPorCaja.values.fold(0, (sum, val) => sum + val);
          Set<String> todosLosLotes = <String>{};
          for (var lotes in lotesPorCaja.values) {
            todosLosLotes.addAll(lotes);
          }

          tripletSummary[tripletKey] = {
            'Recolector': globalRecolector,
            'Cortero': globalCortero,
            'Caja': 'Sin Caja',
            'TotalRacimos': totalRacimos,
            'TotalTusa': totalTusaGlobal,
            'Lotes': todosLosLotes,
          };

          debugPrint('→ Triplete creado (sin cajas): $tripletKey');
        }
      }

      debugPrint('TripletSummary final: ${tripletSummary.keys.toList()}');
      debugPrint('=== FIN PROCESAMIENTO ACTIVIDAD 222 - AGRUPADO POR CAJA ===\n');

      // Convertir a formato final para actividad 222 con agrupación por caja
      List<Map<String, dynamic>> tripletResults = [];

      debugPrint('=== CONVIRTIENDO TRIPLET SUMMARY A RESULTADO FINAL ===');
      debugPrint('Número de tripletes procesados: ${tripletSummary.length}');

      tripletSummary.forEach((tripletKey, data) {
        debugPrint('Procesando triplete: $tripletKey');
        debugPrint('  - Recolector: ${data['Recolector']}');
        debugPrint('  - Cortero: ${data['Cortero']}');
        debugPrint('  - Caja: ${data['Caja']}');
        debugPrint('  - TotalRacimos: ${data['TotalRacimos']}');
        debugPrint('  - TotalTusa: ${data['TotalTusa']}');
        debugPrint('  - Lotes: ${(data['Lotes'] as Set<String>).toList()}');

        tripletResults.add({
          'Recolector': data['Recolector'],
          'Cortero': data['Cortero'],
          'Caja': data['Caja'], // Nueva propiedad en el resultado
          'TotalRacimos': data['TotalRacimos'],
          'TotalTusa': data['TotalTusa'],
          'Lotes': (data['Lotes'] as Set<String>).toList().join(', '),
        });
      });

      debugPrint('Resultado final antes de ordenar:');
      for (int i = 0; i < tripletResults.length; i++) {
        debugPrint('  [$i]: ${tripletResults[i]}');
      }

      // Ordenar por total de racimos descendente, luego por recolector, cortero y caja
      tripletResults.sort((a, b) {
        int racimosComparison = b['TotalRacimos'].compareTo(a['TotalRacimos']);
        if (racimosComparison != 0) return racimosComparison;

        int recolectorComparison = a['Recolector'].compareTo(b['Recolector']);
        if (recolectorComparison != 0) return recolectorComparison;

        int corteroComparison = a['Cortero'].compareTo(b['Cortero']);
        if (corteroComparison != 0) return corteroComparison;

        return a['Caja'].compareTo(b['Caja']);
      });

      dynamic result = {
        'Form': activityData['name_activity'] ?? 'Unknown',
        'DateHour': dateHour,
        'WorkersPairsSummary':
            tripletResults, // Ahora contiene agrupación por caja
      };

      // PRINT DEBUG - Resultado final para actividad 222 con agrupación por caja
      debugPrint('=== RESULTADO FINAL - ACTIVIDAD 222 CON AGRUPACIÓN POR CAJA ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(result));

      return result;
    } else {
      // PROCESAMIENTO NORMAL PARA OTRAS ACTIVIDADES
      Map<String, Map<String, int>> aggregatedData = {};

      for (var visit in visits) {
        if (visit.visitsDetails.isNotEmpty) {
          for (var visitDetail in visit.visitsDetails) {
            int activityStatusId = visitDetail.idActivityStatus;
            String response = visitDetail.statusResponse ?? '';

            if (statusMap.containsKey(activityStatusId)) {
              var statusInfo = statusMap[activityStatusId];
              String stepName = statusInfo?['step_name'] ?? 'Unknown';

              if (response.isNotEmpty &&
                  response != '0' &&
                  response != 'false') {
                String valueOption;

                if (statusInfo?['type_status'] == 'number') {
                  valueOption = response;
                } else {
                  valueOption = statusInfo?['status_name'] ?? response;
                }

                if (!aggregatedData.containsKey(stepName)) {
                  aggregatedData[stepName] = {};
                }

                if (!aggregatedData[stepName]!.containsKey(valueOption)) {
                  aggregatedData[stepName]![valueOption] = 0;
                }

                aggregatedData[stepName]![valueOption] =
                    aggregatedData[stepName]![valueOption]! + 1;
              }
            }
          }
        }
      }

      // Convertir los datos agregados al formato requerido
      List<Map<String, dynamic>> results = [];

      aggregatedData.forEach((stepName, options) {
        List<Map<String, dynamic>> valuesOptions = [];

        options.forEach((option, amount) {
          valuesOptions.add({
            'Option': option,
            'Amount': amount,
          });
        });

        valuesOptions.sort((a, b) => b['Amount'].compareTo(a['Amount']));

        results.add({
          'NameOption': stepName,
          'ValuesOptions': valuesOptions,
        });
      });

      dynamic result = {
        'Form': activityData['name_activity'] ?? 'Unknown',
        'DateHour': dateHour,
        'Results': results,
      };

      // PRINT DEBUG - Resultado final para actividades normales
      debugPrint('=== RESULTADO FINAL - ACTIVIDAD NORMAL ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(result));

      return result;
    }
  } catch (e) {
    dynamic errorResult = {
      'Form': 'Error',
      'DateHour': '',
      'Results': [],
      'error': 'Error processing multiple visits summary: ${e.toString()}',
    };

    // PRINT DEBUG - Error general
    debugPrint('=== ERROR GENERAL ===');
    debugPrint(const JsonEncoder.withIndent('  ').convert(errorResult));

    return errorResult;
  }
}

bool searchInVisitsDetails(
  List<VisitsDetailsStruct> visitsList,
  int searchValue,
  String searchType,
) {
  // Validar que la lista no esté vacía
  if (visitsList.isEmpty) {
    return false;
  }

  // Normalizar el string para comparación (convertir a mayúsculas)
  String normalizedSearchType = searchType.toUpperCase();

  // Iterar sobre la lista de VisitsDetailsStruct
  for (VisitsDetailsStruct visit in visitsList) {
    if (normalizedSearchType == "STEP") {
      // Buscar en el campo idStepParent
      if (visit.idStepParent == searchValue) {
        return true;
      }
    } else if (normalizedSearchType == "STATUS") {
      // Buscar en el campo idActivityStatus
      if (visit.idActivityStatus == searchValue) {
        return true;
      }
    }
  }

  // Si no se encontró el valor en ningún elemento
  return false;
}

List<VisitsDetailsStruct> removeVisits(List<VisitsDetailsStruct> visitsList) {
  // Verifica si la lista no es nula y no está vacía
  if (visitsList.isEmpty) {
    return [];
  }

  // Filtra manteniendo solo los elementos con rememberStatus = true
  // Esto aplica para TODOS los tipos, incluyendo tag-reader, tag-writer y tag-transfer
  return visitsList.where((visit) {
    // Mantener solo si rememberStatus = true
    return visit.hasRememberStatus() && visit.rememberStatus == true;
  }).toList();
}

bool jsonDynamicToBool(dynamic value) {
  if (value == null) return false;

  // 1) Si ya es bool, lo retornamos tal cual.
  if (value is bool) return value;

  // 2) Si es String, normalizamos y comprobamos valores típicos.
  if (value is String) {
    final v = value.trim().toLowerCase();
    const trueSet = {'true', '1', 'yes', 'y', 'on', 'verdadero', 'si'};
    const falseSet = {'false', '0', 'no', 'n', 'off', 'falso'};
    if (trueSet.contains(v)) return true;
    if (falseSet.contains(v)) return false;
    // Cualquier otro string → conversión fallida
    return false;
  }

  // 3) Si es num, consideramos 1 → true, 0 → false
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
    // Cualquier otro número → conversión fallida
    return false;
  }

  // 4) Cualquier otro tipo → conversión fallida
  return false;
}

String statusResponseByActivityStatusAlternative(
  int activityStatusId,
  List<VisitsDetailsStruct> visitsDetails,
  int idStepParent,
) {
  if (idStepParent == 0) {
    // Buscar solo por activityStatusId
    for (final v in visitsDetails) {
      if (v.idActivityStatus == activityStatusId) {
        return v.statusResponse;
      }
    }
  } else {
    // Buscar por ambos: activityStatusId Y idStepParent
    for (final v in visitsDetails) {
      if (v.idActivityStatus == activityStatusId &&
          v.idStepParent == idStepParent) {
        return v.statusResponse;
      }
    }
  }

  return '';
}

dynamic insertActivityStep(
  dynamic jsonData,
  dynamic newStep,
  int targetId,
) {
  debugPrint("🔍ENTRANDO A NUEVA FUNCION");
  try {
    // Convertir a Map si es necesario
    Map<String, dynamic> data;
    if (jsonData is String) {
      data = Map<String, dynamic>.from(json.decode(jsonData));
    } else if (jsonData is Map) {
      data = Map<String, dynamic>.from(jsonData);
    } else {
      // Si el tipo no es reconocido, devolver el original
      return jsonData;
    }

    debugPrint("🔍Convertir a Map si es necesario");

    debugPrint(newStep);
    // Convertir newStep a Map si es necesario
    Map<String, dynamic> newStepData;
    if (newStep is String) {
      newStepData = Map<String, dynamic>.from(json.decode(newStep));
    } else if (newStep is Map) {
      newStepData = Map<String, dynamic>.from(newStep);
    } else {
      // Si el tipo no es reconocido, devolver el original
      debugPrint("Si el tipo no es reconocido, devolver el original 2");
      return jsonData;
    }

    debugPrint("Verificar que existe el campo activity_steps");
    // Verificar que existe el campo activity_steps
    if (!data.containsKey('activity_steps')) {
      // Si no existe, crear el array con el nuevo elemento
      data['activity_steps'] = [newStepData];
      return data;
    }

    // Obtener el array de activity_steps
    List<dynamic> activitySteps = List.from(data['activity_steps'] ?? []);

    debugPrint("Obtener el array de activity_steps");

    // NUEVO: Verificar si existe un elemento con el mismo customParent
    // y eliminarlo antes de insertar el nuevo
    debugPrint(newStepData['customParent']);
    if (newStepData.containsKey('customParent') &&
        newStepData['customParent'] != null) {
      activitySteps.removeWhere((step) {
        if (step is Map && step.containsKey('customParent')) {
          bool shouldRemove =
              step['customParent'] == newStepData['customParent'];
          if (shouldRemove) {
            debugPrint(
                "⚠️ Eliminando elemento existente con customParent: ${step['customParent']}");
          }
          return shouldRemove;
        }
        return false;
      });
    }

    // Buscar el índice del elemento con el id_activity_step especificado
    int targetIndex = -1;
    for (int i = 0; i < activitySteps.length; i++) {
      // Verificar que el elemento tiene id_activity_step
      if (activitySteps[i] is Map &&
          activitySteps[i].containsKey('id_activity_step')) {
        // Comparar como entero
        if (activitySteps[i]['id_activity_step'] == targetId) {
          targetIndex = i;
          break;
        }
      }
    }

    debugPrint('$targetIndex');

    // Si se encontró el elemento, insertar después de él
    if (targetIndex != -1) {
      // Insertar en la posición siguiente al elemento encontrado
      newStepData["customParent"] = targetId;
      activitySteps.insert(targetIndex + 1, newStepData);
    } else {
      // Si no se encontró, agregar al final del array
      activitySteps.add(newStepData);
    }

    debugPrint("Actualizar el array en el objeto principal");
    // Actualizar el array en el objeto principal
    data['activity_steps'] = activitySteps;

    // Devolver el Map actualizado
    debugPrint(data.toString());
    return data;
  } catch (e) {
    // En caso de error, devolver el JSON original
    debugPrint('Error al insertar activity step: $e');
    return jsonData;
  }
}

List<VisitsDetailsStruct> updateStepsVisitList(
  List<VisitsDetailsStruct> visitsList,
  int idStepParent,
  dynamic jsonData,
) {
  // Evitar NPE: la lista no es nullable por firma en FF
  if (visitsList.isEmpty) {
    return visitsList;
  }
  debugPrint("Variables");
  debugPrint('$idStepParent');
  debugPrint('${visitsList.length}');

  // Parseo robusto de jsonData -> Map<String,dynamic>
  Map<String, dynamic> data;
  if (jsonData is String) {
    try {
      final decoded = json.decode(jsonData);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else {
        return visitsList;
      }
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return visitsList;
    }
  } else if (jsonData is Map) {
    data = Map<String, dynamic>.from(jsonData);
  } else {
    return visitsList;
  }

  // Helpers de tipo
  List<dynamic>? asList(dynamic v) => (v is List) ? v : null;
  Map<String, dynamic>? asMap(dynamic v) =>
      (v is Map) ? Map<String, dynamic>.from(v) : null;

  // Buscar un status por ID recorriendo TODAS las ramas (statuses y steps)
  Map<String, dynamic>? findActivityStatusById(int targetId) {
    final statusStack = <Map<String, dynamic>>[];
    final stepStack = <Map<String, dynamic>>[];

    // Cargar top-level
    final topStatuses = asList(data['activity_status']);
    if (topStatuses != null) {
      for (final s in topStatuses) {
        final m = asMap(s);
        if (m != null) statusStack.add(m);
      }
    }
    final rootSteps = asList(data['activity_steps']);
    if (rootSteps != null) {
      for (final st in rootSteps) {
        final m = asMap(st);
        if (m != null) stepStack.add(m);
      }
    }

    // DFS iterativo mezclando statuses y steps
    while (statusStack.isNotEmpty || stepStack.isNotEmpty) {
      while (statusStack.isNotEmpty) {
        final status = statusStack.removeLast();

        if (status['id_activity_status'] == targetId) {
          return status;
        }

        // Profundizar en hijos
        final statusChilds = asList(status['activities_status_childs']);
        if (statusChilds != null) {
          for (final sc in statusChilds) {
            final m = asMap(sc);
            if (m != null) statusStack.add(m);
          }
        }
        final stepsChilds = asList(status['activities_steps_childs']);
        if (stepsChilds != null) {
          for (final st in stepsChilds) {
            final m = asMap(st);
            if (m != null) stepStack.add(m);
          }
        }
      }

      if (stepStack.isNotEmpty) {
        final step = stepStack.removeLast();
        final statuses = asList(step['activities_status']);
        if (statuses != null) {
          for (final s in statuses) {
            final m = asMap(s);
            if (m != null) statusStack.add(m);
          }
        }
      }
    }
    return null;
  }

  // Buscar el parent_id de un activity_step dado su id recorriendo todas las ramas
  int? findParentIdActivityStep(int targetIdActivityStep) {
    final statusStack = <Map<String, dynamic>>[];
    final stepStack = <Map<String, dynamic>>[];

    // Cargar raíces
    final rootSteps = asList(data['activity_steps']);
    if (rootSteps != null) {
      for (final st in rootSteps) {
        final m = asMap(st);
        if (m != null) stepStack.add(m);
      }
    }

    if (targetIdActivityStep == 54) debugPrint("ACAAA 54 #1");
    if (targetIdActivityStep == 54) debugPrint('${stepStack.length}');

    while (statusStack.isNotEmpty || stepStack.isNotEmpty) {
      // Procesar steps
      while (stepStack.isNotEmpty) {
        final step = stepStack.removeLast();

        // ¿Es el que buscamos?
        if (targetIdActivityStep == 54) debugPrint('${step['id_activity_step']}');

        if (step['id_activity_step'] == targetIdActivityStep) {
          final parentStatusId = step['id_activity_status_parent'];
          if (parentStatusId != null) {
            final parentStatus = findActivityStatusById(parentStatusId);
            if (parentStatus != null &&
                parentStatus.containsKey('id_activity_step_parent')) {
              final v = parentStatus['id_activity_step_parent'];
              if (v is int) return v;
              // Por si viene como numérico no-int
              if (v is num) return v.toInt();
            }
          }
          return null; // existe el step pero sin padre conocido
        }

        // Añadir sus statuses para seguir bajando
        final statuses = asList(step['activities_status']);
        if (statuses != null) {
          for (final s in statuses) {
            final m = asMap(s);
            if (m != null) {
              if (targetIdActivityStep == 54) debugPrint('${statuses.length}');
              statusStack.add(m);
            }
          }
        }
      }

      // Procesar statuses
      if (statusStack.isNotEmpty) {
        final status = statusStack.removeLast();

        // Sus steps hijos
        final stepsChilds = asList(status['activities_steps_childs']);
        //if(step['id_activity_step'] == 52) debugPrint(statuses.length);

        if (stepsChilds != null) {
          for (final st in stepsChilds) {
            final m = asMap(st);

            if (m != null) {
              if (m['id_activity_step'] == 54) debugPrint("ACAAA 54");
              stepStack.add(m);
            }
          }
        }
        // Y sus statuses hijos
        final statusChilds = asList(status['activities_status_childs']);
        if (statusChilds != null) {
          for (final sc in statusChilds) {
            final m = asMap(sc);
            if (m != null) statusStack.add(m);
          }
        }
      }
    }
    return null;
  }

  // Copia defensiva para no mutar la lista original
  final updatedList = List<VisitsDetailsStruct>.from(visitsList);

  // Eliminar visits cuyo parent_id_activity_step == idStepParent
  updatedList.removeWhere((visit) {
    final int visitIdParent = visit.idStepParent;
    debugPrint("visitIdParent");
    debugPrint('$visitIdParent');

    if (visitIdParent == 0) return false;

    final int? foundParentId = findParentIdActivityStep(visitIdParent);
    debugPrint("foundParentId");

    debugPrint('$foundParentId');

    if (foundParentId != null && foundParentId == idStepParent) {
      debugPrint(
        'Eliminando visit con idParent: $visitIdParent porque su parent_id ($foundParentId) coincide con $idStepParent',
      );
      return true;
    }
    return false;
  });

  debugPrint('${updatedList.length}');

  debugPrint("Visit Detail");

  for (int i = 0; i < updatedList.length; i++) {
    var visit = visitsList[i];
    debugPrint(visit.toString());
  }
  return updatedList;
}

String? showCurrentStatus(
  List<VisitsDetailsStruct> visitsList,
  int? stepId,
) {
  for (int i = 0; i < visitsList.length; i++) {
    var visit = visitsList[i];
    if (visit.idStepParent == stepId) {
      // Devolver el nombre del status (statusOption), no la respuesta (statusResponse)
      // statusOption contiene el nombre legible como "Lote A", "Opción 1", etc.
      // statusResponse contiene valores como "true", "false", números, etc.
      return visit.statusOption ?? visit.statusResponse;
    }
  }
  return "N/A";
}

bool validateRequiredSteps(
  dynamic jsonData,
  List<VisitsDetailsStruct> visitsList,
) {
  // Validar inputs
  if (jsonData == null) {
    debugPrint('Error: Inputs nulos');
    return false;
  }

  // Convertir JSON si es necesario
  Map<String, dynamic> data;
  if (jsonData is String) {
    try {
      data = Map<String, dynamic>.from(json.decode(jsonData));
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return false;
    }
  } else if (jsonData is Map) {
    data = Map<String, dynamic>.from(jsonData);
  } else {
    debugPrint('Error: Tipo de datos no reconocido');
    return false;
  }

  // Listas para almacenar IDs requeridos
  List<int> requiredStepIds = [];
  List<int> requiredStatusIds = [];
  List<int> missingStepIds = [];
  List<int> missingStatusIds = [];

  // Verificar si hay activity_status en el primer nivel
  if (data.containsKey('activity_status')) {
    List<dynamic> activityStatusList = data['activity_status'];

    // Buscar activity_status requeridos (primer nivel solamente)
    for (var status in activityStatusList) {
      if (status is! Map<String, dynamic>) continue;

      // Por defecto, considerar todos los activity_status del primer nivel como requeridos
      // o puedes agregar una condición específica si existe un campo is_required
      if (status.containsKey('id_activity_status')) {
        int statusId = status['id_activity_status'];
        requiredStatusIds.add(statusId);
        debugPrint(
            'Activity_status encontrado (primer nivel): ID=$statusId, Nombre=${status['status_name'] ?? 'Sin nombre'}');
      }
    }
  }

  // Verificar que existe activity_steps
  if (data.containsKey('activity_steps')) {
    List<dynamic> activitySteps = data['activity_steps'];

    // Función recursiva para buscar todos los activity_steps requeridos
    void findRequiredSteps(List<dynamic>? steps) {
      if (steps == null) return;

      for (var step in steps) {
        if (step is! Map<String, dynamic>) continue;

        // Verificar si es requerido
        if (step.containsKey('is_required') &&
            step['is_required'] == true &&
            step.containsKey('id_activity_step')) {
          int stepId = step['id_activity_step'];
          requiredStepIds.add(stepId);
          debugPrint(
              'Step requerido encontrado: ID=$stepId, Nombre=${step['name_step'] ?? 'Sin nombre'}');
        }

        // Buscar en activities_status para encontrar más steps anidados
        // if (step.containsKey('activities_status')) {
        //   List<dynamic>? statusList = step['activities_status'];
        //   if (statusList != null) {
        //     for (var status in statusList) {
        //       if (status is Map<String, dynamic> &&
        //           status.containsKey('activities_steps_childs')) {
        //         // Buscar recursivamente en activities_steps_childs
        //         findRequiredSteps(status['activities_steps_childs']);
        //       }
        //     }
        //   }
        // }
      }
    }

    // Buscar todos los steps requeridos en el JSON
    findRequiredSteps(activitySteps);
  }

  // Si no hay nada requerido, retornar true
  if (requiredStepIds.isEmpty && requiredStatusIds.isEmpty) {
    debugPrint('No hay steps ni status requeridos');
    return true;
  }

  debugPrint('Total de steps requeridos: ${requiredStepIds.length}');
  debugPrint('IDs de steps requeridos: $requiredStepIds');
  debugPrint('Total de status requeridos: ${requiredStatusIds.length}');
  debugPrint('IDs de status requeridos: $requiredStatusIds');

  // Verificar cada elemento en la lista de visits
  for (var visit in visitsList) {
    // Si idStepParent es 0, buscar en activity_status
    if (visit.idStepParent == 0) {
      // Buscar por idActivityStatus en lugar de idStepParent
      if (visit.idActivityStatus != 0) {
        // Remover de la lista de status requeridos si existe
        requiredStatusIds.remove(visit.idActivityStatus);
        debugPrint(
            '✓ Activity_status encontrado en visits: ID=${visit.idActivityStatus}');
      }
    } else if (visit.idStepParent != 0) {
      // Si idStepParent NO es 0, buscar normalmente en activity_steps
      // Remover de la lista de steps requeridos si existe
      requiredStepIds.remove(visit.idStepParent);
      debugPrint('✓ Step encontrado en visits: ID=${visit.idStepParent}');
    }
  }

  // Los IDs que queden en las listas son los faltantes
  missingStepIds = requiredStepIds;
  missingStatusIds = requiredStatusIds;

  // Verificar si hay elementos faltantes
  bool hasAllRequired = missingStepIds.isEmpty && missingStatusIds.isEmpty;

  if (!hasAllRequired) {
    debugPrint('VALIDACIÓN FALLIDA');
    if (missingStepIds.isNotEmpty) {
      debugPrint(
          'Faltan ${missingStepIds.length} steps requeridos: $missingStepIds');
    }
    if (missingStatusIds.isNotEmpty) {
      debugPrint(
          'Faltan ${missingStatusIds.length} status requeridos: $missingStatusIds');
    }
    return false;
  }

  debugPrint('VALIDACIÓN EXITOSA - Todos los elementos requeridos están presentes');
  return true;
}

dynamic sortActivityStepsByOrder(dynamic jsonData) {
  // Validar input
  if (jsonData == null) {
    debugPrint('Error: JSON nulo');
    return jsonData;
  }

  // Convertir JSON si es necesario
  Map<String, dynamic> data;
  if (jsonData is String) {
    try {
      data = Map<String, dynamic>.from(json.decode(jsonData));
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return jsonData;
    }
  } else if (jsonData is Map) {
    // Crear una copia profunda para no modificar el original
    data = Map<String, dynamic>.from(json.decode(json.encode(jsonData)));
  } else {
    debugPrint('Error: Tipo de datos no reconocido');
    return jsonData;
  }

  // Verificar que existe activity_steps
  if (!data.containsKey('activity_steps')) {
    debugPrint('No se encontró activity_steps en el JSON');
    return data;
  }

  // Función recursiva para ordenar activity_steps en cualquier nivel
  void sortStepsRecursively(Map<String, dynamic> node) {
    // Ordenar activity_steps en el nivel actual
    if (node.containsKey('activity_steps') && node['activity_steps'] is List) {
      List<dynamic> steps = List.from(node['activity_steps']);

      // Ordenar por order_step
      steps.sort((a, b) {
        if (a is Map && b is Map) {
          int orderA = a['order_step'] ?? 999999;
          int orderB = b['order_step'] ?? 999999;
          return orderA.compareTo(orderB);
        }
        return 0;
      });

      node['activity_steps'] = steps;

      // Procesar recursivamente cada step
      // for (var step in steps) {
      //   if (step is Map<String, dynamic>) {
      //     // Ordenar activities_status si existe
      //     if (step.containsKey('activities_status') && step['activities_status'] is List) {
      //       List<dynamic> statusList = List.from(step['activities_status']);

      //       // Ordenar activities_status por order_status si existe
      //       statusList.sort((a, b) {
      //         if (a is Map && b is Map) {
      //           int orderA = a['order_status'] ?? 999999;
      //           int orderB = b['order_status'] ?? 999999;
      //           return orderA.compareTo(orderB);
      //         }
      //         return 0;
      //       });

      //       step['activities_status'] = statusList;

      //       // Procesar activities_steps_childs dentro de cada status
      //       for (var status in statusList) {
      //         if (status is Map<String, dynamic> &&
      //             status.containsKey('activities_steps_childs') &&
      //             status['activities_steps_childs'] is List) {

      //           List<dynamic> childSteps = List.from(status['activities_steps_childs']);

      //           // Ordenar los child steps
      //           childSteps.sort((a, b) {
      //             if (a is Map && b is Map) {
      //               int orderA = a['order_step'] ?? 999999;
      //               int orderB = b['order_step'] ?? 999999;
      //               return orderA.compareTo(orderB);
      //             }
      //             return 0;
      //           });

      //           status['activities_steps_childs'] = childSteps;

      //           // Recursión para procesar steps anidados más profundos
      //           for (var childStep in childSteps) {
      //             if (childStep is Map<String, dynamic>) {
      //               sortStepsRecursively(childStep);
      //             }
      //           }
      //         }
      //       }
      //     }
      //   }
      // }
    }
  }

  // Ordenar el array principal de activity_steps
  if (data['activity_steps'] is List) {
    List<dynamic> mainSteps = List.from(data['activity_steps']);

    debugPrint('Ordenando ${mainSteps.length} activity_steps principales');

    // Ordenar por order_step
    mainSteps.sort((a, b) {
      if (a is Map && b is Map) {
        int orderA = a['order_step'] ?? 999999;
        int orderB = b['order_step'] ?? 999999;

        // Log para debugging
        String nameA = a['name_step'] ?? 'Sin nombre';
        String nameB = b['name_step'] ?? 'Sin nombre';
        debugPrint(
            'Comparando: "$nameA" (order: $orderA) vs "$nameB" (order: $orderB)');

        return orderA.compareTo(orderB);
      }
      return 0;
    });

    data['activity_steps'] = mainSteps;

    // Procesar recursivamente todos los steps anidados
    sortStepsRecursively(data);

    debugPrint('Ordenamiento completado');
  }

  return data;
}

String joinHeadquarterIds(List<HeadquartersStruct> headquartersList) {
  // Extrae todos los id_headquarter de la lista y los convierte a String
  List<String> ids = headquartersList
      .map((headquarter) => headquarter.idHeadquarter.toString())
      .toList();

  // Une los IDs con comas
  String result = ids.join(',');

  return result;
}

bool validateAdvancedAccessCode(String inputCode) {
  // El código correcto es "123456789"
  const String correctCode = "123456789";

  // Validar que el código ingresado sea exactamente igual al correcto
  return inputCode == correctCode;
}
