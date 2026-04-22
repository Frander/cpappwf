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
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_android.dart'
    show IsoDepAndroid, NfcAAndroid, MifareClassicAndroid, NfcTagAndroid;

/// Lee un TAG NFC y devuelve información detallada incluyendo:
/// - tagId: Identificación del TAG (hex)
/// - tagType: Tipo de TAG (NFC-A, Mifare Classic, etc.)
/// - content: Contenido almacenado en el TAG
/// - maxSize: Capacidad máxima en bytes
/// - currentSize: Tamaño actual del contenido en bytes
/// - availableSize: Espacio disponible en bytes
Future<Map<String, dynamic>> readNfcDetailed(BuildContext context) async {
  if (Platform.isWindows) return {'success': false, 'content': ''}; // NFC no disponible en Windows
  final result = <String, dynamic>{
    'success': false,
    'tagId': '',
    'tagType': 'Desconocido',
    'content': '',
    'maxSize': 0,
    'currentSize': 0,
    'availableSize': 0,
    'errorMessage': '',
  };

  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    result['errorMessage'] = 'NFC no disponible o desactivado';
    return result;
  }

  Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();

  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
      NfcPollingOption.iso18092,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        String tagData = '';
        String tagId = '';
        String tagType = 'Desconocido';
        int maxSize = 0;
        int currentSize = 0;

        // 1. OBTENER ID DEL TAG
        final androidTag = NfcTagAndroid.from(tag);
        if (androidTag != null && androidTag.id.isNotEmpty) {
          tagId = androidTag.id
              .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join('');
          debugPrint('🏷️ TAG ID: $tagId');
        }

        // 2. OBTENER INFORMACIÓN DEL TAG (tipo y capacidad)
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          maxSize = ndef.maxSize;

          // Determinar tipo basado en maxSize
          if (maxSize >= 4096) {
            tagType = 'NTAG 216 / Mifare 4K';
          } else if (maxSize >= 716) {
            tagType = 'NTAG 215';
          } else if (maxSize >= 137) {
            tagType = 'NTAG 213 / Mifare 1K';
          } else {
            tagType = 'NFC Type 2';
          }

          debugPrint('🏷️ TAG Type: $tagType (NDEF maxSize: $maxSize bytes)');

          // 3. LEER CONTENIDO DEL TAG
          if (ndef.cachedMessage != null) {
            final records = ndef.cachedMessage!.records;
            if (records.isNotEmpty) {
              final firstRecord = records.first;
              final payload = firstRecord.payload;

              if (payload.isNotEmpty) {
                try {
                  // Decodificar Text Record
                  final statusByte = payload[0];
                  final languageCodeLength = statusByte & 0x3F;

                  if (payload.length > languageCodeLength + 1) {
                    final textBytes = payload.sublist(1 + languageCodeLength);
                    tagData = utf8.decode(textBytes);
                    currentSize = tagData.length;
                    debugPrint('📖 Contenido leído: ${tagData.length} bytes');
                  }
                } catch (e) {
                  debugPrint('⚠️ Error decodificando NDEF: $e');
                }
              }
            }
          }
        } else {
          // Intentar detectar otros tipos de TAG
          final isoDep = IsoDepAndroid.from(tag);
          if (isoDep != null) {
            tagType = 'DESFire / IsoDep';
            debugPrint('🏷️ TAG Type: $tagType (debe formatearse como NDEF)');
          }

          final nfcA = NfcAAndroid.from(tag);
          if (nfcA != null) {
            tagType = 'NFC-A (ATQA: ${nfcA.atqa}, SAK: ${nfcA.sak})';
            debugPrint('🏷️ TAG Type: $tagType');
          }

          final mifareClassic = MifareClassicAndroid.from(tag);
          if (mifareClassic != null) {
            tagType = 'Mifare Classic (${mifareClassic.size} bytes, ${mifareClassic.blockCount} bloques, ${mifareClassic.sectorCount} sectores)';
            maxSize = mifareClassic.size;
            debugPrint('🏷️ TAG Type: $tagType');

            // Intentar leer contenido de Mifare Classic
            try {
              final key = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
              final allBytes = <int>[];

              // Leer sector 0: bloques 1-2
              await mifareClassic.authenticateSectorWithKeyA(sectorIndex: 0, key: key);
              final block1 = await mifareClassic.readBlock(blockIndex: 1);
              final block2 = await mifareClassic.readBlock(blockIndex: 2);
              allBytes.addAll(block1);
              allBytes.addAll(block2);

              // Leer sectores 1-14
              for (int sector = 1; sector <= 14; sector++) {
                try {
                  await mifareClassic.authenticateSectorWithKeyA(sectorIndex: sector, key: key);
                  for (int block = 0; block < 3; block++) {
                    final blockIndex = (sector * 4) + block;
                    final blockData = await mifareClassic.readBlock(blockIndex: blockIndex);
                    allBytes.addAll(blockData);
                  }
                } catch (e) {
                  debugPrint('⚠️ No se pudo leer sector $sector');
                  break;
                }
              }

              // Filtrar bytes nulos del final
              int lastNonZero = allBytes.lastIndexWhere((byte) => byte != 0);
              if (lastNonZero >= 0) {
                final trimmedBytes = allBytes.sublist(0, lastNonZero + 1);
                tagData = utf8.decode(trimmedBytes, allowMalformed: true);
                currentSize = tagData.length;
                debugPrint('📖 Contenido Mifare Classic: ${tagData.length} bytes');
              }
            } catch (e) {
              debugPrint('⚠️ Error leyendo Mifare Classic: $e');
            }
          }
        }

        // Calcular espacio disponible
        int availableSize = maxSize - currentSize;
        if (availableSize < 0) availableSize = 0;

        // Preparar resultado
        result['success'] = true;
        result['tagId'] = tagId;
        result['tagType'] = tagType;
        result['content'] = tagData;
        result['maxSize'] = maxSize;
        result['currentSize'] = currentSize;
        result['availableSize'] = availableSize;

        debugPrint('✅ TAG leído exitosamente');
        debugPrint('   ID: $tagId');
        debugPrint('   Tipo: $tagType');
        debugPrint('   Capacidad: $maxSize bytes');
        debugPrint('   Usado: $currentSize bytes');
        debugPrint('   Disponible: $availableSize bytes');

        NfcManager.instance.stopSession();
        completer.complete(result);
      } catch (e, stackTrace) {
        debugPrint('❌ Error leyendo TAG: $e');
        debugPrint('Stack trace: $stackTrace');
        result['errorMessage'] = e.toString();
        NfcManager.instance.stopSession();
        completer.complete(result);
      }
    },
  );

  return completer.future;
}
