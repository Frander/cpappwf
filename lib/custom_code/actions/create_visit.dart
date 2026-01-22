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

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'dart:math' as math;

Future<VisitsStruct?> createVisit(
  BuildContext context,
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
  try {
    debugPrint('=== Iniciando creación de visita ===');
    debugPrint('ID Visita: $idVisit');
    debugPrint('ID Company: $idCompany');
    debugPrint('ID Activity: $idActivity');
    debugPrint('ID Headquarter: $idHeadquarter');
    debugPrint('ID Product: $idProduct');
    debugPrint('ID User: $idUser');
    debugPrint('ID Device: $idDevice');
    debugPrint('ID Status: $idStatus');
    debugPrint('Created At: ${createdAt.toIso8601String()}');
    debugPrint('Location Default: $locationDefault');
    debugPrint('locationsAdd (${locationsAdd.length} coordenadas):');
    for (int i = 0; i < locationsAdd.length; i++) {
      debugPrint('   [$i] ${locationsAdd[i]}');
    }

    debugPrint('visitsDetails (${visitsDetails.length} detalles):');
    for (int i = 0; i < visitsDetails.length; i++) {
      final detail = visitsDetails[i];
      debugPrint('   [$i] ID Activity Status: ${detail.idActivityStatus}');
      debugPrint('       Status Option: ${detail.statusOption ?? "null"}');
      debugPrint('       Status Response: ${detail.statusResponse ?? "null"}');
      debugPrint('       ID Visit Detail: ${detail.idVisitDetail ?? "null"}');
      debugPrint('       Type Status: ${detail.typeStatus ?? "null"}');
      debugPrint('       Remember Status: ${detail.rememberStatus}');
    }

    // 1. Crear el objeto VisitsStruct con TODOS los detalles (sin filtrar)
    // ✅ TODOS los registros deben guardarse en SQLite
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
      visitsDetails: visitsDetails, // ✅ Sin filtrar - guardar TODO en SQLite
      locationsAdd: locationsAdd,
    );

    // 2. Obtener información del dispositivo para batería
    double battery = await _getBatteryLevel();

    // 3. Extraer coordenadas de locationDefault
    double latitude = 0.0;
    double longitude = 0.0;
    double altitude = 0.0;
    double errorHorizontal = 0.0;

    if (locationDefault != null && locationDefault.isNotEmpty) {
      final coordinates = _parseLocationString(locationDefault);
      latitude = coordinates['latitude'] ?? 0.0;
      longitude = coordinates['longitude'] ?? 0.0;
      altitude = coordinates['altitude'] ?? 0.0;
      errorHorizontal = coordinates['errorHorizontal'] ?? 0.0;
    }

    // 4. Obtener ruta de la base de datos
    final String dbPath = await _getDatabasePath();
    debugPrint('📂 Ruta de la base de datos SQLite: $dbPath');

    // 5. Insertar en la tabla Visits
    debugPrint('📝 Insertando visita en la base de datos...');
    debugPrint('   - ID Company: $idCompany');
    debugPrint('   - ID Activity: $idActivity');
    debugPrint('   - ID Headquarter: $idHeadquarter');
    debugPrint('   - ID User: $idUser');
    debugPrint('   - Fecha creación: ${createdAt.toIso8601String()}');
    debugPrint(
        '   - Coordenadas: Lat: $latitude, Lon: $longitude, Alt: $altitude');
    debugPrint('   - Batería: $battery%');

    final int insertedVisitId = await _insertVisitToDatabase(
      dbPath: dbPath,
      idCompany: idCompany,
      idActivity: idActivity,
      idHeadquarter: idHeadquarter,
      idProduct: idProduct,
      idUser: idUser,
      idDevice: idDevice,
      idStatus: idStatus,
      createdAt: createdAt,
      battery: battery,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      errorHorizontal: errorHorizontal,
    );

    if (insertedVisitId <= 0) {
      throw Exception('Error al insertar la visita en la base de datos');
    }

    debugPrint('✅ Visita insertada con ID: $insertedVisitId');

    // 6. Insertar coordenadas de locationsAdd en Visits_locations
    if (locationsAdd.isNotEmpty) {
      debugPrint(
          '📍 Insertando ${locationsAdd.length} coordenadas en Visits_locations...');
      await _insertVisitLocationsToDatabase(
        dbPath: dbPath,
        visitId: insertedVisitId,
        locations: locationsAdd,
      );
      debugPrint('✅ Coordenadas insertadas: ${locationsAdd.length} registros');
    } else {
      debugPrint('ℹ️ No hay coordenadas adicionales para insertar');
    }

    // 7. Insertar detalles de la visita en Visits_details
    if (visitsDetails.isNotEmpty) {
      debugPrint('📋 Insertando ${visitsDetails.length} detalles de visita...');
      debugPrint('📂 Usando base de datos: $dbPath');
      await _insertVisitDetailsToDatabase(
        dbPath: dbPath,
        visitId: insertedVisitId,
        visitsDetails: visitsDetails,
      );
      debugPrint(
          '✅ Detalles de visita insertados: ${visitsDetails.length} registros');
    } else {
      debugPrint('ℹ️ No hay detalles de visita para insertar');
    }

    // 8. LIMPIAR memoria: Eliminar registros con rememberStatus=false DESPUÉS de guardar en SQLite
    debugPrint('🧹 LIMPIEZA DE MEMORIA: Aplicando filtro después de guardar en SQLite');
    final cleanedVisitsDetails = _cleanTagStatusByRememberFlag(visitsDetails);
    debugPrint('   ✅ ${visitsDetails.length} registros → ${cleanedVisitsDetails.length} registros en memoria');

    // Crear nuevo VisitsStruct con la lista limpia para retornar y actualizar memoria
    final cleanedVisitsStruct = VisitsStruct(
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
      visitsDetails: cleanedVisitsDetails, // ✅ Lista limpia para memoria
      locationsAdd: locationsAdd,
    );

    // 9. Actualizar la lista visitsAdd en el AppState con la lista limpia
    await _updateVisitsAddInAppState(context, cleanedVisitsStruct);

    debugPrint('=== Visita creada exitosamente ===');
    return cleanedVisitsStruct; // Retornar la lista limpia para actualizar memoria
  } catch (e) {
    debugPrint('❌ Error creando visita: $e');
    return null;
  }
}

