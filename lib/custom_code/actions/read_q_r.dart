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

import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> readQR(BuildContext context) async {
  try {
    final qrValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Escanear QR'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  // Primero actualizamos el AppState
                  FFAppState().update(() {
                    FFAppState().qrRead = barcode.rawValue!;
                  });

                  // Luego cerramos el scanner y devolvemos el valor
                  Navigator.of(context).pop(barcode.rawValue!);
                  break; // Salimos después del primer QR válido
                }
              }
            },
          ),
        ),
      ),
    );

    // Solo cerramos el popup actual si obtuvimos un valor válido
    if (qrValue != null && qrValue.isNotEmpty) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return qrValue;
    }

    return null;
  } catch (e) {
    debugPrint('Error al escanear QR: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al escanear QR: ${e.toString()}')),
    );
    return null;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
