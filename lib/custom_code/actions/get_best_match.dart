// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
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
