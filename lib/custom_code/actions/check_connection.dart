// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';

Future<bool> checkConnection() async {
  // Usar InternetConnectionChecker para verificar conexión
  bool isConnected = await InternetConnectionChecker().hasConnection;
  return isConnected;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
