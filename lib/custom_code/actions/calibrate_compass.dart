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

import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:io' show Platform;

Future<bool> calibrateCompass() async {
  if (Platform.isWindows) return false; // Sensores no disponibles en Windows
  try {
    final completer = Completer<bool>();
    StreamSubscription<MagnetometerEvent>? subscription;
    bool calibrationComplete = false;
    int dataCount = 0;

    // 30-second timeout
    final timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(false);
      }
    });

    subscription = magnetometerEvents.listen((MagnetometerEvent event) {
      dataCount++;
      // Consider calibrated after receiving 50 data points (adjust as needed)
      if (!calibrationComplete && dataCount >= 30) {
        calibrationComplete = true;
        subscription?.cancel();
        timeoutTimer.cancel();
        completer.complete(true);
      }
    });

    return await completer.future;
  } catch (e) {
    debugPrint('Compass calibration error: $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
