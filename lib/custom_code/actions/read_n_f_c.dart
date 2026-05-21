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
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '/custom_code/platform_utils.dart';

Future<String> readNFC(
  BuildContext context, {
  bool autoClose = true,
  bool clearAfterRead = false,
  Future<bool> Function(String tagData)? onTagReadCallback,
}) async {
  if (!Platforms.isMobile) return ''; // NFC no disponible en desktop
  // Verificar si NFC está disponible y activado usando la nueva función
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    FFAppState().update(() {
      FFAppState().nfcRead = ''; // Actualizar AppState pero no cerrar popup
    });
    return '';
  }

  // Se utiliza un Completer para esperar la lectura del tag
  Completer<String> completer = Completer<String>();

  // Inicia la sesión NFC con un callback onDiscovered para cuando se detecte un tag
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
                // Decodificar Text Record
                final statusByte = payload[0];
                final languageCodeLength = statusByte & 0x3F;

                if (payload.length > languageCodeLength + 1) {
                  final textBytes = payload.sublist(1 + languageCodeLength);
                  tagData = utf8.decode(textBytes);
                  debugPrint('Leído desde NDEF: ${tagData.length} bytes');
                }
              } catch (e) {
                debugPrint('Error decodificando NDEF: $e');
              }
            }
          }
        }

        // Si no se pudo leer como NDEF, intentar leer como MifareClassic o DESFire
        if (tagData.isEmpty) {
          // Primero intentar detectar si es un tag DESFire (IsoDep)
          final isoDep = IsoDepAndroid.from(tag);
          if (isoDep != null) {
            debugPrint('Tag DESFire/IsoDep detectado - debe formatearse como NDEF para uso en esta app');
          }

          // Si aún no se pudo leer, intentar MifareClassic
          final mifareClassic = MifareClassicAndroid.from(tag);
          if (mifareClassic != null && tagData.isEmpty) {
            try {
              debugPrint('Intentando leer tag MifareClassic...');

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

                for (var block = 1; block <= 2 && !tagLost; block++) {
                  try {
                    final blockData =
                        await mifareClassic.readBlock(blockIndex: block);
                    allBytes.addAll(blockData);
                  } catch (blockError) {
                    if (blockError.toString().contains('IOException') ||
                        blockError.toString().contains('TagLostException')) {
                      debugPrint('⚠️ TAG perdido durante lectura del bloque $block');
                      tagLost = true;
                      break;
                    }
                    debugPrint('Error leyendo bloque $block: $blockError');
                  }
                }
              } catch (e) {
                if (e.toString().contains('IOException') ||
                    e.toString().contains('TagLostException')) {
                  debugPrint('⚠️ TAG perdido durante autenticación del sector 0');
                  tagLost = true;
                } else {
                  debugPrint('Error leyendo sector 0: $e');
                }
              }

              // Leer solo sectores 1-6 (reducido para evitar timeout)
              // Esto da ~240 bytes de datos útiles, suficiente para la mayoría de casos
              if (!tagLost) {
                bool foundEnd = false;
                for (var sector = 1; sector <= 6 && !tagLost; sector++) {
                  try {
                    await mifareClassic.authenticateSectorWithKeyA(
                      sectorIndex: sector,
                      key: key,
                    );

                    for (var blockInSector = 0; blockInSector <= 2 && !tagLost; blockInSector++) {
                      final blockIndex = (sector * 4) + blockInSector;
                      try {
                        final blockData =
                            await mifareClassic.readBlock(blockIndex: blockIndex);
                        allBytes.addAll(blockData);

                        // Verificar si encontramos el fin del mensaje (múltiples 0x00)
                        if (blockData.where((byte) => byte == 0).length > 10) {
                          foundEnd = true;
                          break;
                        }
                      } catch (blockError) {
                        if (blockError.toString().contains('IOException') ||
                            blockError.toString().contains('TagLostException')) {
                          debugPrint('⚠️ TAG perdido durante lectura del bloque $blockIndex');
                          tagLost = true;
                          break;
                        }
                        debugPrint('Error leyendo bloque $blockIndex: $blockError');
                      }
                    }

                    if (foundEnd) {
                      debugPrint('Fin de datos detectado en sector $sector');
                      break;
                    }
                  } catch (e) {
                    if (e.toString().contains('IOException') ||
                        e.toString().contains('TagLostException')) {
                      debugPrint('⚠️ TAG perdido durante autenticación del sector $sector');
                      tagLost = true;
                      break;
                    }
                    debugPrint('Error leyendo sector $sector: $e');
                    break; // Dejar de leer si falla un sector
                  }
                }
              }

              // Convertir bytes a texto, eliminando padding de ceros
              if (allBytes.isNotEmpty) {
                // Encontrar el primer byte 0x00 (fin del texto)
                int endIndex = allBytes.indexOf(0);
                if (endIndex == -1) endIndex = allBytes.length;

                final validBytes = allBytes.sublist(0, endIndex);
                tagData = utf8.decode(validBytes, allowMalformed: true);
                debugPrint('Leído desde MifareClassic: ${tagData.length} bytes');
              }
            } catch (e) {
              debugPrint('Error leyendo MifareClassic: $e');
            }
          }
        }

        // Si aún no se pudo leer, usar el formato raw del tag
        if (tagData.isEmpty) {
          tagData = tag.data.toString();
        }

        // ===== CAPTURAR INFORMACIÓN DEL TAG =====
        String tagId = '';
        String tagType = 'Desconocido';

        try {
          // Obtener el ID del TAG desde NfcTagAndroid
          final androidTag = NfcTagAndroid.from(tag);
          if (androidTag != null && androidTag.id.isNotEmpty) {
            // Convertir Uint8List a formato hexadecimal sin separadores
            tagId = androidTag.id
                .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
                .join('');
            debugPrint('📍 TAG ID: $tagId');
            FFAppState().nfcHardwareTagId = tagId;
          } else {
            debugPrint('⚠️ No se pudo obtener el ID del TAG');
          }

          // Detectar tipo de TAG
          final isoDep = IsoDepAndroid.from(tag);
          final mifareClassic = MifareClassicAndroid.from(tag);
          final ndef = Ndef.from(tag);

          if (isoDep != null) {
            // DESFire usa IsoDep
            tagType = 'Mifare DESFire EV3 8K';
            debugPrint('🏷️ TAG Type: DESFire (IsoDep detected)');
          } else if (mifareClassic != null) {
            // Mifare Classic - detectar tamaño
            final size = mifareClassic.size;
            if (size >= 4096) {
              tagType = 'Mifare Classic 4K';
            } else {
              tagType = 'Mifare Classic 1K';
            }
            debugPrint('🏷️ TAG Type: $tagType (Size: $size bytes)');
          } else if (ndef != null) {
            // NDEF formateado pero tipo desconocido
            final maxSize = ndef.maxSize;
            if (maxSize >= 4096) {
              tagType = 'Mifare Classic 4K';
            } else if (maxSize >= 716) {
              tagType = 'Mifare Classic 1K';
            } else {
              tagType = 'NDEF Tag';
            }
            debugPrint('🏷️ TAG Type: $tagType (NDEF maxSize: $maxSize bytes)');
          }

          // Guardar información del TAG en historial
          _saveTagToHistory(tagId, tagType, tagData.length);
        } catch (e) {
          debugPrint('⚠️ Error capturando información del TAG: $e');
        }

        // === VALIDACIÓN PARA TAG-TRANSFER (TAG DE ORIGEN) ===
        if (tagId.isNotEmpty && tagData.isNotEmpty) {
          final currentActivity = FFAppState().currentActivity;
          final activityStatusList = getJsonField(currentActivity, r'''$.activity_status''') as List?;

          if (activityStatusList != null) {
            for (var statusItem in activityStatusList) {
              final typeStatus = getJsonField(statusItem, r'''$.type_status''')?.toString() ?? '';
              final defaultStatusStr = getJsonField(statusItem, r'''$.default_status''')?.toString() ?? '';

              if (typeStatus == 'tag-transfer' && defaultStatusStr.contains('=TYPE_PRODUCT_START:')) {
                debugPrint('🔍 TAG-TRANSFER: Validación de tag de origen requerida');

                // Extraer el tipo de producto de origen requerido
                // Captura todo hasta ; o } (permitiendo espacios en el nombre)
                final regex = RegExp(r'=TYPE_PRODUCT_START:([^;}]+)');
                final match = regex.firstMatch(defaultStatusStr);

                if (match != null && match.groupCount >= 1) {
                  final requiredProductType = match.group(1)!.trim();
                  debugPrint('   Tipo de origen requerido: $requiredProductType');

                  // Buscar el producto en SQLite por RFID
                  // NOTA: No cerrar la base de datos manualmente — sqflite maneja el pool
                  // automáticamente. Cerrarla aquí causa database_closed en _saveTagToHistory
                  // que corre concurrentemente (sin await) en línea 248.
                  try {
                    final dbPath = FFAppState().pathDatabase;
                    if (dbPath.isNotEmpty) {
                      final database = await openDatabase(dbPath);

                      final productResults = await database.rawQuery('''
                        SELECT Type_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1
                      ''', [tagId]);

                      if (productResults.isEmpty) {
                        debugPrint('❌ TAG-TRANSFER: RFID de origen no encontrado: $tagId');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:PRODUCTO_NO_ENCONTRADO:$requiredProductType';
                        });
                        completer.complete('ERROR:PRODUCTO_NO_ENCONTRADO:$requiredProductType');
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      final productType = productResults.first['Type_product'] as String?;
                      final productName = productResults.first['Name_product'] as String?;

                      debugPrint('✅ TAG-TRANSFER: Producto origen encontrado: $productName (Tipo: $productType)');
                      FFAppState().nfcLastProductName = productName ?? '';

                      if ((productType ?? '').toLowerCase().trim() != requiredProductType.toLowerCase().trim()) {
                        debugPrint('❌ TAG-TRANSFER: Tipo de producto de origen no coincide');
                        debugPrint('   Esperado: $requiredProductType');
                        debugPrint('   Encontrado: $productType');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:TIPO_INCORRECTO:$requiredProductType:${productType ?? "Sin tipo"}';
                        });
                        completer.complete('ERROR:TIPO_INCORRECTO:$requiredProductType:${productType ?? "Sin tipo"}');
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      debugPrint('✅ TAG-TRANSFER: Validación de tipo de origen exitosa');
                    }
                  } catch (dbError) {
                    debugPrint('❌ TAG-TRANSFER: Error validando producto de origen: $dbError');
                  }
                }
                break;
              }
            }
          }
        }

        // Inyectar tag_from, tag_to y US en el JSON leído (si es formato JSON)
        String enrichedTagData = tagData;
        if (isNewJsonFormat(tagData)) {
          try {
            final readJson = parseNfcJson(tagData);
            if (readJson != null) {
              final readInfo = readJson['Read_info'] as Map<String, dynamic>?;
              if (readInfo != null) {
                readInfo['tag_from'] = tagId; // RFID del tag leído
                readInfo['tag_to'] = '';       // vacío para tag-reader
                readInfo['US'] = FFAppState().userSelected.idUser;
              }
              enrichedTagData = nfcJsonToString(readJson);
              debugPrint('✅ TAG-READER: JSON enriquecido con tag_from=$tagId, US=${FFAppState().userSelected.idUser}');
            }
          } catch (e) {
            debugPrint('⚠️ Error enriqueciendo JSON del tag-reader: $e');
          }
        }

        // Actualizar el AppState con los datos leídos
        FFAppState().update(() {
          FFAppState().nfcRead = enrichedTagData;
        });

        // === BORRADO EN SESIÓN (tag-transfer de origen) ===
        if (clearAfterRead) {
          debugPrint('🧹 clearAfterRead=true: borrando tag de origen en sesión activa...');
          try {
            final erased = await _eraseTagInSession(tag);
            debugPrint(erased
                ? '✅ Tag de origen borrado exitosamente (misma sesión NFC)'
                : '⚠️ No se pudo borrar el tag de origen — continuando con los datos leídos');
          } catch (eraseError) {
            debugPrint('⚠️ Error durante borrado en sesión (no crítico): $eraseError');
          }
        }

        // === ENVÍO + BORRADO EN SESIÓN (tag-transfer-adb-from) ===
        if (onTagReadCallback != null) {
          try {
            final shouldErase = await onTagReadCallback(enrichedTagData);
            if (shouldErase) {
              debugPrint('🧹 onTagReadCallback=true: borrando tag en sesión activa...');
              final erased = await _eraseTagInSession(tag);
              debugPrint(erased
                  ? '✅ Tag borrado tras envío ADB (misma sesión NFC)'
                  : '⚠️ No se pudo borrar el tag tras envío ADB');
            }
          } catch (callbackError) {
            debugPrint('⚠️ Error en onTagReadCallback (no crítico): $callbackError');
          }
        }

        // Cerrar el popup solo cuando se lee exitosamente un tag (si autoClose está habilitado)
        if (autoClose && context.mounted) {
          Navigator.of(context).pop();
        }

        completer.complete(tagData);

        // Detener la sesión NFC al haber leído el tag
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('Error leyendo NFC: $e');
        // En caso de error, actualizar AppState pero no cerrar popup
        FFAppState().update(() {
          FFAppState().nfcRead = '';
        });
        completer.complete('');
        await NfcManager.instance.stopSession();
      }
    },
  );

  // Esperar a que se complete la lectura del tag o se produzca un error
  return completer.future;
}

