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
