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
import 'dart:io' show Platform;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_android.dart' show IsoDepAndroid;
import 'package:ndef_record/ndef_record.dart';
import 'dart:typed_data';

/// Escribe datos directamente en un TAG NFC sin leer el contenido previo
/// OPTIMIZADO PARA TEST DE CAPACIDAD - NO usar para escritura normal
///
/// Esta función escribe directamente el contenido que le pasas, SIN leer
/// el contenido existente del TAG. Esto elimina el cuello de botella de
/// lectura que causa lentitud en escrituras repetitivas.
///
/// USO EXCLUSIVO: Test de Capacidad TAG
Future<bool> writeNFCTagDirect(
  BuildContext context,
  String dataToWrite,
) async {
  if (Platform.isWindows) return false; // NFC no disponible en Windows
  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    return false;
  }

  Completer<bool> completer = Completer<bool>();

  // Iniciar sesión NFC para escritura
  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        // NO LEER EL CONTENIDO EXISTENTE - Escribir directamente
        debugPrint('🚀 ESCRITURA DIRECTA: ${dataToWrite.length} bytes (sin lectura previa)');

        // VALIDAR ESPACIO DISPONIBLE
        final finalContentBytes = utf8.encode(dataToWrite);
        final requiredBytes = finalContentBytes.length;

        // Determinar capacidad máxima según el tipo de tag
        int maxCapacity = 0;
        final ndef = Ndef.from(tag);
        final isoDep = IsoDepAndroid.from(tag);
        final mifareClassic = MifareClassicAndroid.from(tag);

        if (ndef != null) {
          // Tags NDEF: usar la capacidad reportada
          maxCapacity = ndef.maxSize;
          debugPrint('Tag NDEF con capacidad: $maxCapacity bytes');
        } else if (isoDep != null) {
          // Mifare DESFire: Capacidad típica 2KB-8KB
          maxCapacity = 8192; // 8KB para DESFire EV3
          debugPrint('Tag DESFire (IsoDep) con capacidad: $maxCapacity bytes');
        } else if (mifareClassic != null) {
          // Mifare Classic: Capacidad limitada
          maxCapacity = 240; // Limitado para evitar timeout
          debugPrint('Tag Mifare Classic con capacidad limitada: $maxCapacity bytes');
        }

        // Verificar si hay espacio suficiente
        if (maxCapacity > 0 && requiredBytes > maxCapacity) {
          debugPrint(
              '❌ ESPACIO INSUFICIENTE: Se requieren $requiredBytes bytes, pero solo hay $maxCapacity bytes disponibles');

          // Actualizar AppState con mensaje de error
          FFAppState().update(() {
            FFAppState().nfcRead =
                'ERROR:ESPACIO_INSUFICIENTE:$requiredBytes/$maxCapacity';
          });

          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        debugPrint('✅ Espacio OK: $requiredBytes bytes de $maxCapacity disponibles');

        // Crear payload del Text Record según estándar NDEF
        const languageCode = 'en';
        final languageCodeBytes = utf8.encode(languageCode);
        final textBytes = utf8.encode(dataToWrite);

        // Status byte: UTF-8 encoding (bit 7 = 0) + language code length
        final statusByte = languageCodeBytes.length;

        final payload = Uint8List.fromList([
          statusByte,
          ...languageCodeBytes,
          ...textBytes,
        ]);

        // Crear el mensaje NDEF usando ndef_record
        final record = NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([84]), // 'T' para Text
          identifier: Uint8List(0),
          payload: payload,
        );

        final message = NdefMessage(records: [record]);

        // Intentar escribir en el tag usando Ndef
        var ndefWriter = Ndef.from(tag);

        if (ndefWriter == null) {
          // Intentar formatear el tag como NDEF (solo primera vez)
          final tagTypeName = isoDep != null
              ? 'DESFire'
              : (mifareClassic != null ? 'MifareClassic' : 'desconocido');
          debugPrint('Tag no soporta NDEF ($tagTypeName), intentando formatear...');
          final ndefFormatable = NdefFormatableAndroid.from(tag);

          if (ndefFormatable != null) {
            try {
              await ndefFormatable.format(message);
              debugPrint('✅ Tag $tagTypeName formateado y escrito exitosamente');

              // Actualizar AppState
              FFAppState().update(() {
                FFAppState().nfcRead = dataToWrite;
              });

              completer.complete(true);
              await NfcManager.instance.stopSession();
              return;
            } catch (formatError) {
              debugPrint('❌ Error al formatear tag: $formatError');
              completer.complete(false);
              await NfcManager.instance.stopSession();
              return;
            }
          }

          // Si no se puede formatear como NDEF, intentar MifareClassic
          if (mifareClassic != null) {
            try {
              debugPrint('📝 Escribiendo en MifareClassic...');

              final contentBytes = utf8.encode(dataToWrite);
              final totalBytes = contentBytes.length;

              // Clave default de Mifare
              final key =
                  Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

              final blocksToWrite = <int, Uint8List>{};
              int byteIndex = 0;

              // Sector 0: bloques 1 y 2
              for (var blockInSector = 1; blockInSector <= 2; blockInSector++) {
                if (byteIndex >= totalBytes) break;

                final blockIndex = blockInSector;
                final end =
                    (byteIndex + 16 < totalBytes) ? byteIndex + 16 : totalBytes;
                final blockData = contentBytes.sublist(byteIndex, end);

                final paddedBlock = Uint8List(16);
                paddedBlock.setRange(0, blockData.length, blockData);
                blocksToWrite[blockIndex] = paddedBlock;

                byteIndex = end;
              }

              // Sectores 1-6
              for (var sector = 1; sector <= 6; sector++) {
                if (byteIndex >= totalBytes) break;

                for (var blockInSector = 0; blockInSector <= 2; blockInSector++) {
                  if (byteIndex >= totalBytes) break;

                  final blockIndex = (sector * 4) + blockInSector;
                  final end = (byteIndex + 16 < totalBytes)
                      ? byteIndex + 16
                      : totalBytes;
                  final blockData = contentBytes.sublist(byteIndex, end);

                  final paddedBlock = Uint8List(16);
                  paddedBlock.setRange(0, blockData.length, blockData);
                  blocksToWrite[blockIndex] = paddedBlock;

                  byteIndex = end;
                }
              }

              if (byteIndex < totalBytes) {
                debugPrint('⚠️ Contenido muy largo. ${totalBytes - byteIndex} bytes no escritos');
                completer.complete(false);
                await NfcManager.instance.stopSession();
                return;
              }

              // Escribir bloques
              int currentSector = -1;
              for (var entry in blocksToWrite.entries) {
                final blockIndex = entry.key;
                final data = entry.value;
                final sector = blockIndex ~/ 4;

                if (sector != currentSector) {
                  try {
                    await mifareClassic.authenticateSectorWithKeyA(
                      sectorIndex: sector,
                      key: key,
                    );
                    currentSector = sector;
                  } catch (authError) {
                    try {
                      await mifareClassic.authenticateSectorWithKeyB(
                        sectorIndex: sector,
                        key: key,
                      );
                      currentSector = sector;
                    } catch (authErrorB) {
                      continue;
                    }
                  }
                }

                try {
                  await mifareClassic.writeBlock(
                    blockIndex: blockIndex,
                    data: data,
                  );
                } catch (writeError) {
                  debugPrint('❌ Error escribiendo bloque $blockIndex: $writeError');
                }
              }

              debugPrint('✅ MifareClassic escrito exitosamente');

              FFAppState().update(() {
                FFAppState().nfcRead = dataToWrite;
              });

              completer.complete(true);
              await NfcManager.instance.stopSession();
              return;
            } catch (mifareError) {
              debugPrint('❌ Error escribiendo MifareClassic: $mifareError');
              completer.complete(false);
              await NfcManager.instance.stopSession();
              return;
            }
          }

          debugPrint('❌ Tag no es compatible');
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        if (!ndefWriter.isWritable) {
          debugPrint('❌ Tag no es escribible (protegido)');
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        try {
          // Escribir usando NDEF estándar
          await ndefWriter.write(message: message);
          debugPrint('✅ NDEF escrito exitosamente: ${dataToWrite.length} bytes');

          // Actualizar AppState
          FFAppState().update(() {
            FFAppState().nfcRead = dataToWrite;
          });

          completer.complete(true);
        } catch (writeError) {
          debugPrint('❌ Error escribiendo NDEF: $writeError');

          final errorMsg = writeError.toString().toLowerCase();
          if (errorMsg.contains('ioexception') ||
              errorMsg.contains('tag was lost')) {
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:TAG_ALEJADO';
            });
          } else if (errorMsg.contains('readonly') ||
              errorMsg.contains('not writable')) {
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:TAG_PROTEGIDO';
            });
          } else {
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:ESCRITURA_FALLIDA';
            });
          }

          completer.complete(false);
        }

        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('❌ Error general escribiendo NFC: $e');
        completer.complete(false);
        await NfcManager.instance.stopSession();
      }
    },
  );

  return completer.future;
}
