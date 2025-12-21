// Automatic FlutterFlow imports
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
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
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

  // NOTA: Ya no se inserta directamente a SQLite desde el isolate.
  // Ahora las ubicaciones se envían al hilo principal via service.invoke('newLocation')
  // El hilo principal las acumula en AppState y cada 60s las depura e inserta a SQLite.

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
      } else {
        lastSensorUpdate ??= DateTime.now();
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

      // Enviar progreso de GPS al hilo principal (accuracy actual)
      if (!isStabilized) {
        service.invoke('gpsProgress', {
          'accuracy': position.accuracy,
          'elapsed': elapsed,
        });
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

        // Notificar al hilo principal que el GPS está estabilizado
        service.invoke('gpsStabilized', {'stabilized': true});
      }

      // Conversión a UTM
      final ptUtm = utmCache.toUTM(position.latitude, position.longitude);
      if (ptUtm == null) return;

      final measX = ptUtm.x;
      final measY = ptUtm.y;
      final measAlt = position.altitude;

      // Multipath y HDOP
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

      // Enviar ubicación al hilo principal para acumular y depurar
      if (isStabilized) {
        try {
          final batteryLevel = await batteryCache.getBatteryLevel();

          // Enviar ubicación al hilo principal via service.invoke()
          // El hilo principal acumulará en AppState y cada 60s depurará e insertará a SQLite
          service.invoke('newLocation', {
            'latitude': filteredGeo.y,
            'longitude': filteredGeo.x,
            'altitude': filteredAlt,
            'horizontalError': finalError,
            'speed': filteredSpeed,
            'battery': batteryLevel,
            'createdAt': DateTime.now().toIso8601String(),
          });

          if (updateCount % 40 == 0) {
            debugPrint(
                '📤 Ubicación enviada al hilo principal: lat=${filteredGeo.y.toStringAsFixed(6)}, lon=${filteredGeo.x.toStringAsFixed(6)}, speed=${filteredSpeed.toStringAsFixed(2)}m/s');
          }
        } catch (e) {
          debugPrint('❌ Error enviando ubicación al hilo principal: $e');
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

    debugPrint('🧹 Limpieza del servicio de segundo plano completada');
  }
}

/// Función pública para iniciar el servicio
Future<void> startBackgroundLocationService() async {
  final service = FlutterBackgroundService();

  // IMPORTANTE: Verificar permisos ANTES de iniciar el servicio
  // Esto debe hacerse en el hilo principal donde hay Activity/UI disponible
  debugPrint('🔐 Verificando permisos de ubicación antes de iniciar servicio...');

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    debugPrint('📍 Solicitando permisos de ubicación...');
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('❌ Permisos de ubicación denegados por el usuario');
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    debugPrint('❌ Permisos de ubicación denegados permanentemente. El usuario debe habilitarlos en Configuración.');
    return;
  }

  // Verificar que los servicios de ubicación estén habilitados
  if (!await Geolocator.isLocationServiceEnabled()) {
    debugPrint('❌ Servicios de ubicación deshabilitados. Solicitando activación...');
    // Intentar abrir configuración de ubicación
    await Geolocator.openLocationSettings();
    return;
  }

  debugPrint('✅ Permisos de ubicación verificados: $permission');

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
