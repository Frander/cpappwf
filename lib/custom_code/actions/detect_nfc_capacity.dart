// Automatic FlutterFlow imports
import 'index.dart'; // Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import '/custom_code/platform_utils.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart'
    show IsoDepAndroid, NfcAAndroid, MifareClassicAndroid, NfcTagAndroid;

/// Consulta la memoria libre de un tag DeSFire mediante APDU GET_FREE_MEMORY.
/// Retorna null si el comando falla (requiere auth o tag no lo soporta).
Future<int?> _getDeSFireFreeMemory(IsoDepAndroid isoDep) async {
  try {
    // Comando nativo DeSFire: CLA=0x90, INS=0x6E (GET_FREE_MEMORY), P1/P2=0x00, Le=0x00
    final response = await isoDep.transceive(
      Uint8List.fromList([0x90, 0x6E, 0x00, 0x00, 0x00]),
    );
    // Respuesta exitosa: 3 bytes (little-endian free memory) + 0x91 0x00 = 5 bytes
    if (response.length >= 5 && response[3] == 0x91 && response[4] == 0x00) {
      final freeBytes = response[0] | (response[1] << 8) | (response[2] << 16);
      debugPrint('DeSFire GET_FREE_MEMORY: $freeBytes bytes libres');
      return freeBytes;
    }
  } catch (e) {
    debugPrint('DeSFire GET_FREE_MEMORY falló (requiere auth o no soportado): $e');
  }
  return null;
}

/// Detecta la capacidad del TAG NFC y retorna el tamaño en bytes
/// Retorna 0 si no se pudo detectar o si hay un error
Future<int> detectNfcCapacity(BuildContext context) async {
  if (!Platforms.isMobile) return 0; // NFC no disponible en desktop
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

        // Detectar tipo de TAG y su capacidad.
        // ORDEN CRÍTICO: NDEF primero (un DeSFire ya-formateado es tanto IsoDep como NDEF;
        // si verificamos IsoDep antes que NDEF, retornamos capacidad estimada en lugar de la real).
        final ndef = Ndef.from(tag);
        final mifareClassic = MifareClassicAndroid.from(tag);
        final isoDep = IsoDepAndroid.from(tag);

        if (ndef != null) {
          // Tags NDEF (NTAG2xx, DeSFire ya-formateado, cualquier tag con aplicación NDEF):
          // ndef.maxSize es el espacio real reportado por el stack NFC para el mensaje NDEF.
          capacity = ndef.maxSize;
          debugPrint('🏷️ TAG detectado: NDEF - Capacidad: $capacity bytes');
        } else if (mifareClassic != null) {
          // Mifare Classic: calcular bytes de datos usables reales.
          // Sector 0: 2 bloques de datos (bloque 0 = fabricante, bloque 3 = auth trailer)
          // Sectores 1..N-1: 3 bloques de datos cada uno (bloque 3 = auth trailer)
          final sc = mifareClassic.sectorCount; // 16 para 1K, 32 para 2K, 40 para 4K
          capacity = 32 + (sc - 1) * 48; // 752 bytes para 1K, 1520 para 2K
          debugPrint('🏷️ TAG detectado: Mifare Classic ($sc sectores) - Capacidad usable: $capacity bytes');
        } else if (isoDep != null) {
          // DeSFire no-NDEF: intentar consulta real vía APDU GET_FREE_MEMORY.
          // Si falla (requiere auth o no soportado), usar 8192 como estimación.
          capacity = await _getDeSFireFreeMemory(isoDep) ?? 8192;
          debugPrint('🏷️ TAG detectado: DeSFire (no-NDEF) - Capacidad: $capacity bytes');
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
