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

import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// 📌 Función para guardar la lista de VisitsStruct como un archivo JSON en Descargas
Future<void> saveVisitsToDownloads(List<VisitsStruct> visits) async {
  try {
    // 🔹 Solicitar permisos de almacenamiento (y de manejo, si es necesario) en Android
    if (Platform.isAndroid) {
      // Solicitar permiso básico de almacenamiento
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        print("🚫 Permiso de almacenamiento denegado.");
        return;
      }

      // En Android 11+ puede requerirse el permiso de manejo de almacenamiento
      var manageStatus = await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) {
        print("🚫 Permiso de manejo de almacenamiento denegado.");
        return;
      }
    }

    // 🔹 Convertir la lista a JSON
    String jsonContent = jsonEncode(
      visits.map((v) => v.toSerializableMap()).toList(),
    );

    // 🔹 Obtener la ruta de la carpeta de Descargas
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      // Ruta común en Android para la carpeta Descargas
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        // Si no existe, se utiliza la carpeta de almacenamiento externo
        downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir == null) {
          print(
              "🚫 No se pudo obtener el directorio de almacenamiento externo.");
          return;
        }
      }
    } else {
      // En otras plataformas (por ejemplo, iOS) se puede usar el directorio de documentos
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    // 🔹 Definir el nombre y la ruta del archivo
    String fileName = 'visits_${DateTime.now().millisecondsSinceEpoch}.json';
    String filePath = '${downloadsDir.path}/$fileName';

    // 🔹 Guardar el archivo
    File file = File(filePath);
    await file.writeAsString(jsonContent);
    print("✅ Archivo guardado en: $filePath");
  } catch (e) {
    print("❌ Error al guardar el archivo: $e");
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
