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

Future<String?> validateDbSqlite(BuildContext context) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Esta función solo está disponible en Android');
  }

  try {
    // 1. Verificar y solicitar permisos (duplicado de get_persistent_id.dart)
    final hasPermissions = await _checkAndRequestStoragePermissions(context);
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // 2. Obtener ruta segura y persistente (duplicado de get_persistent_id.dart)
    final String docsPath = await _getBestDocumentsPath();
    final Directory dir = Directory(docsPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 3. Ruta de la base de datos
    final String dbPath = path.join(docsPath, 'clickpalm_database.db');
    debugPrint('Ruta de la base de datos: $dbPath');

    // 4. Abrir o crear la base de datos
    final Database database = await openDatabase(
      dbPath,
      version:
          17, // Incrementada a v17 para agregar campo is_sync_full a Activities
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Migración de versiones anteriores
        await _upgradeDatabase(db, oldVersion, newVersion);
      },
    );

    // 5. Verificar que las tablas existen
    await _verifyTables(database);

    // 6. Verificar y actualizar esquema de Location_tracking si es necesario
    await _verifyAndUpdateLocationTrackingSchema(database);

    // 7. Verificar y actualizar esquema de Optimized_routes si es necesario
    await _verifyAndUpdateOptimizedRoutesSchema(database);

    // 7. Cerrar la conexión (SQLiteManager manejará sus propias conexiones)
    await database.close();

    debugPrint('✅ Base de datos validada y creada exitosamente en: $dbPath');
    return dbPath; // Devolver la ruta de la base de datos
  } catch (e) {
    debugPrint('❌ Error validando/creando base de datos: $e');
    return null; // Devolver null en caso de error
  }
}

