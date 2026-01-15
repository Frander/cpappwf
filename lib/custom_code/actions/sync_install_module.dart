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

import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Sincroniza los datos de un headquarter desde el API e inserta en SQLite
///
/// Llama al endpoint /Headquarters/{id}/with-all-relations y guarda:
/// - Types_points (tipos de puntos con colores - SE GUARDA PRIMERO)
/// - Headquarters (lote)
/// - Headquarters_polygons (polígonos del lote)
/// - Virtual_points (puntos virtuales con referencia a Types_points)
/// - Headquarters_coordinates (coordenadas del lote con referencia a Types_points)
/// - Products (productos/palmas con referencia a Types_points)
/// - Products_coordinates (coordenadas de productos)
///
/// ORDEN DE INSERCIÓN:
/// 1. Types_points (primero porque otras tablas tienen FK a esta)
/// 2. Headquarters
/// 3. Headquarters_polygons
/// 4. Virtual_points
/// 5. Headquarters_coordinates
/// 6. Products + Products_coordinates
Future<bool> syncInstallModule(
  BuildContext context,
  int headquarterId,
  String authToken,
) async {
  final String baseUrl = 'https://api.clickpalm.com';
  final String endpoint =
      '$baseUrl/Headquarters/$headquarterId/with-all-relations';

  try {
    debugPrint('=== Iniciando sincronización de módulo de instalación ===');
    debugPrint('🏢 Headquarter ID: $headquarterId');

    // 1. LLAMAR AL API
    debugPrint('📡 Llamando al endpoint: $endpoint');
    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('📥 Respuesta recibida:');
    debugPrint('   - Status Code: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('❌ Error en la petición: ${response.statusCode}');
      debugPrint('   Response: ${response.body}');
      return false;
    }

    // 2. PARSEAR JSON
    debugPrint('🔄 Parseando JSON...');
    final Map<String, dynamic> data = jsonDecode(response.body);
    debugPrint('✅ JSON parseado exitosamente');

    // 3. ABRIR BASE DE DATOS (usando el mismo método que validate_db_sqlite.dart)
    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);
    debugPrint('🔗 Conexión SQLite abierta: ${db.hashCode}');

    // 4. INSERTAR DATOS EN TRANSACCIÓN
    debugPrint('💾 Insertando datos en SQLite...');
    try {
      await db.transaction((txn) async {
        // 4.0 PRIMERO: Insertar todos los Types_points (relaciones de foreign key)
        await _insertAllTypesPoints(txn, data);

        // 4.1 Insertar Headquarter principal
        await _insertHeadquarter(txn, data);

        // 4.2 Insertar Headquarters_polygons
        if (data['headquarters_polygons'] != null &&
            data['headquarters_polygons'] is List) {
          await _insertHeadquartersPolygons(
              txn, data['headquarters_polygons'], headquarterId);
        }

        // 4.3 Insertar Virtual_points
        if (data['virtual_points'] != null && data['virtual_points'] is List) {
          await _insertVirtualPoints(txn, data['virtual_points'], headquarterId);
        }

        // 4.4 Insertar Headquarters_coordinates
        if (data['headquarters_coordinates'] != null &&
            data['headquarters_coordinates'] is List) {
          await _insertHeadquartersCoordinates(
              txn, data['headquarters_coordinates'], headquarterId);
        }

        // 4.5 Insertar Products y sus coordenadas
        if (data['products'] != null && data['products'] is List) {
          await _insertProducts(txn, data['products'], headquarterId);
        }
      });
    } catch (e) {
      debugPrint('❌ Error guardando en SQLite: $e');
      await db.close();
      rethrow;
    }

    // Cerrar la conexión después de completar la transacción
    await db.close();
    debugPrint('🔗 Conexión SQLite cerrada: ${db.hashCode}');

    debugPrint('✅ Sincronización completada exitosamente');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ EXCEPCIÓN en syncInstallModule: $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
  }
}

// ============================================================================
// FUNCIONES DE INSERCIÓN
// ============================================================================

