// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Verifica si se necesita calibración de GPS y brújula
///
/// Retorna true si se requiere calibración, false si ya está calibrado
/// Usa FFAppState().calibrateCompass como fuente de verdad
Future<bool> checkCalibrationNeeded() async {
  try {
    // Usar la variable del AppState como fuente de verdad
    final isCalibrated = FFAppState().calibrateCompass;

    debugPrint('📍 Estado de calibración (calibrateCompass): ${isCalibrated ? "Calibrado" : "Requiere calibración"}');

    // Retorna true si NO está calibrado (necesita calibración)
    return !isCalibrated;
  } catch (e) {
    debugPrint('❌ Error verificando calibración: $e');
    // En caso de error, asumir que NO necesita calibración para evitar bloquear al usuario
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
