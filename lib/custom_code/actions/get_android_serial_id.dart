// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getAndroidSerialId() async {
  try {
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      // Try to get the Android ID (unique identifier)
      // Note: androidId is available on all Android devices
      String serialId = androidInfo.id ?? '';

      if (serialId.isEmpty) {
        // Fallback to fingerprint if androidId is not available
        serialId = androidInfo.fingerprint ?? 'UNKNOWN_SERIAL';
      }

      return serialId;
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo =
          await DeviceInfoPlugin().windowsInfo;
      return windowsInfo.computerName.isNotEmpty
          ? windowsInfo.computerName
          : 'WINDOWS_DESKTOP';
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await DeviceInfoPlugin().linuxInfo;
      return linuxInfo.machineId ?? 'LINUX_DESKTOP';
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macInfo = await DeviceInfoPlugin().macOsInfo;
      return macInfo.systemGUID ?? 'MACOS_DESKTOP';
    } else {
      return 'DESKTOP_DEVICE';
    }
  } catch (e) {
    print('Error getting Android serial ID: $e');
    return 'ERROR_SERIAL';
  }
}
