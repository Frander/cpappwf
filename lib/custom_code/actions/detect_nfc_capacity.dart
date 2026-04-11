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

import 'dart:async';
import 'dart:io' show Platform;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart'
    show IsoDepAndroid, NfcAAndroid, MifareClassicAndroid, NfcTagAndroid;

/// Detecta la capacidad del TAG NFC y retorna el tamaño en bytes
/// Retorna 0 si no se pudo detectar o si hay un error
Future<int> detectNfcCapacity(BuildContext context) async {
  if (Platform.isWindows) return 0; // NFC no disponible en Windows
  // Verificar si NFC está disponible
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    return 0;
  }

  Completer<int> completer = Completer<int>();

  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
      NfcPollingOption.iso18092,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        int capacity = 0;

        // Detectar tipo de TAG y su capacidad
        final isoDep = IsoDepAndroid.from(tag);
        final mifareClassic = MifareClassicAndroid.from(tag);
        final ndef = Ndef.from(tag);

        if (isoDep != null) {
          // DESFire EV3 8K
          capacity = 8192;
          debugPrint('🏷️ TAG detectado: Mifare DESFire EV3 8K - Capacidad: $capacity bytes');
        } else if (mifareClassic != null) {
          // Mifare Classic - usar el tamaño reportado
          capacity = mifareClassic.size;
          debugPrint('🏷️ TAG detectado: Mifare Classic - Capacidad: $capacity bytes');
        } else if (ndef != null) {
          // NDEF - usar maxSize
          capacity = ndef.maxSize;
          debugPrint('🏷️ TAG detectado: NDEF - Capacidad: $capacity bytes');
        } else {
          debugPrint('⚠️ No se pudo determinar el tipo de TAG');
          capacity = 504; // Default a NTAG215
        }

        completer.complete(capacity);
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('❌ Error detectando capacidad del TAG: $e');
        completer.complete(0);
        await NfcManager.instance.stopSession();
      }
    },
  );

  return completer.future;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
