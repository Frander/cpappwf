import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/main.dart' show rootScaffoldMessengerKey;

// ============================================================================
// MODELOS
// ============================================================================

class ZoneTile {
  final int id;
  final int idZone;
  final String urlTile;
  final String createdAt;
  final int displayPriority;

  /// Extrae el relativePath del url_tile (sin trailing slash).
  /// Ej: "https://...s3.../Resources/Files_tiles/6_Palmeiras/30_Palmeiras/vuelo16_.../"
  ///   → "6_Palmeiras/30_Palmeiras/vuelo16_..."
  String get relativePath {
    const prefix = '/Resources/Files_tiles/';
    final uri = Uri.tryParse(urlTile);
    final uriPath = uri?.path ?? '';
    final idx = uriPath.indexOf(prefix);
    if (idx == -1) return urlTile.trimRight().replaceAll(RegExp(r'/$'), '');
    return uriPath.substring(idx + prefix.length).replaceAll(RegExp(r'/$'), '');
  }

  /// URL base del tile (con trailing slash) tal como viene en url_tile.
  /// Usamos esto directamente para construir las URLs de descarga,
  /// evitando hardcodear la región de S3.
  String get tileBaseUrl {
    final url = urlTile.trim();
    return url.endsWith('/') ? url : '$url/';
  }

  String get displayName {
    final parts = relativePath.split('/');
    // Quitar primer segmento (carpeta de empresa) si hay más de uno
    if (parts.length >= 3) return parts.sublist(1).join(' / ');
    if (parts.length == 2) return parts[1];
    return parts.first;
  }

  ZoneTile({
    required this.id,
    required this.idZone,
    required this.urlTile,
    required this.createdAt,
    required this.displayPriority,
  });

  factory ZoneTile.fromJson(Map<String, dynamic> json) => ZoneTile(
        id: json['id_zone_tile'] ?? json['id'] ?? 0,
        idZone: json['id_zone'] ?? 0,
        urlTile: json['url_tile'] ?? '',
        createdAt: json['created_at'] ?? '',
        displayPriority: json['display_priority'] ?? 0,
      );
}

class OrtomosaicInfo {
  final String path;
  final String zoneName;
  final int tileCount;
  final int totalBytes;
  final String downloadedAt;
  final int minZoom, maxZoom;

  OrtomosaicInfo({
    required this.path,
    required this.zoneName,
    required this.tileCount,
    required this.totalBytes,
    required this.downloadedAt,
    required this.minZoom,
    required this.maxZoom,
  });

  factory OrtomosaicInfo.fromMap(Map<String, dynamic> m) => OrtomosaicInfo(
        path: m['path'] as String,
        zoneName: m['zone_name'] as String? ?? '',
        tileCount: m['tile_count'] as int? ?? 0,
        totalBytes: m['total_bytes'] as int? ?? 0,
        downloadedAt: m['downloaded_at'] as String? ?? '',
        minZoom: m['min_zoom'] as int? ?? 16,
        maxZoom: m['max_zoom'] as int? ?? 21,
      );
}

/// Información de un tile individual tal como lo devuelve /S3Files/list
class _TileEntry {
  final int z, x, y;
  final int sizeBytes;
  const _TileEntry(this.z, this.x, this.y, this.sizeBytes);
}

class OrtomosaicDownloadProgress {
  final String zonePath;
  final String zoneName;
  final int downloadedTiles;
  final int totalTiles;
  final int downloadedBytes;
  final int expectedTotalBytes; // obtenido de /S3Files/list (suma real de tamaños)
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;
  final bool isCancelled;

  OrtomosaicDownloadProgress({
    required this.zonePath,
    required this.zoneName,
    required this.downloadedTiles,
    required this.totalTiles,
    required this.downloadedBytes,
    this.expectedTotalBytes = 0,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
    this.isCancelled = false,
  });

  /// Fracción basada en bytes reales si los conocemos, si no en tiles
  double get fraction {
    if (expectedTotalBytes > 0) {
      return (downloadedBytes / expectedTotalBytes).clamp(0.0, 1.0);
    }
    return totalTiles == 0 ? 0.0 : (downloadedTiles / totalTiles).clamp(0.0, 1.0);
  }

  String get downloadedMB => (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
  String get totalMB => expectedTotalBytes > 0
      ? (expectedTotalBytes / (1024 * 1024)).toStringAsFixed(1)
      : '?';
  String get percent => '${(fraction * 100).toStringAsFixed(0)}%';
  bool get isActive => !isComplete && !hasError && !isCancelled;
}

// ============================================================================
// SERVICIO PRINCIPAL
// ============================================================================

class OrtomosaicDownloadService {
  static final OrtomosaicDownloadService _instance =
      OrtomosaicDownloadService._internal();
  factory OrtomosaicDownloadService() => _instance;
  OrtomosaicDownloadService._internal();

