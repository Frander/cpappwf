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

import 'package:geolocator/geolocator.dart';

Future<String> getLocation() async {
  try {
    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return "ERROR: Location permission denied";
      }
    }

    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Intenta obtener la última ubicación conocida si los servicios no están habilitados
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return "LAT:${lastKnownPosition.latitude};LON:${lastKnownPosition.longitude};ALT:${lastKnownPosition.altitude}";
      } else {
        return "ERROR: Location services disabled, and no last known location available";
      }
    }

    // Obtener la ubicación en tiempo real
    Position currentPosition = await Geolocator.getCurrentPosition();
    return "LAT:${currentPosition.latitude};LON:${currentPosition.longitude};ALT:${currentPosition.altitude}";
  } catch (e) {
    return "ERROR: $e";
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