Future<void> _insertHeadquarter(
    Transaction txn, Map<String, dynamic> data) async {
  try {
    debugPrint('   📝 Insertando Headquarter completo...');

    // sync_install_module es el dueño de los datos COMPLETOS del headquarter
    // incluyendo campos avanzados (Azimuth, Slope, etc.)
    // sync_login.dart usa INSERT OR IGNORE para no sobrescribir estos datos
    // Aquí usamos REPLACE para actualizar TODO cuando se vuelve a instalar
    await txn.insert(
      'Headquarters',
      {
        'Id_headquarter': data['id_headquarter'],
        'Id_zone': data['id_zone'],
        'Created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        'Name_headquarter': data['name_headquarter'],
        'Density_headquarter': data['density_headquarter'],
        'Seed_time': data['seed_time'],
        'State_headquarter': data['state_headquarter'],
        'Area_headquarter': data['area_headquarter'],
        'Polygon': data['polygon'],
        'Centroid_coordinate': data['centroid_coordinate'],
        // Campos avanzados - solo sync_install_module los inserta
        'Azimuth': data['azimuth'],
        'Slope_azimuth_direction': data['slope_azimuth_direction'],
        'Slope_azimuth_perpendicular': data['slope_azimuth_perpendicular'],
        'Horizontal_palm_distance': data['horizontal_palm_distance'],
        'Vertical_palm_distance': data['vertical_palm_distance'],
        'Magnetic_declination': data['magnetic_declination'],
        'CustomOriginLatitude': data['customOriginLatitude'],
        'CustomOriginLongitude': data['customOriginLongitude'],
        'Has_plants': (data['has_plants'] == true) ? 1 : 0,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // ✅ REPLACE para actualizar todo
    );

    debugPrint('   ✅ Headquarter completo insertado/actualizado');
  } catch (e) {
    debugPrint('   ❌ Error insertando Headquarter: $e');
    rethrow;
  }
}

Future<void> _insertHeadquartersPolygons(
    Transaction txn, List<dynamic> polygons, int headquarterId) async {
  try {
    debugPrint('   📝 Insertando ${polygons.length} polígonos...');

    int validPolygons = 0;
    int skippedPolygons = 0;

    for (var polygon in polygons) {
      // Validar que el polígono tenga coordenadas válidas (NOT NULL)
      // Algunos headquarters pueden no tener polígonos válidos
      if (polygon['latitude'] != null && polygon['longitude'] != null) {
        await txn.insert(
          'Headquarters_polygons',
          {
            'Id_headquarter_polygon': polygon['id_headquarter_polygon'],
            'Id_headquarter': headquarterId,
            'Latitude': polygon['latitude'],
            'Longitude': polygon['longitude'],
            'Created_at':
                polygon['created_at'] ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        validPolygons++;
      } else {
        debugPrint(
            '   ⚠️ Polígono ${polygon['id_headquarter_polygon']} sin coordenadas válidas, se omite');
        skippedPolygons++;
      }
    }

    debugPrint('   ✅ $validPolygons polígonos insertados');
    if (skippedPolygons > 0) {
      debugPrint('   ⚠️ $skippedPolygons polígonos omitidos (sin coordenadas)');
    }
  } catch (e) {
    debugPrint('   ❌ Error insertando polígonos: $e');
    rethrow;
  }
}

Future<void> _insertVirtualPoints(
    Transaction txn, List<dynamic> points, int headquarterId) async {
  try {
    debugPrint('   📝 Insertando ${points.length} puntos virtuales...');

    for (var point in points) {
      await txn.insert(
        'Virtual_points',
        {
          'Id_virtual_point': point['id_virtual_point'],
          'Id_headquarter': headquarterId,
          'Id_type_point': point['id_type_point'],
          'Line_number': point['line_number'],
          'Point_number': point['point_number'],
          'Latitude': point['latitude'],
          'Longitude': point['longitude'],
          'Description_virtual_point': point['description_virtual_point'],
          'Generation_method': point['generation_method'],
          'Created_date':
              point['created_date'] ?? DateTime.now().toIso8601String(),
          'Is_active': (point['is_active'] == true) ? 1 : 0,
          'Headquarter_name': point['headquarter_name'],
          'Type_point_name': point['type_point_name'],
          'Point_display_name': point['point_display_name'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    debugPrint('   ✅ ${points.length} puntos virtuales insertados');
  } catch (e) {
    debugPrint('   ❌ Error insertando puntos virtuales: $e');
    rethrow;
  }
}

Future<void> _insertHeadquartersCoordinates(
    Transaction txn, List<dynamic> coordinates, int headquarterId) async {
  try {
    debugPrint('   📝 Insertando ${coordinates.length} coordenadas...');

    for (var coord in coordinates) {
      await txn.insert(
        'Headquarters_coordinates',
        {
          'Id_polygon_coordinate': coord['id_polygon_coordinate'],
          'Id_headquarter': headquarterId,
          'Name_polygon_coordinate': coord['name_polygon_coordinate'],
          'Coordinates_raw': coord['coordinates_raw'],
          'Point_type': coord['point_type'],
          'Id_type_point': coord['id_type_point'],
          'Created_at': coord['created_at'] ?? DateTime.now().toIso8601String(),
          'Modified_at':
              coord['modified_at'] ?? DateTime.now().toIso8601String(),
          'Is_active': (coord['is_active'] == true) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    debugPrint('   ✅ ${coordinates.length} coordenadas insertadas');
  } catch (e) {
    debugPrint('   ❌ Error insertando coordenadas: $e');
    rethrow;
  }
}

Future<void> _insertProducts(
    Transaction txn, List<dynamic> products, int headquarterId) async {
  try {
    debugPrint('   📝 Insertando ${products.length} productos...');

    int coordinatesCount = 0;

    for (var product in products) {
      // Insertar producto con TODOS los campos
      await txn.insert(
        'Products',
        {
          'Id_product': product['id_product'],
          'Id_headquarter': headquarterId,
          'Id_company': product['id_company'] ?? 0,
          'Id_type': product['id_type'] ?? 0,
          'Created_at':
              product['created_at'] ?? DateTime.now().toIso8601String(),
          'Modified_at':
              product['modified_at'] ?? DateTime.now().toIso8601String(),
          'Type_product': product['type_product'],
          'Name_product': product['name_product'],
          'Rfid': product['rfid'],
          'State_product': product['state_product'],
          'Description_product': product['description_product'],
          'Location_raw': product['location_raw'],
          'Line': product['line'],
          'Palm': product['palm'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insertar coordenadas del producto (nota el typo 'coordenates' del API)
      if (product['coordenates'] != null && product['coordenates'] is List) {
        for (var coord in product['coordenates']) {
          // Solo insertar si latitude y longitude no son null
          final lat = coord['latitude'];
          final lon = coord['longitude'];
          if (lat != null && lon != null) {
            await txn.insert(
              'Products_coordinates',
              {
                'Id_product_coordenate': coord['id_product_coordenate'],
                'Id_product': product['id_product'],
                'Latitude': lat,
                'Longitude': lon,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            coordinatesCount++;
          }
        }
      }
    }

    debugPrint(
        '   ✅ ${products.length} productos insertados con $coordinatesCount coordenadas');
  } catch (e) {
    debugPrint('   ❌ Error insertando productos: $e');
    rethrow;
  }
}

/// Extrae y guarda todos los Types_points de la respuesta del API
/// Esto se debe hacer PRIMERO porque otras tablas tienen foreign keys a Types_points
Future<void> _insertAllTypesPoints(
    Transaction txn, Map<String, dynamic> data) async {
  try {
    debugPrint('   🎨 Extrayendo y guardando todos los Types_points...');

    final Set<int> insertedTypePointIds = {};
    int totalInserted = 0;

    // Extraer type_point de virtual_points
    if (data['virtual_points'] != null && data['virtual_points'] is List) {
      for (var point in data['virtual_points']) {
        if (point['type_point'] != null && point['type_point'] is Map) {
          final typePoint = point['type_point'] as Map<String, dynamic>;
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint);
            insertedTypePointIds.add(id);
            totalInserted++;
          }
        }
      }
    }

    // Extraer type_point de headquarters_coordinates
    if (data['headquarters_coordinates'] != null &&
        data['headquarters_coordinates'] is List) {
      for (var coord in data['headquarters_coordinates']) {
        if (coord['type_point'] != null && coord['type_point'] is Map) {
          final typePoint = coord['type_point'] as Map<String, dynamic>;
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint);
            insertedTypePointIds.add(id);
            totalInserted++;
          }
        }
      }
    }

    // Extraer type_point de products
    if (data['products'] != null && data['products'] is List) {
      for (var product in data['products']) {
        if (product['type_point'] != null && product['type_point'] is Map) {
          final typePoint = product['type_point'] as Map<String, dynamic>;
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint);
            insertedTypePointIds.add(id);
            totalInserted++;
          }
        }
      }
    }

    debugPrint('   ✅ $totalInserted Types_points únicos insertados');
  } catch (e) {
    debugPrint('   ❌ Error insertando Types_points: $e');
    rethrow;
  }
}

Future<void> _insertTypePoint(
    Transaction txn, Map<String, dynamic> typePoint) async {
  try {
    await txn.insert(
      'Types_points',
      {
        'Id_type_point': typePoint['id_type_point'],
        'Name_type': typePoint['name_type'],
        'Color_type': typePoint['color_type'],
        'Order_type': typePoint['order_type'],
        'Virtual_points_count': typePoint['virtual_points_count'] ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } catch (e) {
    debugPrint('   ⚠️ Error insertando type_point individual: $e');
    // No rethrow porque type_point es opcional
  }
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

Future<String> _getDatabasePath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String basePath = '${externalDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}