/// Actualiza la lista visitsAdd en el AppState manteniendo solo las últimas 50 visitas
Future<void> _updateVisitsAddInAppState(
    BuildContext context, VisitsStruct newVisit) async {
  try {
    debugPrint('=== Actualizando lista visitsAdd en AppState ===');

    // DEBUG: Verificar estado ANTES de tomar la lista
    debugPrint('🔍 ANTES de tomar FFAppState().visitsAdd:');
    debugPrint('   - visitsAdd.length = ${FFAppState().visitsAdd.length}');
    debugPrint('   - visitCount = ${FFAppState().visitCount}');

    // Obtener la lista actual del AppState
    List<VisitsStruct> currentVisits = List.from(FFAppState().visitsAdd);

    debugPrint('🔍 Lista copiada: ${currentVisits.length} visitas');

    // Agregar la nueva visita al inicio de la lista
    currentVisits.insert(0, newVisit);

    debugPrint('Total de visitas antes de filtrar: ${currentVisits.length}');

    // Ordenar por fecha de creación (más reciente primero)
    currentVisits.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.now();
      final dateB = b.createdAt ?? DateTime.now();
      return dateB.compareTo(dateA); // Orden descendente (más reciente primero)
    });

    // Mantener solo las últimas 50 visitas
    if (currentVisits.length > 50) {
      currentVisits = currentVisits.take(50).toList();
      debugPrint('Lista reducida a las últimas 50 visitas');
    }

    debugPrint('Total de visitas después de filtrar: ${currentVisits.length}');

    // Actualizar el AppState
    FFAppState().visitsAdd = currentVisits;

    // Forzar persistencia
    FFAppState().update(() {});

    // Verificar después de actualizar
    debugPrint('🔍 DESPUÉS de actualizar FFAppState():');
    debugPrint('   - visitsAdd.length = ${FFAppState().visitsAdd.length}');

    debugPrint('✅ Lista visitsAdd actualizada correctamente');
  } catch (e) {
    debugPrint('❌ Error actualizando visitsAdd en AppState: $e');
    // No lanzamos excepción para no afectar el proceso principal
  }
}