  static const String _apiBase = 'https://api.clickpalm.com';
  // La URL base de S3 se extrae directamente de url_tile por zona (puede ser us-east-1 o us-west-2)
  static const int _minZoom = 16;
  static const int _maxZoom = 21;
  static const int _concurrency = 6;

  // ── Estado ──────────────────────────────────────────────────────────────
  Database? _db;
  String? _basePath; // /ClickPalmData/Ortomosaics

  final Map<String, OrtomosaicDownloadProgress> _activeDownloads = {};
  final Map<String, bool> _cancelFlags = {};

  // Caché de tamaños estimados por relativePath (de /S3Files/folder-structure)
  final Map<String, int> _expectedBytes = {};

  final _progressController =
      StreamController<Map<String, OrtomosaicDownloadProgress>>.broadcast();
  Stream<Map<String, OrtomosaicDownloadProgress>> get progressStream =>
      _progressController.stream;

  Map<String, OrtomosaicDownloadProgress> get activeDownloads =>
      Map.unmodifiable(_activeDownloads);
  bool get hasActiveDownloads =>
      _activeDownloads.values.any((p) => p.isActive);
  bool isDownloading(String path) =>
      _activeDownloads[path]?.isActive ?? false;

  // ── Rutas ────────────────────────────────────────────────────────────────

  Future<String> _getBasePath() async {
    if (_basePath != null) return _basePath!;
    late Directory base;
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      base = ext ?? await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    _basePath = '${base.path}/ClickPalmData/Ortomosaics';
    await Directory(_basePath!).create(recursive: true);
    return _basePath!;
  }

  String _tilePath(String basePath, String rPath, int z, int x, int y) =>
      p.join(basePath, rPath, z.toString(), x.toString(), '$y.png');

  // ── Base de datos (solo índice, sin BLOBs) ───────────────────────────────