Future<void> _createTables(Database db) async {
  debugPrint('Creando tablas de la base de datos...');

  // ============================================================================
  // TABLAS DEL ENDPOINT LOGIN (Nivel 1: Sin dependencias)
  // ============================================================================

  // Tabla Companies (debe crearse ANTES que Zones por la FK circular)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Companies (
        Id_company INTEGER PRIMARY KEY,
        Name_company TEXT,
        Business_name TEXT,
        Nit TEXT,
        Address TEXT,
        Telephone TEXT,
        Id_zone_default INTEGER,
        Created_at TEXT
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Companies_zone_default ON Companies(Id_zone_default);');

  // Tabla Zones
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Zones (
        Id_zone INTEGER PRIMARY KEY,
        Id_company INTEGER NOT NULL,
        Name_zone TEXT,
        Difficulty INTEGER NOT NULL,
        State_zone TEXT,
        Created_at TEXT,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Zones_company ON Zones(Id_company);');

  // Tabla Zones_polygons
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Zones_polygons (
        Id_zone_polygon INTEGER PRIMARY KEY,
        Id_zone INTEGER NOT NULL,
        Latitude REAL NOT NULL,
        Longitude REAL NOT NULL,
        Created_at TEXT,
        FOREIGN KEY (Id_zone) REFERENCES Zones(Id_zone) ON DELETE CASCADE
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Zones_polygons_zone ON Zones_polygons(Id_zone);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Zones_polygons_coords ON Zones_polygons(Latitude, Longitude);');

  // Tabla Users
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Users (
        Id_user INTEGER PRIMARY KEY,
        Id_company INTEGER NOT NULL,
        Oper_id TEXT,
        Name_user TEXT,
        Email TEXT,
        Created_at TEXT,
        Modified_at TEXT,
        Is_default INTEGER DEFAULT 0,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Users_company ON Users(Id_company);');
  await db
      .execute('CREATE INDEX IF NOT EXISTS IX_Users_email ON Users(Email);');

  // Tabla Devices
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Devices (
        Id_device INTEGER PRIMARY KEY,
        Id_company INTEGER NOT NULL,
        Device_name TEXT,
        Cell_phone TEXT,
        Serial_id TEXT,
        Imei1 TEXT,
        Imei2 TEXT,
        Model TEXT,
        State TEXT,
        Is_default INTEGER DEFAULT 0,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Devices_company ON Devices(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Devices_imei1 ON Devices(Imei1);');
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS IX_Devices_imei_unique ON Devices(Imei1, Imei2);');

  // Tabla Activities
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Activities (
        Id_activity INTEGER PRIMARY KEY,
        Id_company INTEGER NOT NULL,
        Id_activity_parent INTEGER,
        Name_activity TEXT,
        Group_activity TEXT,
        Unity TEXT,
        Type_activity TEXT,
        Type_effectivity TEXT,
        Cycle INTEGER,
        Effectivity_unitys INTEGER,
        Effectivity_visits INTEGER,
        Module_activity TEXT,
        Description_activity TEXT,
        Created_at TEXT,
        Is_default INTEGER DEFAULT 0,
        Is_sync INTEGER DEFAULT 0,
        Tracking_headquarter INTEGER DEFAULT 1,
        Is_sync_full INTEGER DEFAULT 0,
        Read_default TEXT,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company),
        FOREIGN KEY (Id_activity_parent) REFERENCES Activities(Id_activity)
    );
  ''');

  // Migración: Agregar columna Read_default si no existe (para bases de datos existentes)
  try {
    final tableInfo = await db.rawQuery("PRAGMA table_info(Activities)");
    final hasReadDefaultColumn = tableInfo.any((col) => col['name'] == 'Read_default');
    if (!hasReadDefaultColumn) {
      await db.execute('ALTER TABLE Activities ADD COLUMN Read_default TEXT');
      debugPrint('✅ Columna Read_default agregada a tabla Activities');
    }
  } catch (e) {
    debugPrint('⚠️ Error verificando/agregando columna Read_default: $e');
  }

  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_company ON Activities(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_parent ON Activities(Id_activity_parent);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_type ON Activities(Type_activity);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_module ON Activities(Module_activity);');

  // Tabla Activities_steps
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Activities_steps (
        Id_activity_step INTEGER PRIMARY KEY,
        Id_activity INTEGER NOT NULL,
        Type_step TEXT,
        Order_step INTEGER,
        Default_value TEXT,
        Unity TEXT,
        Calculation TEXT,
        Name_step TEXT,
        Status TEXT,
        Is_required INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity) ON DELETE CASCADE
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_steps_activity ON Activities_steps(Id_activity);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_steps_order ON Activities_steps(Order_step);');
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS IX_Activities_steps_unique ON Activities_steps(Id_activity, Order_step);');

  // Tabla Activities_status
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Activities_status (
        Id_activity_status INTEGER PRIMARY KEY,
        Id_activity INTEGER NOT NULL,
        Id_activity_step_parent INTEGER,
        Id_activity_status_parent INTEGER,
        Type_status TEXT,
        Order_status INTEGER,
        Default_status TEXT,
        Status_name TEXT,
        Color TEXT,
        Peso REAL,
        Castigo INTEGER,
        Boton INTEGER,
        Factor INTEGER,
        Status TEXT,
        FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity) ON DELETE CASCADE,
        FOREIGN KEY (Id_activity_step_parent) REFERENCES Activities_steps(Id_activity_step),
        FOREIGN KEY (Id_activity_status_parent) REFERENCES Activities_status(Id_activity_status)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_status_activity ON Activities_status(Id_activity);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_status_step_parent ON Activities_status(Id_activity_step_parent);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_status_parent ON Activities_status(Id_activity_status_parent);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Activities_status_order ON Activities_status(Order_status);');

  // Tabla Headquarters_weights
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Headquarters_weights (
        Id_headquarter_weight INTEGER PRIMARY KEY,
        Id_headquarter INTEGER NOT NULL,
        Id_company INTEGER NOT NULL,
        Date_year INTEGER NOT NULL,
        Date_month INTEGER NOT NULL,
        Weight REAL NOT NULL,
        Created_at TEXT,
        Modified_at TEXT,
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter) ON DELETE CASCADE,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_hq ON Headquarters_weights(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_company ON Headquarters_weights(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_date ON Headquarters_weights(Date_year, Date_month);');
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS IX_Headquarters_weights_unique ON Headquarters_weights(Id_headquarter, Date_year, Date_month);');

  // Tabla News
  await db.execute('''
    CREATE TABLE IF NOT EXISTS News (
        Id_new INTEGER PRIMARY KEY,
        Id_company INTEGER NOT NULL,
        Name_new TEXT,
        Descripcion_activity TEXT,
        Order_display INTEGER NOT NULL,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_News_company ON News(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_News_order ON News(Order_display);');

  // Tabla Login_sessions (opcional pero útil para tracking)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Login_sessions (
        Id_session INTEGER PRIMARY KEY AUTOINCREMENT,
        Token TEXT,
        Products_raw TEXT,
        Created_at TEXT,
        Synced_at TEXT,
        Id_user INTEGER,
        Id_device INTEGER,
        Id_activity INTEGER,
        FOREIGN KEY (Id_user) REFERENCES Users(Id_user),
        FOREIGN KEY (Id_device) REFERENCES Devices(Id_device),
        FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity)
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Login_sessions_user ON Login_sessions(Id_user);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Login_sessions_created ON Login_sessions(Created_at);');

  // Tabla Nfc_tags_history (almacena historial de tags NFC leídos)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Nfc_tags_history (
        Id_nfc_tag INTEGER PRIMARY KEY AUTOINCREMENT,
        Tag_id TEXT NOT NULL,
        Tag_type TEXT,
        Total_space INTEGER DEFAULT 0,
        Used_space INTEGER DEFAULT 0,
        Last_read DATETIME NOT NULL,
        Read_count INTEGER NOT NULL DEFAULT 1,
        Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc'))
    );
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_tag_id ON Nfc_tags_history(Tag_id);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_last_read ON Nfc_tags_history(Last_read);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_tag_type ON Nfc_tags_history(Tag_type);');
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS UX_Nfc_tags_history_tag_id ON Nfc_tags_history(Tag_id);');

  debugPrint('✅ Tablas del Login creadas exitosamente');

  // ============================================================================
  // TABLAS EXISTENTES (Visits, Location_tracking, etc.)
  // ============================================================================

  // Tabla Visits
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Visits (
        Id_visit INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_company INTEGER NOT NULL,
        Id_activity INTEGER NOT NULL,
        Id_headquarter INTEGER NOT NULL,
        Id_product INTEGER NOT NULL,
        Id_bulk INTEGER NOT NULL,
        Id_user INTEGER NOT NULL,
        Id_device INTEGER NOT NULL,
        Id_status INTEGER,
        Created_at DATETIME NOT NULL,
        Battery DECIMAL NOT NULL,
        Latitude REAL NOT NULL DEFAULT 0,
        Longitude REAL NOT NULL DEFAULT 0,
        Altitude REAL NOT NULL DEFAULT 0,
        Error_horizontal REAL NOT NULL DEFAULT 0,
        Id_virtual_point INTEGER,
        Status INTEGER NOT NULL DEFAULT 0,
        Rfid TEXT,
        FOREIGN KEY (Id_company) REFERENCES Companies(Id_company),
        FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity),
        FOREIGN KEY (Id_product) REFERENCES Products(Id_product),
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter),
        FOREIGN KEY (Id_user) REFERENCES Users(Id_user),
        FOREIGN KEY (Id_device) REFERENCES Devices(Id_device),
        FOREIGN KEY (Id_status) REFERENCES Activities_status(Id_activity_status),
        FOREIGN KEY (Id_virtual_point) REFERENCES Virtual_points(Id_virtual_point)
    );
  ''');

  // Migración: Agregar columna Rfid si no existe (para bases de datos existentes)
  try {
    final tableInfo = await db.rawQuery("PRAGMA table_info(Visits)");
    final hasRfidColumn = tableInfo.any((col) => col['name'] == 'Rfid');
    if (!hasRfidColumn) {
      await db.execute('ALTER TABLE Visits ADD COLUMN Rfid TEXT');
      debugPrint('✅ Columna Rfid agregada a tabla Visits');
    }
  } catch (e) {
    debugPrint('⚠️ Error verificando/agregando columna Rfid: $e');
  }

  // Índices para optimizar consultas en Visits
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Id_company ON Visits(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Id_user ON Visits(Id_user);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Created_at ON Visits(Created_at);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Id_product ON Visits(Id_product);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Status ON Visits(Status);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_Rfid ON Visits(Rfid);');

  // Tabla Visits_details
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Visits_details (
        Id_visit_detail INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_visit INTEGER NOT NULL,
        Id_activity_status INTEGER NOT NULL,
        Status_option TEXT NOT NULL DEFAULT '',
        Status_response TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (Id_visit) REFERENCES Visits(Id_visit),
        FOREIGN KEY (Id_activity_status) REFERENCES Activities_status(Id_activity_status)
    );
  ''');

  // Índices para optimizar consultas en Visits_details
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_details_Id_visit ON Visits_details(Id_visit);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_details_Id_activity_status ON Visits_details(Id_activity_status);');

  // Tabla Location_tracking
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Location_tracking (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_company INTEGER NOT NULL,
        Imei TEXT NOT NULL,
        Latitude DECIMAL(10,8) NOT NULL,
        Longitude DECIMAL(11,8) NOT NULL,
        Altitude DECIMAL(8,2) NOT NULL DEFAULT 0,
        HorizontalError DECIMAL(8,2) NOT NULL DEFAULT 0,
        Speed DECIMAL(8,2) NOT NULL DEFAULT 0,
        Battery INTEGER NOT NULL DEFAULT 0,
        CreatedAt DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
        SyncedAt DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
        batch_id TEXT
    );
  ''');

  // Índices para optimizar consultas en Location_tracking
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Location_tracking_Id_company ON Location_tracking(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Location_tracking_Imei ON Location_tracking(Imei);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Location_tracking_CreatedAt ON Location_tracking(CreatedAt);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Location_tracking_batch_id ON Location_tracking(batch_id);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Location_tracking_coordinates ON Location_tracking(Latitude, Longitude);');

  // Índice UNIQUE para prevenir duplicados por fecha/hora (v8)
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS UX_Location_tracking_CreatedAt ON Location_tracking(CreatedAt);');

  // Nueva tabla Visits_locations
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Visits_locations (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_visit INTEGER NOT NULL,
        Latitude DECIMAL(10,8) NOT NULL,
        Longitude DECIMAL(11,8) NOT NULL,
        Altitude DECIMAL(8,2) NOT NULL DEFAULT 0,
        HorizontalError DECIMAL(8,2) NOT NULL DEFAULT 0,
        CreatedAt DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
        FOREIGN KEY (Id_visit) REFERENCES Visits(Id_visit)
    );
  ''');

  // Índices para optimizar consultas en Visits_locations
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_locations_Id_visit ON Visits_locations(Id_visit);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_locations_CreatedAt ON Visits_locations(CreatedAt);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Visits_locations_coordinates ON Visits_locations(Latitude, Longitude);');

  // Tabla Headquarters
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Headquarters (
        Id_headquarter INTEGER PRIMARY KEY,
        Id_zone INTEGER NOT NULL,
        Created_at DATETIME NOT NULL,
        Name_headquarter TEXT,
        Density_headquarter REAL,
        Seed_time TEXT,
        State_headquarter TEXT,
        Area_headquarter REAL,
        Polygon TEXT,
        Centroid_coordinate TEXT,
        Azimuth REAL,
        Slope_azimuth_direction REAL,
        Slope_azimuth_perpendicular REAL,
        Horizontal_palm_distance REAL,
        Vertical_palm_distance REAL,
        Magnetic_declination REAL,
        CustomOriginLatitude REAL,
        CustomOriginLongitude REAL,
        Has_plants INTEGER DEFAULT 0
    );
  ''');

  // Índices para Headquarters
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_Id_zone ON Headquarters(Id_zone);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_State ON Headquarters(State_headquarter);');

  // Tabla Headquarters_polygons
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Headquarters_polygons (
        Id_headquarter_polygon INTEGER PRIMARY KEY,
        Id_headquarter INTEGER NOT NULL,
        Latitude REAL NOT NULL,
        Longitude REAL NOT NULL,
        Created_at DATETIME NOT NULL,
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
    );
  ''');

  // Índices para Headquarters_polygons
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_polygons_Id_headquarter ON Headquarters_polygons(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_polygons_coordinates ON Headquarters_polygons(Latitude, Longitude);');

  // Tabla Virtual_points
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Virtual_points (
        Id_virtual_point INTEGER PRIMARY KEY,
        Id_headquarter INTEGER NOT NULL,
        Id_type_point INTEGER NOT NULL,
        Line_number INTEGER NOT NULL,
        Point_number INTEGER NOT NULL,
        Latitude REAL NOT NULL,
        Longitude REAL NOT NULL,
        Description_virtual_point TEXT,
        Generation_method TEXT,
        Created_date DATETIME NOT NULL,
        Is_active INTEGER DEFAULT 1,
        Headquarter_name TEXT,
        Type_point_name TEXT,
        Point_display_name TEXT,
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
    );
  ''');

  // Índices para Virtual_points
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Virtual_points_Id_headquarter ON Virtual_points(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Virtual_points_Id_type_point ON Virtual_points(Id_type_point);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Virtual_points_coordinates ON Virtual_points(Latitude, Longitude);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Virtual_points_Line_Point ON Virtual_points(Line_number, Point_number);');

  // Tabla Types_points (NUEVA - para almacenar tipos de puntos con colores)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Types_points (
        Id_type_point INTEGER PRIMARY KEY,
        Name_type TEXT,
        Color_type TEXT,
        Order_type INTEGER,
        Virtual_points_count INTEGER DEFAULT 0
    );
  ''');

  // Índices para Types_points
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Types_points_Order_type ON Types_points(Order_type);');

  // Tabla Headquarters_coordinates
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Headquarters_coordinates (
        Id_polygon_coordinate INTEGER PRIMARY KEY,
        Id_headquarter INTEGER NOT NULL,
        Name_polygon_coordinate TEXT,
        Coordinates_raw TEXT,
        Point_type TEXT,
        Id_type_point INTEGER,
        Created_at DATETIME NOT NULL,
        Modified_at DATETIME NOT NULL,
        Is_active INTEGER DEFAULT 1,
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter),
        FOREIGN KEY (Id_type_point) REFERENCES Types_points(Id_type_point)
    );
  ''');

  // Índices para Headquarters_coordinates
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_coordinates_Id_headquarter ON Headquarters_coordinates(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Headquarters_coordinates_Point_type ON Headquarters_coordinates(Point_type);');

  // Tabla Exclusion_zones_history (NUEVA - para registrar cambios de tipos en zonas de exclusión)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Exclusion_zones_history (
        Id_history INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_polygon_coordinate INTEGER NOT NULL,
        Id_virtual_point INTEGER,
        Line_number INTEGER,
        Point_number INTEGER,
        Previous_type_id INTEGER,
        Previous_type_name TEXT,
        New_type_id INTEGER NOT NULL,
        New_type_name TEXT,
        Modified_at DATETIME NOT NULL,
        User_id INTEGER,
        FOREIGN KEY (Id_polygon_coordinate) REFERENCES Headquarters_coordinates(Id_polygon_coordinate),
        FOREIGN KEY (Id_virtual_point) REFERENCES Virtual_points(Id_virtual_point),
        FOREIGN KEY (Previous_type_id) REFERENCES Types_points(Id_type_point),
        FOREIGN KEY (New_type_id) REFERENCES Types_points(Id_type_point)
    );
  ''');

  // Índices para Exclusion_zones_history
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Exclusion_zones_history_Id_polygon ON Exclusion_zones_history(Id_polygon_coordinate);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Exclusion_zones_history_Id_virtual_point ON Exclusion_zones_history(Id_virtual_point);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Exclusion_zones_history_Modified_at ON Exclusion_zones_history(Modified_at);');

  // Tabla Products
  // Sync_status: 'synced' = sincronizado, 'new' = nuevo por insertar, 'updated' = modificado por actualizar
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Products (
        Id_product INTEGER PRIMARY KEY,
        Id_headquarter INTEGER NOT NULL,
        Id_company INTEGER NOT NULL,
        Id_type INTEGER NOT NULL,
        Created_at DATETIME NOT NULL,
        Modified_at DATETIME NOT NULL,
        Type_product TEXT,
        Name_product TEXT,
        Rfid TEXT,
        State_product TEXT,
        Description_product TEXT,
        Location_raw TEXT,
        Line INTEGER,
        Palm INTEGER,
        Sync_status TEXT DEFAULT 'synced',
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter),
        FOREIGN KEY (Id_type) REFERENCES Types_points(Id_type_point)
    );
  ''');

  // Migrar columna Sync_status si no existe (para bases de datos existentes)
  try {
    await db.execute('ALTER TABLE Products ADD COLUMN Sync_status TEXT DEFAULT \'synced\';');
  } catch (e) {
    // La columna ya existe, ignorar error
  }

  // Índices para Products
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_Id_headquarter ON Products(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_Id_company ON Products(Id_company);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_Id_type ON Products(Id_type);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_Rfid ON Products(Rfid);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_State ON Products(State_product);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_Line_Palm ON Products(Line, Palm);');

  // Tabla Products_coordinates
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Products_coordinates (
        Id_product_coordenate INTEGER PRIMARY KEY,
        Id_product INTEGER NOT NULL,
        Latitude REAL NOT NULL,
        Longitude REAL NOT NULL,
        FOREIGN KEY (Id_product) REFERENCES Products(Id_product)
    );
  ''');

  // Índices para Products_coordinates
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_coordinates_Id_product ON Products_coordinates(Id_product);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Products_coordinates_coordinates ON Products_coordinates(Latitude, Longitude);');

  // Tabla Optimized_routes (almacena metadata de rutas optimizadas y todas las demás rutas)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Optimized_routes (
        Id_optimized_route INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_headquarter INTEGER NOT NULL,
        Start_line INTEGER NOT NULL,
        Start_point INTEGER NOT NULL,
        Max_lines INTEGER NOT NULL DEFAULT 0,
        Max_points INTEGER NOT NULL DEFAULT 0,
        Route_pattern TEXT NOT NULL DEFAULT 'rutaOptimizada',
        Average_speed_kmh REAL NOT NULL,
        Time_limit_seconds INTEGER NOT NULL,
        Optimization_strategy TEXT,
        Apply_exclusion_zones INTEGER DEFAULT 1,
        Total_distance_km REAL,
        Estimated_duration TEXT,
        Estimated_duration_seconds INTEGER,
        Excluded_points_count INTEGER DEFAULT 0,
        Algorithm TEXT,
        Strategy_used TEXT,
        Optimization_time_seconds REAL,
        Total_lines INTEGER,
        Lines_in_range TEXT,
        Start_location TEXT,
        End_location TEXT,
        Improvement_percentage REAL,
        Solution_quality TEXT,
        Warnings TEXT,
        Total_segments INTEGER,
        Valid_segments INTEGER,
        Minor_violations INTEGER,
        Major_violations INTEGER,
        Violation_percentage REAL,
        Is_geometrically_valid INTEGER,
        Geometry_quality TEXT,
        Geometry_warnings TEXT,
        Disconnected_components INTEGER,
        Components_were_connected INTEGER,
        Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
        FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
    );
  ''');

  // Índices para Optimized_routes
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Id_headquarter ON Optimized_routes(Id_headquarter);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Created_at ON Optimized_routes(Created_at);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Config ON Optimized_routes(Id_headquarter, Start_line, Start_point, Max_lines, Max_points, Route_pattern);');

  // Tabla Optimized_route_points (almacena puntos ordenados de cada ruta optimizada)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS Optimized_route_points (
        Id_optimized_route_point INTEGER PRIMARY KEY AUTOINCREMENT,
        Id_optimized_route INTEGER NOT NULL,
        Id_virtual_point INTEGER NOT NULL,
        Line_number INTEGER NOT NULL,
        Point_number INTEGER NOT NULL,
        Latitude REAL NOT NULL,
        Longitude REAL NOT NULL,
        Id_type_point INTEGER,
        Route_position INTEGER NOT NULL,
        Distance_to_next_meters REAL,
        Time_to_next TEXT,
        FOREIGN KEY (Id_optimized_route) REFERENCES Optimized_routes(Id_optimized_route),
        FOREIGN KEY (Id_virtual_point) REFERENCES Virtual_points(Id_virtual_point),
        FOREIGN KEY (Id_type_point) REFERENCES Types_points(Id_type_point)
    );
  ''');

  // Índices para Optimized_route_points
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_optimized_route ON Optimized_route_points(Id_optimized_route);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_virtual_point ON Optimized_route_points(Id_virtual_point);');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Route_position ON Optimized_route_points(Id_optimized_route, Route_position);');

  debugPrint('✅ Tablas e índices creados exitosamente');
}

