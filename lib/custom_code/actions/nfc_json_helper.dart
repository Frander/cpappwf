// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';

/// Helper para construir y parsear el nuevo formato JSON de los tags NFC
///
/// Formato JSON:
/// ```json
/// {
///   "Read_info": {
///     "Id_product": 789542,
///     "RFID": "4C72D5F2",
///     "Name_product": "Caja 10",
///     "Date_created": "2026-05-15T09:00:00"
///   },
///   "Visits": [
///     {
///       "DH": "2026-05-15T08:30:00",
///       "OP": 293,
///       "VISITS": 10,
///       "RESULTS": 8,
///       "HE": 204
///     }
///   ]
/// }
/// ```

/// Construye el JSON inicial para un nuevo tag
Map<String, dynamic> buildInitialNfcJson({
  required int idProduct,
  required String rfid,
  required String nameProduct,
}) {
  return {
    'Read_info': {
      'Id_product': idProduct,
      'RFID': rfid,
      'Name_product': nameProduct,
      'Date_created': DateTime.now().toIso8601String(),
    },
    'Visits': [],
  };
}

/// Actualiza la información Read_info con nueva fecha y datos del producto
Map<String, dynamic> updateReadInfo(
  Map<String, dynamic> nfcJson, {
  required int idProduct,
  required String rfid,
  required String nameProduct,
}) {
  nfcJson['Read_info'] = {
    'Id_product': idProduct,
    'RFID': rfid,
    'Name_product': nameProduct,
    'Date_created': DateTime.now().toIso8601String(),
  };
  return nfcJson;
}

/// Agrega una nueva visita al array de Visits
Map<String, dynamic> addVisitToNfcJson(
  Map<String, dynamic> nfcJson, {
  required int operatorId,
  required int visits,
  required int results,
  required int headquarterId,
  DateTime? dateTime,
}) {
  final visitEntry = {
    'DH': (dateTime ?? DateTime.now()).toIso8601String(),
    'OP': operatorId,
    'VISITS': visits,
    'RESULTS': results,
    'HE': headquarterId,
  };

  if (nfcJson['Visits'] == null) {
    nfcJson['Visits'] = [];
  }

  (nfcJson['Visits'] as List).add(visitEntry);

  return nfcJson;
}

