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

import 'package:string_similarity/string_similarity.dart';

/// **Mejora la comparación de frases utilizando la calibración previa**
/// - Compara `recognizedText` con `validPhrases` (frases predefinidas)
/// - También compara con `capturedPhrases` (frases calibradas por el usuario)
/// - Usa la similitud de texto para encontrar la mejor coincidencia
String getBestMatch(String recognizedText, List<String> validPhrases,
    List<String> capturedPhrases) {
  String bestMatch = "Opción no reconocida";
  double highestSimilarity = 0.7; // Umbral mínimo de coincidencia

  // Combinar ambas listas para mejorar la detección
  List<String> allPhrases = [...validPhrases, ...capturedPhrases];

  for (String phrase in allPhrases) {
    double similarity = recognizedText.similarityTo(phrase);
    if (similarity > highestSimilarity) {
      highestSimilarity = similarity;
      bestMatch = phrase;
    }
  }

  return bestMatch;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
