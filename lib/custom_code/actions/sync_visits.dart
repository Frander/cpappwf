import 'package:flutter/foundation.dart';
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/global_db_singleton.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!


import 'dart:convert';
import 'package:http/http.dart' as http;

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
    debugPrint('Request body: $jsonBody'); // Para depuración

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
      final List<Map<String, dynamic>> geoRecords =
          await globalDb.executeOperation(
        (db) => db.query('Location_tracking', orderBy: 'CreatedAt ASC'),
      );

      // Verificar si hay registros para procesar
      if (geoRecords.isEmpty) {
        debugPrint('No hay registros de geolocalización para sincronizar');
      } else {
        debugPrint('Procesando ${geoRecords.length} registros de geolocalización');

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
        debugPrint('CSV generado con ${geoRecords.length} registros');

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
          debugPrint('Archivo subido exitosamente');
          debugPrint('Respuesta del servidor: $responseData');

          // 5. BORRAR REGISTROS DE LA TABLA SOLO SI SE SUBIÓ EXITOSAMENTE
          int deletedCount = await globalDb.executeOperation(
              (db) => db.delete('Location_tracking'));
          debugPrint('Eliminados $deletedCount registros de la tabla local');

          debugPrint('Archivo temporal eliminado');
        } else {
          debugPrint('Error al subir archivo. Código: ${response.statusCode}');
          debugPrint('Respuesta: $responseData');

          // Opcional: Lanzar error para manejarlo en el Action Flow
          throw Exception(
              'Error al sincronizar geolocalizaciones: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error en sincronización de Location_tracking: $e');
      // Opcional: propagar el error para manejarlo en FlutterFlow
      // throw e;
    }

// ========== FIN SECCIÓN SYNC LOCATION_TRACKING ==========

    if (response.statusCode == 200 || response.statusCode == 202) {
      debugPrint(
          '✅ Sincronización enviada; el servidor la procesará en segundo plano.');
      return true;
    } else {
      debugPrint(
          '❌ Failed to sync visits. Status: ${response.statusCode}. Response: ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('⚠️ Error syncing visits: $e');
    return false;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
