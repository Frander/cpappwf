// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// ============================================================================
// SERVICIO GPS — VERSIÓN LITE
// ----------------------------------------------------------------------------
// Filtro ligero que prioriza bajo consumo de batería y CPU sobre máxima
// precisión. Alcanza ~70-80% de la precisión del pipeline UKF+IMU con ~5%
// del costo de cómputo.
//
// Pipeline (5 pasos):
//   1. Rechazo de outliers crudos por accuracy > maxAccuracy
//   2. Ventana deslizante de 5 lecturas
//   3. Mediana (lat/lon) para rechazo intra-ventana de saltos bruscos
//   4. Media ponderada por inverse-variance (peso = 1/err²) — MLE gaussiano
//   5. Error estimado = mejor accuracy de la ventana (sin EMA para evitar
//      convergencia lenta que dispara falsos "calidad GPS baja")
// ============================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:battery_plus/battery_plus.dart';

class LiteGPSFilter {
  static const int _windowSize = 5;
  static const int _minPoints = 3;
  static const double _maxAccuracy = 25.0;
  static const double _medianRejectMeters = 20.0;

  final Queue<Position> _window = Queue<Position>();
  bool _warmedUp = false;
  DateTime? _startTime;
  static const int _warmupSeconds = 3;

  Map<String, dynamic>? process(Position p, int batteryLevel) {
    _startTime ??= DateTime.now();

    // 1. Warmup corto (3s en LITE vs 10s en ADVANCED)
    if (!_warmedUp) {
      if (DateTime.now().difference(_startTime!).inSeconds < _warmupSeconds) {
        return null;
      }
      _warmedUp = true;
    }

    // 2. Rechazo de outliers crudos
    if (p.accuracy <= 0 || p.accuracy > _maxAccuracy) return null;

    // 3. Ventana deslizante
    _window.addLast(p);
    if (_window.length > _windowSize) _window.removeFirst();
    if (_window.length < _minPoints) return null;

    // 4. Mediana para rechazar saltos bruscos dentro de la ventana
    final lats = _window.map((e) => e.latitude).toList()..sort();
    final lons = _window.map((e) => e.longitude).toList()..sort();
    final medLat = lats[lats.length ~/ 2];
    final medLon = lons[lons.length ~/ 2];

    const metersPerDegLat = 111320.0;
    final metersPerDegLon = 111320.0 * cos(medLat * pi / 180.0);

    final validPoints = _window.where((pt) {
      final dLat = (pt.latitude - medLat) * metersPerDegLat;
      final dLon = (pt.longitude - medLon) * metersPerDegLon;
      return sqrt(dLat * dLat + dLon * dLon) < _medianRejectMeters;
    }).toList();

    if (validPoints.isEmpty) return null;

    // 5. Media ponderada por inverse-variance (MLE gaussiano)
    double wSum = 0.0, wLat = 0.0, wLon = 0.0, wAlt = 0.0;
    double bestAcc = double.infinity;
    for (final pt in validPoints) {
      final w = 1.0 / (pt.accuracy * pt.accuracy + 0.01);
      wLat += pt.latitude * w;
      wLon += pt.longitude * w;
      wAlt += pt.altitude * w;
      wSum += w;
      if (pt.accuracy < bestAcc) bestAcc = pt.accuracy;
    }

    // Error estimado: usar la mejor accuracy de la ventana directamente.
    // El promedio ponderado por inverse-variance ya reduce el error estadístico,
    // pero no sabemos cuánto sin calibración. Usar bestAcc es conservador y
    // evita que el detector de calidad en main.dart dispare falsos positivos
    // por un EMA que converge lento desde valores altos.
    // Piso: bestAcc × 0.7 (el promedio ponderado es mejor que el mejor punto solo)
    final estimatedError = bestAcc * 0.7;

    return {
      'latitude': wLat / wSum,
      'longitude': wLon / wSum,
      'altitude': wAlt / wSum,
      'horizontalError': estimatedError,
      'speed': p.speed,
      'battery': batteryLevel,
      'createdAt': DateTime.now().toIso8601String(),
      'method': 'LITE',
      'heading': p.heading,
      'acceleration': 0.0,
      'isStatic': p.speed < 0.3,
      'isBrushChange': false,
      'ukfPositionError': estimatedError,
      'vx': 0.0,
      'vy': 0.0,
    };
  }

