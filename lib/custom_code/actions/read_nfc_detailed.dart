// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import '/custom_code/platform_utils.dart';
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
  if (!Platforms.isMobile) return {'success': false, 'content': ''}; // NFC no disponible en desktop
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

        // 2. IDENTIFICAR HARDWARE DEL TAG (tecnología y capacidad real)
        final ndef = Ndef.from(tag);
        final isoDep = IsoDepAndroid.from(tag);
        final mifareClassic = MifareClassicAndroid.from(tag);
        final nfcA = NfcAAndroid.from(tag);

        String tagTechnology = 'Desconocido';
        bool ndefWritable = false;
        String atqaSak = '';

        // ATQA / SAK identifica el fabricante y familia del chip (NfcA only)
        if (nfcA != null) {
          final atqaHex = nfcA.atqa
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join('');
          final sakHex = nfcA.sak.toRadixString(16).padLeft(2, '0').toUpperCase();
          atqaSak = 'ATQA:$atqaHex  SAK:$sakHex';
        }

        if (mifareClassic != null) {
          // Mifare Classic 1K / 4K — NfcA con sectores de 64 bytes
          maxSize = mifareClassic.size;
          tagType = maxSize >= 4096 ? 'Mifare Classic 4K' : 'Mifare Classic 1K';
          tagTechnology = 'NfcA · Mifare Classic';
          ndefWritable = ndef?.isWritable ?? false;
          debugPrint('🏷️ Mifare Classic: ${mifareClassic.size}B, '
              '${mifareClassic.sectorCount} sectores, ${mifareClassic.blockCount} bloques');
        } else if (isoDep != null && ndef != null) {
          // DESFire formateado como NDEF
          maxSize = ndef.maxSize;
          tagType = 'Mifare DESFire (NDEF)';
          tagTechnology = 'IsoDep · DESFire';
          ndefWritable = ndef.isWritable;
          debugPrint('🏷️ DESFire NDEF: maxSize=$maxSize');
        } else if (isoDep != null) {
          // DESFire virgen (no formateado como NDEF)
          maxSize = 2048;
          tagType = 'Mifare DESFire (sin NDEF)';
          tagTechnology = 'IsoDep · DESFire';
          debugPrint('🏷️ DESFire sin NDEF');
        } else if (ndef != null && nfcA != null) {
          // NTAG213/215/216 y Ultralight — todos son NfcA + NDEF
          maxSize = ndef.maxSize;
          ndefWritable = ndef.isWritable;
          tagTechnology = 'NfcA · Mifare Ultralight';
          if (maxSize >= 888) {
            tagType = 'NTAG 216';
          } else if (maxSize >= 504) {
            tagType = 'NTAG 215';
          } else if (maxSize >= 137) {
            tagType = 'NTAG 213';
          } else {
            tagType = 'Mifare Ultralight C';
          }
          debugPrint('🏷️ $tagType (NfcA+NDEF, maxSize=$maxSize, writable=$ndefWritable)');
        } else if (ndef != null) {
          // NDEF con tecnología no identificada
          maxSize = ndef.maxSize;
          ndefWritable = ndef.isWritable;
          tagType = 'NDEF Tag';
          tagTechnology = 'Desconocido';
          debugPrint('🏷️ NDEF genérico: maxSize=$maxSize');
        } else if (nfcA != null) {
          tagType = 'NFC-A (sin NDEF)';
          tagTechnology = 'NfcA';
          debugPrint('🏷️ NfcA sin NDEF');
        }

        // 3. LEER CONTENIDO DEL TAG
        if (ndef != null && ndef.cachedMessage != null) {
          final records = ndef.cachedMessage!.records;
          if (records.isNotEmpty) {
            final payload = records.first.payload;
            if (payload.isNotEmpty) {
              try {
                final statusByte = payload[0];
                final languageCodeLength = statusByte & 0x3F;
                if (payload.length > languageCodeLength + 1) {
                  final textBytes = payload.sublist(1 + languageCodeLength);
                  tagData = utf8.decode(textBytes);
                  currentSize = utf8.encode(tagData).length;
                  debugPrint('📖 Contenido NDEF: ${tagData.length} chars / $currentSize bytes');
                }
              } catch (e) {
                debugPrint('⚠️ Error decodificando NDEF: $e');
              }
            }
          }
        } else if (mifareClassic != null && tagData.isEmpty) {
          // Mifare Classic sin NDEF: leer raw
          try {
            final key = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
            final allBytes = <int>[];

            await mifareClassic.authenticateSectorWithKeyA(sectorIndex: 0, key: key);
            allBytes.addAll(await mifareClassic.readBlock(blockIndex: 1));
            allBytes.addAll(await mifareClassic.readBlock(blockIndex: 2));

            for (int sector = 1; sector <= 14; sector++) {
              try {
                await mifareClassic.authenticateSectorWithKeyA(sectorIndex: sector, key: key);
                for (int block = 0; block < 3; block++) {
                  allBytes.addAll(await mifareClassic.readBlock(blockIndex: (sector * 4) + block));
                }
              } catch (_) {
                break;
              }
            }

            final lastNonZero = allBytes.lastIndexWhere((b) => b != 0);
            if (lastNonZero >= 0) {
              tagData = utf8.decode(allBytes.sublist(0, lastNonZero + 1), allowMalformed: true);
              currentSize = tagData.length;
              debugPrint('📖 Contenido Mifare Classic raw: ${tagData.length} bytes');
            }
          } catch (e) {
            debugPrint('⚠️ Error leyendo Mifare Classic: $e');
          }
        }

        // Calcular espacio disponible
        int availableSize = maxSize > 0 ? maxSize - currentSize : 0;
        if (availableSize < 0) availableSize = 0;

        // Preparar resultado con campos extendidos
        result['success'] = true;
        result['tagId'] = tagId;
        result['tagType'] = tagType;
        result['tagTechnology'] = tagTechnology;
        result['ndefWritable'] = ndefWritable;
        if (atqaSak.isNotEmpty) result['atqaSak'] = atqaSak;
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
