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

import 'package:shared_preferences/shared_preferences.dart';

/// Marca la calibración como completada para el usuario y dispositivo actual
///
/// Guarda la fecha de calibración para poder validar si necesita recalibrarse
Future<void> markCalibrationCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Obtener ID del usuario y dispositivo actual
    final userId = FFAppState().userSelected.idUser;
    final deviceId = FFAppState().deviceDefault.idDevice;

    // Key única por usuario y dispositivo
    final calibrationKey = 'calibration_completed_$userId\_$deviceId';

    // Marcar como calibrado
    await prefs.setBool(calibrationKey, true);

    // Guardar fecha de calibración
    final now = DateTime.now().toIso8601String();
    await prefs.setString('$calibrationKey\_date', now);

    debugPrint('✅ Calibración marcada como completada para usuario $userId y dispositivo $deviceId');
    debugPrint('📅 Fecha de calibración: $now');
  } catch (e) {
    debugPrint('❌ Error al marcar calibración como completada: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