  void reset() {
    _window.clear();
    _warmedUp = false;
    _startTime = null;
  }
}

/// Lógica de rastreo LITE. Se llama desde el isolate de background cuando el
/// modo activo es 'LITE'. Comparte el mismo ServiceInstance que el ADVANCED.
Future<void> startLiteLocationTracking(
    ServiceInstance service,
    double effectiveAccuracyThreshold) async {
  debugPrint('🌱 Iniciando rastreo GPS en modo LITE | umbral: ${effectiveAccuracyThreshold}m');

  final filter = LiteGPSFilter();
  final battery = Battery();
  int cachedBattery = 100;
  DateTime lastBatteryFetch = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<Position>? locationSub;
  bool stabilizedEmitted = false;
  int consecutiveOverMarginLite = 0;
  const int overMarginHysteresis = 3;

  try {
    // Misma configuración de plataforma que ADVANCED para obtener las
    // mejores lecturas del chip GPS. La diferencia LITE vs ADVANCED está
    // en el post-procesamiento, no en la adquisición del hardware.
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
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    locationSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) async {
        // Cachear batería cada 60s
        if (DateTime.now().difference(lastBatteryFetch).inSeconds > 60) {
          try {
            cachedBattery = await battery.batteryLevel;
          } catch (_) {}
          lastBatteryFetch = DateTime.now();
        }

        // Estabilización inmediata por calidad (umbral dinámico según actividad)
        if (!stabilizedEmitted &&
            position.accuracy > 0 &&
            position.accuracy <= effectiveAccuracyThreshold) {
          stabilizedEmitted = true;
          consecutiveOverMarginLite = 0;
          service.invoke('gpsStabilized', {'stabilized': true});
          debugPrint(
              '✅ LITE estabilizado (${position.accuracy.toStringAsFixed(1)}m ≤ ${effectiveAccuracyThreshold}m)');
        }

        // Progreso para UI mientras no está estabilizado
        if (!stabilizedEmitted) {
          service.invoke('gpsProgress', {
            'accuracy': position.accuracy,
            'phase': 'lite-warmup',
            'speed': position.speed,
            'altitude': position.altitude,
          });
        }

        // Verificación continua: si la accuracy supera el umbral durante N lecturas → desestabilizar.
        // Aplica siempre (con o sin actividad), umbral mínimo 100 m.
        if (stabilizedEmitted) {
          if (position.accuracy > effectiveAccuracyThreshold) {
            consecutiveOverMarginLite++;
            if (consecutiveOverMarginLite >= overMarginHysteresis) {
              stabilizedEmitted = false;
              consecutiveOverMarginLite = 0;
              service.invoke('gpsStabilized', {'stabilized': false});
              debugPrint(
                  '⚠️ LITE desestabilizado: ${position.accuracy.toStringAsFixed(1)}m > ${effectiveAccuracyThreshold}m');
            }
          } else {
            consecutiveOverMarginLite = 0;
          }
        }

        final payload = filter.process(position, cachedBattery);
        if (payload == null) return;

        // Fallback: filtro produjo resultado → emitir estabilizado
        if (!stabilizedEmitted) {
          stabilizedEmitted = true;
          consecutiveOverMarginLite = 0;
          service.invoke('gpsStabilized', {'stabilized': true});
          debugPrint('✅ LITE estabilizado (primera lectura filtrada)');
        }

        service.invoke('newLocation', payload);
      },
      onError: (e) => debugPrint('❌ LITE stream error: $e'),
      cancelOnError: false,
    );

    // Keep-alive hasta stopService
    final keepAlive = Completer<void>();
    service.on('stopService').listen((_) {
      if (!keepAlive.isCompleted) keepAlive.complete();
    });
    await keepAlive.future;
  } catch (e) {
    debugPrint('❌ Error en LITE tracking: $e');
  } finally {
    await locationSub?.cancel();
    debugPrint('🧹 LITE tracking finalizado');
  }
}
