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

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geodesy/geodesy.dart';
import 'package:proj4dart/proj4dart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Importar las clases del archivo get_location_list.dart
import 'get_location_list.dart';

/// Inicializa y configura el servicio de segundo plano
Future<void> initializeBackgroundLocationService() async {
  final service = FlutterBackgroundService();

  // Crear canal de notificaciones para Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_tracking_channel', // ID
    'Servicio de Geolocalización', // Título
    description:
        'Este canal muestra la notificación del servicio de rastreo de ubicación',
    importance: Importance.low, // Importancia baja para no molestar
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // No iniciar automáticamente, lo haremos manualmente
      autoStartOnBoot: false, // NO reiniciar cuando el dispositivo arranque
      isForegroundMode: true, // IMPORTANTE: Modo foreground para seguir vivo
      notificationChannelId: 'location_tracking_channel',
      initialNotificationTitle: 'ClickPalm GPS',
      initialNotificationContent: 'Rastreando ubicación...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  debugPrint('✅ Servicio de segundo plano configurado correctamente');
}

/// Función principal que se ejecuta en el servicio de segundo plano (Android)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugPrint('🚀 Servicio de segundo plano INICIADO');

  // Para Android, configurar como servicio foreground
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    debugPrint('🛑 Deteniendo servicio de segundo plano');
    service.stopSelf();
  });

  // Iniciar el servicio como foreground inmediatamente
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'ClickPalm GPS Activo',
      content: 'Registrando tu ubicación en segundo plano',
    );
  }

  // Ejecutar la lógica de geolocalización
  await _startBackgroundLocationTracking(service);
}

/// Callback para iOS cuando la app está en background
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  debugPrint('📱 iOS: Servicio en background');
  return true;
}

