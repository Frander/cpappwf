import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
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
      debugPrint("Base de datos creada en $path");
    },
  );

  // Retornar la ruta de la base de datos
  return path;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
