// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

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
  const String baseUrl = 'https://api.clickpalm.com';
  final String endpoint =
      '$baseUrl/Headquarters/$headquarterId/with-all-relations-compressed';

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

    // 2. PARSEAR RESPUESTA (con detección automática de compresión GZIP)
    final Map<String, dynamic> data = _decodeGzipResponse(response.bodyBytes);
    debugPrint('✅ JSON parseado exitosamente (${response.bodyBytes.length} bytes recibidos)');

    // DEBUG: Mostrar todas las keys del JSON
    debugPrint('🔍 Keys disponibles en JSON de respuesta:');
    debugPrint('   ${data.keys.toList()}');

    // DEBUG: Verificar si headquarters_weights existe en el JSON
    debugPrint('🔍 Verificando headquarters_weights en JSON:');
    debugPrint('   - Existe key? ${data.containsKey('headquarters_weights')}');
    if (data.containsKey('headquarters_weights')) {
      debugPrint('   - Es List? ${data['headquarters_weights'] is List}');
      if (data['headquarters_weights'] is List) {
        debugPrint('   - Cantidad: ${(data['headquarters_weights'] as List).length}');
      }
    }

    // 3. ABRIR BASE DE DATOS (usando el mismo método que validate_db_sqlite.dart)
    final String dbPath = await _getDatabasePath();
    final Database db = await openDatabase(dbPath);
    debugPrint('🔗 Conexión SQLite abierta: ${db.hashCode}');

    // PRAGMAs de rendimiento para inserción masiva
    // sqflite requiere rawQuery para PRAGMAs (retornan filas)
    await db.rawQuery('PRAGMA journal_mode = WAL;');
    await db.rawQuery('PRAGMA synchronous = NORMAL;');
    await db.rawQuery('PRAGMA cache_size = -65536;'); // 64 MB cache

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

        // 4.6 Insertar Headquarters_weights
        if (data['headquarters_weights'] != null &&
            data['headquarters_weights'] is List) {
          await _insertHeadquartersWeights(
              txn, data['headquarters_weights'], headquarterId);
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
        'CustomOriginLatitude': data['custom_origin_latitude'],
        'CustomOriginLongitude': data['custom_origin_longitude'],
        'Has_plants': (data['has_plants'] == true || data['has_plants'] == 1) ? 1 : 0,
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
            'Created_at': polygon['created_at'] ?? DateTime.now().toIso8601String(),
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
    debugPrint('   📝 Preparando inserción de ${products.length} productos...');

    // ── Límite SQLite: 999 bind params por statement ──────────────────────────
    const int productFields = 14;
    const int coordFields   = 4;
    const int productChunk  = 999 ~/ productFields; // 71 filas por statement
    const int coordChunk    = 999 ~/ coordFields;   // 249 filas por statement

    // ── 1. Separar datos en listas planas (un solo recorrido del JSON) ─────────
    final List<List<dynamic>> productRows = [];
    final List<List<dynamic>> coordRows   = [];
    final String now = DateTime.now().toIso8601String();

    for (final product in products) {
      productRows.add([
        product['id_product'],
        headquarterId,
        product['id_company'] ?? 0,
        product['id_type'] ?? 0,
        product['created_at'] ?? now,
        product['modified_at'] ?? now,
        product['type_product'],
        product['name_product'],
        product['rfid'],
        product['state_product'],
        product['description_product'],
        product['location_raw'],
        product['line'],
        product['palm'],
      ]);

      if (product['coordenates'] is List) {
        for (final coord in product['coordenates']) {
          final lat = coord['latitude'];
          final lon = coord['longitude'];
          if (lat != null && lon != null) {
            coordRows.add([
              coord['id_product_coordenate'],
              product['id_product'],
              lat,
              lon,
            ]);
          }
        }
      }
    }

    // ── 2. DELETE previo: elimina registros del HQ sin overhead de conflictos ──
    await txn.rawDelete(
      'DELETE FROM Products_coordinates '
      'WHERE Id_product IN (SELECT Id_product FROM Products WHERE Id_headquarter = ?)',
      [headquarterId],
    );
    await txn.rawDelete(
      'DELETE FROM Products WHERE Id_headquarter = ?',
      [headquarterId],
    );

    // ── 3. INSERT Products en chunks de $productChunk filas ───────────────────
    const String productCols =
        'Id_product, Id_headquarter, Id_company, Id_type, '
        'Created_at, Modified_at, Type_product, Name_product, '
        'Rfid, State_product, Description_product, Location_raw, Line, Palm';
    final String productPlaceholder =
        '(${List.filled(productFields, '?').join(',')})';

    int productStatements = 0;
    for (int i = 0; i < productRows.length; i += productChunk) {
      final int end = i + productChunk < productRows.length
          ? i + productChunk
          : productRows.length;
      final chunk  = productRows.sublist(i, end);
      final params = chunk.expand((r) => r).toList();
      await txn.rawInsert(
        'INSERT INTO Products ($productCols) VALUES '
        '${List.filled(chunk.length, productPlaceholder).join(',')}',
        params,
      );
      productStatements++;
    }

    // ── 4. INSERT Products_coordinates en chunks de $coordChunk filas ─────────
    int coordStatements = 0;
    if (coordRows.isNotEmpty) {
      const String coordCols =
          'Id_product_coordenate, Id_product, Latitude, Longitude';

      for (int i = 0; i < coordRows.length; i += coordChunk) {
        final int end = i + coordChunk < coordRows.length
            ? i + coordChunk
            : coordRows.length;
        final chunk  = coordRows.sublist(i, end);
        final params = chunk.expand((r) => r).toList();
        await txn.rawInsert(
          'INSERT INTO Products_coordinates ($coordCols) VALUES '
          '${List.filled(chunk.length, '(?,?,?,?)').join(',')}',
          params,
        );
        coordStatements++;
      }
    }

    debugPrint('   ✅ ${productRows.length} productos  → $productStatements statements');
    debugPrint('   ✅ ${coordRows.length} coordenadas → $coordStatements statements');
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
    final virtualPoints = data['virtual_points'];
    if (virtualPoints is List) {
      for (var point in virtualPoints) {
        final typePoint = point['type_point'];
        if (typePoint is Map) {
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint.cast<String, dynamic>());
            insertedTypePointIds.add(id);
            totalInserted++;
          }
        }
      }
    }

    // Extraer type_point de headquarters_coordinates
    final hqCoordinates = data['headquarters_coordinates'];
    if (hqCoordinates is List) {
      for (var coord in hqCoordinates) {
        final typePoint = coord['type_point'];
        if (typePoint is Map) {
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint.cast<String, dynamic>());
            insertedTypePointIds.add(id);
            totalInserted++;
          }
        }
      }
    }

    // Extraer type_point de products
    final products = data['products'];
    if (products is List) {
      for (var product in products) {
        final typePoint = product['type_point'];
        if (typePoint is Map) {
          final id = typePoint['id_type_point'];
          if (id != null && !insertedTypePointIds.contains(id)) {
            await _insertTypePoint(txn, typePoint.cast<String, dynamic>());
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

/// Inserta Headquarters_weights del lote
Future<void> _insertHeadquartersWeights(
  Transaction txn,
  List<dynamic> weights,
  int headquarterId,
) async {
  try {
    debugPrint('   📝 Insertando ${weights.length} Headquarters_weights...');

    final batch = txn.batch();

    for (final weight in weights) {
      batch.insert(
        'Headquarters_weights',
        {
          'Id_headquarter_weight': weight['id_headquarter_weight'],
          'Id_headquarter': weight['id_headquarter'],
          'Id_company': weight['id_company'],
          'Date_year': weight['date_year'],
          'Date_month': weight['date_month'],
          'Weight': weight['weight'],
          'Created_at': weight['created_at'],
          'Modified_at': weight['modified_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    debugPrint(
        '   ✅ ${weights.length} Headquarters_weights insertados/actualizados');
  } catch (e) {
    debugPrint('   ❌ Error insertando Headquarters_weights: $e');
    rethrow;
  }
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

/// Decodifica una respuesta que puede estar comprimida con GZIP o ser JSON plano.
///
/// El cliente HTTP de Flutter (dart:io HttpClient) descomprime automáticamente
/// cuando recibe Content-Encoding: gzip, por lo que response.bodyBytes puede
/// llegar ya descomprimido. Esta función detecta por magic bytes (0x1F 0x8B)
/// si los datos siguen siendo GZIP y los descomprime solo si es necesario.
Map<String, dynamic> _decodeGzipResponse(List<int> bodyBytes) {
  final List<int> jsonBytes = _isGzip(bodyBytes)
      ? gzip.decode(bodyBytes)
      : bodyBytes;
  return jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
}

/// Detecta si los bytes corresponden a datos GZIP por magic bytes (0x1F 0x8B).
bool _isGzip(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

Future<String> _getDatabasePath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}
