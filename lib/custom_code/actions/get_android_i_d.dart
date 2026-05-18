// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:device_info_plus/device_info_plus.dart';

Future<String> getAndroidID() async {
  try {
    // Create an instance of the plugin
    final deviceInfo = DeviceInfoPlugin();

    // Get information specific to Android devices
    final androidInfo = await deviceInfo.androidInfo;

    // Retrieve the unique Android identifier
    // This may be substituted with the `id` field depending on the latest changes in the package
    final uniqueId = androidInfo.id ?? 'Unknown Android ID';

    return uniqueId;
  } catch (e) {
    // Handle errors gracefully
    return 'Error retrieving Android ID: $e';
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