/// Borra un tag NFC dentro de una sesión ya activa.
/// El objeto [tag] DEBE provenir de un callback onDiscovered activo.
/// NO llama startSession ni stopSession — el caller maneja la sesión.
Future<bool> _eraseTagInSession(NfcTag tag) async {
  debugPrint('🧹 _eraseTagInSession: iniciando borrado en sesión activa...');

  final minimalMsg = _createMinimalNdefMessage();

  // 1. Intentar como NDEF (tag ya formateado — Mifare Classic 4K con NDEF mapping)
  final ndef = Ndef.from(tag);
  debugPrint('🔍 Ndef.from(tag): ${ndef != null ? "OK (isWritable=${ndef.isWritable}, maxSize=${ndef.maxSize})" : "null"}');

  if (ndef != null) {
    if (ndef.isWritable) {
      // Intento 1
      try {
        await ndef.write(message: minimalMsg);
        debugPrint('✅ TAG borrado como NDEF intento 1 ("0")');
        return true;
      } catch (e) {
        debugPrint('⚠️ Error NDEF intento 1: $e — reintentando en 300ms...');
      }
      // Intento 2 con pequeña pausa (permite que Android NFC stack se resetee)
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await ndef.write(message: minimalMsg);
        debugPrint('✅ TAG borrado como NDEF intento 2 ("0")');
        return true;
      } catch (e) {
        debugPrint('⚠️ Error NDEF intento 2: $e');
      }
    } else {
      debugPrint('⚠️ TAG NDEF de solo lectura — no se puede borrar');
      return false;
    }
  }

  // 2. Intentar como NdefFormatable (tag sin NDEF mapping)
  final ndefFormatable = NdefFormatableAndroid.from(tag);
  debugPrint('🔍 NdefFormatable.from(tag): ${ndefFormatable != null ? "OK" : "null"}');
  if (ndefFormatable != null) {
    try {
      await ndefFormatable.format(minimalMsg);
      debugPrint('✅ TAG formateado y borrado (NdefFormatable)');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error al formatear NdefFormatable: $e');
    }
  }

  // 3. Mifare Classic raw — SOLO como último recurso y de forma segura:
  //    Escribir el payload NDEF ("0") en los bloques de datos conservando
  //    el TLV header de NDEF intacto (sector 1 bloque 4).
  //    NO se zerean los bloques — se escribe el mensaje NDEF serializado correctamente.
  final mifareClassic = MifareClassicAndroid.from(tag);
  debugPrint('🔍 MifareClassic.from(tag): ${mifareClassic != null ? "OK" : "null"}');
  if (mifareClassic != null) {
    try {
      debugPrint('📝 Intentando borrado MifareClassic raw con NDEF payload válido...');
      final key = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

      // Serializar el mensaje NDEF correctamente con TLV wrapper
      // Formato: 0x03 [length] [ndef payload] 0xFE
      final ndefPayloadBytes = _serializeNdefMessage(minimalMsg);
      debugPrint('   Payload NDEF serializado: ${ndefPayloadBytes.length} bytes');

      // Escribir solo en sector 1 bloques 0-2 (donde NDEF mapping pone los datos en MC4K)
      // Sector 1 = bloques 4, 5, 6 (bloque 7 = trailer, no tocar)
      await mifareClassic.authenticateSectorWithKeyA(sectorIndex: 1, key: key);

      int offset = 0;
      for (var blockInSector = 0; blockInSector <= 2; blockInSector++) {
        final blockIndex = 4 + blockInSector;
        final blockData = Uint8List(16);
        final end = (offset + 16 < ndefPayloadBytes.length) ? offset + 16 : ndefPayloadBytes.length;
        if (offset < ndefPayloadBytes.length) {
          blockData.setRange(0, end - offset, ndefPayloadBytes, offset);
        }
        await mifareClassic.writeBlock(blockIndex: blockIndex, data: blockData);
        offset += 16;
        debugPrint('   Bloque $blockIndex escrito');
      }

      debugPrint('✅ TAG borrado por MifareClassic raw (NDEF payload intacto)');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error borrado MifareClassic raw: $e');
    }
  }

  debugPrint('❌ No se pudo borrar el TAG — ningún método disponible');
  return false;
}