Future<void> _verifyTables(Database db) async {
  debugPrint('Verificando existencia de tablas...');

  final List<Map<String, dynamic>> tables =
      await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");

  final List<String> tableNames =
      tables.map((table) => table['name'] as String).toList();

  final requiredTables = [
    // Tablas del Login
    'Companies',
    'Zones',
    'Zones_polygons',
    'Users',
    'Devices',
    'Activities',
    'Activities_steps',
    'Activities_status',
    'Headquarters_weights',
    'News',
    'Login_sessions',
    'Nfc_tags_history',
    // Tablas existentes
    'Visits',
    'Visits_details',
    'Location_tracking',
    'Visits_locations',
    'Headquarters',
    'Headquarters_polygons',
    'Virtual_points',
    'Types_points',
    'Headquarters_coordinates',
    'Products',
    'Products_coordinates',
    'Optimized_routes',
    'Optimized_route_points',
    'Exclusion_zones_history'
  ];

  for (String requiredTable in requiredTables) {
    if (tableNames.contains(requiredTable)) {
      debugPrint('✅ Tabla "$requiredTable" existe');
    } else {
      throw Exception('❌ Tabla "$requiredTable" no existe');
    }
  }

  debugPrint('✅ Todas las tablas requeridas están presentes');
}

// Duplicado de get_persistent_id.dart - Función para obtener la ruta de documentos
Future<String> _getBestDocumentsPath() async {
  final Directory? externalDir = await getExternalStorageDirectory();
  if (externalDir == null) {
    throw Exception('No se pudo acceder al almacenamiento externo');
  }

  final String path =
      '${externalDir.path}/ClickPalmData'; // Carpeta personalizada
  final Directory targetDir = Directory(path);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return targetDir.path;
}

