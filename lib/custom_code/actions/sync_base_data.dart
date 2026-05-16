// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '/stream_download.dart';

// ============================================================================
// FLAG: SINCRONIZACIÓN BASE INCOMPLETA
// Si por cualquier motivo falla la inserción, este flag persiste entre sesiones
// para forzar una re-sincronización completa en el próximo intento.
// ============================================================================
const String _kSyncBaseIncompleteKey = 'sync_base_data_incomplete';

Future<bool> _sbIsIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kSyncBaseIncompleteKey) ?? false;
}

Future<void> _sbSetIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kSyncBaseIncompleteKey, true);
  debugPrint('🚩 [SyncBase] FLAG SET: sync_base_data_incomplete=true');
}

Future<void> _sbClearIncomplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kSyncBaseIncompleteKey);
  debugPrint('✅ [SyncBase] FLAG CLEARED: Sincronización base exitosa.');
}

// ============================================================================
// FUNCIÓN PÚBLICA PRINCIPAL
// ============================================================================

/// Descarga todos los datos base de la empresa desde los 12 endpoints GZIP
/// y los guarda en SQLite. Llama en lotes de 3 endpoints en paralelo.
///
/// [imei]      → IMEI del dispositivo (para renovar token si expira)
/// [authToken] → Token de autenticación actual
/// [idCompany] → ID de la empresa
/// [onProgress]→ Callback opcional para reportar progreso en tiempo real
Future<bool> syncBaseData(
  BuildContext context,
  String imei,
  String authToken,
  int idCompany, {
  void Function(double progress, String message)? onProgress,
}) async {
  try {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🚀 INICIANDO SINCRONIZACIÓN DE DATOS BASE (syncBaseData)');
    debugPrint('   idCompany: $idCompany | imei: $imei');
    debugPrint('═══════════════════════════════════════════════════════════');

    // 0. Verificar flag de sync incompleto anterior
    final wasIncomplete = await _sbIsIncomplete();
    if (wasIncomplete) {
      debugPrint('⚠️ [SyncBase] Sincronización anterior incompleta. Forzando re-sync completo.');
    }

    // 1. Validar token
    String currentToken = authToken;
    if (currentToken.isEmpty) {
      debugPrint('🔑 [SyncBase] Token vacío, intentando renovar...');
      final renewed = await _sbRenewAuthToken(imei);
      if (renewed == null) {
        debugPrint('❌ [SyncBase] No se pudo obtener token');
        return false;
      }
      currentToken = renewed;
    }

    if (idCompany <= 0) {
      debugPrint('❌ [SyncBase] idCompany inválido: $idCompany');
      return false;
    }

    final idDevice = FFAppState().deviceDefault.idDevice;
    final syncNow  = DateTime.now();

    debugPrint('   🔑 Token OK | idDevice: $idDevice | fecha: ${syncNow.toIso8601String()}');

    // ─────────────────────────────────────────────────────────────────────────
    // ESTRATEGIA — Bajar peak de RAM en gama media-baja:
    // En lugar de descargar los 12 datasets y mantenerlos vivos hasta una
    // única transacción gigante, el flujo se parte en 3 bloques con
    // descarga → insert → liberación de memoria entre cada uno:
    //
    //   Bloque BASE: tablas pequeñas/medianas (types-points, companies, zones,
    //                activities, headquarters, hq-weights, news, hq-coords)
    //   Bloque PRODUCTS: products + products-coordinates
    //   Bloque VPOINTS:  virtual-points
    //
    // Así nunca conviven products y virtual-points en memoria.
    // Si un bloque falla, _sbSetIncomplete() ya está activo y el próximo
    // intento limpia y re-sincroniza desde cero.
    // ─────────────────────────────────────────────────────────────────────────
    await _sbSetIncomplete(); // marcamos pendiente desde antes del primer insert

    // ═════════════ BLOQUE BASE ═════════════════════════════════════════════
    debugPrint('\n📦 [BASE] Descargando tablas pequeñas/medianas en paralelo');
    onProgress?.call(0.03, 'Descargando actividades, lotes y zonas...');
    final batch1 = await Future.wait([
      _sbFetchList('activities',   currentToken, {'idCompany': '$idCompany', 'idDevice': '$idDevice'}, imei: imei),
      _sbFetchList('headquarters', currentToken, {'idCompany': '$idCompany'}, imei: imei),
      _sbFetchList('zones',        currentToken, {'idCompany': '$idCompany'}, imei: imei),
    ]);
    List<dynamic>? activitiesData   = batch1[0];
    List<dynamic>? headquartersData = batch1[1];
    List<dynamic>? zonesData        = batch1[2];
    debugPrint('   activities:   ${activitiesData?.length ?? "❌ Error"}');
    debugPrint('   headquarters: ${headquartersData?.length ?? "❌ Error"}');
    debugPrint('   zones:        ${zonesData?.length ?? "❌ Error"}');
    final lote1Errors = <String>[];
    if (activitiesData   == null) lote1Errors.add('activities');
    if (headquartersData == null) lote1Errors.add('headquarters');
    if (zonesData        == null) lote1Errors.add('zones');
    if (lote1Errors.isNotEmpty) {
      debugPrint('❌ [SyncBase] Endpoints críticos fallaron: $lote1Errors → abortando');
      return false;
    }

    onProgress?.call(0.18, 'Descargando noticias, empresa, pesos y tipos de puntos...');
    final prevMonth = DateTime(syncNow.year, syncNow.month - 1);
    final batch2 = await Future.wait([
      _sbFetchList('news',                 currentToken, {'idCompany': '$idCompany'}, imei: imei),
      _sbFetchList('companies',            currentToken, {'idCompany': '$idCompany'}, imei: imei),
      _sbFetchList('headquarters-weights', currentToken, {
        'idCompany': '$idCompany',
        'year':      '${prevMonth.year}',
        'month':     '${prevMonth.month}',
      }, imei: imei),
      _sbFetchList('types-points',         currentToken, {'idCompany': '$idCompany'}, imei: imei),
      _sbFetchList('headquarters-coordinates', currentToken, {'idCompany': '$idCompany'}, imei: imei),
    ]);
    List<dynamic>? newsData            = batch2[0];
    List<dynamic>? companiesData       = batch2[1];
    List<dynamic>? hqWeightsData       = batch2[2];
    List<dynamic>? typesPointsData     = batch2[3];
    List<dynamic>? hqCoordinatesData   = batch2[4];
    debugPrint('   news:           ${newsData?.length ?? "❌ Error"}');
    debugPrint('   companies:      ${companiesData?.length ?? "❌ Error"}');
    debugPrint('   hq-weights:     ${hqWeightsData?.length ?? "❌ Error"}');
    debugPrint('   types-points:   ${typesPointsData?.length ?? "❌ Error"}');
    debugPrint('   hq-coordinates: ${hqCoordinatesData?.length ?? "❌ Error"}');
    if (typesPointsData == null) {
      debugPrint('❌ [SyncBase] Endpoint crítico types-points falló → abortando');
      return false;
    }

    onProgress?.call(0.35, 'Guardando datos base en SQLite...');
    debugPrint('\n💾 [BASE] Guardando en SQLite y liberando memoria');
    final savedBase = await _sbSyncBaseToSQLite(
      activitiesData:    activitiesData!,
      headquartersData:  headquartersData!,
      zonesData:         zonesData!,
      newsData:          newsData,
      companiesData:     companiesData,
      hqWeightsData:     hqWeightsData,
      typesPointsData:   typesPointsData,
      hqCoordinatesData: hqCoordinatesData,
      onProgress:        onProgress,
    );
    // Liberar inmediatamente para que el GC reclame antes de descargar products
    activitiesData    = null;
    headquartersData  = null;
    zonesData         = null;
    newsData          = null;
    companiesData     = null;
    hqWeightsData     = null;
    typesPointsData   = null;
    hqCoordinatesData = null;
    if (!savedBase) {
      FFAppState().lastSyncBase = null;
      debugPrint('❌ [SyncBase] Falló bloque BASE en SQLite');
      return false;
    }

    // ═════════════ BLOQUE PRODUCTS ═════════════════════════════════════════
    onProgress?.call(0.50, 'Descargando productos...');
    debugPrint('\n📦 [PRODUCTS] Descarga independiente (~200k registros)');
    List<dynamic>? productsData = await _sbFetchList(
        'products', currentToken, {'idCompany': '$idCompany'}, imei: imei);
    debugPrint('   products: ${productsData?.length ?? "❌ Error"}');
    if (productsData == null) {
      FFAppState().lastSyncBase = null;
      debugPrint('❌ [SyncBase] Endpoint crítico products falló → abortando');
      return false;
    }

    onProgress?.call(0.62, 'Descargando coordenadas de productos...');
    List<dynamic>? productsCoordsData = await _sbFetchList(
        'products-coordinates', currentToken, {'idCompany': '$idCompany'}, imei: imei);
    debugPrint('   products-coordinates: ${productsCoordsData?.length ?? "❌ Error"}');
    // products-coordinates es opcional

    onProgress?.call(0.68, 'Guardando productos en SQLite...');
    debugPrint('\n💾 [PRODUCTS] Guardando en SQLite y liberando memoria');
    final savedProducts = await _sbSyncProductsToSQLite(
      productsData:       productsData,
      productsCoordsData: productsCoordsData,
      onProgress:         onProgress,
    );
    productsData       = null;
    productsCoordsData = null;
    if (!savedProducts) {
      FFAppState().lastSyncBase = null;
      debugPrint('❌ [SyncBase] Falló bloque PRODUCTS en SQLite');
      return false;
    }

    // ═════════════ BLOQUE VIRTUAL-POINTS ═══════════════════════════════════
    onProgress?.call(0.80, 'Descargando puntos virtuales...');
    debugPrint('\n📦 [VPOINTS] Descarga independiente (~150k registros)');
    List<dynamic>? virtualPointsData = await _sbFetchList(
        'virtual-points', currentToken, {'idCompany': '$idCompany'}, imei: imei);
    debugPrint('   virtual-points: ${virtualPointsData?.length ?? "❌ Error"}');
    if (virtualPointsData == null) {
      FFAppState().lastSyncBase = null;
      debugPrint('❌ [SyncBase] Endpoint crítico virtual-points falló → abortando');
      return false;
    }

    onProgress?.call(0.92, 'Guardando puntos virtuales en SQLite...');
    debugPrint('\n💾 [VPOINTS] Guardando en SQLite y liberando memoria');
    final savedVPoints = await _sbSyncVirtualPointsToSQLite(
      virtualPointsData: virtualPointsData,
      onProgress:        onProgress,
    );
    virtualPointsData = null;
    if (!savedVPoints) {
      FFAppState().lastSyncBase = null;
      debugPrint('❌ [SyncBase] Falló bloque VPOINTS en SQLite');
      return false;
    }

    await _sbClearIncomplete();
    onProgress?.call(1.0, 'Sincronización de datos base completada');

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('✅ SINCRONIZACIÓN DE DATOS BASE COMPLETADA EXITOSAMENTE');
    debugPrint('═══════════════════════════════════════════════════════════');
    return true;

  } catch (e, st) {
    debugPrint('❌ [SyncBase] EXCEPCIÓN: $e');
    debugPrint('   Stack: $st');
    // Datos en SQLite pueden estar corruptos/incompletos — forzar re-sync completo
    FFAppState().lastSyncBase = null;
    debugPrint('   → lastSyncBase = null (se requiere re-sincronización completa)');
    await _sbSetIncomplete();
    return false;
  }
}

