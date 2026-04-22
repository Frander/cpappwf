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

import 'dart:io'; // ✅ Importación para manejar archivos y directorios
import 'dart:async';
import 'package:dio/dio.dart'; // ✅ Importación para descargar archivos
import 'package:path_provider/path_provider.dart'; // ✅ Importación para manejar almacenamiento
import 'package:intl/intl.dart'; // ✅ Importación para formatear fechas
import 'package:archive/archive.dart'; // Para descomprimir archivos gzip

// -------------------------------------------------------------------
// Función que descarga el archivo GNSS y devuelve la ruta del archivo ya descomprimido
// -------------------------------------------------------------------
Future<String> downloadGNSSData() async {
  try {
    DateTime now = DateTime.now().toUtc(); // Usar UTC para consistencia
    int year = now.year;
    int doy = int.parse(DateFormat("D").format(now));

    String fileName;
    String url;
    bool fileFound = false;
    Dio dio = Dio();

    // Intentar hasta 15 días anteriores si el archivo no se encuentra
    for (int i = 0; i < 15; i++) {
      fileName =
          "brdc${(doy - i).toString().padLeft(3, '0')}0.${year % 100}n.gz";
      url =
          "https://cddis.nasa.gov/archive/gnss/data/daily/$year/${(doy - i).toString().padLeft(3, '0')}/$fileName";

      try {
        // Verificar si el archivo existe antes de descargar
        final response = await dio.head(url);
        if (response.statusCode != 200) {
          print("Archivo no encontrado: $url");
          continue;
        }

        Directory dir = await getApplicationDocumentsDirectory();
        String filePath = "${dir.path}/$fileName";

        // Descargar usando GET para manejar la respuesta
        final downloadResponse = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        if (downloadResponse.statusCode == 200) {
          await File(filePath).writeAsBytes(downloadResponse.data);
          print("Datos GNSS descargados en: $filePath");
          fileFound = true;
          return await decompressGNSSFile(filePath);
        }
      } catch (e) {
        print("Intento fallido con DOY ${doy - i}: $e");
      }
    }

    if (!fileFound) {
      throw Exception(
          "No se encontró un archivo válido en los últimos 15 días");
    }
    return "";
  } catch (e) {
    print("Error crítico al descargar datos GNSS: $e");
    return "";
  }
}

// -------------------------------------------------------------------
// Función que descomprime un archivo .gz y devuelve la ruta del archivo descomprimido
// -------------------------------------------------------------------
Future<String> decompressGNSSFile(String gzFilePath) async {
  try {
    File gzFile = File(gzFilePath);
    if (!await gzFile.exists()) {
      return "ERROR: Archivo gz no encontrado en $gzFilePath";
    }
    // Leer los bytes del archivo comprimido
    List<int> bytes = await gzFile.readAsBytes();

    // Verificar la firma GZip (0x1f y 0x8b)
    if (bytes.length < 2 || bytes[0] != 0x1F || bytes[1] != 0x8B) {
      print(
          "El archivo descargado no tiene firma GZip válida: ${bytes.take(10).toList()}");
      return "ERROR: Archivo no válido, no tiene firma GZip";
    }

    // Descomprimir usando GZipDecoder del paquete archive
    List<int> decompressedBytes = GZipDecoder().decodeBytes(bytes);
    // Definir la ruta del archivo descomprimido (quitamos la extensión .gz)
    String decompressedPath = gzFilePath.replaceAll(".gz", "");
    File decompressedFile = File(decompressedPath);
    await decompressedFile.writeAsBytes(decompressedBytes);
    print("Archivo GNSS descomprimido en: $decompressedPath");
    return decompressedPath;
  } catch (e) {
    print("Error al descomprimir archivo GNSS: $e");
    return "";
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
