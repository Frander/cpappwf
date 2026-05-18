// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Instancia singleton para evitar crear nuevas instancias en cada llamada
final InternetConnection _internetChecker = InternetConnection();

/// Verifica si hay conexión a internet con timeout para evitar bloqueos
Future<bool> checkConnection() async {
  try {
    // Timeout de 5 segundos para evitar bloquear la UI
    final result = await _internetChecker.hasInternetAccess
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    return result;
  } catch (e) {
    // En caso de error, asumir sin conexión
    return false;
  }
}
