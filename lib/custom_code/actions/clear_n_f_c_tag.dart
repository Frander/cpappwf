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
      // onDiscovered puede dispararse varias veces en una sesión; si ya
      // completamos, ignorar para no provocar "Future already completed".
      if (completer.isCompleted) return;
      try {
        debugPrint('🏷️ TAG detectado, iniciando limpieza...');

        // 1. Intentar limpiar como NDEF (si ya está formateado)
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          if (ndef.isWritable) {
            // Escribir "0" y VERIFICAR por relectura que el tag quedó limpio,
            // con un reintento en sesión. Si tras los intentos no se confirma,
            // se cae a los otros métodos (formatable) y, si todo falla, el
            // desenlace final reporta ERROR:LIMPIEZA_FALLIDA.
            final minimalMessage = _createMinimalNdefMessage();
            for (int attempt = 1; attempt <= 2; attempt++) {
              try {
                debugPrint('🔄 TAG NDEF: escribiendo "0" (intento $attempt/2)...');
                await ndef.write(message: minimalMessage);
                if (await _verifyTagCleared(tag)) {
                  await NfcManager.instance.stopSession();
                  debugPrint('✅ TAG limpiado y verificado (contenido: "0")');
                  completer.complete(true);
                  return;
                }
                debugPrint('⚠️ Verificación de limpieza falló — reintentando...');
                await Future.delayed(const Duration(milliseconds: 300));
              } catch (e) {
                debugPrint('⚠️ No se pudo limpiar como NDEF (intento $attempt): $e');
                break; // pasar a otros métodos
              }
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
        FFAppState().update(() {
          FFAppState().nfcRead = 'ERROR:LIMPIEZA_FALLIDA';
        });
        completer.complete(false);
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('❌ Error general limpiando TAG: $e');
        FFAppState().update(() {
          FFAppState().nfcRead = 'ERROR:LIMPIEZA_FALLIDA';
        });
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

/// Re-lee el tag por NDEF y confirma que quedó limpio (vacío o contenido "0").
/// Se ejecuta en la misma sesión, con el tag aún presente. Retorna false si
/// no se pudo releer o si todavía hay contenido distinto de "0".
Future<bool> _verifyTagCleared(NfcTag tag) async {
  try {
    final ndef = Ndef.from(tag);
    if (ndef == null) return false;
    final msg = await ndef.read();
    if (msg == null || msg.records.isEmpty) return true; // sin records = limpio
    final payload = msg.records.first.payload;
    if (payload.isEmpty) return true;
    final langLen = payload[0] & 0x3F;
    if (payload.length <= langLen + 1) return true;
    final content =
        utf8.decode(payload.sublist(1 + langLen), allowMalformed: true).trim();
    return content.isEmpty || content == '0';
  } catch (e) {
    debugPrint('⚠️ _verifyTagCleared error: $e');
    return false;
  }
}