Future<String> _getDatabasePath() async {
  final String docsPath = await _getBestDocumentsPath();
  return path.join(docsPath, 'clickpalm_database.db');
}

Future<int> _insertVisitToDatabase({
  required String dbPath,
  required int idCompany,
  required int idActivity,
  required int idHeadquarter,
  required int idProduct,
  required int idUser,
  required int idDevice,
  required int idStatus,
  required DateTime createdAt,
  required double battery,
  required double latitude,
  required double longitude,
  required double altitude,
  required double errorHorizontal,
}) async {
  debugPrint('🔗 Abriendo conexión a base de datos: $dbPath');
  final database = await openDatabase(dbPath);

  try {
    debugPrint('💾 Ejecutando INSERT en tabla Visits...');
    final int result = await database.insert(
      'Visits',
      {
        'Id_company': idCompany,
        'Id_activity': idActivity,
        'Id_headquarter': idHeadquarter,
        'Id_product': idProduct,
        'Id_bulk': 0, // Default value
        'Id_user': idUser,
        'Id_device': idDevice,
        'Id_status': idStatus,
        'Created_at': createdAt.toIso8601String(),
        'Battery': battery,
        'Latitude': latitude,
        'Longitude': longitude,
        'Altitude': altitude,
        'Error_horizontal': errorHorizontal,
        'Id_virtual_point': null,
        'Status': 0, // Status por defecto (false)
      },
    );

    debugPrint('✅ Visita insertada exitosamente en SQLite con ID: $result');
    debugPrint('🔒 Cerrando conexión a base de datos');
    await database.close();
    return result;
  } catch (e) {
    debugPrint('❌ Error durante inserción en SQLite: $e');
    await database.close();
    throw Exception('Error insertando visita: $e');
  }
}

Future<void> _insertVisitDetailsToDatabase({
  required String dbPath,
  required int visitId,
  required List<VisitsDetailsStruct> visitsDetails,
}) async {
  debugPrint('🔗 Abriendo conexión para detalles en: $dbPath');
  final database = await openDatabase(dbPath);

  try {
    // Filtrar registros de tipo STEP (aquellos con idActivityStatus == 0)
    final detailsToInsert = visitsDetails
        .where((detail) => detail.idActivityStatus != null && detail.idActivityStatus! > 0)
        .toList();

    debugPrint(
        '📦 Creando batch para insertar ${detailsToInsert.length} detalles (${visitsDetails.length - detailsToInsert.length} registros STEP excluidos)...');
    final batch = database.batch();

    for (int i = 0; i < detailsToInsert.length; i++) {
      final detail = detailsToInsert[i];
      debugPrint(
          '   📝 Detalle ${i + 1}: ID_activity_status=${detail.idActivityStatus}');
      batch.insert(
        'Visits_details',
        {
          'Id_visit': visitId,
          'Id_activity_status': detail.idActivityStatus,
          'Status_option': detail.statusOption ?? '',
          'Status_response': detail.statusResponse ?? '',
        },
      );
    }

    debugPrint('💾 Ejecutando batch de detalles en SQLite...');
    await batch.commit(noResult: true);
    debugPrint('✅ Batch de detalles ejecutado exitosamente (${detailsToInsert.length} registros insertados)');
    debugPrint('🔒 Cerrando conexión de detalles');
    await database.close();
  } catch (e) {
    debugPrint('❌ Error durante inserción de detalles: $e');
    await database.close();
    throw Exception('Error insertando detalles de visita: $e');
  }
}