/// Parsea un string JSON del tag NFC y retorna el Map
/// Retorna null si el contenido no es un JSON válido
Map<String, dynamic>? parseNfcJson(String nfcContent) {
  try {
    final decoded = jsonDecode(nfcContent);
    if (decoded is Map<String, dynamic>) {
      // Validar que tenga la estructura esperada
      if (decoded.containsKey('Read_info') && decoded.containsKey('Visits')) {
        return decoded;
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error parseando JSON del NFC: $e');
  }
  return null;
}

/// Convierte el Map del JSON a String para escribir en el tag
String nfcJsonToString(Map<String, dynamic> nfcJson) {
  return jsonEncode(nfcJson);
}

/// Extrae la lista de visitas del JSON en un formato compatible con la UI
/// Retorna una lista de Maps con los campos parseados
List<Map<String, dynamic>> extractVisitsFromJson(Map<String, dynamic> nfcJson) {
  final List<Map<String, dynamic>> parsedVisits = [];

  if (nfcJson['Visits'] == null) {
    return parsedVisits;
  }

  final visits = nfcJson['Visits'] as List;

  for (var visit in visits) {
    if (visit is! Map<String, dynamic>) continue;

    // Parsear fecha ISO 8601
    DateTime dateTime = DateTime.now();
    try {
      final dhStr = visit['DH'] as String?;
      if (dhStr != null && dhStr.isNotEmpty) {
        dateTime = DateTime.parse(dhStr);
      }
    } catch (e) {
      debugPrint('⚠️ Error parseando fecha: $e');
    }

    parsedVisits.add({
      'operatorId': visit['OP']?.toString() ?? '',
      'operator2Id': '', // No usado en el nuevo formato
      'visits': visit['VISITS'] ?? 0,
      'results': visit['RESULTS'] ?? 0,
      'headquarterId': visit['HE'] ?? 0,
      'dateTime': dateTime,
    });
  }

  return parsedVisits;
}

/// Agrupa visitas por headquarterId para el resumen de tag-writer
/// Retorna un Map con headquarterId como key y datos agrupados como value
Map<int, Map<String, dynamic>> groupVisitsByHeadquarter(
    List<Map<String, dynamic>> visits) {
  final Map<int, Map<String, dynamic>> grouped = {};

  for (var visit in visits) {
    final headquarterId = visit['headquarterId'] as int? ?? 0;
    if (headquarterId == 0) continue;

    if (!grouped.containsKey(headquarterId)) {
      grouped[headquarterId] = {
        'totalVisits': 0,
        'totalResults': 0,
        'entries': <Map<String, dynamic>>[],
      };
    }

    grouped[headquarterId]!['totalVisits'] =
        (grouped[headquarterId]!['totalVisits'] as int) + (visit['visits'] as int? ?? 0);
    grouped[headquarterId]!['totalResults'] =
        (grouped[headquarterId]!['totalResults'] as int) + (visit['results'] as int? ?? 0);
    (grouped[headquarterId]!['entries'] as List).add(visit);
  }

  return grouped;
}

/// Migra el formato antiguo {DH:...;OP:...} al nuevo formato JSON
/// Útil para tags que todavía usan el formato antiguo
Map<String, dynamic>? migrateOldFormatToJson(
  String oldContent, {
  required int idProduct,
  required String rfid,
  required String nameProduct,
}) {
  try {
    // Crear JSON base
    final nfcJson = buildInitialNfcJson(
      idProduct: idProduct,
      rfid: rfid,
      nameProduct: nameProduct,
    );

    // Extraer todos los registros entre {}
    final regexRecords = RegExp(r'\{([^}]+)\}');
    final matches = regexRecords.allMatches(oldContent);

    for (var match in matches) {
      final recordContent = match.group(1);
      if (recordContent == null) continue;

      // Parsear cada campo del registro antiguo
      final fields = recordContent.split(';');
      DateTime? dateTime;
      int? operatorId;
      int? visits;
      int? results;
      int? headquarterId;

      for (var field in fields) {
        final parts = field.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          switch (key) {
            case 'DH':
              // Parsear fecha antigua: 2025_11_06_13:20:00
              try {
                final dateStr = value.replaceAll('_', '-');
                final dateParts = dateStr.split('-');
                if (dateParts.length >= 4) {
                  final year = int.parse(dateParts[0]);
                  final month = int.parse(dateParts[1]);
                  final day = int.parse(dateParts[2]);
                  final timeParts = dateParts[3].split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  final second = int.parse(timeParts[2]);
                  dateTime = DateTime(year, month, day, hour, minute, second);
                }
              } catch (e) {
                dateTime = DateTime.now();
              }
              break;
            case 'OP':
              operatorId = int.tryParse(value);
              break;
            case 'VISITS':
              visits = int.tryParse(value);
              break;
            case 'RESULTS':
              results = int.tryParse(value);
              break;
            case 'HE':
              headquarterId = int.tryParse(value);
              break;
          }
        }
      }

      // Solo agregar si tiene los datos mínimos
      if (operatorId != null &&
          visits != null &&
          results != null &&
          headquarterId != null) {
        addVisitToNfcJson(
          nfcJson,
          operatorId: operatorId,
          visits: visits,
          results: results,
          headquarterId: headquarterId,
          dateTime: dateTime,
        );
      }
    }

    return nfcJson;
  } catch (e) {
    debugPrint('⚠️ Error migrando formato antiguo a JSON: $e');
    return null;
  }
}

/// Valida si el contenido del tag tiene el formato JSON nuevo
bool isNewJsonFormat(String nfcContent) {
  try {
    final decoded = jsonDecode(nfcContent);
    if (decoded is Map<String, dynamic>) {
      return decoded.containsKey('Read_info') && decoded.containsKey('Visits');
    }
  } catch (e) {
    // No es JSON válido
  }
  return false;
}

/// Valida si el contenido del tag tiene el formato antiguo
bool isOldFormat(String nfcContent) {
  final validPattern =
      RegExp(r'\{DH:[^}]+;OP:[^}]+;VISITS:[^}]+;RESULTS:[^}]+;HE:[^}]+\}');
  return validPattern.hasMatch(nfcContent);
}
