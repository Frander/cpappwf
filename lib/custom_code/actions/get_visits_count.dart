// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';

Future<int> getVisitsCount() async {
  try {
    debugPrint('=== Obteniendo conteo de visitas ===');

    // Usa el singleton global en lugar de abrir conexión aislada
    return await globalDb.executeOperation((db) async {
      // Ejecutar query de conteo
      debugPrint('🔍 Ejecutando COUNT en tabla Visits...');
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Visits',
      );

      // Extraer el resultado
      final int count = result.isNotEmpty ? (result.first['count'] as int) : 0;
      debugPrint('✅ Total de visitas encontradas: $count');

      return count;
    });
  } catch (e) {
    debugPrint('❌ Error obteniendo conteo de visitas: $e');
    return 0;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
