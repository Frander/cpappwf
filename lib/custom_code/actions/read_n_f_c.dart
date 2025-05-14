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

import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';

Future<String> readNFC(BuildContext context) async {
  // Verificar si NFC está disponible en el dispositivo
  bool nfcAvailable = await NfcManager.instance.isAvailable();
  if (!nfcAvailable) {
    FFAppState().update(() {
      FFAppState().nfcRead = ''; // Actualizar AppState pero no cerrar popup
    });
    return '';
  }

  // Se utiliza un Completer para esperar la lectura del tag
  Completer<String> completer = Completer<String>();

  // Inicia la sesión NFC con un callback onDiscovered para cuando se detecte un tag
  NfcManager.instance.startSession(
    onDiscovered: (NfcTag tag) async {
      try {
        // Procesar los datos del tag
        final String tagData = tag.data.toString();

        // Actualizar el AppState con los datos leídos
        FFAppState().update(() {
          FFAppState().nfcRead = tagData;
        });

        // Cerrar el popup solo cuando se lee exitosamente un tag
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        completer.complete(tagData);

        // Detener la sesión NFC al haber leído el tag
        await NfcManager.instance.stopSession();
      } catch (e) {
        // En caso de error, actualizar AppState pero no cerrar popup
        FFAppState().update(() {
          FFAppState().nfcRead = '';
        });
        completer.complete('');
        await NfcManager.instance.stopSession(errorMessage: e.toString());
      }
    },
  );

  // Esperar a que se complete la lectura del tag o se produzca un error
  return completer.future;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
