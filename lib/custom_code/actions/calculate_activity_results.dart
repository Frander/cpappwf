// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Calcula el total de visitas y resultados de actividades
Future<Map<String, int>> calculateActivityResults(
  BuildContext context,
) async {
  int totalVisits = 0;
  int totalResults = 0;

  try {
    // Obtener total de visitas desde AppState o SQLite
    final visitDetails = FFAppState().visitDetails;

    // Contar visitas únicas
    Set<int> uniqueVisits = {};
    for (var detail in visitDetails) {
      if (detail.idVisit > 0) {
        uniqueVisits.add(detail.idVisit);
      }
    }
    totalVisits = uniqueVisits.length;

    // Calcular resultados (racimos, flores, etc.)
    // Buscar en visitDetails los valores de factores
    for (var detail in visitDetails) {
      // Si el detalle contiene información de resultados
      // Buscar fields como "racimos", "bunches", "clusters"
      final response = detail.statusResponse;

      if (response.isNotEmpty) {
        // Intentar parsear como número
        final numericValue = int.tryParse(response);
        if (numericValue != null && numericValue > 0) {
          totalResults += numericValue;
        }
      }
    }

    // Si no hay resultados en visitDetails, intentar desde SQLite
    // DESHABILITADO: Este query tiene errores de schema (tabla y columna no existen)
    // La tabla se llama 'Activities_status' (mayúscula) y no tiene columna 'factor_type'
    /*
    if (totalResults == 0) {
      try {
        // Query a la base de datos para obtener racimos/resultados
        final db = await SQLiteManager.instance.database;

        // Intentar contar desde tabla de actividades
        final results = await db.rawQuery('''
          SELECT COUNT(*) as total FROM activities_status
          WHERE factor_type = 'racimos' OR factor_type = 'bunches'
        ''');

        if (results.isNotEmpty && results.first['total'] != null) {
          totalResults = results.first['total'] as int;
        }
      } catch (e) {
        debugPrint('Error al consultar resultados desde SQLite: $e');
      }
    }
    */
  } catch (e) {
    debugPrint('Error al calcular resultados de actividades: $e');
  }

  return {
    'visits': totalVisits,
    'results': totalResults,
  };
}
