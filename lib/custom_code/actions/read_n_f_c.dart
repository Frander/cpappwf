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
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<String> readNFC(BuildContext context, {bool autoClose = true}) async {
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

              // Leer sector 0: bloques 1-2
              try {
                await mifareClassic.authenticateSectorWithKeyA(
                  sectorIndex: 0,
                  key: key,
                );

                for (var block = 1; block <= 2; block++) {
                  final blockData =
                      await mifareClassic.readBlock(blockIndex: block);
                  allBytes.addAll(blockData);
                }
              } catch (e) {
                debugPrint('Error leyendo sector 0: $e');
              }

              // Leer solo sectores 1-6 (reducido para evitar timeout)
              // Esto da ~240 bytes de datos útiles, suficiente para la mayoría de casos
              bool foundEnd = false;
              for (var sector = 1; sector <= 6; sector++) {
                try {
                  await mifareClassic.authenticateSectorWithKeyA(
                    sectorIndex: sector,
                    key: key,
                  );

                  for (var blockInSector = 0; blockInSector <= 2; blockInSector++) {
                    final blockIndex = (sector * 4) + blockInSector;
                    final blockData =
                        await mifareClassic.readBlock(blockIndex: blockIndex);
                    allBytes.addAll(blockData);

                    // Verificar si encontramos el fin del mensaje (múltiples 0x00)
                    if (blockData.where((byte) => byte == 0).length > 10) {
                      foundEnd = true;
                      break;
                    }
                  }

                  if (foundEnd) {
                    debugPrint('Fin de datos detectado en sector $sector');
                    break;
                  }
                } catch (e) {
                  debugPrint('Error leyendo sector $sector: $e');
                  break; // Dejar de leer si falla un sector
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

        // Actualizar el AppState con los datos leídos
        FFAppState().update(() {
          FFAppState().nfcRead = tagData;
        });

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

  try {
    // Obtener la ruta de la base de datos
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      debugPrint('❌ No se pudo acceder al almacenamiento externo');
      return;
    }

    final String dbPath = path.join(
      '${externalDir.path}/ClickPalmData',
      'clickpalm_database.db',
    );

    // Abrir conexión a la base de datos
    final Database db = await openDatabase(dbPath);

    try {
      final now = DateTime.now().toUtc();

      // Verificar si el TAG ya existe
      final List<Map<String, dynamic>> existing = await db.query(
        'Nfc_tags_history',
        where: 'Tag_id = ?',
        whereArgs: [tagId],
      );

      if (existing.isNotEmpty) {
        // Actualizar TAG existente
        final int currentReadCount = existing.first['Read_count'] as int;
        await db.update(
          'Nfc_tags_history',
          {
            'Last_read': now.toIso8601String(),
            'Read_count': currentReadCount + 1,
            'Tag_type': tagType, // Actualizar tipo por si cambió
            'Total_space': totalSpace,
            'Used_space': usedSpace,
          },
          where: 'Tag_id = ?',
          whereArgs: [tagId],
        );
        debugPrint('📝 TAG actualizado en historial: $tagId (lecturas: ${currentReadCount + 1}, espacio: $usedSpace/$totalSpace bytes)');
      } else {
        // Insertar nuevo TAG
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

      // Opcional: Limitar a los últimos 50 TAGs (eliminar los más antiguos)
      final List<Map<String, dynamic>> allTags = await db.query(
        'Nfc_tags_history',
        orderBy: 'Last_read DESC',
      );

      if (allTags.length > 50) {
        // Eliminar los tags más antiguos
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
    } finally {
      await db.close();
    }
  } catch (e) {
    debugPrint('❌ Error guardando TAG en historial SQLite: $e');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
