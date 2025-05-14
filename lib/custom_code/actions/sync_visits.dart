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

Future<bool> syncVisits(
  List<VisitsStruct> visitsAdd,
  List<VisitsNewsStruct> newsAdd,
  int idCompany,
  String idsHeadquarters, // Nuevo parámetro: cadena de IDs concatenados
) async {
  const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

  try {
    // Preparar lista de VisitsAdd
    final List<Map<String, dynamic>> visitsAddJson = visitsAdd.map((visit) {
      final map = visit.toMap();
      map['id_company'] = idCompany;
      map['created_at'] = (visit.createdAt != null)
          ? visit.createdAt!.toUtc().toIso8601String()
          : null;
      return map;
    }).toList();

    // Preparar lista de NewsAdd
    final List<Map<String, dynamic>> newsAddJson = newsAdd.map((visitNews) {
      final map = visitNews.toMap();
      map['created_at'] = (visitNews.createdAt != null)
          ? visitNews.createdAt!.toUtc().toIso8601String()
          : null;
      return map;
    }).toList();

    // Crear el objeto de sincronización con el nuevo campo Ids_headquarters
    final syncData = {
      'CreatedAt': DateTime.now().toUtc().toIso8601String(),
      'VisitsAdd': visitsAddJson,
      'NewsAdd': newsAddJson,
      'Ids_headquarters': idsHeadquarters, // Nuevo campo agregado
    };

    // Convertir a JSON
    final jsonBody = jsonEncode(syncData);
    print('Request body: $jsonBody'); // Para depuración

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonBody,
    );

    if (response.statusCode == 200) {
      print('✅ Sync successful. Response: ${response.body}');
      return true;
    } else {
      print(
          '❌ Failed to sync visits. Status: ${response.statusCode}. Response: ${response.body}');
      return false;
    }
  } catch (e) {
    print('⚠️ Error syncing visits: $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
