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

Future<List<String>> getLocationList(BuildContext context, int seconds) async {
  List<String> locationList = await _fetchLocationList(context, seconds);
  // Cerrar cualquier diálogo abierto si fuera necesario
  return locationList;
}

Future<List<String>> _fetchLocationList(
    BuildContext context, int seconds) async {
  List<String> locationList = [];
  int attempts = (seconds * 1000) ~/ 500; // Número de intentos

  // Variables para el filtro de Kalman en cada dimensión.
  double? latEstimate, lonEstimate, altEstimate, accEstimate;
  double latCov = 0.0, lonCov = 0.0, altCov = 0.0, accCov = 0.0;
  // Parámetros del filtro (ajusta según tus necesidades)
  double processNoise = 0.0001;
  double measurementNoise = 0.1;

  try {
    // Verificar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return ["ERROR: Permiso de ubicación denegado"];
      }
    }

    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return ["ERROR: Servicios de ubicación deshabilitados"];
    }

    // Capturar ubicaciones en el tiempo especificado
    for (int i = 0; i < attempts; i++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation);

        if (latEstimate == null) {
          // Primera medición: inicializamos los valores y covarianzas.
          latEstimate = position.latitude;
          lonEstimate = position.longitude;
          altEstimate = position.altitude;
          accEstimate = position.accuracy;
          latCov = 1.0;
          lonCov = 1.0;
          altCov = 1.0;
          accCov = 1.0;
        } else {
          // Actualización del filtro para latitud:
          latCov = latCov + processNoise;
          double latKalmanGain = latCov / (latCov + measurementNoise);
          latEstimate =
              latEstimate! + latKalmanGain * (position.latitude - latEstimate!);
          latCov = (1 - latKalmanGain) * latCov;

          // Actualización del filtro para longitud:
          lonCov = lonCov + processNoise;
          double lonKalmanGain = lonCov / (lonCov + measurementNoise);
          lonEstimate = lonEstimate! +
              lonKalmanGain * (position.longitude - lonEstimate!);
          lonCov = (1 - lonKalmanGain) * lonCov;

          // Actualización del filtro para altitud:
          altCov = altCov + processNoise;
          double altKalmanGain = altCov / (altCov + measurementNoise);
          altEstimate =
              altEstimate! + altKalmanGain * (position.altitude - altEstimate!);
          altCov = (1 - altKalmanGain) * altCov;

          // Actualización del filtro para precisión:
          accCov = accCov + processNoise;
          double accKalmanGain = accCov / (accCov + measurementNoise);
          accEstimate =
              accEstimate! + accKalmanGain * (position.accuracy - accEstimate!);
          accCov = (1 - accKalmanGain) * accCov;
        }

        String locationData =
            "LAT:${latEstimate!.toStringAsFixed(6)}; LON:${lonEstimate!.toStringAsFixed(6)}; ALT:${altEstimate!.toStringAsFixed(2)}; ERH:${accEstimate!.toStringAsFixed(2)}";
        locationList.add(locationData);
      } catch (e) {
        locationList.add(
            "ERROR: No se puede recuperar la ubicación en el intento $i: $e");
      }

      // Retraso de 200 ms entre intentos
      await Future.delayed(Duration(milliseconds: 200));
    }
  } catch (e) {
    return ["ERROR: $e"];
  }

  return locationList;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
