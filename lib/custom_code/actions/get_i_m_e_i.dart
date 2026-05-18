// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:device_info_plus/device_info_plus.dart';

Future<String> getIMEI() async {
  try {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    // IMEI no está disponible directamente en Android 10+ por restricciones de seguridad
    // Usaremos el identificador único de hardware del dispositivo
    String imei = androidInfo.id ?? "Unavailable";

    return imei;
  } catch (e) {
    return "Error: ${e.toString()}";
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
