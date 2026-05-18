import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getDeviceModel() async {
  try {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // Return manufacturer + model for better identification
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.model ?? 'Unknown iOS Device';
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.productName;
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
      return 'Linux ${linuxInfo.prettyName}';
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
      return 'macOS ${macInfo.model}';
    } else {
      return 'Unknown Device';
    }
  } catch (e) {
    debugPrint('Error getting device model: $e');
    return 'Unknown Device';
  }
}
