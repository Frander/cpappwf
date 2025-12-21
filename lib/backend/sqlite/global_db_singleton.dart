// Singleton Global para Base de Datos SQLite
// Basado en el patrón de validate_db_sqlite.dart
// TODA la app debe usar este singleton para evitar locks de base de datos

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class GlobalDbSingleton {
  // Instancia singleton
  static final GlobalDbSingleton _instance = GlobalDbSingleton._internal();
  factory GlobalDbSingleton() => _instance;
  GlobalDbSingleton._internal();

  // Conexión única a la base de datos
  Database? _database;
  String? _dbPath;
  bool _isInitializing = false;

  /// Obtener la ruta de la base de datos (IDÉNTICO a validate_db_sqlite.dart)
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

  /// Obtener la instancia de la base de datos
  /// Usa el mismo path y configuración que validate_db_sqlite.dart
  Future<Database> get database async {
    // Si ya está abierta y funcional, retornarla
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // Esperar si otra instancia está inicializando
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Verificar de nuevo después de esperar
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // Inicializar
    _isInitializing = true;
    try {
      // Obtener path IDÉNTICO a validate_db_sqlite.dart
      final String docsPath = await _getBestDocumentsPath();

      _dbPath = path.join(docsPath, 'clickpalm_database.db');

      // Abrir con singleInstance: true (default) para que sqflite maneje el singleton
      _database = await openDatabase(
        _dbPath!,
        singleInstance: true,
      );

      // IMPORTANTE: Habilitar WAL mode para mejor concurrencia con el servicio de segundo plano
      // WAL permite lecturas y escrituras simultáneas sin bloqueos
      // Usar rawQuery en lugar de execute para PRAGMA
      await _database!.rawQuery('PRAGMA journal_mode=WAL');
      // Tiempo de espera de bloqueo (5 segundos)
      await _database!.rawQuery('PRAGMA busy_timeout=5000');
      // Sincronización normal (balance entre seguridad y velocidad)
      await _database!.rawQuery('PRAGMA synchronous=NORMAL');

      debugPrint('🔗 GlobalDbSingleton: Conexión inicializada con WAL mode en $_dbPath');
      return _database!;
    } catch (e) {
      debugPrint('❌ GlobalDbSingleton: Error inicializando: $e');
      _database = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Obtener el path de la base de datos
  Future<String> get dbPath async {
    if (_dbPath == null) {
      await database; // Esto inicializará el path
    }
    return _dbPath!;
  }

  /// Ejecutar una operación de forma segura con reintentos para bloqueos
  /// NO cierra la conexión - usa el singleton
  Future<T> executeOperation<T>(Future<T> Function(Database db) operation) async {
    const maxRetries = 3;
    const baseDelay = Duration(milliseconds: 100);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final db = await database;
        return await operation(db);
      } catch (e) {
        final errorStr = e.toString().toLowerCase();

        // Si es error de conexión cerrada, intentar reconectar
        if (errorStr.contains('database_closed')) {
          debugPrint('⚠️ GlobalDbSingleton: Reconectando...');
          _database = null;
          continue; // Reintentar con nueva conexión
        }

        // Si es error de bloqueo, reintentar con backoff exponencial
        if (errorStr.contains('locked') || errorStr.contains('busy')) {
          if (attempt < maxRetries - 1) {
            final delay = baseDelay * (1 << attempt); // 100ms, 200ms, 400ms
            debugPrint('⏳ GlobalDbSingleton: DB bloqueada, reintentando en ${delay.inMilliseconds}ms (intento ${attempt + 1}/$maxRetries)');
            await Future.delayed(delay);
            continue;
          }
        }

        debugPrint('❌ GlobalDbSingleton: Error en operación: $e');
        rethrow;
      }
    }

    // Si llegamos aquí, falló después de todos los reintentos
    throw Exception('GlobalDbSingleton: Operación falló después de $maxRetries intentos');
  }

  /// Verificar que la tabla Location_tracking existe
  Future<void> ensureLocationTrackingTable() async {
    final db = await database;

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Location_tracking';"
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Location_tracking (
          Id_location_tracking INTEGER PRIMARY KEY AUTOINCREMENT,
          Id_company INTEGER,
          Imei TEXT,
          Latitude REAL,
          Longitude REAL,
          Altitude REAL,
          HorizontalError REAL,
          Speed REAL,
          Battery INTEGER,
          CreatedAt TEXT,
          SyncedAt TEXT,
          batch_id TEXT,
          date_start TEXT,
          date_finish TEXT,
          evaluated_radius REAL,
          point_count INTEGER DEFAULT 1
        );
      ''');
      debugPrint('📦 GlobalDbSingleton: Tabla Location_tracking creada');
    }
  }

  /// Cerrar la conexión (solo usar al salir de la app)
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      debugPrint('🔒 GlobalDbSingleton: Conexión cerrada');
    }
  }
}

// Acceso global fácil
final globalDb = GlobalDbSingleton();
