// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:geolocator/geolocator.dart';
import '/custom_code/platform_utils.dart';

Future<String> getLocation() async {
  if (!Platforms.isMobile) return 'LAT:0.0;LON:0.0;ALT:0.0'; // GPS no disponible en desktop
  try {
    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return "ERROR: Location permission denied";
      }
    }

    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Intenta obtener la última ubicación conocida si los servicios no están habilitados
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return "LAT:${lastKnownPosition.latitude};LON:${lastKnownPosition.longitude};ALT:${lastKnownPosition.altitude}";
      } else {
        return "ERROR: Location services disabled, and no last known location available";
      }
    }

    // Obtener la ubicación en tiempo real
    Position currentPosition = await Geolocator.getCurrentPosition();
    return "LAT:${currentPosition.latitude};LON:${currentPosition.longitude};ALT:${currentPosition.altitude}";
  } catch (e) {
    return "ERROR: $e";
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
