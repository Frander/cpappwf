// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:mobile_scanner/mobile_scanner.dart';
import '/custom_code/platform_utils.dart';

Future<String?> readQR(BuildContext context) async {
  if (!Platforms.isMobile) return null; // Escáner QR no disponible en desktop
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
      if (!context.mounted) return qrValue;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return qrValue;
    }

    return null;
  } catch (e) {
    debugPrint('Error al escanear QR: $e');
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al escanear QR: ${e.toString()}')),
    );
    return null;
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