/// Serializa un NdefMessage al formato TLV usado en Mifare Classic NDEF mapping.
/// Formato: 0x03 [len] [records...] 0xFE
Uint8List _serializeNdefMessage(NdefMessage message) {
  // Serializar cada record manualmente
  final recordBytes = <int>[];
  for (final record in message.records) {
    // NDEF Short Record: MB=1, ME=1, SR=1, TNF=wellKnown(0x01)
    const tnf = 0x01;
    const flags = 0xD1; // MB | ME | SR | TNF=wellKnown
    recordBytes.add(flags);
    recordBytes.add(record.type.length);        // Type length
    recordBytes.add(record.payload.length);     // Payload length (short record = 1 byte)
    recordBytes.addAll(record.type);
    recordBytes.addAll(record.payload);
  }
  // TLV wrapper: T=0x03, L=[length], V=[records], T=0xFE (terminator)
  return Uint8List.fromList([0x03, recordBytes.length, ...recordBytes, 0xFE]);
}

/// Crea un mensaje NDEF mínimo con contenido "0"
/// (Android no permite mensajes completamente vacíos)
NdefMessage _createMinimalNdefMessage() {
  const clearContent = '0';
  const languageCode = 'en';
  final languageCodeBytes = utf8.encode(languageCode);
  final textBytes = utf8.encode(clearContent);
  final statusByte = languageCodeBytes.length;
  final payload = Uint8List.fromList([statusByte, ...languageCodeBytes, ...textBytes]);
  final record = NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList([84]), // 'T' para Text
    identifier: Uint8List(0),
    payload: payload,
  );
  return NdefMessage(records: [record]);
}

