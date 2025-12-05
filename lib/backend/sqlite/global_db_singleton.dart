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

      debugPrint('🔗 GlobalDbSingleton: Conexión inicializada en $_dbPath');
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

  /// Ejecutar una operación de forma segura
  /// NO cierra la conexión - usa el singleton
  Future<T> executeOperation<T>(Future<T> Function(Database db) operation) async {
    try {
      final db = await database;
      return await operation(db);
    } catch (e) {
      // Si es error de conexión cerrada, intentar reconectar
      if (e.toString().contains('database_closed')) {
        debugPrint('⚠️ GlobalDbSingleton: Reconectando...');
        _database = null;
        final db = await database;
        return await operation(db);
      }
      debugPrint('❌ GlobalDbSingleton: Error en operación: $e');
      rethrow;
    }
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
          batch_id TEXT
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
