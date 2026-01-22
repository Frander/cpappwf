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
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_android.dart'
    show IsoDepAndroid, NfcAAndroid, MifareClassicAndroid, NfcTagAndroid;

/// Lectura básica de NFC sin validación de tipo de producto
/// Esta función es usada por el Centro de Administración NFC para:
/// - Leer contenido del tag
/// - Limpiar tags
/// - Operaciones de administración que NO requieren validación de tipo
Future<String> readNFCBasic(BuildContext context,
    {bool autoClose = true}) async {
  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    return '';
  }

  Completer<String> completer = Completer<String>();

  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
      NfcPollingOption.iso18092,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        String tagData = '';

        // Intentar leer como NDEF primero
        final ndef = Ndef.from(tag);
        if (ndef != null && ndef.cachedMessage != null) {
          final records = ndef.cachedMessage!.records;
          if (records.isNotEmpty) {
            final firstRecord = records.first;
            final payload = firstRecord.payload;

            if (payload.isNotEmpty) {
              try {
                final statusByte = payload[0];
                final languageCodeLength = statusByte & 0x3F;

                if (payload.length > languageCodeLength + 1) {
                  final textBytes = payload.sublist(1 + languageCodeLength);
                  tagData = utf8.decode(textBytes);
                  debugPrint('📖 readNFCBasic: Leído desde NDEF: ${tagData.length} bytes');
                }
              } catch (e) {
                debugPrint('⚠️ readNFCBasic: Error decodificando NDEF: $e');
              }
            }
          }
        }

        // Si no se pudo leer como NDEF, intentar MifareClassic
        if (tagData.isEmpty) {
          final mifareClassic = MifareClassicAndroid.from(tag);
          if (mifareClassic != null) {
            try {
              debugPrint('📖 readNFCBasic: Intentando leer tag MifareClassic...');

              final key =
                  Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
              final allBytes = <int>[];
              bool tagLost = false;

              // Leer sector 0: bloques 1-2
              try {
                await mifareClassic.authenticateSectorWithKeyA(
                  sectorIndex: 0,
                  key: key,
                );
                for (int blockInSector = 1; blockInSector <= 2; blockInSector++) {
                  try {
                    final blockData =
                        await mifareClassic.readBlock(blockIndex: blockInSector);
                    allBytes.addAll(blockData);
                  } catch (e) {
                    if (e.toString().contains('TagLostException')) {
                      tagLost = true;
                      break;
                    }
                  }
                }
              } catch (e) {
                if (e.toString().contains('TagLostException')) {
                  tagLost = true;
                }
              }

              // Leer sectores 1-3
              if (!tagLost) {
                for (int sector = 1; sector <= 3 && !tagLost; sector++) {
                  try {
                    await mifareClassic.authenticateSectorWithKeyA(
                      sectorIndex: sector,
                      key: key,
                    );
                  } catch (e) {
                    if (e.toString().contains('TagLostException')) {
                      tagLost = true;
                      break;
                    }
                    continue;
                  }

                  for (int blockInSector = 0;
                      blockInSector <= 2 && !tagLost;
                      blockInSector++) {
                    final blockIndex = (sector * 4) + blockInSector;
                    try {
                      final blockData =
                          await mifareClassic.readBlock(blockIndex: blockIndex);
                      allBytes.addAll(blockData);
                    } catch (e) {
                      if (e.toString().contains('TagLostException')) {
                        tagLost = true;
                        break;
                      }
                    }
                  }
                }
              }

              if (allBytes.isNotEmpty) {
                // Buscar fin de contenido (primer byte 0x00)
                int endIndex = allBytes.indexOf(0);
                if (endIndex != -1) {
                  allBytes.removeRange(endIndex, allBytes.length);
                }

                if (allBytes.isNotEmpty) {
                  tagData = utf8.decode(allBytes, allowMalformed: true);
                  debugPrint('📖 readNFCBasic: Leído desde MifareClassic: ${tagData.length} bytes');
                }
              }
            } catch (e) {
              debugPrint('⚠️ readNFCBasic: Error leyendo MifareClassic: $e');
            }
          }
        }

        // Obtener información del tag
        String tagId = 'DESCONOCIDO';
        try {
          final androidTag = NfcTagAndroid.from(tag);
          if (androidTag != null && androidTag.id.isNotEmpty) {
            tagId = androidTag.id
                .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
                .join('');
            debugPrint('📍 readNFCBasic: TAG ID: $tagId');
          }
        } catch (e) {
          debugPrint('⚠️ readNFCBasic: Error obteniendo TAG ID: $e');
        }

        // Cerrar sesión si se solicitó
        if (autoClose) {
          await NfcManager.instance.stopSession();
        }

        debugPrint('✅ readNFCBasic: Lectura completada');
        completer.complete(tagData);
      } catch (e) {
        debugPrint('❌ readNFCBasic: Error general: $e');
        if (autoClose) {
          await NfcManager.instance.stopSession();
        }
        completer.complete('');
      }
    },
  );

  return completer.future;
}