/// Guarda la información del TAG en el historial persistente (SQLite)
Future<void> _saveTagToHistory(String tagId, String tagType, int usedSpace) async {
  if (tagId.isEmpty) return;

  // Calcular el espacio total basado en el tipo de tag
  int totalSpace = 0;
  if (tagType.contains('DESFire') || tagType.contains('8K')) {
    totalSpace = 8192; // 8KB
  } else if (tagType.contains('4K')) {
    totalSpace = 4096; // 4KB
  } else if (tagType.contains('1K')) {
    totalSpace = 1024; // 1KB
  } else {
    totalSpace = 1024; // Por defecto 1KB
  }

  // NOTA: No cerrar db manualmente — sqflite maneja el pool automáticamente.
  // Cerrar aquí causa database_closed en _saveTagToHistory que corre concurrente (sin await).
  try {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        debugPrint('❌ No se pudo acceder al almacenamiento externo');
        return;
      }
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final String dbPath = path.join(
      '${baseDir.path}/ClickPalmData',
      'clickpalm_database.db',
    );

    final Database db = await openDatabase(dbPath);
    final now = DateTime.now().toUtc();

    final List<Map<String, dynamic>> existing = await db.query(
      'Nfc_tags_history',
      where: 'Tag_id = ?',
      whereArgs: [tagId],
    );

    if (existing.isNotEmpty) {
      final int currentReadCount = existing.first['Read_count'] as int;
      await db.update(
        'Nfc_tags_history',
        {
          'Last_read': now.toIso8601String(),
          'Read_count': currentReadCount + 1,
          'Tag_type': tagType,
          'Total_space': totalSpace,
          'Used_space': usedSpace,
        },
        where: 'Tag_id = ?',
        whereArgs: [tagId],
      );
      debugPrint('📝 TAG actualizado en historial: $tagId (lecturas: ${currentReadCount + 1}, espacio: $usedSpace/$totalSpace bytes)');
    } else {
      await db.insert(
        'Nfc_tags_history',
        {
          'Tag_id': tagId,
          'Tag_type': tagType,
          'Total_space': totalSpace,
          'Used_space': usedSpace,
          'Last_read': now.toIso8601String(),
          'Read_count': 1,
          'Created_at': now.toIso8601String(),
        },
      );
      debugPrint('📝 Nuevo TAG agregado al historial: $tagId (espacio: $usedSpace/$totalSpace bytes)');
    }

    final List<Map<String, dynamic>> allTags = await db.query(
      'Nfc_tags_history',
      orderBy: 'Last_read DESC',
    );

    if (allTags.length > 50) {
      final tagsToDelete = allTags.skip(50).toList();
      for (var tag in tagsToDelete) {
        await db.delete(
          'Nfc_tags_history',
          where: 'Id_nfc_tag = ?',
          whereArgs: [tag['Id_nfc_tag']],
        );
      }
      debugPrint('🧹 Limpiados ${tagsToDelete.length} TAGs antiguos del historial');
    }
  } catch (e) {
    debugPrint('❌ Error guardando TAG en historial SQLite: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
