// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';

Future<List<ProductsStruct>> productsSelect(
  String databasePath,
  String typeSearch,
  String textSearch1,
  String textSearch2,
  List<String> searchParams, // Se asegura que sea siempre una lista de strings
) async {
  // Usa el singleton global en lugar de abrir conexión aislada
  return await globalDb.executeOperation((db) async {
    // Construir la consulta SQL basada en typeSearch
    String? whereClause;
    List<dynamic>? whereArgs;

    if (typeSearch == "COORDENADAS") {
      if (searchParams.isNotEmpty) {
        // Generar placeholders para cada coordenada en la lista
        final placeholders =
            List.generate(searchParams.length, (_) => '?').join(", ");
        whereClause = "location_raw IN ($placeholders)";
        whereArgs = searchParams;
      } else {
        // Si searchParams está vacío, usa textSearch1 como valor único
        whereClause = "location_raw = ?";
        whereArgs = [textSearch1];
      }
    } else if (typeSearch == "ID HEADQUARTER") {
      whereClause = "id_headquarter = ?";
      whereArgs = [textSearch1];
    } else if (typeSearch == "OTHER_TYPE") {
      // Ejemplo para otro caso utilizando textSearch2
      whereClause = "some_column = ?";
      whereArgs = [textSearch2];
    }

    // Ejecutar la consulta SELECT
    final List<Map<String, dynamic>> queryResult = await db.query(
      'Products', // Tabla fija
      where: whereClause,
      whereArgs: whereArgs,
    );

    // Mapear los resultados a una lista de ProductsStruct
    final List<ProductsStruct> productsList =
        queryResult.map((map) => ProductsStruct.fromMap(map)).toList();

    return productsList;
  });
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
