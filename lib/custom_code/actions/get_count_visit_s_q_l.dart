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

import '/backend/sqlite/global_db_singleton.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<int> getCountVisitSQL() async {
  // Add your function code here!
  try {
    // Usa el singleton global en lugar de abrir conexión aislada
    return await globalDb.executeOperation((db) async {
      // Consultar visitas con todos sus datos relacionados usando la misma query optimizada
      final List<Map<String, dynamic>> rawData =
          await db.rawQuery('select COUNT(*) as count from Visits');
      int count = rawData[0]['count'];
      return count;
    });
  } catch (e) {
    debugPrint('Error obteniendo visits_add completas desde SQLite: $e');
  }
  return 0;
}

/// Limpia datos de SQLite tras sincronización exitosa
Future<void> _cleanupSQLiteDataAfterSync() async {
  try {
    // Usa el singleton global en lugar de abrir conexión aislada
    await globalDb.executeOperation((db) async {
      // 1. Limpiar tabla Location_tracking (todas las geolocalizaciones)
      final int deletedLocations = await db.delete('Location_tracking');
      debugPrint('Eliminadas $deletedLocations geolocalizaciones de SQLite');

      // 2. Eliminar TODAS las visitas después de sincronización exitosa
      debugPrint('🧹 Limpiando todas las visitas sincronizadas...');

      // Primero obtener los IDs de todas las visitas para eliminar sus datos relacionados
      final List<Map<String, dynamic>> allVisits = await db.rawQuery('''
        SELECT Id_visit FROM Visits
      ''');

      if (allVisits.isNotEmpty) {
        final List<int> visitIds =
            allVisits.map((v) => v['Id_visit'] as int).toList();
        final String placeholders = visitIds.map((_) => '?').join(',');

        debugPrint(
            '🗑️ Eliminando datos de ${visitIds.length} visitas sincronizadas...');

        // Eliminar coordenadas de todas las visitas
        final int deletedLocations = await db.rawDelete('''
          DELETE FROM Visits_locations
          WHERE Id_visit IN ($placeholders)
        ''', visitIds);

        // Eliminar detalles de todas las visitas
        final int deletedDetails = await db.rawDelete('''
          DELETE FROM Visits_details
          WHERE Id_visit IN ($placeholders)
        ''', visitIds);

        // Eliminar todas las visitas
        final int deletedVisits = await db.delete('Visits');

        debugPrint('✅ Eliminadas $deletedVisits visitas sincronizadas de SQLite');
        debugPrint('✅ Eliminados $deletedDetails detalles de visitas de SQLite');
        debugPrint(
            '✅ Eliminadas $deletedLocations coordenadas de visitas de SQLite');
      } else {
        debugPrint('ℹ️ No hay visitas para eliminar');
      }
    });
  } catch (e) {
    debugPrint('Error limpiando datos de SQLite: $e');
  }
}

/// Formatea las coordenadas al formato requerido por el API
/// Formato: "LAT:10.12345678;LON:-74.87654321;ALT:100.5;ERH:5.2"
String _formatLocationString(
  double latitude,
  double longitude,
  double altitude,
  double horizontalError,
) {
  return 'LAT:${latitude.toStringAsFixed(8)};LON:${longitude.toStringAsFixed(8)};ALT:${altitude.toStringAsFixed(2)};ERH:${horizontalError.toStringAsFixed(2)}';
}