  Future<Database> _getDb() async {
    if (_db != null && _db!.isOpen) return _db!;
    final base = await _getBasePath();
    final dbPath = p.join(p.dirname(base), 'Maps', 'ortomosaics.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, _) => _createTables(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('DROP TABLE IF EXISTS tiles');
          await _createTables(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    // Solo índice: nada de BLOBs, los archivos están en el filesystem
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ortomosaics (
        path          TEXT PRIMARY KEY,
        zone_name     TEXT,
        min_zoom      INTEGER,
        max_zoom      INTEGER,
        tile_count    INTEGER,
        total_bytes   INTEGER,
        downloaded_at TEXT
      )
    ''');
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future<List<ZoneTile>> fetchActiveZones() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
    final resp = await dio.get('$_apiBase/ZonesTiles/active');
    final List data = resp.data is List ? resp.data : [];
    return data.map((e) => ZoneTile.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Obtiene el tamaño estimado por zona usando /S3Files/folder-structure.
  /// Agrupa por carpeta raíz → 1 llamada por carpeta (ej: ~4 calls para 19 zonas).
  /// Obtiene el tamaño estimado por zona.
  /// Usa la raíz del primer registro (el más reciente del API) para hacer
  /// UNA SOLA llamada a /S3Files/folder-structure y distribuir el total
  /// entre las zonas que comparten esa misma raíz.
  Future<Map<String, int>> fetchFolderSizes(List<ZoneTile> zones) async {
    if (zones.isEmpty) return {};

    // La raíz base = primer segmento del relativePath del registro más reciente
    final primaryRoot = zones.first.relativePath.split('/').first;
    final primaryZones = zones
        .where((z) => z.relativePath.split('/').first == primaryRoot)
        .toList();

    final result = <String, int>{};

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
      final resp = await dio.get(
        '$_apiBase/S3Files/folder-structure',
        queryParameters: {
          'prefix': 'Resources/Files_tiles/$primaryRoot',
          'maxDepth': -1,
          'summaryOnly': true,
        },
      );

      final stats = resp.data?['data']?['statistics'];
      final totalSize = (stats?['totalSize'] as num?)?.toInt() ?? 0;

      debugPrint(
          '📦 $primaryRoot: ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB, '
          '${primaryZones.length} zonas activas');

      final sizePerZone =
          primaryZones.isEmpty ? 0 : totalSize ~/ primaryZones.length;

      for (final z in primaryZones) {
        result[z.relativePath] = sizePerZone;
        _expectedBytes[z.relativePath] = sizePerZone;
      }
    } catch (e) {
      debugPrint('⚠️ fetchFolderSizes ($primaryRoot): $e');
    }

    return result;
  }

  /// Extrae la lista de archivos de la respuesta del API /S3Files/list,
  /// independientemente de si viene como List directo o anidado en un Map.
  List<dynamic> _extractFileList(dynamic rawData) {
    if (rawData is List) return rawData;
    if (rawData is Map) {
      for (final key in ['files', 'items', 'contents', 'data', 'objects', 'results']) {
        final val = rawData[key];
        if (val is List) return val;
      }
      // Buscar recursivamente en 'data' si es un Map
      final data = rawData['data'];
      if (data is Map) {
        for (final key in ['files', 'items', 'contents', 'objects', 'results']) {
          final val = data[key];
          if (val is List) return val;
        }
      }
    }
    return [];
  }

  /// Obtiene la lista exacta de tiles de una zona usando /S3Files/list.
  /// Una sola llamada → lista plana de todos los archivos .png.
  /// Retorna los tile entries con z/x/y y su tamaño real en bytes.
  Future<List<_TileEntry>> _listTilesFromAPI(String rPath) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
    ));

    debugPrint('🔍 Listando tiles de $rPath...');

    // /S3Files/list devuelve lista plana de archivos con sus metadatos
    final resp = await dio.get(
      '$_apiBase/S3Files/list',
      queryParameters: {
        'prefix': 'Resources/Files_tiles/$rPath/',
        'maxKeys': 100000, // más que suficiente para cualquier zona
      },
    );

    final rawData = resp.data;
    debugPrint('📋 /S3Files/list keys: ${rawData is Map ? rawData.keys.toList() : rawData.runtimeType}');

    List<dynamic> files = _extractFileList(rawData);

    final entries = <_TileEntry>[];

    for (final file in files) {
      if (file is! Map) continue;

      // Obtener la clave/path del archivo
      final key = (file['key'] ?? file['Key'] ?? file['path'] ?? file['name'] ?? '')
          .toString();

      if (!key.endsWith('.png')) continue;

      // Parsear z/x/y del path: .../{rPath}/{z}/{x}/{y}.png
      final parts = key.split('/');
      if (parts.length < 3) continue;

      final yStr = parts.last.replaceAll('.png', '');
      final x = int.tryParse(parts[parts.length - 2]);
      final z = int.tryParse(parts[parts.length - 3]);
      final y = int.tryParse(yStr);

      if (z == null || x == null || y == null) continue;
      if (z < _minZoom || z > _maxZoom) continue;

      final sizeBytes = (file['size'] ?? file['Size'] ?? file['fileSize'] ?? 0)
          as int? ?? 0;

      entries.add(_TileEntry(z, x, y, sizeBytes));
    }

    debugPrint('✅ $rPath: ${entries.length} tiles encontrados');
    return entries;
  }

  // ── DESCARGA ─────────────────────────────────────────────────────────────

  Future<void> downloadZone(ZoneTile zone) async {
    final path = zone.relativePath;
    if (_activeDownloads[path]?.isActive ?? false) return;

    _cancelFlags[path] = false;
    _updateProgress(OrtomosaicDownloadProgress(
      zonePath: path,
      zoneName: zone.displayName,
      downloadedTiles: 0,
      totalTiles: 0,
      downloadedBytes: 0,
      expectedTotalBytes: _expectedBytes[path] ?? 0,
    ));

    // Ejecutar en background sin await — no bloquea la UI
    _runDownload(zone).catchError((e) {
      debugPrint('❌ downloadZone fatal ($path): $e');
      _updateProgress(OrtomosaicDownloadProgress(
        zonePath: path,
        zoneName: zone.displayName,
        downloadedTiles: 0,
        totalTiles: 1,
        downloadedBytes: 0,
        hasError: true,
        errorMessage: e.toString(),
      ));
    });
  }

  Future<void> _runDownload(ZoneTile zone) async {
    final rPath = zone.relativePath;
    final tileBaseUrl = zone.tileBaseUrl; // URL base con región correcta de S3
    final name = zone.displayName;

    int downloaded = 0;
    int bytesDownloaded = 0;

    try {
      final basePath = await _getBasePath();
      final db = await _getDb();

      // ── Paso 1: Obtener lista exacta de tiles vía API ──────────────────
      final tiles = await _listTilesFromAPI(rPath);
      final total = tiles.length;

      if (total == 0) {
        _updateProgress(OrtomosaicDownloadProgress(
          zonePath: rPath, zoneName: name,
          downloadedTiles: 0, totalTiles: 0, downloadedBytes: 0,
          hasError: true,
          errorMessage: 'No se encontraron tiles para esta zona. '
              'Verifica que el ortomosaico esté publicado en S3.',
        ));
        return;
      }

      // Tamaño total real = suma de tamaños individuales de /S3Files/list
      final realTotalBytes = tiles.fold<int>(0, (s, t) => s + t.sizeBytes);
      // Si la API no devolvió tamaños individuales, usar el estimado del folder
      final expectedBytes = realTotalBytes > 0
          ? realTotalBytes
          : (_expectedBytes[rPath] ?? 0);

      debugPrint('🛰️ $name: $total tiles, ~${(expectedBytes / 1024 / 1024).toStringAsFixed(1)} MB');

      _updateProgress(OrtomosaicDownloadProgress(
        zonePath: rPath, zoneName: name,
        downloadedTiles: 0, totalTiles: total,
        downloadedBytes: 0, expectedTotalBytes: expectedBytes,
      ));

      // ── Paso 2: Crear estructura de carpetas base ──────────────────────
      // Las subcarpetas se crean al escribir cada tile

      // ── Paso 3: Descargar en lotes de _concurrency ────────────────────
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ));

      for (int i = 0; i < tiles.length; i += _concurrency) {
        if (_cancelFlags[rPath] == true) break;

        final chunk = tiles.skip(i).take(_concurrency).toList();

        await Future.wait(chunk.map((tile) async {
          if (_cancelFlags[rPath] == true) return;

          final filePath = _tilePath(basePath, rPath, tile.z, tile.x, tile.y);

          // Saltar si ya existe (reanudación)
          if (File(filePath).existsSync()) {
            downloaded++;
            bytesDownloaded += tile.sizeBytes;
            return;
          }

          final url = '$tileBaseUrl${tile.z}/${tile.x}/${tile.y}.png';

          try {
            // Crear directorio antes de descargar
            await Directory(p.dirname(filePath)).create(recursive: true);

            await dio.download(
              url,
              filePath,
              options: Options(responseType: ResponseType.bytes),
            );

            final fileSize = await File(filePath).length();
            bytesDownloaded += fileSize;
          } catch (_) {
            // Tile no disponible en S3 → skip silencioso
          }

          downloaded++;
          _updateProgress(OrtomosaicDownloadProgress(
            zonePath: rPath, zoneName: name,
            downloadedTiles: downloaded, totalTiles: total,
            downloadedBytes: bytesDownloaded, expectedTotalBytes: expectedBytes,
          ));
        }));
      }

      if (_cancelFlags[rPath] == true) {
        _updateProgress(OrtomosaicDownloadProgress(
          zonePath: rPath, zoneName: name,
          downloadedTiles: downloaded, totalTiles: total,
          downloadedBytes: bytesDownloaded, expectedTotalBytes: expectedBytes,
          isCancelled: true,
        ));
        _cancelFlags.remove(rPath);
        return;
      }

      // ── Paso 4: Registrar en el índice SQLite ──────────────────────────
      await db.insert(
        'ortomosaics',
        {
          'path': rPath,
          'zone_name': name,
          'min_zoom': _minZoom,
          'max_zoom': _maxZoom,
          'tile_count': downloaded,
          'total_bytes': bytesDownloaded,
          'downloaded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Actualizar AppState
      FFAppState().update(() => FFAppState().hasOrtomosaics = true);

      _updateProgress(OrtomosaicDownloadProgress(
        zonePath: rPath, zoneName: name,
        downloadedTiles: downloaded, totalTiles: total,
        downloadedBytes: bytesDownloaded, expectedTotalBytes: expectedBytes,
        isComplete: true,
      ));

      debugPrint('✅ $name: $downloaded tiles guardados en $basePath/$rPath');
    } catch (e) {
      debugPrint('❌ _runDownload ($name): $e');
      _updateProgress(OrtomosaicDownloadProgress(
        zonePath: rPath, zoneName: name,
        downloadedTiles: downloaded, totalTiles: 1,
        downloadedBytes: bytesDownloaded,
        hasError: true, errorMessage: e.toString(),
      ));
    } finally {
      _cancelFlags.remove(rPath);
    }
  }

  // ── Control ──────────────────────────────────────────────────────────────

  void cancelDownload(String path) {
    _cancelFlags[path] = true;
    debugPrint('⏹️ Cancelando: $path');
  }

  void cancelAll() {
    for (final k in _cancelFlags.keys.toList()) {
      _cancelFlags[k] = true;
    }
  }

  // ── Consultas ────────────────────────────────────────────────────────────

  Future<List<OrtomosaicInfo>> getDownloadedOrtomosaics() async {
    final db = await _getDb();
    final rows = await db.query('ortomosaics');
    return rows.map(OrtomosaicInfo.fromMap).toList();
  }

  Future<OrtomosaicInfo?> getOrtomosaicInfo(String relativePath) async {
    final db = await _getDb();
    final rows = await db.query('ortomosaics',
        where: 'path = ?', whereArgs: [relativePath]);
    if (rows.isEmpty) return null;
    return OrtomosaicInfo.fromMap(rows.first);
  }

  Future<void> deleteZone(String relativePath) async {
    final db = await _getDb();
    final basePath = await _getBasePath();

    // Eliminar archivos del filesystem
    final dir = Directory(p.join(basePath, relativePath));
    if (await dir.exists()) await dir.delete(recursive: true);

    // Eliminar del índice
    await db.delete('ortomosaics', where: 'path = ?', whereArgs: [relativePath]);
    _activeDownloads.remove(relativePath);
    _emit();

    // Actualizar AppState
    final remaining = await db.rawQuery('SELECT COUNT(*) as c FROM ortomosaics');
    final count = Sqflite.firstIntValue(remaining) ?? 0;
    FFAppState().update(() => FFAppState().hasOrtomosaics = count > 0);

    debugPrint('🗑️ $relativePath eliminado (quedan $count zonas)');
  }

  Future<Database> getDatabase() async => _getDb();

  /// Devuelve la ruta base donde están los tiles en el filesystem.
  Future<String> getTilesBasePath() async => _getBasePath();

  // ── Progreso ─────────────────────────────────────────────────────────────

  void _updateProgress(OrtomosaicDownloadProgress prog) {
    _activeDownloads[prog.zonePath] = prog;
    _emit();
  }

  // ── SnackBar global de progreso ─────────────────────────────────────────
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackCtrl;

  void _emit() {
    if (!_progressController.isClosed) {
      _progressController.add(Map.unmodifiable(_activeDownloads));
    }
    _syncGlobalSnackBar();
  }

  void _syncGlobalSnackBar() {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final actives = _activeDownloads.values.where((p) => p.isActive).toList();

    if (actives.isEmpty) {
      // Verificar si hay alguno recién completado/error para mostrar brevemente
      final done = _activeDownloads.values
          .where((p) => p.isComplete || p.hasError)
          .toList();
      if (done.isNotEmpty) {
        final first = done.first;
        messenger.hideCurrentSnackBar();
        _snackCtrl = null;
        messenger.showSnackBar(SnackBar(
          content: Text(
            first.isComplete
                ? '✓ ${first.zoneName} descargado (${first.downloadedMB} MB)'
                : '✗ Error: ${first.errorMessage ?? first.zoneName}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: first.isComplete
              ? const Color(0xFF004D40)
              : const Color(0xFFB71C1C),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        // Nada activo ni pendiente → ocultar
        if (_snackCtrl != null) {
          messenger.hideCurrentSnackBar();
          _snackCtrl = null;
        }
      }
      return;
    }

    // Hay descargas activas → construir texto de progreso agregado
    final totalBytes = actives.fold<int>(0, (s, p) => s + p.expectedTotalBytes);
    final doneBytes = actives.fold<int>(0, (s, p) => s + p.downloadedBytes);
    final pct = totalBytes > 0
        ? '${(doneBytes / totalBytes * 100).toStringAsFixed(0)}%'
        : '${actives.fold<int>(0, (s, p) => s + p.downloadedTiles)} tiles';

    final label = actives.length == 1
        ? '↓ ${actives.first.zoneName}  '
            '${(doneBytes / 1024 / 1024).toStringAsFixed(1)} MB  $pct'
        : '↓ ${actives.length} zonas  '
            '${(doneBytes / 1024 / 1024).toStringAsFixed(1)} MB  $pct';

    // Si ya hay un SnackBar visible del servicio, reemplazarlo
    if (_snackCtrl != null) {
      messenger.hideCurrentSnackBar();
      _snackCtrl = null;
    }

    _snackCtrl = messenger.showSnackBar(SnackBar(
      content: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF004D40),
      duration: const Duration(days: 1), // persiste hasta que lo cerramos
      behavior: SnackBarBehavior.floating,
    ));
  }

  void clearFinished() {
    _activeDownloads.removeWhere(
        (_, p) => p.isComplete || p.hasError || p.isCancelled);
    _emit();
  }

  void dispose() {
    _progressController.close();
    _db?.close();
  }
}
