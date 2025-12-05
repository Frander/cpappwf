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
    } else {
      return 'NOT_ANDROID';
    }
  } catch (e) {
    print('Error getting Android serial ID: $e');
    return 'ERROR_SERIAL';
  }
}