// ============================================================================
// HELPERS DE CONVERSIÓN DE TIPOS
// ============================================================================

/// Convierte cualquier valor JSON (int, double, String, null) a int?.
/// Necesario porque el API puede retornar Factor como double (1.0), string ("1") o null.
/// sqflite almacena un Dart double como REAL, lo que rompe comparaciones INTEGER > 0.
int? _sbToInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.isFinite ? v.round() : null;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

// ============================================================================
// FETCH CON GZIP
// ============================================================================

/// Descarga un endpoint con reintentos automáticos (hasta 3) y renovación de token en 401.
/// - Backoff exponencial: 2s, 4s, 8s entre intentos
/// - HTTP 401: renueva token una vez y reintenta inmediatamente
/// - Timeout por intento: 4 min (endpoints grandes como products ~82 MB)
///
/// La descarga usa [streamDownloadGzippedToTempFile]: la respuesta gzip
/// se descomprime al vuelo y se vuelca a un archivo temporal, evitando
/// los picos de RAM que mataban al Dart VM en gama media-baja
/// (`response.bodyBytes` + `gzip.decode(bodyBytes)` sumaban 250-500 MB).
/// El parse JSON se delega a un isolate vía `compute` para no bloquear UI.
Future<List<dynamic>?> _sbFetchList(
  String endpoint,
  String authToken,
  Map<String, String> queryParams, {
  String imei = '',
}) async {
  const int maxAttempts = 3;
  String token = authToken;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    final uri = Uri.parse('https://api.clickpalm.com/Users/login-data/$endpoint')
        .replace(queryParameters: queryParams);

    if (attempt == 1) {
      debugPrint('   📡 GET /login-data/$endpoint ...');
    } else {
      debugPrint('   🔄 GET /login-data/$endpoint (intento $attempt/$maxAttempts)...');
    }

    final result = await streamDownloadGzippedToTempFile(
      url: uri,
      headers: {'Authorization': 'Bearer $token'},
      tagForLog: endpoint,
      timeout: const Duration(minutes: 4),
    );

    debugPrint('   → HTTP ${result.statusCode}');

    // ── 401: token expirado → renovar y reintentar inmediatamente ──────────
    if (result.statusCode == 401) {
      debugPrint('   🔑 [SyncBase] Token expirado en $endpoint, renovando...');
      if (imei.isNotEmpty) {
        final renewed = await _sbRenewAuthToken(imei);
        if (renewed != null) {
          token = renewed;
          debugPrint('   ✅ Token renovado, reintentando $endpoint...');
          continue; // reintenta sin contar este intento como fallo
        }
      }
      debugPrint('   ❌ No se pudo renovar token para $endpoint');
      return null;
    }

    if (result.statusCode == 200 && result.file != null) {
      final file = result.file!;
      try {
        final raw = await parseJsonFromFileInIsolate(file.path);
        final List<dynamic>? data = raw is List
            ? raw
            : (raw is Map<String, dynamic> ? <dynamic>[raw] : null);
        if (data != null) {
          debugPrint('   ✅ $endpoint: ${data.length} elementos');
          return data;
        }
        debugPrint('   ⚠️ $endpoint: respuesta no es lista ni objeto válido');
        return null;
      } catch (e) {
        debugPrint('   ❌ Error parseando $endpoint: $e');
      } finally {
        try {
          await file.delete();
        } catch (_) {}
      }
      return null;
    }

    debugPrint('   ❌ $endpoint → HTTP ${result.statusCode}');
    // No reintentar en errores 4xx (excepto 401 ya manejado arriba)
    if (result.statusCode >= 400 && result.statusCode < 500) return null;

    // Backoff exponencial antes del siguiente intento (5xx / red / timeout)
    if (attempt < maxAttempts) {
      final waitSeconds = attempt * 2; // 2s, 4s
      debugPrint('   ⏳ Esperando ${waitSeconds}s antes de reintentar $endpoint...');
      await Future.delayed(Duration(seconds: waitSeconds));
    }
  }

  debugPrint('   ❌ $endpoint: falló tras $maxAttempts intentos');
  return null;
}