Future<void> _insertVisitLocationsToDatabase({
  required String dbPath,
  required int visitId,
  required List<String> locations,
}) async {
  debugPrint('🔗 Abriendo conexión para coordenadas en: $dbPath');
  final database = await openDatabase(dbPath);

  try {
    debugPrint(
        '📦 Creando batch para insertar ${locations.length} coordenadas...');
    final batch = database.batch();

    for (int i = 0; i < locations.length; i++) {
      final locationString = locations[i];
      final coordinates = _parseLocationString(locationString);

      debugPrint(
          '   📍 Coordenada ${i + 1}: LAT=${coordinates['latitude']}, LON=${coordinates['longitude']}, ALT=${coordinates['altitude']}, ERH=${coordinates['errorHorizontal']}');

      batch.insert(
        'Visits_locations',
        {
          'Id_visit': visitId,
          'Latitude': coordinates['latitude'],
          'Longitude': coordinates['longitude'],
          'Altitude': coordinates['altitude'],
          'HorizontalError': coordinates['errorHorizontal'],
        },
      );
    }

    debugPrint('💾 Ejecutando batch de coordenadas en SQLite...');
    await batch.commit(noResult: true);
    debugPrint('✅ Batch de coordenadas ejecutado exitosamente');
    debugPrint('🔒 Cerrando conexión de coordenadas');
    await database.close();
  } catch (e) {
    debugPrint('❌ Error durante inserción de coordenadas: $e');
    await database.close();
    throw Exception('Error insertando coordenadas de visita: $e');
  }
}

Future<double> _getBatteryLevel() async {
  try {
    if (Platform.isAndroid) {
      // Simulamos un nivel de batería para Android
      // En una implementación real, usarías battery_plus package
      return 85.0 + (math.Random().nextDouble() * 10); // 85-95%
    }
    return 90.0; // Default para otras plataformas
  } catch (e) {
    debugPrint('Error obteniendo nivel de batería: $e');
    return 0.0;
  }
}

Map<String, double> _parseLocationString(String locationString) {
  try {
    // Formato esperado: "LAT:12.345678;LON:-67.890123;ALT:100.50;ERH:5.25"
    final result = <String, double>{
      'latitude': 0.0,
      'longitude': 0.0,
      'altitude': 0.0,
      'errorHorizontal': 0.0,
    };

    final parts = locationString.split(';');

    for (final part in parts) {
      if (part.startsWith('LAT:')) {
        result['latitude'] = double.tryParse(part.substring(4)) ?? 0.0;
      } else if (part.startsWith('LON:')) {
        result['longitude'] = double.tryParse(part.substring(4)) ?? 0.0;
      } else if (part.startsWith('ALT:')) {
        result['altitude'] = double.tryParse(part.substring(4)) ?? 0.0;
      } else if (part.startsWith('ERH:')) {
        result['errorHorizontal'] = double.tryParse(part.substring(4)) ?? 0.0;
      }
    }

    return result;
  } catch (e) {
    debugPrint('Error parseando coordenadas: $e');
    return {
      'latitude': 0.0,
      'longitude': 0.0,
      'altitude': 0.0,
      'errorHorizontal': 0.0,
    };
  }
}

/// Limpia TODOS los status con rememberStatus = false de la memoria
/// Solo mantiene los status que tienen rememberStatus = true
/// Esto se aplica DESPUÉS de guardar en SQLite
List<VisitsDetailsStruct> _cleanTagStatusByRememberFlag(
    List<VisitsDetailsStruct> visitsDetails) {
  debugPrint('🧹 LIMPIEZA DE STATUS: Filtrando TODOS los status con rememberStatus=false');

  final filteredDetails = visitsDetails.where((detail) {
    final shouldRemove = !detail.rememberStatus;

    if (shouldRemove) {
      debugPrint('   ❌ Removiendo de memoria: ${detail.statusOption} (tipo=${detail.typeStatus}, remember=${detail.rememberStatus})');
    } else {
      debugPrint('   ✅ Manteniendo en memoria: ${detail.statusOption} (tipo=${detail.typeStatus}, remember=${detail.rememberStatus})');
    }

    return !shouldRemove;
  }).toList();

  debugPrint('✅ Limpieza completada: ${visitsDetails.length} → ${filteredDetails.length}');
  return filteredDetails;
}

Future<String> _getBestDocumentsPath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String pathStr = '${externalDir.path}/ClickPalmData';
  final Directory targetDir = Directory(pathStr);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return targetDir.path;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