/// Lógica principal de rastreo de ubicación en segundo plano
Future<void> _startBackgroundLocationTracking(ServiceInstance service) async {
  debugPrint('=== Iniciando rastreo de ubicación en segundo plano ===');

  // IMPORTANTE: El servicio de segundo plano corre en un isolate separado
  // Por eso debe manejar su propia conexión a la base de datos
  Database? backgroundDb;
  bool tableVerified = false; // Cache para evitar verificar la tabla cada vez

  // Función para obtener o reconectar la base de datos del servicio
  Future<Database?> getBackgroundDatabase() async {
    try {
      // Si la conexión está abierta, usarla
      if (backgroundDb != null && backgroundDb!.isOpen) {
        return backgroundDb;
      }

      // Abrir nueva conexión
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        debugPrint('❌ BG Service: No se pudo acceder al almacenamiento');
        return null;
      }

      final String basePath = '${externalDir.path}/ClickPalmData';
      final Directory targetDir = Directory(basePath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final String dbPath = path.join(basePath, 'clickpalm_database.db');

      // Abrir con singleInstance: false porque este isolate es independiente
      backgroundDb = await openDatabase(
        dbPath,
        singleInstance: false, // CRÍTICO: false porque estamos en isolate separado
      );

      // IMPORTANTE: Habilitar WAL mode para mejor concurrencia
      // WAL permite lecturas y escrituras simultáneas sin bloqueos
      // Usar rawQuery en lugar de execute para PRAGMA
      await backgroundDb!.rawQuery('PRAGMA journal_mode=WAL');
      // Reducir tiempo de espera de bloqueo (5 segundos en vez de default)
      await backgroundDb!.rawQuery('PRAGMA busy_timeout=5000');
      // Sincronización normal (balance entre seguridad y velocidad)
      await backgroundDb!.rawQuery('PRAGMA synchronous=NORMAL');

      debugPrint('🔗 BG Service: Conexión a DB abierta con WAL mode en $dbPath');
      tableVerified = false; // Reset para verificar tabla con nueva conexión
      return backgroundDb;
    } catch (e) {
      debugPrint('❌ BG Service: Error abriendo DB: $e');
      backgroundDb = null;
      return null;
    }
  }

  // Función para insertar ubicación con reintentos en caso de bloqueo
  Future<bool> insertLocationWithRetry(Database db, List<dynamic> values) async {
    const maxRetries = 3;
    const baseDelay = Duration(milliseconds: 100);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await db.rawInsert('''
          INSERT OR IGNORE INTO Location_tracking
          (Id_company, Imei, Latitude, Longitude, Altitude, HorizontalError, Speed, Battery, CreatedAt, SyncedAt, batch_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', values);
        return true;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Si es error de bloqueo, reintentar con backoff exponencial
        if (errorStr.contains('locked') || errorStr.contains('busy')) {
          final delay = baseDelay * (1 << attempt); // 100ms, 200ms, 400ms
          debugPrint('⏳ BG Service: DB bloqueada, reintentando en ${delay.inMilliseconds}ms (intento ${attempt + 1}/$maxRetries)');
          await Future.delayed(delay);
        } else {
          // Si es otro tipo de error, no reintentar
          debugPrint('❌ BG Service: Error insertando ubicación: $e');
          return false;
        }
      }
    }
    debugPrint('❌ BG Service: No se pudo insertar después de $maxRetries intentos');
    return false;
  }

  // Función para asegurar que la tabla existe
  Future<void> ensureTableExists(Database db) async {
    try {
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
        debugPrint('📦 BG Service: Tabla Location_tracking creada');
      }
    } catch (e) {
      debugPrint('❌ BG Service: Error verificando tabla: $e');
    }
  }

  // Inicialización de componentes (igual que en get_location_list.dart)
  final movementDetector = MovementDetector();
  final multipathDetector = MultipathDetector();
  final imuIntegrator = IMUIntegrator();
  final utmCache = UTMCache();
  final batteryCache = BatteryCache();

  int consecutiveRejects = 0;
  final xWindow = Queue<double>();
  final yWindow = Queue<double>();
  final altWindow = Queue<double>();
  final speedWindow = Queue<double>();

  DateTime? lastSensorUpdate;
  DateTime? lastGPSUpdate;
  AccelerometerEvent? lastAccelEvent;
  GyroscopeEvent? lastGyroEvent;

  // Suscripciones a sensores
  StreamSubscription<AccelerometerEvent>? accelSub;
  StreamSubscription<GyroscopeEvent>? gyroSub;
  StreamSubscription<Position>? locationSub;

  // UKF
  final ukf = UnscentedKalmanFilter();

  try {
    // Configurar acelerómetro
    accelSub = accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 200))
        .listen((event) {
      lastAccelEvent = event;
      movementDetector.updateAccelerometer(event);
    });

    // Configurar giroscopio
    gyroSub =
        gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 200))
            .listen((event) {
      lastGyroEvent = event;

      if (lastAccelEvent != null && lastSensorUpdate != null) {
        final now = DateTime.now();
        final dt = now.difference(lastSensorUpdate!).inMilliseconds / 1000.0;

        if (dt > 0 && dt < 1.0) {
          imuIntegrator.updateOrientation(event, dt);
          imuIntegrator.updatePosition(
            lastAccelEvent!,
            event,
            dt,
            !movementDetector.isCurrentlyStatic(),
            movementDetector.isCurrentlyStatic(),
          );
          imuIntegrator.detectBrushChange();
        }

        lastSensorUpdate = now;
      } else if (lastSensorUpdate == null) {
        lastSensorUpdate = DateTime.now();
      }
    });

    // Verificar permisos - IMPORTANTE: NO solicitar permisos aquí
    // porque el servicio de segundo plano no tiene Activity/UI
    // Los permisos deben ser solicitados ANTES de iniciar el servicio (en la app principal)
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('❌ BG Service: Permisos de ubicación no otorgados. Solicítelos desde la app.');
      return;
    }

    // Verificar si el servicio de ubicación está habilitado
    // NOTA: No intentar habilitarlo aquí porque requiere UI
    bool locationEnabled = false;
    try {
      locationEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('⚠️ BG Service: No se pudo verificar servicio de ubicación: $e');
      // Continuar de todas formas, el stream de posiciones manejará el error
      locationEnabled = true;
    }

    if (!locationEnabled) {
      debugPrint('❌ BG Service: Servicios de ubicación deshabilitados. Habilítelos desde configuración.');
      return;
    }

    // Configuración de ubicación según plataforma
    late LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 1500),
        forceLocationManager: false,
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.fitness,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true, // IMPORTANTE para iOS
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    final startTime = DateTime.now();
    bool isWarmedUp = false;
    bool isStabilized = false;

    int updateCount = 0;

    // Stream de posiciones GPS
    locationSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) async {
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      updateCount++;

      // Actualizar notificación cada 10 segundos
      if (updateCount % 7 == 0 && service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'ClickPalm GPS Activo',
          content:
              'Ubicación: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} | Precisión: ${position.accuracy.toStringAsFixed(1)}m',
        );
      }

      // Validación inicial
      if (!PositionValidator.isValidPosition(
          position, ukf, movementDetector, utmCache, lastGPSUpdate)) {
        consecutiveRejects++;
        if (consecutiveRejects > LocationConfig.maxConsecutiveRejects) {
          consecutiveRejects = 0;
          ukf.increaseUncertainty(2.0);
        }
        return;
      }

      consecutiveRejects = 0;
      lastGPSUpdate = DateTime.now();

      // Limitar ventanas
      while (xWindow.length >= LocationConfig.medianWindowSize) {
        xWindow.removeFirst();
      }
      while (yWindow.length >= LocationConfig.medianWindowSize) {
        yWindow.removeFirst();
      }

      // Warm-up
      if (elapsed < LocationConfig.warmupSeconds) {
        return;
      }

      if (!isWarmedUp) {
        isWarmedUp = true;
        xWindow.clear();
        yWindow.clear();
        altWindow.clear();
        speedWindow.clear();
      }

      // Marcar como estabilizado
      if (elapsed >=
              LocationConfig.warmupSeconds +
                  LocationConfig.stabilizationSeconds &&
          !isStabilized) {
        isStabilized = true;
        debugPrint(
            '✅ Servicio en segundo plano estabilizado después de ${elapsed}s');
      }

      // Conversión a UTM
      final ptUtm = utmCache.toUTM(position.latitude, position.longitude);
      if (ptUtm == null) return;

      final measX = ptUtm.x;
      final measY = ptUtm.y;
      final measAlt = position.altitude;

      // Multipath y HDOP
      final isMultipath =
          multipathDetector.isLikelyMultipath(position, movementDetector);
      final multipathPenalty = multipathDetector.getMultipathPenalty();
      final baseAccuracy = HDOPCorrector.adjustAccuracyByDOP(position);
      final adjustedAccuracy = baseAccuracy * multipathPenalty;
      final measNoise = pow(adjustedAccuracy, 2).toDouble();

      // Inicializar UKF
      if (ukf.state[0] == 0.0 && ukf.state[1] == 0.0) {
        ukf.state[0] = measX;
        ukf.state[1] = measY;
      }

      // IMU
      Vector3? imuAccel = lastAccelEvent != null
          ? imuIntegrator.getWorldAcceleration(lastAccelEvent!)
          : null;

      final ukfPos = ukf.getPosition();
      final currentSpeed = ukfPos['speed'] ?? position.speed;
      final currentAccel = ukfPos['acceleration'] ?? 0.0;
      final processNoise = AdaptiveProcessNoise.calculate(
          currentSpeed, currentAccel, movementDetector.isCurrentlyStatic());

      // Predicción y actualización UKF
      ukf.predict(1.5, processNoise);
      ukf.update(measX, measY, measNoise, imuAccel);

      final ukfState = ukf.getPosition();
      final ukfX = ukfState['x']!;
      final ukfY = ukfState['y']!;
      final ukfSpeed = ukfState['speed']!;

      // Sincronizar IMU
      final gpsHeading = position.heading * (pi / 180.0);
      imuIntegrator.syncWithGPS(ukfX, ukfY, ukfSpeed, gpsHeading);

      // Ventanas
      void addToWindow(Queue<double> window, double value, int maxSize) {
        window.addLast(value);
        if (window.length > maxSize) window.removeFirst();
      }

      addToWindow(xWindow, ukfX, LocationConfig.medianWindowSize);
      addToWindow(yWindow, ukfY, LocationConfig.medianWindowSize);
      addToWindow(altWindow, measAlt, LocationConfig.medianWindowSize);
      addToWindow(speedWindow, ukfSpeed, LocationConfig.medianWindowSize);

      // Mediana
      double getMedian(Queue<double> window, {int? customSize}) {
        if (window.isEmpty) return 0.0;

        final elementsToUse = customSize != null && customSize < window.length
            ? window.toList().sublist(window.length - customSize)
            : window.toList();

        elementsToUse.sort();
        final len = elementsToUse.length;

        if (len == 1) return elementsToUse[0];

        final medianIndex = len ~/ 2;
        if (len.isOdd) {
          return elementsToUse[medianIndex];
        } else {
          return (elementsToUse[medianIndex - 1] + elementsToUse[medianIndex]) /
              2;
        }
      }

      final adaptiveWindowSize = imuIntegrator.isBrushChange
          ? 5
          : LocationConfig.medianWindowSize;

      final filteredX = getMedian(xWindow, customSize: adaptiveWindowSize);
      final filteredY = getMedian(yWindow, customSize: adaptiveWindowSize);
      final filteredAlt = getMedian(altWindow, customSize: adaptiveWindowSize);
      final filteredSpeed =
          getMedian(speedWindow, customSize: adaptiveWindowSize);

      // Error estimado
      final baseError = ukf.getPositionError();
      final speedFactor = filteredSpeed > 1.0 ? 1 + (filteredSpeed / 10) : 1.0;
      final movementFactor = movementDetector.isCurrentlyStatic() ? 0.8 : 1.2;
      final finalError =
          max(baseError * speedFactor * movementFactor, position.accuracy * 0.7);

      // Conversión a geo
      final filteredGeo = utmCache.toGeo(filteredX, filteredY);
      if (filteredGeo == null) return;

      // Guardar en SQLite si está estabilizado - usando conexión local del servicio
      if (isStabilized) {
        try {
          // Obtener o reconectar la base de datos del servicio
          final db = await getBackgroundDatabase();
          if (db == null) {
            debugPrint('⚠️ BG Service: No se pudo obtener conexión a DB');
            return;
          }

          // Asegurar que la tabla existe (solo la primera vez o después de reconexión)
          if (!tableVerified) {
            await ensureTableExists(db);
            tableVerified = true;
          }

          final batteryLevel = await batteryCache.getBatteryLevel();

          // Usar función con reintentos para evitar bloqueos
          final success = await insertLocationWithRetry(db, [
            0, // Id_company
            '', // Imei
            filteredGeo.y, // Latitude
            filteredGeo.x, // Longitude
            filteredAlt,
            finalError,
            filteredSpeed,
            batteryLevel,
            DateTime.now().toIso8601String(),
            DateTime.now().toIso8601String(),
            null, // batch_id
          ]);

          if (success && updateCount % 40 == 0) {
            debugPrint(
                '💾 Ubicación guardada en segundo plano: lat=${filteredGeo.y.toStringAsFixed(6)}, lon=${filteredGeo.x.toStringAsFixed(6)}, speed=${filteredSpeed.toStringAsFixed(2)}m/s');
          }
        } catch (e) {
          debugPrint('❌ Error guardando ubicación en segundo plano: $e');
          // Si hay error de base de datos cerrada, intentar reconectar en el próximo ciclo
          if (e.toString().contains('database_closed')) {
            backgroundDb = null;
            tableVerified = false;
            debugPrint('🔄 BG Service: Reconectando DB en próximo ciclo...');
          }
        }
      }
    }, onError: (error) {
      debugPrint('❌ Error en stream de posiciones (servicio): $error');
    }, cancelOnError: false);

    // Mantener el servicio vivo
    while (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      await Future.delayed(const Duration(seconds: 1));
    }
  } catch (e) {
    debugPrint('❌ Error en servicio de segundo plano: $e');
  } finally {
    // Cleanup
    await accelSub?.cancel();
    await gyroSub?.cancel();
    await locationSub?.cancel();

    // Cerrar conexión de base de datos del servicio
    if (backgroundDb != null && backgroundDb!.isOpen) {
      await backgroundDb!.close();
      debugPrint('🔒 BG Service: Conexión a DB cerrada');
    }

    debugPrint('🧹 Limpieza del servicio de segundo plano completada');
  }
}

/// Función pública para iniciar el servicio
Future<void> startBackgroundLocationService() async {
  final service = FlutterBackgroundService();

  // Inicializar si no está inicializado
  if (!await service.isRunning()) {
    await initializeBackgroundLocationService();
  }

  // Iniciar el servicio
  await service.startService();
  debugPrint('✅ Servicio de geolocalización en segundo plano INICIADO');
}

/// Función pública para detener el servicio
Future<void> stopBackgroundLocationService() async {
  final service = FlutterBackgroundService();
  service.invoke('stopService');
  debugPrint('🛑 Servicio de geolocalización en segundo plano DETENIDO');
}

/// Función pública para verificar si el servicio está corriendo
Future<bool> isBackgroundLocationServiceRunning() async {
  final service = FlutterBackgroundService();
  return await service.isRunning();
}
