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

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<String> getDatabase() async {
  final databasePath =
      await getDatabasesPath(); // Directorio base de la base de datos
  final path = join(databasePath,
      'ClickPalmBD.db'); // Ruta completa del archivo de la base de datos

  // Abrir o crear la base de datos
  await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      print("Base de datos creada en $path");
    },
  );

  // Retornar la ruta de la base de datos
  return path;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
