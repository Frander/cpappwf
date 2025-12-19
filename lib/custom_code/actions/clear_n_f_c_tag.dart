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
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';
import 'dart:typed_data';

/// Limpia completamente un TAG NFC escribiendo ceros en todos los sectores
Future<bool> clearNFCTag(BuildContext context) async {
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

        // 3. Si no funciona NDEF/Formatable, intentar con MifareClassic (bajo nivel)
        final mifareClassic = MifareClassicAndroid.from(tag);
        if (mifareClassic != null) {
          try {
            debugPrint('📝 Limpiando TAG Mifare Classic 1K (bajo nivel)...');

            // Clave default de Mifare
            final key =
                Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

            // Crear un bloque de 16 bytes con ceros
            final emptyBlock = Uint8List(16);

            // OPTIMIZACIÓN: Solo limpiar sectores 0-3 donde típicamente se almacenan datos NDEF
            // Los sectores 4-15 raramente se usan para datos de usuario
            // Sector 0: bloques 1-2 (NO tocar bloque 0 que es de fabricante)
            // Sectores 1-3: bloques 0-2 de cada sector (NO tocar bloque 3 que es de autenticación)

            int blocksCleared = 0;
            bool tagLost = false;

            // Sector 0: limpiar bloques 1 y 2
            try {
              await mifareClassic.authenticateSectorWithKeyA(
                sectorIndex: 0,
                key: key,
              );
              debugPrint('Sector 0 autenticado');

              // Limpiar bloques 1 y 2 del sector 0
              for (var blockInSector = 1; blockInSector <= 2; blockInSector++) {
                try {
                  await mifareClassic.writeBlock(
                    blockIndex: blockInSector,
                    data: emptyBlock,
                  );
                  blocksCleared++;
                } catch (e) {
                  if (e.toString().contains('TagLostException')) {
                    debugPrint('⚠️ TAG perdido durante escritura');
                    tagLost = true;
                    break;
                  }
                  debugPrint('⚠️ Error al limpiar bloque $blockInSector: $e');
                }
              }
            } catch (e) {
              if (e.toString().contains('TagLostException')) {
                debugPrint('⚠️ TAG perdido durante autenticación sector 0');
                tagLost = true;
              } else {
                debugPrint('⚠️ Error al autenticar sector 0: $e');
              }
            }

            // Sectores 1-3: limpiar bloques 0, 1, 2 de cada sector (solo si el TAG sigue conectado)
            // NOTA: Reducido de 1-15 a 1-3 para evitar TagLostException
            if (!tagLost) {
              for (var sector = 1; sector <= 3 && !tagLost; sector++) {
                // Autenticar sector
                try {
                  await mifareClassic.authenticateSectorWithKeyA(
                    sectorIndex: sector,
                    key: key,
                  );
                  debugPrint('Sector $sector autenticado');
                } catch (authError) {
                  if (authError.toString().contains('TagLostException')) {
                    debugPrint('⚠️ TAG perdido - deteniendo limpieza');
                    tagLost = true;
                    break;
                  }
                  debugPrint('! Error al autenticar sector $sector con KeyA: $authError');
                  // Intentar con KeyB
                  try {
                    await mifareClassic.authenticateSectorWithKeyB(
                      sectorIndex: sector,
                      key: key,
                    );
                    debugPrint('Sector $sector autenticado con KeyB');
                  } catch (authErrorB) {
                    if (authErrorB.toString().contains('TagLostException')) {
                      debugPrint('⚠️ TAG perdido - deteniendo limpieza');
                      tagLost = true;
                      break;
                    }
                    debugPrint('! Error al autenticar sector $sector con KeyB: $authErrorB');
                    continue; // Saltar este sector
                  }
                }

                // Limpiar bloques 0, 1, 2 del sector (NO tocar bloque 3 que es de autenticación)
                for (var blockInSector = 0; blockInSector <= 2 && !tagLost; blockInSector++) {
                  final blockIndex = (sector * 4) + blockInSector;
                  try {
                    await mifareClassic.writeBlock(
                      blockIndex: blockIndex,
                      data: emptyBlock,
                    );
                    blocksCleared++;
                  } catch (e) {
                    if (e.toString().contains('TagLostException')) {
                      debugPrint('⚠️ TAG perdido durante escritura bloque $blockIndex');
                      tagLost = true;
                      break;
                    }
                    debugPrint('⚠️ Error al limpiar bloque $blockIndex: $e');
                  }
                }
              }
            }

            debugPrint(
                '✅ TAG Mifare Classic limpiado: $blocksCleared bloques borrados${tagLost ? " (TAG perdido)" : ""}');

            // Solo intentar reformatear si el TAG sigue conectado
            if (!tagLost && blocksCleared > 0) {
              try {
                debugPrint('🔄 Reformateando TAG con contenido mínimo...');
                final ndefFormatableAfterClear = NdefFormatableAndroid.from(tag);
                if (ndefFormatableAfterClear != null) {
                  final minimalMessage = _createMinimalNdefMessage();
                  await ndefFormatableAfterClear.format(minimalMessage);
                  debugPrint('✅ TAG reformateado exitosamente (contenido: "0")');
                } else {
                  debugPrint(
                      '⚠️ TAG no soporta reformateo NDEF, pero bloques limpiados');
                }
              } catch (reformatError) {
                debugPrint('⚠️ No se pudo reformatear como NDEF: $reformatError');
                debugPrint('   (Los bloques fueron limpiados exitosamente)');
              }
            }

            // Detener sesión
            await NfcManager.instance.stopSession();

            // Si se limpió al menos un bloque, considerar éxito
            completer.complete(blocksCleared > 0);
            return;
          } catch (e) {
            debugPrint('❌ Error al limpiar Mifare Classic: $e');
          }
        }

        // Si llegamos aquí, no se pudo limpiar
        debugPrint(
            '❌ No se pudo limpiar el TAG: tipo no soportado o protegido');
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
