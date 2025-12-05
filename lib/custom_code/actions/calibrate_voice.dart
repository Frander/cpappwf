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

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

Future<List<String>> calibrateVoice(List<String> phrases) async {
  stt.SpeechToText speech = stt.SpeechToText();
  List<String> capturedPhrases = [];

  for (String phrase in phrases) {
    print("Di la frase: '$phrase' para calibrar.");

    Completer<String> completer = Completer<String>();

    await speech.initialize();
    await speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          capturedPhrases.add(result.recognizedWords.trim());
          completer.complete(result.recognizedWords.trim());
        }
      },
      listenFor: Duration(seconds: 5),
      pauseFor: Duration(seconds: 2),
      localeId: "es_CO",
    );

    await completer.future; // Espera que el usuario hable
    await Future.delayed(Duration(seconds: 1)); // Pequeña pausa entre frases
  }

  return capturedPhrases;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
