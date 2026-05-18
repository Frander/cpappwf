// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import '/custom_code/platform_utils.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';
import 'dart:typed_data';

/// Limpia completamente un TAG NFC escribiendo ceros en todos los sectores
Future<bool> clearNFCTag(BuildContext context) async {
  if (!Platforms.isMobile) return false; // NFC no disponible en desktop
  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    debugPrint('❌ NFC no está disponible o está desactivado');
    return false;
  }

  Completer<bool> completer = Completer<bool>();

  // Iniciar sesión NFC
  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        debugPrint('🏷️ TAG detectado, iniciando limpieza...');

        // 1. Intentar limpiar como NDEF (si ya está formateado)
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          if (ndef.isWritable) {
            try {
              debugPrint('🔄 TAG NDEF detectado, escribiendo contenido mínimo...');
              // Escribir un mensaje NDEF con contenido mínimo "0"
              // (Android no permite mensajes completamente vacíos)
              final minimalMessage = _createMinimalNdefMessage();
              await ndef.write(message: minimalMessage);

              // Detener sesión
              await NfcManager.instance.stopSession();

              debugPrint('✅ TAG limpiado exitosamente (contenido: "0")');
              completer.complete(true);
              return;
            } catch (e) {
              debugPrint('⚠️ No se pudo limpiar como NDEF: $e');
            }
          } else {
            debugPrint('⚠️ TAG NDEF detectado pero es de solo lectura');
            await NfcManager.instance.stopSession();
            completer.complete(false);
            return;
          }
        }

        // 2. Detectar si es IsoDep (Mifare DESFire, etc.) antes de NdefFormatable
        // Para evitar que NdefFormatable intente formatear un DESFire y falle
        final isoDep = IsoDepAndroid.from(tag);
        if (isoDep != null && ndef == null) {
          debugPrint('🔍 TAG IsoDep (DESFire) detectado sin NDEF');

          // Verificar si también es NdefFormatable
          final ndefFormatableCheck = NdefFormatableAndroid.from(tag);
          if (ndefFormatableCheck != null) {
            // Es IsoDep + NdefFormatable (DESFire sin aplicación NDEF)
            try {
              debugPrint('🔄 Intentando formatear DESFire con aplicación NDEF...');
              final minimalMessage = _createMinimalNdefMessage();
              await ndefFormatableCheck.format(minimalMessage);

              await NfcManager.instance.stopSession();
              debugPrint('✅ TAG DESFire formateado exitosamente (contenido: "0")');
              completer.complete(true);
              return;
            } catch (e) {
              debugPrint('⚠️ Error al formatear DESFire: $e');
              debugPrint('   Este TAG puede requerir formateo con app externa (NXP TagWriter)');
              await NfcManager.instance.stopSession();
              completer.complete(false);
              return;
            }
          }

          // IsoDep sin NDEF y sin NdefFormatable - no soportado
          debugPrint('⚠️ TAG IsoDep no soporta NDEF estándar');
          debugPrint('   Intente formatear el TAG como NDEF con NXP TagWriter primero');
          await NfcManager.instance.stopSession();
          completer.complete(false);
          return;
        }

        // 3. Si no es NDEF ni IsoDep, intentar formatear como NDEF (para tags vírgenes/raw)
        final ndefFormatable = NdefFormatableAndroid.from(tag);
        if (ndefFormatable != null) {
          try {
            debugPrint(
                '🔄 Intentando formatear y limpiar TAG (NdefFormatableAndroid)...');
            // Escribir un mensaje NDEF con contenido mínimo "0"
            final minimalMessage = _createMinimalNdefMessage();
            await ndefFormatable.format(minimalMessage);

            // Detener sesión
            await NfcManager.instance.stopSession();

            debugPrint(
                '✅ TAG formateado y limpiado exitosamente (contenido: "0")');
            completer.complete(true);
            return;
          } catch (e) {
            debugPrint('⚠️ Error al formatear TAG: $e');
          }
        }

        // NOTA: El path MifareClassic raw fue eliminado intencionalmente.
        // Escribir ceros en bloques raw destruye el TLV header de NDEF (sector 1, bloque 4),
        // dejando el tag irrecuperable: Ndef.from() y NdefFormatable.from() retornan null
        // en accesos posteriores. El único camino seguro es NDEF o NdefFormatable.
        debugPrint('❌ No se pudo limpiar el TAG: el tipo de TAG no tiene soporte NDEF accesible.');
        debugPrint('   Si el TAG está corrompido, use NXP TagWriter para reformatearlo.');
        completer.complete(false);
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('❌ Error general limpiando TAG: $e');
        completer.complete(false);
        await NfcManager.instance.stopSession();
      }
    },
  );

  return completer.future;
}

/// Crea un mensaje NDEF mínimo con un registro de texto "0"
/// (Android requiere al menos un registro, no permite mensajes vacíos)
NdefMessage _createMinimalNdefMessage() {
  const clearContent = '0';
  const languageCode = 'en';
  final languageCodeBytes = utf8.encode(languageCode);
  final textBytes = utf8.encode(clearContent);

  // Status byte: UTF-8 encoding (bit 7 = 0) + language code length
  final statusByte = languageCodeBytes.length;

  final payload = Uint8List.fromList([
    statusByte,
    ...languageCodeBytes,
    ...textBytes,
  ]);

  final record = NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList([84]), // 'T' para Text
    identifier: Uint8List(0),
    payload: payload,
  );

  return NdefMessage(records: [record]);
}
