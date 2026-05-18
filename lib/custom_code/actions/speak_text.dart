// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports other custom actions
// Imports custom functions

import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '/custom_code/platform_utils.dart';

Future<void> speakText(String text) async {
  if (!Platforms.isMobile) return; // TTS no disponible en desktop
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
