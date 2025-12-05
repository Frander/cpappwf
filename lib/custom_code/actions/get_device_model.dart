// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
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
    } else {
      return 'Unknown Device';
    }
  } catch (e) {
    print('Error getting device model: $e');
    return 'Unknown Device';
  }
}