// Duplicado de get_persistent_id.dart - Función para verificar permisos
Future<bool> _checkAndRequestStoragePermissions(BuildContext context) async {
  try {
    if (!Platform.isAndroid) return false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    if (sdkVersion >= 33) {
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

      if (photosStatus.isGranted && videosStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialog(
        context,
        'La aplicación necesita acceso a tus fotos y videos para guardar la base de datos.',
      );
      if (!shouldContinue) return false;

      final result = await [
        Permission.photos,
        Permission.videos,
      ].request();

      return result[Permission.photos]?.isGranted == true &&
          result[Permission.videos]?.isGranted == true;
    }

    if (sdkVersion >= 30) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final shouldContinue = await _showPermissionExplanationDialog(
        context,
        'Para continuar, se requiere permiso para gestionar el almacenamiento externo.',
      );
      if (!shouldContinue) return false;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }

    // Android 6 - 10
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    await _showPermissionExplanationDialog(
      context,
      'Se necesita permiso para acceder al almacenamiento externo.',
    );

    final result = await Permission.storage.request();
    return result.isGranted;
  } catch (e) {
    debugPrint('Error solicitando permisos: $e');
    return false;
  }
}

// Duplicado de get_persistent_id.dart - Función para mostrar diálogo de permisos
Future<bool> _showPermissionExplanationDialog(
    BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Verificar y actualizar el esquema de Location_tracking si faltan columnas
Future<void> _verifyAndUpdateLocationTrackingSchema(Database db) async {
  try {
    debugPrint('Verificando esquema de Location_tracking...');

    // Obtener información de las columnas de la tabla
    final List<Map<String, dynamic>> columns =
        await db.rawQuery('PRAGMA table_info(Location_tracking);');

    final List<String> columnNames =
        columns.map((col) => col['name'] as String).toList();

    debugPrint('Columnas actuales: $columnNames');

    // Verificar si faltan las columnas Speed y Battery
    bool needsSpeedColumn = !columnNames.contains('Speed');
    bool needsBatteryColumn = !columnNames.contains('Battery');

    if (needsSpeedColumn || needsBatteryColumn) {
      debugPrint(
          '⚠️ Faltan columnas en Location_tracking. Actualizando esquema...');

      // Agregar columna Speed si no existe
      if (needsSpeedColumn) {
        await db.execute(
            'ALTER TABLE Location_tracking ADD COLUMN Speed DECIMAL(8,2) NOT NULL DEFAULT 0;');
        debugPrint('✅ Columna Speed agregada a Location_tracking');
      }

      // Agregar columna Battery si no existe
      if (needsBatteryColumn) {
        await db.execute(
            'ALTER TABLE Location_tracking ADD COLUMN Battery INTEGER NOT NULL DEFAULT 0;');
        debugPrint('✅ Columna Battery agregada a Location_tracking');
      }

      debugPrint('✅ Esquema de Location_tracking actualizado exitosamente');
    } else {
      debugPrint('✅ Esquema de Location_tracking está actualizado');
    }
  } catch (e) {
    debugPrint(
        '❌ Error verificando/actualizando esquema de Location_tracking: $e');
    rethrow;
  }
}

/// Verificar y actualizar el esquema de Optimized_routes si faltan columnas
Future<void> _verifyAndUpdateOptimizedRoutesSchema(Database db) async {
  try {
    debugPrint('Verificando esquema de Optimized_routes...');

    // Verificar si la tabla existe
    final List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Optimized_routes';");

    if (tables.isEmpty) {
      debugPrint(
          '⚠️ Tabla Optimized_routes no existe, será creada en la siguiente migración');
      return;
    }

    // Obtener información de las columnas de la tabla
    final List<Map<String, dynamic>> columns =
        await db.rawQuery('PRAGMA table_info(Optimized_routes);');

    final List<String> columnNames =
        columns.map((col) => col['name'] as String).toList();

    debugPrint('Columnas actuales en Optimized_routes: $columnNames');

    // Lista de columnas que deben existir en Optimized_routes
    final Map<String, String> requiredColumns = {
      'Route_pattern': 'TEXT',
      'Total_segments': 'INTEGER',
      'Valid_segments': 'INTEGER',
      'Minor_violations': 'INTEGER',
      'Major_violations': 'INTEGER',
      'Violation_percentage': 'REAL',
      'Is_geometrically_valid': 'INTEGER',
      'Geometry_quality': 'TEXT',
      'Geometry_warnings': 'TEXT',
      'Disconnected_components': 'INTEGER',
      'Components_were_connected': 'INTEGER',
    };

    bool needsUpdate = false;
    final List<String> missingColumns = [];

    // Verificar qué columnas faltan
    for (String columnName in requiredColumns.keys) {
      if (!columnNames.contains(columnName)) {
        missingColumns.add(columnName);
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      debugPrint(
          '⚠️ Faltan ${missingColumns.length} columnas en Optimized_routes. Actualizando esquema...');
      debugPrint('   Columnas faltantes: ${missingColumns.join(", ")}');

      // SQLite no soporta agregar múltiples columnas en un solo ALTER TABLE,
      // así que necesitamos recrear la tabla completa
      debugPrint(
          '   🔄 Recreando tabla Optimized_routes con esquema completo...');

      // 1. Renombrar tabla antigua
      await db.execute(
          'ALTER TABLE Optimized_routes RENAME TO Optimized_routes_old;');
      debugPrint('   ✅ Tabla renombrada a Optimized_routes_old');

      // 2. Crear nueva tabla con estructura completa
      await db.execute('''
        CREATE TABLE Optimized_routes (
            Id_optimized_route INTEGER PRIMARY KEY AUTOINCREMENT,
            Id_headquarter INTEGER NOT NULL,
            Start_line INTEGER NOT NULL,
            Start_point INTEGER NOT NULL,
            Max_lines INTEGER NOT NULL DEFAULT 0,
            Max_points INTEGER NOT NULL DEFAULT 0,
            Route_pattern TEXT NOT NULL DEFAULT 'rutaOptimizada',
            Average_speed_kmh REAL NOT NULL,
            Time_limit_seconds INTEGER NOT NULL,
            Optimization_strategy TEXT,
            Apply_exclusion_zones INTEGER DEFAULT 1,
            Total_distance_km REAL,
            Estimated_duration TEXT,
            Estimated_duration_seconds INTEGER,
            Excluded_points_count INTEGER DEFAULT 0,
            Algorithm TEXT,
            Strategy_used TEXT,
            Optimization_time_seconds REAL,
            Total_lines INTEGER,
            Lines_in_range TEXT,
            Start_location TEXT,
            End_location TEXT,
            Improvement_percentage REAL,
            Solution_quality TEXT,
            Warnings TEXT,
            Total_segments INTEGER,
            Valid_segments INTEGER,
            Minor_violations INTEGER,
            Major_violations INTEGER,
            Violation_percentage REAL,
            Is_geometrically_valid INTEGER,
            Geometry_quality TEXT,
            Geometry_warnings TEXT,
            Disconnected_components INTEGER,
            Components_were_connected INTEGER,
            Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
            FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
        );
      ''');
      debugPrint(
          '   ✅ Nueva tabla Optimized_routes creada con esquema completo');

      // 3. Copiar datos de la tabla antigua (solo las columnas que existen en ambas)
      final commonColumns = columnNames
          .where((col) =>
              col != 'Id_optimized_route' ||
              columnNames.contains('Id_optimized_route'))
          .toList();

      if (commonColumns.isNotEmpty) {
        final columnsStr = commonColumns.join(', ');
        await db.execute('''
          INSERT INTO Optimized_routes ($columnsStr)
          SELECT $columnsStr FROM Optimized_routes_old;
        ''');
        debugPrint('   ✅ Datos copiados de la tabla antigua');
      }

      // 4. Eliminar tabla antigua
      await db.execute('DROP TABLE Optimized_routes_old;');
      debugPrint('   ✅ Tabla antigua eliminada');

      // 5. Recrear índices
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Id_headquarter ON Optimized_routes(Id_headquarter);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Created_at ON Optimized_routes(Created_at);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Config ON Optimized_routes(Id_headquarter, Start_line, Start_point, Max_lines, Max_points, Route_pattern);');
      debugPrint('   ✅ Índices recreados');

      debugPrint('✅ Esquema de Optimized_routes actualizado exitosamente');
    } else {
      debugPrint('✅ Esquema de Optimized_routes está completo y actualizado');
    }
  } catch (e) {
    debugPrint(
        '❌ Error verificando/actualizando esquema de Optimized_routes: $e');
    rethrow;
  }
}

/// Función de migración para actualizar la base de datos de versiones anteriores
Future<void> _upgradeDatabase(
    Database db, int oldVersion, int newVersion) async {
  debugPrint(
      '🔄 Migrando base de datos de versión $oldVersion a $newVersion...');

  try {
    // Migración de v4 a v5: Agregar tabla Types_points y actualizar otras tablas
    if (oldVersion < 5) {
      debugPrint('📦 Aplicando migración a versión 5...');

      // 1. Crear tabla Types_points si no existe
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Types_points (
            Id_type_point INTEGER PRIMARY KEY,
            Name_type TEXT,
            Color_type TEXT,
            Order_type INTEGER,
            Virtual_points_count INTEGER DEFAULT 0
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Types_points_Order_type ON Types_points(Order_type);');
      debugPrint('✅ Tabla Types_points creada');

      // 2. Agregar columna Id_type_point a Headquarters_coordinates
      final hqCoordColumns =
          await db.rawQuery('PRAGMA table_info(Headquarters_coordinates);');
      final hqCoordColumnNames =
          hqCoordColumns.map((col) => col['name'] as String).toList();

      if (!hqCoordColumnNames.contains('Id_type_point')) {
        await db.execute(
            'ALTER TABLE Headquarters_coordinates ADD COLUMN Id_type_point INTEGER;');
        debugPrint(
            '✅ Columna Id_type_point agregada a Headquarters_coordinates');
      }

      // 3. Migrar tabla Products con nuevas columnas
      final productColumns = await db.rawQuery('PRAGMA table_info(Products);');
      final productColumnNames =
          productColumns.map((col) => col['name'] as String).toList();

      // Verificar si faltan columnas en Products
      bool needsProductMigration = !productColumnNames.contains('Id_company') ||
          !productColumnNames.contains('Id_type') ||
          !productColumnNames.contains('Modified_at') ||
          !productColumnNames.contains('Type_product') ||
          !productColumnNames.contains('Name_product');

      if (needsProductMigration) {
        debugPrint('🔄 Migrando tabla Products...');

        // Renombrar tabla antigua
        await db.execute('ALTER TABLE Products RENAME TO Products_old;');

        // Crear nueva tabla con estructura actualizada
        await db.execute('''
          CREATE TABLE Products (
              Id_product INTEGER PRIMARY KEY,
              Id_headquarter INTEGER NOT NULL,
              Id_company INTEGER NOT NULL DEFAULT 0,
              Id_type INTEGER NOT NULL DEFAULT 0,
              Created_at DATETIME NOT NULL,
              Modified_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
              Type_product TEXT,
              Name_product TEXT,
              Rfid TEXT,
              State_product TEXT,
              Description_product TEXT,
              Location_raw TEXT,
              Line INTEGER,
              Palm INTEGER,
              FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter),
              FOREIGN KEY (Id_type) REFERENCES Types_points(Id_type_point)
          );
        ''');

        // Copiar datos de la tabla antigua a la nueva
        await db.execute('''
          INSERT INTO Products (
              Id_product, Id_headquarter, Id_company, Id_type, Created_at,
              Modified_at, Rfid, State_product, Description_product,
              Location_raw, Line, Palm
          )
          SELECT
              Id_product, Id_headquarter, 0, 0, Created_at,
              Created_at, Rfid, State_product, Description_product,
              Location_raw, Line, Palm
          FROM Products_old;
        ''');

        // Eliminar tabla antigua
        await db.execute('DROP TABLE Products_old;');

        // Recrear índices
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_Id_headquarter ON Products(Id_headquarter);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_Id_company ON Products(Id_company);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_Id_type ON Products(Id_type);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_Rfid ON Products(Rfid);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_State ON Products(State_product);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Products_Line_Palm ON Products(Line, Palm);');

        debugPrint('✅ Tabla Products migrada exitosamente');
      }

      debugPrint('✅ Migración a versión 5 completada');
    }

    // Migración de v6 a v7: Agregar tablas de rutas optimizadas
    if (oldVersion < 7) {
      debugPrint('📦 Aplicando migración a versión 7...');

      // Crear tabla Optimized_routes
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Optimized_routes (
            Id_optimized_route INTEGER PRIMARY KEY AUTOINCREMENT,
            Id_headquarter INTEGER NOT NULL,
            Start_line INTEGER NOT NULL,
            Start_point INTEGER NOT NULL,
            Max_lines INTEGER NOT NULL DEFAULT 0,
            Max_points INTEGER NOT NULL DEFAULT 0,
            Average_speed_kmh REAL NOT NULL,
            Time_limit_seconds INTEGER NOT NULL,
            Optimization_strategy TEXT,
            Apply_exclusion_zones INTEGER DEFAULT 1,
            Total_distance_km REAL,
            Estimated_duration TEXT,
            Estimated_duration_seconds INTEGER,
            Excluded_points_count INTEGER DEFAULT 0,
            Algorithm TEXT,
            Strategy_used TEXT,
            Optimization_time_seconds REAL,
            Total_lines INTEGER,
            Lines_in_range TEXT,
            Start_location TEXT,
            End_location TEXT,
            Improvement_percentage REAL,
            Solution_quality TEXT,
            Warnings TEXT,
            Total_segments INTEGER,
            Valid_segments INTEGER,
            Minor_violations INTEGER,
            Major_violations INTEGER,
            Violation_percentage REAL,
            Is_geometrically_valid INTEGER,
            Geometry_quality TEXT,
            Geometry_warnings TEXT,
            Disconnected_components INTEGER,
            Components_were_connected INTEGER,
            Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
            FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Id_headquarter ON Optimized_routes(Id_headquarter);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Created_at ON Optimized_routes(Created_at);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Config ON Optimized_routes(Id_headquarter, Start_line, Start_point, Max_lines, Max_points);');
      debugPrint('✅ Tabla Optimized_routes creada');

      // Crear tabla Optimized_route_points
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Optimized_route_points (
            Id_optimized_route_point INTEGER PRIMARY KEY AUTOINCREMENT,
            Id_optimized_route INTEGER NOT NULL,
            Id_virtual_point INTEGER NOT NULL,
            Line_number INTEGER NOT NULL,
            Point_number INTEGER NOT NULL,
            Latitude REAL NOT NULL,
            Longitude REAL NOT NULL,
            Id_type_point INTEGER,
            Route_position INTEGER NOT NULL,
            Distance_to_next_meters REAL,
            Time_to_next TEXT,
            FOREIGN KEY (Id_optimized_route) REFERENCES Optimized_routes(Id_optimized_route),
            FOREIGN KEY (Id_virtual_point) REFERENCES Virtual_points(Id_virtual_point),
            FOREIGN KEY (Id_type_point) REFERENCES Types_points(Id_type_point)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_optimized_route ON Optimized_route_points(Id_optimized_route);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_virtual_point ON Optimized_route_points(Id_virtual_point);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Route_position ON Optimized_route_points(Id_optimized_route, Route_position);');
      debugPrint('✅ Tabla Optimized_route_points creada');

      debugPrint('✅ Migración a versión 7 completada');
    }

    // Migración de v7 a v8: Agregar índice UNIQUE en Location_tracking para prevenir duplicados
    if (oldVersion < 8) {
      debugPrint('📦 Aplicando migración a versión 8...');

      // Agregar índice UNIQUE en CreatedAt de Location_tracking para prevenir duplicados
      try {
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS UX_Location_tracking_CreatedAt ON Location_tracking(CreatedAt);');
        debugPrint(
            '✅ Índice UNIQUE UX_Location_tracking_CreatedAt creado para prevenir duplicados');
      } catch (e) {
        debugPrint(
            '⚠️ Advertencia: No se pudo crear índice UNIQUE (posiblemente ya existe o hay duplicados): $e');
        debugPrint(
            '   Si hay duplicados existentes, considera limpiar la tabla Location_tracking');
      }

      debugPrint('✅ Migración a versión 8 completada');
    }

    // Migración de v8 a v9: Actualizar estructura de tablas de rutas optimizadas
    if (oldVersion < 9) {
      debugPrint('📦 Aplicando migración a versión 9...');
      debugPrint(
          '   Actualizando estructura de rutas optimizadas para nueva API');

      // Eliminar tablas existentes de rutas optimizadas para recrearlas
      try {
        await db.execute('DROP TABLE IF EXISTS Optimized_route_points;');
        debugPrint('   ✅ Tabla Optimized_route_points eliminada');
      } catch (e) {
        debugPrint('   ⚠️ No se pudo eliminar Optimized_route_points: $e');
      }

      try {
        await db.execute('DROP TABLE IF EXISTS Optimized_routes;');
        debugPrint('   ✅ Tabla Optimized_routes eliminada');
      } catch (e) {
        debugPrint('   ⚠️ No se pudo eliminar Optimized_routes: $e');
      }

      // Recrear tabla Optimized_routes con estructura actualizada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Optimized_routes (
            Id_optimized_route INTEGER PRIMARY KEY AUTOINCREMENT,
            Id_headquarter INTEGER NOT NULL,
            Start_line INTEGER NOT NULL,
            Start_point INTEGER NOT NULL,
            Max_lines INTEGER NOT NULL DEFAULT 0,
            Max_points INTEGER NOT NULL DEFAULT 0,
            Average_speed_kmh REAL NOT NULL,
            Time_limit_seconds INTEGER NOT NULL,
            Optimization_strategy TEXT,
            Apply_exclusion_zones INTEGER DEFAULT 1,
            Total_distance_km REAL,
            Estimated_duration TEXT,
            Estimated_duration_seconds INTEGER,
            Excluded_points_count INTEGER DEFAULT 0,
            Algorithm TEXT,
            Strategy_used TEXT,
            Optimization_time_seconds REAL,
            Total_lines INTEGER,
            Lines_in_range TEXT,
            Start_location TEXT,
            End_location TEXT,
            Improvement_percentage REAL,
            Solution_quality TEXT,
            Warnings TEXT,
            Total_segments INTEGER,
            Valid_segments INTEGER,
            Minor_violations INTEGER,
            Major_violations INTEGER,
            Violation_percentage REAL,
            Is_geometrically_valid INTEGER,
            Geometry_quality TEXT,
            Geometry_warnings TEXT,
            Disconnected_components INTEGER,
            Components_were_connected INTEGER,
            Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc')),
            FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter)
        );
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Id_headquarter ON Optimized_routes(Id_headquarter);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Created_at ON Optimized_routes(Created_at);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_routes_Config ON Optimized_routes(Id_headquarter, Start_line, Start_point, Max_lines, Max_points);');
      debugPrint('   ✅ Tabla Optimized_routes recreada');

      // Recrear tabla Optimized_route_points con estructura actualizada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Optimized_route_points (
            Id_optimized_route_point INTEGER PRIMARY KEY AUTOINCREMENT,
            Id_optimized_route INTEGER NOT NULL,
            Id_virtual_point INTEGER NOT NULL,
            Line_number INTEGER NOT NULL,
            Point_number INTEGER NOT NULL,
            Latitude REAL NOT NULL,
            Longitude REAL NOT NULL,
            Id_type_point INTEGER,
            Route_position INTEGER NOT NULL,
            Distance_to_next_meters REAL,
            Time_to_next TEXT,
            FOREIGN KEY (Id_optimized_route) REFERENCES Optimized_routes(Id_optimized_route),
            FOREIGN KEY (Id_virtual_point) REFERENCES Virtual_points(Id_virtual_point),
            FOREIGN KEY (Id_type_point) REFERENCES Types_points(Id_type_point)
        );
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_optimized_route ON Optimized_route_points(Id_optimized_route);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Id_virtual_point ON Optimized_route_points(Id_virtual_point);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Optimized_route_points_Route_position ON Optimized_route_points(Id_optimized_route, Route_position);');
      debugPrint('   ✅ Tabla Optimized_route_points recreada');

      debugPrint('✅ Migración a versión 9 completada');
      debugPrint('   Las rutas optimizadas antiguas fueron eliminadas');
      debugPrint(
          '   Ahora compatible con nueva estructura del API RouteOptimization');
    }

    // Migración de v9 a v10: Agregar tablas del endpoint Login
    if (oldVersion < 10) {
      debugPrint('📦 Aplicando migración a versión 10...');
      debugPrint('   Agregando tablas para almacenar datos del endpoint Login');

      // Crear todas las tablas del Login con CREATE TABLE IF NOT EXISTS
      // Esto es seguro porque solo crea las tablas si no existen

      // Tabla Companies
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Companies (
            Id_company INTEGER PRIMARY KEY,
            Name_company TEXT,
            Business_name TEXT,
            Nit TEXT,
            Address TEXT,
            Telephone TEXT,
            Id_zone_default INTEGER,
            Created_at TEXT
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Companies_zone_default ON Companies(Id_zone_default);');
      debugPrint('   ✅ Tabla Companies creada');

      // Tabla Zones
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Zones (
            Id_zone INTEGER PRIMARY KEY,
            Id_company INTEGER NOT NULL,
            Name_zone TEXT,
            Difficulty INTEGER NOT NULL,
            State_zone TEXT,
            Created_at TEXT,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Zones_company ON Zones(Id_company);');
      debugPrint('   ✅ Tabla Zones creada');

      // Tabla Zones_polygons
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Zones_polygons (
            Id_zone_polygon INTEGER PRIMARY KEY,
            Id_zone INTEGER NOT NULL,
            Latitude REAL NOT NULL,
            Longitude REAL NOT NULL,
            Created_at TEXT,
            FOREIGN KEY (Id_zone) REFERENCES Zones(Id_zone) ON DELETE CASCADE
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Zones_polygons_zone ON Zones_polygons(Id_zone);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Zones_polygons_coords ON Zones_polygons(Latitude, Longitude);');
      debugPrint('   ✅ Tabla Zones_polygons creada');

      // Tabla Users
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Users (
            Id_user INTEGER PRIMARY KEY,
            Id_company INTEGER NOT NULL,
            Oper_id TEXT,
            Name_user TEXT,
            Email TEXT,
            Created_at TEXT,
            Modified_at TEXT,
            Is_default INTEGER DEFAULT 0,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Users_company ON Users(Id_company);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Users_email ON Users(Email);');
      debugPrint('   ✅ Tabla Users creada');

      // Tabla Devices
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Devices (
            Id_device INTEGER PRIMARY KEY,
            Id_company INTEGER NOT NULL,
            Device_name TEXT,
            Cell_phone TEXT,
            Serial_id TEXT,
            Imei1 TEXT,
            Imei2 TEXT,
            Model TEXT,
            State TEXT,
            Is_default INTEGER DEFAULT 0,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Devices_company ON Devices(Id_company);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Devices_imei1 ON Devices(Imei1);');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS IX_Devices_imei_unique ON Devices(Imei1, Imei2);');
      debugPrint('   ✅ Tabla Devices creada');

      // Tabla Activities
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Activities (
            Id_activity INTEGER PRIMARY KEY,
            Id_company INTEGER NOT NULL,
            Id_activity_parent INTEGER,
            Name_activity TEXT,
            Group_activity TEXT,
            Unity TEXT,
            Type_activity TEXT,
            Type_effectivity TEXT,
            Cycle INTEGER,
            Effectivity_unitys INTEGER,
            Effectivity_visits INTEGER,
            Module_activity TEXT,
            Description_activity TEXT,
            Created_at TEXT,
            Is_default INTEGER DEFAULT 0,
            Read_default TEXT,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company),
            FOREIGN KEY (Id_activity_parent) REFERENCES Activities(Id_activity)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_company ON Activities(Id_company);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_parent ON Activities(Id_activity_parent);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_type ON Activities(Type_activity);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_module ON Activities(Module_activity);');
      debugPrint('   ✅ Tabla Activities creada');

      // Tabla Activities_steps
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Activities_steps (
            Id_activity_step INTEGER PRIMARY KEY,
            Id_activity INTEGER NOT NULL,
            Type_step TEXT,
            Order_step INTEGER,
            Default_value TEXT,
            Unity TEXT,
            Calculation TEXT,
            Name_step TEXT,
            Status TEXT,
            Is_required INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity) ON DELETE CASCADE
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_steps_activity ON Activities_steps(Id_activity);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_steps_order ON Activities_steps(Order_step);');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS IX_Activities_steps_unique ON Activities_steps(Id_activity, Order_step);');
      debugPrint('   ✅ Tabla Activities_steps creada');

      // Tabla Activities_status
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Activities_status (
            Id_activity_status INTEGER PRIMARY KEY,
            Id_activity INTEGER NOT NULL,
            Id_activity_step_parent INTEGER,
            Id_activity_status_parent INTEGER,
            Type_status TEXT,
            Order_status INTEGER,
            Default_status TEXT,
            Status_name TEXT,
            Color TEXT,
            Peso REAL,
            Castigo INTEGER,
            Boton INTEGER,
            Factor INTEGER,
            Status TEXT,
            FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity) ON DELETE CASCADE,
            FOREIGN KEY (Id_activity_step_parent) REFERENCES Activities_steps(Id_activity_step),
            FOREIGN KEY (Id_activity_status_parent) REFERENCES Activities_status(Id_activity_status)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_status_activity ON Activities_status(Id_activity);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_status_step_parent ON Activities_status(Id_activity_step_parent);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_status_parent ON Activities_status(Id_activity_status_parent);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Activities_status_order ON Activities_status(Order_status);');
      debugPrint('   ✅ Tabla Activities_status creada');

      // Tabla Headquarters_weights
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Headquarters_weights (
            Id_headquarter_weight INTEGER PRIMARY KEY,
            Id_headquarter INTEGER NOT NULL,
            Id_company INTEGER NOT NULL,
            Date_year INTEGER NOT NULL,
            Date_month INTEGER NOT NULL,
            Weight REAL NOT NULL,
            Created_at TEXT,
            Modified_at TEXT,
            FOREIGN KEY (Id_headquarter) REFERENCES Headquarters(Id_headquarter) ON DELETE CASCADE,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_hq ON Headquarters_weights(Id_headquarter);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_company ON Headquarters_weights(Id_company);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Headquarters_weights_date ON Headquarters_weights(Date_year, Date_month);');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS IX_Headquarters_weights_unique ON Headquarters_weights(Id_headquarter, Date_year, Date_month);');
      debugPrint('   ✅ Tabla Headquarters_weights creada');

      // Tabla News
      await db.execute('''
        CREATE TABLE IF NOT EXISTS News (
            Id_new INTEGER PRIMARY KEY,
            Id_company INTEGER NOT NULL,
            Name_new TEXT,
            Descripcion_activity TEXT,
            Order_display INTEGER NOT NULL,
            FOREIGN KEY (Id_company) REFERENCES Companies(Id_company)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_News_company ON News(Id_company);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_News_order ON News(Order_display);');
      debugPrint('   ✅ Tabla News creada');

      // Tabla Login_sessions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Login_sessions (
            Id_session INTEGER PRIMARY KEY AUTOINCREMENT,
            Token TEXT,
            Products_raw TEXT,
            Created_at TEXT,
            Synced_at TEXT,
            Id_user INTEGER,
            Id_device INTEGER,
            Id_activity INTEGER,
            FOREIGN KEY (Id_user) REFERENCES Users(Id_user),
            FOREIGN KEY (Id_device) REFERENCES Devices(Id_device),
            FOREIGN KEY (Id_activity) REFERENCES Activities(Id_activity)
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Login_sessions_user ON Login_sessions(Id_user);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS IX_Login_sessions_created ON Login_sessions(Created_at);');
      debugPrint('   ✅ Tabla Login_sessions creada');

      debugPrint('✅ Migración a versión 10 completada');
      debugPrint(
          '   Ahora la base de datos puede almacenar todos los datos del endpoint Login');
    }

    // Migración de v10 a v11: Verificar y actualizar esquema de Optimized_routes
    if (oldVersion < 11) {
      debugPrint('📦 Aplicando migración a versión 11...');
      debugPrint(
          '   Verificando esquema de Optimized_routes para columnas faltantes');

      // La verificación y actualización se hará en _verifyAndUpdateOptimizedRoutesSchema
      // Esta migración solo marca que se debe verificar

      debugPrint('✅ Migración a versión 11 completada');
      debugPrint(
          '   El esquema de Optimized_routes será verificado automáticamente');
    }

    if (oldVersion < 12) {
      debugPrint('📦 Aplicando migración a versión 12...');
      debugPrint('   Verificando y actualizando campo Route_pattern en Optimized_routes');
      // La migración de la v12 ya está implementada en la verificación del esquema
      debugPrint('✅ Migración a versión 12 completada');
    }

    if (oldVersion < 13) {
      debugPrint('📦 Aplicando migración a versión 13...');
      debugPrint('   Agregando campo Status a tabla Visits');

      try {
        // Verificar si la columna ya existe
        final tableInfo = await db.rawQuery('PRAGMA table_info(Visits)');
        final columnExists = tableInfo.any((column) => column['name'] == 'Status');

        if (!columnExists) {
          // Agregar la columna Status
          await db.execute(
            'ALTER TABLE Visits ADD COLUMN Status INTEGER NOT NULL DEFAULT 0'
          );
          debugPrint('✅ Campo Status agregado exitosamente a tabla Visits');

          // Crear índice para optimizar consultas por Status
          await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Visits_Status ON Visits(Status)'
          );
          debugPrint('✅ Índice IX_Visits_Status creado exitosamente');
        } else {
          debugPrint('ℹ️ Campo Status ya existe en tabla Visits, omitiendo migración');

          // Verificar si el índice existe, si no, crearlo
          await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Visits_Status ON Visits(Status)'
          );
        }
      } catch (e) {
        debugPrint('❌ Error en migración a versión 13: $e');
        // No lanzar el error para permitir que la app continúe
        // El campo se agregará en la siguiente sincronización
      }

      debugPrint('✅ Migración a versión 13 completada');
    }

    // Migración v13 a v14: Limpiar Activities corruptas
    if (oldVersion < 14) {
      debugPrint('📦 Aplicando migración a versión 14...');
      debugPrint('   Limpiando datos corruptos de Activities para forzar resincronización');

      try {
        // Limpiar tablas de Activities (en orden inverso por FKs)
        await db.execute('DELETE FROM Activities_status');
        debugPrint('   🧹 Tabla Activities_status limpiada');

        await db.execute('DELETE FROM Activities_steps');
        debugPrint('   🧹 Tabla Activities_steps limpiada');

        await db.execute('DELETE FROM Activities');
        debugPrint('   🧹 Tabla Activities limpiada');

        debugPrint('✅ Migración a versión 14 completada');
        debugPrint('   Las Activities se resincronizarán en el próximo login');
      } catch (e) {
        debugPrint('❌ Error en migración a versión 14: $e');
        // No lanzar el error para permitir que la app continúe
      }
    }

    // Migración v14 a v15: Agregar tabla Nfc_tags_history
    if (oldVersion < 15) {
      debugPrint('📦 Aplicando migración a versión 15...');
      debugPrint('   Agregando tabla Nfc_tags_history para historial de tags NFC');

      try {
        // Crear tabla Nfc_tags_history
        await db.execute('''
          CREATE TABLE IF NOT EXISTS Nfc_tags_history (
              Id_nfc_tag INTEGER PRIMARY KEY AUTOINCREMENT,
              Tag_id TEXT NOT NULL,
              Tag_type TEXT,
              Total_space INTEGER DEFAULT 0,
              Used_space INTEGER DEFAULT 0,
              Last_read DATETIME NOT NULL,
              Read_count INTEGER NOT NULL DEFAULT 1,
              Created_at DATETIME NOT NULL DEFAULT (datetime('now', 'utc'))
          );
        ''');
        debugPrint('   ✅ Tabla Nfc_tags_history creada');

        // Crear índices
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_tag_id ON Nfc_tags_history(Tag_id);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_last_read ON Nfc_tags_history(Last_read);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS IX_Nfc_tags_history_tag_type ON Nfc_tags_history(Tag_type);');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS UX_Nfc_tags_history_tag_id ON Nfc_tags_history(Tag_id);');
        debugPrint('   ✅ Índices creados para Nfc_tags_history');

        debugPrint('✅ Migración a versión 15 completada');
        debugPrint('   Ahora el historial de tags NFC se almacena en SQLite');
      } catch (e) {
        debugPrint('❌ Error en migración a versión 15: $e');
        // No lanzar el error para permitir que la app continúe
      }
    }

    // Migración v15 a v16: Agregar campos is_sync y tracking_headquarter a Activities
    if (oldVersion < 16) {
      debugPrint('📦 Aplicando migración a versión 16...');
      debugPrint('   Agregando campos is_sync y tracking_headquarter a tabla Activities');

      try {
        // Verificar si las columnas ya existen
        final columns = await db.rawQuery('PRAGMA table_info(Activities);');
        final columnNames = columns.map((col) => col['name'] as String).toList();

        // Agregar columna Is_sync si no existe
        if (!columnNames.contains('Is_sync')) {
          await db.execute(
              'ALTER TABLE Activities ADD COLUMN Is_sync INTEGER DEFAULT 0;');
          debugPrint('   ✅ Campo Is_sync agregado a tabla Activities');
        } else {
          debugPrint('   ℹ️ Campo Is_sync ya existe en tabla Activities');
        }

        // Agregar columna Tracking_headquarter si no existe
        if (!columnNames.contains('Tracking_headquarter')) {
          await db.execute(
              'ALTER TABLE Activities ADD COLUMN Tracking_headquarter INTEGER DEFAULT 1;');
          debugPrint('   ✅ Campo Tracking_headquarter agregado a tabla Activities');
        } else {
          debugPrint('   ℹ️ Campo Tracking_headquarter ya existe en tabla Activities');
        }

        debugPrint('✅ Migración a versión 16 completada');
        debugPrint('   Campos is_sync y tracking_headquarter disponibles en Activities');
      } catch (e) {
        debugPrint('❌ Error en migración a versión 16: $e');
        // No lanzar el error para permitir que la app continúe
      }
    }

    // Migración v16 a v17: Agregar campo is_sync_full a Activities
    if (oldVersion < 17) {
      debugPrint('📦 Aplicando migración a versión 17...');
      debugPrint('   Agregando campo is_sync_full a tabla Activities');

      try {
        // Verificar si la columna ya existe
        final columns = await db.rawQuery('PRAGMA table_info(Activities);');
        final columnNames = columns.map((col) => col['name'] as String).toList();

        // Agregar columna Is_sync_full si no existe
        if (!columnNames.contains('Is_sync_full')) {
          await db.execute(
              'ALTER TABLE Activities ADD COLUMN Is_sync_full INTEGER DEFAULT 0;');
          debugPrint('   ✅ Campo Is_sync_full agregado a tabla Activities');
        } else {
          debugPrint('   ℹ️ Campo Is_sync_full ya existe en tabla Activities');
        }

        debugPrint('✅ Migración a versión 17 completada');
        debugPrint('   Campo is_sync_full disponible en Activities');
      } catch (e) {
        debugPrint('❌ Error en migración a versión 17: $e');
        // No lanzar el error para permitir que la app continúe
      }
    }

    // Futuras migraciones se agregarían aquí
    // if (oldVersion < 18) { ... }
  } catch (e) {
    debugPrint('❌ Error durante la migración de la base de datos: $e');
    rethrow;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
