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

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> syncVisits(List<VisitsStruct> visits, int idCompany) async {
  const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

  try {
    final List<Map<String, dynamic>> visitsJson = visits.map((visit) {
      final map = visit.toMap();

      // ✅ Sobrescribimos el idCompany en cada visita con el valor del parámetro de entrada
      map['id_company'] = idCompany;

      // ✅ Convertimos created_at a un formato ISO 8601 compatible con .NET
      map['created_at'] = (visit.createdAt != null)
          ? visit.createdAt!.toUtc().toIso8601String()
          : null;

      return map;
    }).toList();

    // 🔹 Imprimir el cuerpo JSON antes de enviarlo
    String jsonBody = jsonEncode(visitsJson);
    print('🔹 JSON Enviado al API:\n$jsonBody');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonBody, // 🔹 Usamos la variable jsonBody aquí
    );

    if (response.statusCode == 200) {
      print('✅ Sync successful: ${response.body}');
      return true;
    } else {
      print(
          '❌ Failed to sync visits. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('⚠️ Error syncing visits: $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
