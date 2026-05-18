// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '/custom_code/platform_utils.dart';

Future<bool> calibrateGPS() async {
  if (!Platforms.isMobile) return false; // GPS no disponible en desktop
  StreamSubscription<Position>? positionStream;
  final completer = Completer<bool>();
  final stopwatch = Stopwatch()..start();

  try {
    // 1. Verificar servicios de ubicación
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final settingsOpened = await Geolocator.openLocationSettings();
      if (!settingsOpened) return false;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // 2. Verificar/obtener permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return false;
      }
    }

    // 3. Configuración de ultra-precisión
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // Recibir todas las actualizaciones
    );

    // 4. Monitoreo en tiempo real
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) {
      final currentAccuracy = pos.accuracy ?? double.infinity;

      // Condiciones de éxito:
      if (currentAccuracy < 3.0 || stopwatch.elapsed.inSeconds >= 30) {
        positionStream?.cancel();
        completer.complete(currentAccuracy < 10.0);

        // Debug: Mostrar métricas finales
        debugPrint('''
        Precisión final: ${currentAccuracy.toStringAsFixed(2)}m
        Tiempo: ${stopwatch.elapsed.inSeconds} seg
        ''');
      }
    });

    // Timeout absoluto (45 segundos como respaldo)
    Future.delayed(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        positionStream?.cancel();
        completer.complete(false);
      }
    });

    return await completer.future;
  } catch (e) {
    positionStream?.cancel();
    debugPrint('Error crítico en calibración: $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
