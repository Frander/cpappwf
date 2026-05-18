// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<void> multipleBackNavigation(BuildContext context, int backCount) async {
  try {
    // Validar que backCount sea mayor a 0
    if (backCount <= 0) {
      throw Exception('El parámetro backCount debe ser mayor a 0');
    }

    // Realizar las navegaciones hacia atrás
    for (int i = 0; i < backCount; i++) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        // Si ya no hay páginas para hacer back, salir del bucle
        debugPrint('No hay más páginas en la pila de navegación.');
        break;
      }
    }
  } catch (e) {
    // Manejo de errores
    throw Exception(
        'Error al intentar realizar múltiples navegaciones hacia atrás: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
