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

import 'dart:io';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

Future<bool> syncVisits(
  List<VisitsStruct> visitsAdd,
  List<VisitsNewsStruct> newsAdd,
  int idCompany,
  String idsHeadquarters,
  String imei,
) async {
  const String url = 'https://api.clickpalm.com/Sync_times/SyncVisitsAdd';

  try {
    //OBTENER LAS VISITAS DESDE SQLITE
    //CREAR UN JSON CON LAS VISITAS USANDO UNA CONSULTA EN SQLITE
    //EL JSON GENERADO GUARDARLO EN UNA CARPETA DEL DISPOSITIVO
    //COMPRIMIR EL JSON
    //
    //OBTENER LAS GEOLOCALIZACIONES DESDE SQLITE
    //CREAR UN ARCHIVO CSV
    //CORTAR TODAS LAS GEOLOCALIZACIONES DE SQLITE AL CSV
    //EL CSV GENERADO GUARDARLO EN UNA CARPETA DEL DISPOSITIVO
    //COMPRIMIR EL CSV
    //
    //ENVIAR AL API
    //
    //VALIDACIONES: CADA VEZ QUE SE CREA UN ARCHIVO EN UNA CARPETA DEL DISPOSITIVO
    //SE DEBE COMPROBAR SI HAY ARCHIVOS DE MÁS DE 1 SEMANA Y SE DEBEN ELIMINAR

    // Preparar lista de VisitsAdd
    final List<Map<String, dynamic>> visitsAddJson = visitsAdd.map((visit) {
      final map = visit.toMap();
      map['id_company'] = idCompany;
      map['created_at'] =
          (visit.createdAt != null) ? visit.createdAt!.toIso8601String() : null;
      return map;
    }).toList();

    // Preparar lista de NewsAdd
    final List<Map<String, dynamic>> newsAddJson = newsAdd.map((visitNews) {
      final map = visitNews.toMap();
      map['created_at'] = (visitNews.createdAt != null)
          ? visitNews.createdAt!.toIso8601String()
          : null;
      return map;
    }).toList();

    // Crear el objeto de sincronización
    final syncData = {
      'CreatedAt': DateTime.now().toIso8601String(),
      'Ids_headquarters': idsHeadquarters,
      'NewsAdd': newsAddJson,
      'VisitsAdd': visitsAddJson,
      'Imei': imei,
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

    // ========== INICIO SECCIÓN PARA SYNC LOCATION_TRACKING ==========

    try {
      // 1. CONSULTAR TODOS LOS REGISTROS DE LA TABLA LOCATION_TRACKING
      final db = SQLiteManager.instance.database;

      // Obtener todos los registros
      final List<Map<String, dynamic>> geoRecords = await db.query(
        'Location_tracking',
        orderBy: 'CreatedAt ASC',
      );

      // Verificar si hay registros para procesar
      if (geoRecords.isEmpty) {
        print('No hay registros de geolocalización para sincronizar');
      } else {
        print('Procesando ${geoRecords.length} registros de geolocalización');

        // 2. CREAR CONTENIDO DEL ARCHIVO TXT (FORMATO CSV)
        StringBuffer csvContent = StringBuffer();

        // Agregar encabezado (actualizando nombres de campos)
        csvContent.writeln(
            'Id_company,Imei,Latitude,Longitude,Altitude,HorizontalError,CreatedAt,SyncedAt,batch_id');

        // Agregar cada registro
        for (var record in geoRecords) {
          String line =
              '${record['Id_company']},${record['Imei']},${record['Latitude']},${record['Longitude']},${record['Altitude']},${record['HorizontalError']},${record['CreatedAt']},${record['SyncedAt']},${record['batch_id'] ?? ''}';
          csvContent.writeln(line);
        }

        // Convertir a bytes
        List<int> csvBytes = utf8.encode(csvContent.toString());
        print('CSV generado con ${geoRecords.length} registros');

        // 4. SUBIR ARCHIVO AL ENDPOINT
        const String endpointUrl =
            'https://tu-api.com/upload-geolocations'; // CAMBIAR POR TU URL

        // Crear request multipart para subir archivo
        var request = http.MultipartRequest('POST', Uri.parse(endpointUrl));

        // Agregar el CSV como si fuera un archivo
        final fileName =
            'geolocations_${DateTime.now().millisecondsSinceEpoch}.csv';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', // nombre del campo que espera el servidor
            csvBytes,
            filename: fileName,
          ),
        );

        // Agregar headers si necesitas autenticación
        // request.headers['Authorization'] = 'Bearer $token';

        // Agregar campos adicionales si los necesitas
        // request.fields['userId'] = FFAppState().userId;
        // request.fields['deviceId'] = FFAppState().deviceId;
        request.fields['recordCount'] = geoRecords.length.toString();
        request.fields['syncDate'] = DateTime.now().toIso8601String();

        // Enviar request
        var response = await request.send();
        var responseData = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          print('Archivo subido exitosamente');
          print('Respuesta del servidor: $responseData');

          // 5. BORRAR REGISTROS DE LA TABLA SOLO SI SE SUBIÓ EXITOSAMENTE
          int deletedCount = await db.delete('Location_tracking');
          print('Eliminados $deletedCount registros de la tabla local');

          print('Archivo temporal eliminado');
        } else {
          print('Error al subir archivo. Código: ${response.statusCode}');
          print('Respuesta: $responseData');

          // Opcional: Lanzar error para manejarlo en el Action Flow
          throw Exception(
              'Error al sincronizar geolocalizaciones: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error en sincronización de Location_tracking: $e');
      // Opcional: propagar el error para manejarlo en FlutterFlow
      // throw e;
    }

// ========== FIN SECCIÓN SYNC LOCATION_TRACKING ==========

    if (response.statusCode == 200 || response.statusCode == 202) {
      print(
          '✅ Sincronización enviada; el servidor la procesará en segundo plano.');
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
