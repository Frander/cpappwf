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

import '/custom_code/actions/index.dart'
    as actions; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'
    as functions; // Imports custom functions

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';

Future<void> speakText(String text) async {
  if (Platform.isWindows) return; // TTS no disponible en Windows
  FlutterTts flutterTts = FlutterTts();

  await flutterTts
      .setLanguage("es-CO"); // Configura el idioma a español de Colombia
  await flutterTts.setPitch(1); // Opcional: tono de la voz (1.0 es normal)
  await flutterTts
      .setSpeechRate(0.5); // Opcional: velocidad de la voz (1.0 es normal)

  await flutterTts.speak(text);
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