// ============================================================================
// RENOVAR TOKEN
// ============================================================================

Future<String?> _sbRenewAuthToken(String imei) async {
  try {
    final response = await http.post(
      Uri.parse('https://api.clickpalm.com/Users/RenewToken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'Type_login': 'IMEI', 'Username': imei, 'Password': imei}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        debugPrint('✅ [SyncBase] Token renovado');
        return token;
      }
    }
    debugPrint('❌ [SyncBase] RenewToken falló: ${response.statusCode}');
    return null;
  } catch (e) {
    debugPrint('⚠️ [SyncBase] Excepción en RenewToken: $e');
    return null;
  }
}

// ============================================================================
// RUTA DE LA BASE DE DATOS
// ============================================================================

Future<String> _sbGetDatabasePath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('[SyncBase] No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final String basePath = '${baseDir.path}/ClickPalmData';
  return path.join(basePath, 'clickpalm_database.db');
}

// ============================================================================
// SINCRONIZACIÓN A SQLITE
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────
// Abre la base y aplica los PRAGMAs de optimización para sync masivo.
// El caller es responsable de cerrar la base.
// ─────────────────────────────────────────────────────────────────────────
Future<Database> _sbOpenTunedDb() async {
  final String dbPath = await _sbGetDatabasePath();
  final Database db = await openDatabase(dbPath);
  // sqflite requiere rawQuery (no execute) para PRAGMAs
  await db.rawQuery('PRAGMA synchronous=NORMAL');   // fsync solo en checkpoint
  await db.rawQuery('PRAGMA busy_timeout=30000');   // 30s ante bloqueos
  await db.rawQuery('PRAGMA cache_size=-32000');    // 32 MB de cache
  return db;
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOQUE BASE — Limpia todas las tablas base y carga las tablas
// pequeñas/medianas. NO toca Products / Virtual_points: esos van en
// transacciones separadas para minimizar el peak de RAM.
// ═══════════════════════════════════════════════════════════════════════════
Future<bool> _sbSyncBaseToSQLite({
  required List<dynamic> activitiesData,
  required List<dynamic> headquartersData,
  required List<dynamic> zonesData,
  List<dynamic>? newsData,
  List<dynamic>? companiesData,
  List<dynamic>? hqWeightsData,
  List<dynamic>? typesPointsData,
  List<dynamic>? hqCoordinatesData,
  void Function(double, String)? onProgress,
}) async {
  Database? db;
  try {
    db = await _sbOpenTunedDb();

    await db.transaction((txn) async {
      debugPrint('🔄 [SyncBase/BASE] Transacción iniciada');

      onProgress?.call(0.36, 'Limpiando datos anteriores...');
      await _sbCleanAllBaseTables(txn);

      if (typesPointsData != null && typesPointsData.isNotEmpty) {
        onProgress?.call(0.38, 'Guardando tipos de puntos...');
        await _sbInsertTypesPoints(txn, typesPointsData);
      }

      if (companiesData != null && companiesData.isNotEmpty) {
        onProgress?.call(0.39, 'Guardando empresa...');
        await _sbInsertCompanies(txn, companiesData);
      }

      if (zonesData.isNotEmpty) {
        onProgress?.call(0.40, 'Guardando zonas geográficas...');
        await _sbInsertZones(txn, zonesData);
      }

      if (activitiesData.isNotEmpty) {
        onProgress?.call(0.42, 'Guardando actividades...');
        await _sbInsertActivities(txn, activitiesData);
      }

      if (headquartersData.isNotEmpty) {
        onProgress?.call(0.44, 'Guardando lotes (sedes)...');
        await _sbInsertHeadquarters(txn, headquartersData);
      }

      if (hqWeightsData != null && hqWeightsData.isNotEmpty) {
        onProgress?.call(0.46, 'Guardando pesos de lotes...');
        await _sbInsertHeadquartersWeights(txn, hqWeightsData);
      }

      if (newsData != null && newsData.isNotEmpty) {
        onProgress?.call(0.47, 'Guardando noticias...');
        await _sbInsertNews(txn, newsData);
      }

      if (hqCoordinatesData != null && hqCoordinatesData.isNotEmpty) {
        onProgress?.call(0.48, 'Guardando zonas de exclusión...');
        await _sbInsertHeadquartersCoordinates(txn, hqCoordinatesData);
      }

      debugPrint('✅ [SyncBase/BASE] Transacción completada');
    });

    // Cargar Headquarters al AppState (necesita la lectura, post-transacción)
    onProgress?.call(0.49, 'Actualizando estado de la aplicación...');
    await _sbLoadHeadquartersToAppState(db);

    // Actualizar activitiesJSON en AppState
    if (activitiesData.isNotEmpty) {
      FFAppState().activitiesJSON = _sbNormalizeActivities(activitiesData);
      debugPrint('✅ [SyncBase/BASE] activitiesJSON actualizado: ${activitiesData.length} actividades');
    }

    return true;
  } catch (e, st) {
    debugPrint('❌ [SyncBase/BASE] Error: $e');
    debugPrint('   Stack: $st');
    return false;
  } finally {
    try { await db?.close(); } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOQUE PRODUCTS — Inserta products + products_coordinates en su propia
// transacción. Asume que las tablas padre ya fueron pobladas por el
// bloque BASE (FKs).
// ═══════════════════════════════════════════════════════════════════════════
Future<bool> _sbSyncProductsToSQLite({
  required List<dynamic> productsData,
  List<dynamic>? productsCoordsData,
  void Function(double, String)? onProgress,
}) async {
  Database? db;
  try {
    db = await _sbOpenTunedDb();

    await db.transaction((txn) async {
      debugPrint('🔄 [SyncBase/PRODUCTS] Transacción iniciada');

      if (productsData.isNotEmpty) {
        onProgress?.call(0.70, 'Guardando productos/tags (${productsData.length})...');
        // Full-sync: limpiar antes de insertar → INSERT INTO es 2-3x más rápido que INSERT OR REPLACE
        await txn.execute('DELETE FROM Products_coordinates');
        await txn.execute('DELETE FROM Products');
        await _sbInsertProducts(txn, productsData);
        productsData.clear(); // liberar ~200k items mientras seguimos en TX
      }

      if (productsCoordsData != null && productsCoordsData.isNotEmpty) {
        onProgress?.call(0.76, 'Guardando coordenadas de productos (${productsCoordsData.length})...');
        await _sbInsertProductsCoordinates(txn, productsCoordsData);
        productsCoordsData.clear();
      }

      debugPrint('✅ [SyncBase/PRODUCTS] Transacción completada');
    });

    return true;
  } catch (e, st) {
    debugPrint('❌ [SyncBase/PRODUCTS] Error: $e');
    debugPrint('   Stack: $st');
    return false;
  } finally {
    try { await db?.close(); } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOQUE VIRTUAL-POINTS — Inserta virtual_points en su propia transacción.
// Asume que Types_points / Headquarters ya están en la base (BASE).
// ═══════════════════════════════════════════════════════════════════════════
Future<bool> _sbSyncVirtualPointsToSQLite({
  required List<dynamic> virtualPointsData,
  void Function(double, String)? onProgress,
}) async {
  Database? db;
  try {
    db = await _sbOpenTunedDb();

    await db.transaction((txn) async {
      debugPrint('🔄 [SyncBase/VPOINTS] Transacción iniciada');

      if (virtualPointsData.isNotEmpty) {
        onProgress?.call(0.95, 'Guardando puntos virtuales (${virtualPointsData.length})...');
        // Full-sync: limpiar antes de insertar → evita conflict check + double index update por fila
        await txn.execute('DELETE FROM Virtual_points');
        await _sbInsertVirtualPoints(txn, virtualPointsData);
        virtualPointsData.clear(); // liberar ~150k items mientras seguimos en TX
      }

      debugPrint('✅ [SyncBase/VPOINTS] Transacción completada');
    });

    return true;
  } catch (e, st) {
    debugPrint('❌ [SyncBase/VPOINTS] Error: $e');
    debugPrint('   Stack: $st');
    return false;
  } finally {
    try { await db?.close(); } catch (_) {}
  }
}

// ============================================================================
// LIMPIEZA DE TABLAS
// ============================================================================

Future<void> _sbCleanAllBaseTables(Transaction txn) async {
  debugPrint('🧹 [SyncBase] Limpiando tablas base...');
  // Tablas de visitas — NO se tocan (datos de campo del usuario)
  // Login_sessions — NO se toca (se regenera en syncLogin normal)
  await txn.delete('News');
  await txn.delete('Products_coordinates');
  await txn.delete('Products');
  await txn.delete('Virtual_points');
  await txn.delete('Headquarters_coordinates');
  await txn.delete('Headquarters_weights');
  await txn.delete('Headquarters_polygons');
  await txn.delete('Headquarters');
  await txn.delete('Activities_status');
  await txn.delete('Activities_steps');
  await txn.delete('Activities');
  await txn.delete('Zones_polygons');
  await txn.delete('Zones');
  await txn.delete('Companies');
  await txn.delete('Types_points');
  debugPrint('   ✅ Tablas limpiadas');
}

// ============================================================================
// FUNCIONES DE INSERCIÓN
// ============================================================================

Future<void> _sbInsertTypesPoints(Transaction txn, List<dynamic> types) async {
  debugPrint('📝 [SyncBase] Insertando ${types.length} Types_points...');
  final batch = txn.batch();
  for (final t in types) {
    batch.insert('Types_points', {
      'Id_type_point':       t['id_type_point'],
      'Name_type':           t['name_type'],
      'Color_type':          t['color_type'],
      'Order_type':          t['order_type'],
      'Virtual_points_count': t['virtual_points_count'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
  debugPrint('   ✅ ${types.length} tipos de puntos insertados');
}

Future<void> _sbInsertCompanies(Transaction txn, List<dynamic> companies) async {
  debugPrint('📝 [SyncBase] Insertando ${companies.length} Companies...');
  final batch = txn.batch();
  for (final c in companies) {
    batch.insert('Companies', {
      'Id_company':          c['id_company'],
      'Name_company':        c['name_company'],
      'Business_name':       c['business_name'],
      'Nit':                 c['nit'],
      'Address':             c['address'],
      'Telephone':           c['telephone'],
      'Id_zone_default':     c['id_zone_default'],
      'Latitude_extractor':  c['latitude_extractor'],
      'Longitude_extractor': c['longitude_extractor'],
      'Created_at':          c['created_at'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
  debugPrint('   ✅ ${companies.length} empresas insertadas');
}

Future<void> _sbInsertZones(Transaction txn, List<dynamic> zones) async {
  debugPrint('📝 [SyncBase] Insertando ${zones.length} Zones...');
  final batch = txn.batch();
  int polygons = 0;
  for (final z in zones) {
    batch.insert('Zones', {
      'Id_zone':     z['id_zone'],
      'Id_company':  z['id_company'],
      'Name_zone':   z['name_zone'],
      'Difficulty':  z['difficulty'] ?? 0,
      'State_zone':  z['state_zone'],
      'Created_at':  z['created_at'],
    });
    if (z['zones_polygons'] is List) {
      for (final p in z['zones_polygons']) {
        batch.insert('Zones_polygons', {
          'Id_zone_polygon': p['id_zone_polygon'],
          'Id_zone':         z['id_zone'],
          'Latitude':        p['latitude'],
          'Longitude':       p['longitude'],
          'Created_at':      p['created_at'],
        });
        polygons++;
      }
    }
  }
  await batch.commit(noResult: true);
  debugPrint('   ✅ ${zones.length} zonas + $polygons polígonos');
}


Future<void> _sbInsertActivities(
    Transaction txn, List<dynamic> activities) async {
  debugPrint('📝 [SyncBase] Insertando ${activities.length} Activities...');

  final List<Map<String, dynamic>> actRows    = [];
  final List<Map<String, dynamic>> stepRows   = [];
  final Set<int>                   statusIds  = {};
  final List<Map<String, dynamic>> statusRows = [];

  for (final a in activities) {
    actRows.add({
      'Id_activity':         a['id_activity'],
      'Id_company':          a['id_company'],
      'Id_activity_parent':  a['id_activity_parent'],
      'Name_activity':       a['name_activity'],
      'Group_activity':      a['group_activity'],
      'Unity':               a['unity'],
      'Type_activity':       a['type_activity'],
      'Type_effectivity':    a['type_effectivity'],
      'Cycle':               a['cycle'],
      'Effectivity_unitys':  a['effectivity_unitys'],
      'Effectivity_visits':  a['effectivity_visits'],
      'Module_activity':     a['module_activity'],
      'Description_activity':a['description_activity'],
      'Created_at':          a['created_at'],
      'Is_default':          0,
      'Is_sync':             (a['is_sync'] == true || a['is_sync'] == 1) ? 1 : 0,
      'Is_sync_full':        (a['is_sync_full'] == true || a['is_sync_full'] == 1) ? 1 : 0,
      'Tracking_headquarter':(a['tracking_headquarter'] == true || a['tracking_headquarter'] == 1) ? 1 : 0,
      'Read_default':        a['read_default'],
      'Color_activity':      a['color_activity'],
      'Icon_activity':       a['icon_activity'],
      'Visits_number':       a['visits_number'] ?? 0,
    });

    if (a['activity_steps'] is List) {
      for (final s in a['activity_steps']) {
        stepRows.add({
          'Id_activity_step': s['id_activity_step'],
          'Id_activity':      s['id_activity'],
          'Type_step':        s['type_step'],
          'Order_step':       s['order_step'],
          'Default_value':    s['default_value'],
          'Unity':            s['unity'],
          'Calculation':      s['calculation'],
          'Name_step':        s['name_step'],
          'Status':           s['status'],
          'Is_required':      s['is_required'] == true ? 1 : 0,
        });
        if (s['activity_step_parent'] != null) {
          _sbCollectStatusRecursive(s['activity_step_parent'], statusIds, statusRows);
        }
        if (s['activities_status'] is List) {
          for (final cs in s['activities_status']) {
            _sbCollectStatusRecursive(cs, statusIds, statusRows);
          }
        }
      }
    }
    if (a['activity_status'] is List) {
      for (final st in a['activity_status']) {
        _sbCollectStatusRecursive(st, statusIds, statusRows);
      }
    }
  }

  // Activities: pocos registros → un solo batch
  final actBatch = txn.batch();
  for (final r in actRows) { actBatch.insert('Activities', r); }
  await actBatch.commit(noResult: true);

  // Steps: potencialmente miles → chunks de 500 para no saturar el platform channel
  for (int i = 0; i < stepRows.length; i += 500) {
    final chunk = stepRows.sublist(i, (i + 500).clamp(0, stepRows.length));
    final b = txn.batch();
    for (final r in chunk) { b.insert('Activities_steps', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    await b.commit(noResult: true);
    await Future.delayed(Duration.zero);
  }

  // Status: potencialmente miles (árbol recursivo) → chunks de 500
  for (int i = 0; i < statusRows.length; i += 500) {
    final chunk = statusRows.sublist(i, (i + 500).clamp(0, statusRows.length));
    final b = txn.batch();
    for (final r in chunk) { b.insert('Activities_status', r, conflictAlgorithm: ConflictAlgorithm.ignore); }
    await b.commit(noResult: true);
    await Future.delayed(Duration.zero);
  }

  final factorPositive = statusRows.where((r) => (_sbToInt(r['Factor']) ?? 0) > 0).length;
  debugPrint('   ✅ ${actRows.length} actividades | ${stepRows.length} pasos | ${statusRows.length} estados');
  debugPrint('   🔢 Factor>0: $factorPositive / ${statusRows.length} estados (diagnóstico RESULTS NFC)');
}

void _sbCollectStatusRecursive(
  dynamic status,
  Set<int> ids,
  List<Map<String, dynamic>> rows,
) {
  if (status is! Map) return;
  final id = status['id_activity_status'];
  if (id == null || ids.contains(id)) return;
  ids.add(id);
  rows.add({
    'Id_activity_status':        id,
    'Id_activity':               status['id_activity'],
    'Id_activity_step_parent':   status['id_activity_step_parent'],
    'Id_activity_status_parent': status['id_activity_status_parent'],
    'Type_status':               status['type_status'],
    'Order_status':              status['order_status'],
    'Default_status':            status['default_status'],
    'Status_name':               status['status_name'],
    'Color':                     status['color'],
    'Peso':                      status['peso'],
    'Castigo':                   status['castigo'],
    'Boton':                     status['boton'],
    'Factor':               _sbToInt(status['factor']),
    'Status':               status['status'],
    'Description_status':   status['description_status'],
    'Alternative_status':   status['alternative_status'],
    'Remember_status':      (status['remember_status'] == true) ? 1 : 0,
    'Tracking_constant':    (status['tracking_constant'] == true) ? 1 : 0,
  });
  if (status['activities_status_childs'] is List) {
    for (final c in status['activities_status_childs']) {
      _sbCollectStatusRecursive(c, ids, rows);
    }
  }
}

/// INSERT fresco de Headquarters (DELETE+INSERT, no MERGE) para base sync
Future<void> _sbInsertHeadquarters(Transaction txn, List<dynamic> headquarters) async {
  debugPrint('📝 [SyncBase] Insertando ${headquarters.length} Headquarters...');

  final List<Map<String, dynamic>> hqRows  = [];
  final List<Map<String, dynamic>> polRows = [];

  for (final hq in headquarters) {
    final hqId = (hq['id_headquarter'] as num?)?.toInt();
    if (hqId == null) continue;

    hqRows.add({
      'Id_headquarter':       hqId,
      'Id_zone':              hq['id_zone'],
      'Created_at':           hq['created_at'],
      'Name_headquarter':     hq['name_headquarter'],
      'Density_headquarter':  hq['density_headquarter'],
      'Seed_time':            hq['seed_time'],
      'State_headquarter':    hq['state_headquarter'],
      'Area_headquarter':     hq['area_headquarter'],
      'Polygon':              hq['polygon'],
      'Centroid_coordinate':  hq['centroid_coordinate'],
    });

    if (hq['headquarters_polygons'] is List) {
      for (final p in hq['headquarters_polygons']) {
        if (p['latitude'] != null && p['longitude'] != null) {
          polRows.add({
            'Id_headquarter_polygon': p['id_headquarter_polygon'],
            'Id_headquarter':         hqId,
            'Latitude':               p['latitude'],
            'Longitude':              p['longitude'],
            'Created_at':             p['created_at'],
          });
        }
      }
    } else if (hq['polygon'] is String && (hq['polygon'] as String).isNotEmpty) {
      try {
        final List<dynamic> pts = jsonDecode(hq['polygon']);
        int tempId = hqId * 10000;
        final now  = DateTime.now().toIso8601String();
        for (final pt in pts) {
          final lat = pt['LAT'] as num?;
          final lon = pt['LON'] as num?;
          if (lat != null && lon != null) {
            polRows.add({
              'Id_headquarter_polygon': tempId++,
              'Id_headquarter':         hqId,
              'Latitude':               lat.toDouble(),
              'Longitude':              lon.toDouble(),
              'Created_at':             now,
            });
          }
        }
      } catch (_) {}
    }
  }

  // HQ rows: pocos registros → un solo batch
  final hqBatch = txn.batch();
  for (final r in hqRows) { hqBatch.insert('Headquarters', r, conflictAlgorithm: ConflictAlgorithm.replace); }
  await hqBatch.commit(noResult: true);

  // Polygon rows: pueden ser miles de puntos → chunks de 500
  for (int i = 0; i < polRows.length; i += 500) {
    final chunk = polRows.sublist(i, (i + 500).clamp(0, polRows.length));
    final b = txn.batch();
    for (final r in chunk) { b.insert('Headquarters_polygons', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    await b.commit(noResult: true);
    await Future.delayed(Duration.zero);
  }

  debugPrint('   ✅ ${hqRows.length} lotes + ${polRows.length} polígonos');
}

Future<void> _sbInsertHeadquartersWeights(Transaction txn, List<dynamic> weights) async {
  debugPrint('📝 [SyncBase] Insertando ${weights.length} Headquarters_weights...');
  final batch = txn.batch();
  for (final w in weights) {
    batch.insert('Headquarters_weights', {
      'Id_headquarter_weight': w['id_headquarter_weight'],
      'Id_headquarter':        w['id_headquarter'],
      'Id_company':            w['id_company'],
      'Date_year':             w['date_year'],
      'Date_month':            w['date_month'],
      'Weight':                (w['weight'] ?? 0).toDouble(),
      'Created_at':            w['created_at'],
      'Modified_at':           w['modified_at'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
  debugPrint('   ✅ ${weights.length} pesos insertados');
}

Future<void> _sbInsertNews(Transaction txn, List<dynamic> news) async {
  debugPrint('📝 [SyncBase] Insertando ${news.length} News...');
  final batch = txn.batch();
  for (final n in news) {
    batch.insert('News', {
      'Id_new':               n['id_new'],
      'Id_company':           n['id_company'],
      'Name_new':             n['name_new'] ?? n['title_new'],
      'Descripcion_activity': n['descripcion_activity'] ?? n['description_new'],
      'Order_display':        n['order_display'] ?? 0,
      'Url_image':            n['url_image'],
      'Type_new':             n['type_new'],
      'Created_at':           n['created_at'],
      'Modified_at':          n['modified_at'],
      'State_new':            n['state_new'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
  debugPrint('   ✅ ${news.length} noticias insertadas');
}

/// Inserta Products + Products_coordinates para TODOS los lotes de la empresa.
/// Usa inserción en chunks de a 71 products / 249 coordenadas (límite 999 bind params SQLite).
Future<void> _sbInsertProducts(Transaction txn, List<dynamic> products) async {
  debugPrint('📝 [SyncBase] Insertando ${products.length} Products (todos los lotes)...');

  const int productFields = 16; // Id_product..Palm + Id_rfid + Sync_status
  const int productChunk  = 999 ~/ productFields; // 62

  final List<List<dynamic>> productRows = [];
  final String now = DateTime.now().toIso8601String();

  for (final p in products) {
    productRows.add([
      p['id_product'],
      p['id_headquarter'],
      p['id_company'] ?? 0,
      p['id_type'] ?? 0,
      p['created_at'] ?? now,
      p['modified_at'] ?? now,
      p['type_product'],
      p['name_product'],
      p['rfid'],
      p['id_rfid'],
      p['state_product'],
      p['description_product'],
      p['location_raw'],
      p['line'],
      p['palm'],
      'synced',
    ]);
  }

  const String productCols = 'Id_product, Id_headquarter, Id_company, Id_type, '
      'Created_at, Modified_at, Type_product, Name_product, '
      'Rfid, Id_rfid, State_product, Description_product, Location_raw, Line, Palm, Sync_status';
  final String productPH = '(${List.filled(productFields, '?').join(',')})';

  for (int i = 0; i < productRows.length; i += productChunk) {
    final chunk  = productRows.sublist(i, (i + productChunk).clamp(0, productRows.length));
    final params = chunk.expand((r) => r).toList();
    await txn.rawInsert(
      'INSERT INTO Products ($productCols) VALUES ${List.filled(chunk.length, productPH).join(',')}',
      params,
    );
    await Future.delayed(Duration.zero); // ceder event loop → evita ANR
  }

  debugPrint('   ✅ ${productRows.length} productos insertados');
}

Future<void> _sbInsertProductsCoordinates(Transaction txn, List<dynamic> coords) async {
  debugPrint('📝 [SyncBase] Insertando ${coords.length} Products_coordinates...');

  const int coordChunk = 999 ~/ 4; // 4 campos → 249 por chunk

  final rows = <List<dynamic>>[];
  for (final c in coords) {
    if (c['latitude'] != null && c['longitude'] != null) {
      rows.add([c['id_product_coordenate'], c['id_product'], c['latitude'], c['longitude']]);
    }
  }

  for (int i = 0; i < rows.length; i += coordChunk) {
    final chunk  = rows.sublist(i, (i + coordChunk).clamp(0, rows.length));
    final params = chunk.expand((r) => r).toList();
    await txn.rawInsert(
      'INSERT INTO Products_coordinates (Id_product_coordenate, Id_product, Latitude, Longitude) VALUES '
      '${List.filled(chunk.length, '(?,?,?,?)').join(',')}',
      params,
    );
    await Future.delayed(Duration.zero);
  }

  debugPrint('   ✅ ${rows.length} coordenadas de productos insertadas');
}

Future<void> _sbInsertVirtualPoints(Transaction txn, List<dynamic> points) async {
  debugPrint('📝 [SyncBase] Insertando ${points.length} Virtual_points...');

  const int vpFields = 14;
  const int vpChunk  = 999 ~/ vpFields; // = 71 registros por chunk

  // Pre-construir filas para evitar accesos repetidos a Map dentro del loop SQL
  final rows = <List<dynamic>>[];
  final now  = DateTime.now().toIso8601String();
  for (final p in points) {
    rows.add([
      p['id_virtual_point'],
      p['id_headquarter'],
      p['id_type_point'],
      p['line_number'],
      p['point_number'],
      p['latitude'],
      p['longitude'],
      p['description_virtual_point'],
      p['generation_method'],
      p['created_date'] ?? now,
      (p['is_active'] == true || p['is_active'] == 1) ? 1 : 0,
      p['headquarter_name'],
      p['type_point_name'],
      p['point_display_name'],
    ]);
  }

  const cols = 'Id_virtual_point,Id_headquarter,Id_type_point,Line_number,'
      'Point_number,Latitude,Longitude,Description_virtual_point,'
      'Generation_method,Created_date,Is_active,Headquarter_name,'
      'Type_point_name,Point_display_name';

  for (int i = 0; i < rows.length; i += vpChunk) {
    final chunk  = rows.sublist(i, (i + vpChunk).clamp(0, rows.length));
    final params = chunk.expand((r) => r).toList();
    await txn.rawInsert(
      'INSERT INTO Virtual_points ($cols) VALUES '
      '${List.filled(chunk.length, "(?,?,?,?,?,?,?,?,?,?,?,?,?,?)").join(",")}',
      params,
    );
    await Future.delayed(Duration.zero); // ceder event loop → evita ANR
  }

  debugPrint('   ✅ ${rows.length} puntos virtuales insertados');
}

Future<void> _sbInsertHeadquartersCoordinates(Transaction txn, List<dynamic> coords) async {
  debugPrint('📝 [SyncBase] Insertando ${coords.length} Headquarters_coordinates...');
  final now = DateTime.now().toIso8601String();
  for (int i = 0; i < coords.length; i += 500) {
    final chunk = coords.sublist(i, (i + 500).clamp(0, coords.length));
    final b = txn.batch();
    for (final c in chunk) {
      b.insert('Headquarters_coordinates', {
        'Id_polygon_coordinate':   c['id_polygon_coordinate'],
        'Id_headquarter':          c['id_headquarter'],
        'Name_polygon_coordinate': c['name_polygon_coordinate'],
        'Coordinates_raw':         c['coordinates_raw'],
        'Point_type':              c['point_type'],
        'Id_type_point':           c['id_type_point'],
        'Created_at':              c['created_at'] ?? now,
        'Modified_at':             c['modified_at'] ?? now,
        'Is_active':               (c['is_active'] == true || c['is_active'] == 1) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
    await Future.delayed(Duration.zero);
  }
  debugPrint('   ✅ ${coords.length} coordenadas de exclusión insertadas');
}

// ============================================================================
// CARGAR HEADQUARTERS AL APPSTATE
// ============================================================================

Future<void> _sbLoadHeadquartersToAppState(Database db) async {
  try {
    final rows = await db.query(
      'Headquarters',
      columns: ['Id_headquarter', 'Id_zone', 'Created_at', 'Name_headquarter',
                 'Density_headquarter', 'Seed_time', 'State_headquarter',
                 'Area_headquarter', 'Polygon'],
      orderBy: 'Name_headquarter ASC',
    );
    final list = rows.map((r) => HeadquartersStruct(
      idHeadquarter:       r['Id_headquarter'] as int?,
      idZone:              r['Id_zone'] as int?,
      createdAt:           r['Created_at'] as String?,
      nameHeadquarter:     r['Name_headquarter'] as String?,
      densityHeadquarter:  r['Density_headquarter'] != null ? (r['Density_headquarter'] as num).toInt() : null,
      seedTime:            r['Seed_time'] as String?,
      stateHeadquarter:    r['State_headquarter'] as String?,
      areaHeadquarter:     r['Area_headquarter'] != null ? (r['Area_headquarter'] as num).toDouble() : null,
      polygon:             r['Polygon'] as String?,
    )).toList();
    FFAppState().headquartersList = list;
    debugPrint('✅ [SyncBase] headquartersList → ${list.length} lotes cargados');
  } catch (e) {
    debugPrint('⚠️ [SyncBase] Error cargando headquarters al AppState: $e');
  }
}

// ============================================================================
// NORMALIZACIÓN DE ACTIVITIES PARA EL FORMULARIO
// ============================================================================

List<dynamic> _sbNormalizeActivities(List<dynamic> activities) {
  return activities.map((activity) {
    if (activity is! Map) return activity;
    final act = Map<String, dynamic>.from(activity);
    final steps = act['activity_steps'];
    if (steps is List) {
      act['activity_steps'] = steps.map((step) {
        if (step is! Map) return step;
        final s   = Map<String, dynamic>.from(step);
        final raw = s['activities_status'] ?? s['activity_status'];
        final norm = (raw is List) ? raw.map(_sbNormalizeStatus).toList() : <dynamic>[];
        s['activities_status'] = norm;
        s['activity_status']   = norm;
        return s;
      }).toList();
    }
    final rootStatus = act['activity_status'];
    if (rootStatus is List) {
      act['activity_status'] = rootStatus.map(_sbNormalizeStatus).toList();
    }
    return act;
  }).toList();
}

Map<String, dynamic> _sbNormalizeStatus(dynamic status) {
  if (status is! Map) return {};
  final s      = Map<String, dynamic>.from(status);
  final childs = s['activities_status_childs'] ?? s['status_childs'];
  if (childs is List) {
    final norm = childs.map(_sbNormalizeStatus).toList();
    s['activities_status_childs'] = norm;
    s['status_childs']            = norm;
  } else {
    s['activities_status_childs'] = <dynamic>[];
    s['status_childs']            = <dynamic>[];
  }
  return s;
}
