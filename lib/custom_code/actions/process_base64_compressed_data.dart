// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:archive/archive.dart'; // Para manejar gzip

Future<dynamic> processBase64CompressedData(String base64String) async {
  try {
    // Decodificar Base64
    final compressedBytes = base64Decode(base64String);

    // Descomprimir los bytes usando GZipDecoder
    final decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);

    // Convertir los bytes descomprimidos a un string JSON
    final jsonString = utf8.decode(decompressedBytes);

    // Convertir el string JSON a un objeto Dart (JSON deserializado)
    final jsonData = json.decode(jsonString);

    // Retornar el JSON deserializado
    return jsonData;
  } catch (e) {
    // Manejo de errores
    throw Exception('Error al procesar los datos: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
