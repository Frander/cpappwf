// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

Future<List<String>> getLocationList(int seconds) async {
  return compute(_fetchLocationList, seconds);
}

// Función que se ejecuta en un Isolate separado
Future<List<String>> _fetchLocationList(int seconds) async {
  List<String> locationList = [];
  int attempts = (seconds * 1000) ~/ 500; // Cantidad de intentos

  try {
    // Verificar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return ["ERROR: Location permission denied"];
      }
    }

    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return ["ERROR: Location services disabled"];
    }

    // Capturar ubicaciones en el tiempo especificado
    for (int i = 0; i < attempts; i++) {
      try {
        Position currentPosition = await Geolocator.getCurrentPosition();
        locationList.add(
            "LAT:${currentPosition.latitude};LON:${currentPosition.longitude};ALT:${currentPosition.altitude}");
      } catch (e) {
        locationList
            .add("ERROR: Unable to retrieve location on attempt $i: $e");
      }

      // Retraso de 500 ms
      await Future.delayed(Duration(milliseconds: 500));
    }
  } catch (e) {
    return ["ERROR: $e"];
  }

  return locationList;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
