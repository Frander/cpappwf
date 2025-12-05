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
import 'package:nfc_manager/nfc_manager_android.dart' show IsoDepAndroid;
import 'package:ndef_record/ndef_record.dart';
import 'dart:typed_data';

/// Escribe datos en un tag NFC
Future<bool> writeNFCTag(
  BuildContext context,
  String dataToWrite,
) async {
  // Verificar si NFC está disponible
  bool nfcAvailable = await NfcManager.instance.isAvailable();
  if (!nfcAvailable) {
    return false;
  }

  Completer<bool> completer = Completer<bool>();

  // Variables para controlar el flujo de múltiples tags
  bool needsAnotherTag = false;
  String contentForNewTag = dataToWrite;

  // Iniciar sesión NFC para escritura
  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
    },
    onDiscovered: (NfcTag tag) async {
      try {
        String finalContent = dataToWrite;
        String existingContent = '';

        // Si ya determinamos que necesitamos otro tag, escribir solo el nuevo contenido
        if (needsAnotherTag) {
          debugPrint('Escribiendo en nuevo tag: Solo el contenido nuevo');
          finalContent = contentForNewTag;
        } else {
          // Intentar leer el contenido existente del tag
          // Esto funciona para tags NDEF: MifareClassic formateado, DESFire formateado, etc.
          try {
            final ndef = Ndef.from(tag);
            if (ndef != null && ndef.cachedMessage != null) {
              final records = ndef.cachedMessage!.records;

              if (records.isNotEmpty) {
                // El primer registro suele ser el de texto
                final firstRecord = records.first;
                final payload = firstRecord.payload;

                if (payload.isNotEmpty) {
                  try {
                    // Decodificar Text Record manualmente
                    // Formato: [status byte][language code][texto]
                    final statusByte = payload[0];
                    final languageCodeLength = statusByte & 0x3F; // bits 0-5

                    if (payload.length > languageCodeLength + 1) {
                      final textBytes = payload.sublist(1 + languageCodeLength);
                      existingContent = utf8.decode(textBytes);

                      if (existingContent.isNotEmpty) {
                        // Si el contenido existente es solo "0" (tag vacío), no concatenar
                        if (existingContent.trim() == '0') {
                          debugPrint(
                              'Tag vacío detectado ("0"), escribiendo solo el nuevo contenido');
                          finalContent = dataToWrite;
                        } else {
                          // Agregar coma separadora y el nuevo contenido
                          finalContent = '$existingContent,$dataToWrite';
                          debugPrint(
                              'Contenido existente encontrado: $existingContent');
                          debugPrint(
                              'Intentando agregar nuevo registro al tag');
                        }
                      }
                    }
                  } catch (decodeError) {
                    debugPrint('Error decodificando registro: $decodeError');
                  }
                }
              }
            }
          } catch (readError) {
            debugPrint(
                'No se pudo leer contenido existente (tag nuevo o vacío): $readError');
            // Si falla la lectura, continuar con solo el nuevo contenido
          }
        }

        // VALIDAR ESPACIO DISPONIBLE
        final finalContentBytes = utf8.encode(finalContent);
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
          // Mifare DESFire: Capacidad típica 2KB-8KB, pero usar límite conservador
          // hasta confirmar el tamaño real del tag
          maxCapacity =
              2048; // 2KB por defecto, conservador para DESFire más pequeños
          debugPrint(
              'Tag DESFire (IsoDep) detectado con capacidad estimada: $maxCapacity bytes');
        } else if (mifareClassic != null) {
          // Mifare Classic 1K: Limitado a ~240 bytes (sectores 0-6) para evitar timeout
          // Capacidad real: 752 bytes (47 bloques), pero escribir todo causa TagLostException
          maxCapacity = 240;
          debugPrint(
              'Tag Mifare Classic 1K con capacidad limitada: $maxCapacity bytes (para evitar timeout)');
        }

        // Verificar si hay espacio suficiente
        if (maxCapacity > 0 && requiredBytes > maxCapacity) {
          debugPrint(
              'ESPACIO INSUFICIENTE: Se requieren $requiredBytes bytes, pero solo hay $maxCapacity bytes disponibles');
          debugPrint('Contenido existente: ${existingContent.length} bytes');
          debugPrint('Nuevo registro: ${dataToWrite.length} bytes');

          // Si es el primer tag (tiene contenido existente), solicitar otro tag
          if (existingContent.isNotEmpty && !needsAnotherTag) {
            debugPrint(
                '📢 SOLICITANDO OTRO TAG: El contenido no cabe en este tag');
            debugPrint(
                '   ℹ️ El contenido existente se conservará en el tag actual');
            debugPrint(
                '   ℹ️ Acerque un nuevo tag para escribir el nuevo contenido');

            // Marcar que necesitamos otro tag
            needsAnotherTag = true;
            contentForNewTag = dataToWrite;

            // Actualizar AppState para mostrar mensaje al usuario
            FFAppState().update(() {
              FFAppState().nfcRead = 'SOLICITAR_OTRO_TAG';
            });

            // NO cerrar la sesión - esperar el siguiente tag
            debugPrint('⏳ Esperando nuevo tag...');
            return; // Salir del callback pero mantener la sesión activa
          } else {
            // Si es un tag nuevo o el segundo tag también está lleno
            debugPrint(
                '❌ ERROR: El contenido es demasiado grande incluso para un tag nuevo');

            // Actualizar AppState con mensaje de error
            FFAppState().update(() {
              FFAppState().nfcRead =
                  'ERROR:ESPACIO_INSUFICIENTE:$requiredBytes/$maxCapacity';
            });

            completer.complete(false);
            await NfcManager.instance.stopSession();
            return;
          }
        }

        debugPrint(
            'Espacio OK: $requiredBytes bytes de $maxCapacity disponibles');

        // Crear payload del Text Record según estándar NDEF
        // Formato: [status byte][language code][texto]
        const languageCode = 'en';
        final languageCodeBytes = utf8.encode(languageCode);
        final textBytes = utf8.encode(finalContent);

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
          // Intentar formatear el tag como NDEF
          // Esto funciona para tags vírgenes: MifareClassic, DESFire, etc.
          final tagTypeName = isoDep != null
              ? 'DESFire'
              : (mifareClassic != null ? 'MifareClassic' : 'desconocido');
          debugPrint(
              'Tag no soporta NDEF ($tagTypeName), intentando formatear...');
          final ndefFormatable = NdefFormatableAndroid.from(tag);

          if (ndefFormatable != null) {
            try {
              await ndefFormatable.format(message);
              debugPrint(
                  'Tag $tagTypeName formateado y escrito exitosamente como NDEF');
              debugPrint('Contenido completo: $finalContent');

              // Actualizar AppState
              FFAppState().update(() {
                FFAppState().nfcRead = finalContent;
              });

              completer.complete(true);
              await NfcManager.instance.stopSession();
              return;
            } catch (formatError) {
              debugPrint('Error al formatear tag: $formatError');
              // Continuar para intentar otros métodos
            }
          }

          // Si no se puede formatear, intentar escribir en MifareClassic
          // (mifareClassic ya fue declarado arriba)
          if (mifareClassic != null) {
            try {
              debugPrint('Intentando escribir en tag MifareClassic 1K...');

              // Convertir el contenido final a bytes
              final contentBytes = utf8.encode(finalContent);
              final totalBytes = contentBytes.length;
              debugPrint('Total de bytes a escribir: $totalBytes');

              // Clave default de Mifare
              final key =
                  Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

              // Estructura de escritura en Mifare Classic 1K (optimizado):
              // Sector 0: bloques 1-2 (bloque 0 = fabricante, bloque 3 = auth)
              // Sectores 1-6: bloques 0-2 de cada sector (bloque 3 = auth)
              // Total: 2 + (6 * 3) = 20 bloques × 16 bytes = ~320 bytes
              // Limitado a ~240 bytes de datos para evitar TagLostException

              final blocksToWrite = <int, Uint8List>{};
              int byteIndex = 0;

              // Sector 0: bloques 1 y 2 (saltar bloque 0 que es fabricante)
              for (var blockInSector = 1; blockInSector <= 2; blockInSector++) {
                if (byteIndex >= totalBytes) break;

                final blockIndex = blockInSector; // Sector 0: bloques 1, 2
                final end =
                    (byteIndex + 16 < totalBytes) ? byteIndex + 16 : totalBytes;
                final blockData = contentBytes.sublist(byteIndex, end);

                // Rellenar con ceros si es necesario
                final paddedBlock = Uint8List(16);
                paddedBlock.setRange(0, blockData.length, blockData);
                blocksToWrite[blockIndex] = paddedBlock;

                byteIndex = end;
              }

              // Sectores 1-6: bloques 0, 1, 2 de cada sector (reducido para evitar timeout)
              // Esto da ~240 bytes útiles, suficiente para la mayoría de casos
              for (var sector = 1; sector <= 6; sector++) {
                if (byteIndex >= totalBytes) break;

                for (var blockInSector = 0;
                    blockInSector <= 2;
                    blockInSector++) {
                  if (byteIndex >= totalBytes) break;

                  final blockIndex =
                      (sector * 4) + blockInSector; // 4 bloques por sector
                  final end = (byteIndex + 16 < totalBytes)
                      ? byteIndex + 16
                      : totalBytes;
                  final blockData = contentBytes.sublist(byteIndex, end);

                  // Rellenar con ceros si es necesario
                  final paddedBlock = Uint8List(16);
                  paddedBlock.setRange(0, blockData.length, blockData);
                  blocksToWrite[blockIndex] = paddedBlock;

                  byteIndex = end;
                }
              }

              // Validar que el contenido cabe en los sectores disponibles
              if (byteIndex < totalBytes) {
                final remainingBytes = totalBytes - byteIndex;
                debugPrint(
                    'ADVERTENCIA: Contenido muy largo. $remainingBytes bytes no serán escritos.');
                debugPrint(
                    'Límite actual: ~240 bytes para evitar timeout del tag');

                FFAppState().update(() {
                  FFAppState().nfcRead =
                      'ERROR:CONTENIDO_MUY_LARGO:$totalBytes/240';
                });

                completer.complete(false);
                await NfcManager.instance.stopSession();
                return;
              }

              debugPrint('Bloques a escribir: ${blocksToWrite.length}');

              // Escribir en los bloques agrupando por sector para autenticación
              int blocksWritten = 0;
              int currentSector = -1;

              for (var entry in blocksToWrite.entries) {
                final blockIndex = entry.key;
                final data = entry.value;
                final sector = blockIndex ~/ 4; // Calcular sector

                // Autenticar sector si cambiamos de sector
                if (sector != currentSector) {
                  try {
                    await mifareClassic.authenticateSectorWithKeyA(
                      sectorIndex: sector,
                      key: key,
                    );
                    currentSector = sector;
                    debugPrint('Sector $sector autenticado');
                  } catch (authError) {
                    debugPrint(
                        'Error al autenticar sector $sector: $authError');
                    // Intentar con KeyB
                    try {
                      await mifareClassic.authenticateSectorWithKeyB(
                        sectorIndex: sector,
                        key: key,
                      );
                      currentSector = sector;
                      debugPrint('Sector $sector autenticado con KeyB');
                    } catch (authErrorB) {
                      debugPrint(
                          'Error al autenticar sector $sector con KeyB: $authErrorB');
                      continue; // Saltar este sector si no se puede autenticar
                    }
                  }
                }

                // Escribir bloque
                try {
                  await mifareClassic.writeBlock(
                    blockIndex: blockIndex,
                    data: data,
                  );
                  blocksWritten++;
                } catch (writeError) {
                  debugPrint(
                      'Error al escribir bloque $blockIndex: $writeError');
                }
              }

              debugPrint(
                  'MifareClassic: Escritos $blocksWritten bloques (${blocksWritten * 16} bytes)');
              debugPrint('Contenido completo: $finalContent');

              // Actualizar AppState
              FFAppState().update(() {
                FFAppState().nfcRead = finalContent;
              });

              completer.complete(true);
              await NfcManager.instance.stopSession();
              return;
            } catch (mifareError) {
              debugPrint('Error al escribir en MifareClassic: $mifareError');
            }
          }

          // Nota: Los tags DESFire vírgenes serán formateados automáticamente por NdefFormatable arriba
          // Los tags DESFire ya formateados con NDEF serán escritos por el código NDEF estándar
          // Si llegamos aquí con un DESFire, significa que no pudo ser formateado/escrito
          if (isoDep != null) {
            debugPrint('Tag DESFire detectado pero no se pudo escribir.');
            debugPrint(
                'Asegúrese de que el tag esté vacío o formateado como NDEF.');
          }

          // Si llegamos aquí, el tag realmente no es compatible
          debugPrint(
              'Tag no es compatible: No soporta NDEF, NdefFormatable, MifareClassic ni DESFire');
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        if (!ndefWriter.isWritable) {
          debugPrint('Tag no es escribible (protegido contra escritura)');
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        try {
          // Escribir usando NDEF estándar
          await ndefWriter.write(message: message);
          debugPrint('Mensaje NDEF escrito exitosamente');
          debugPrint('Contenido completo: $finalContent');

          // Actualizar AppState con el contenido completo
          FFAppState().update(() {
            FFAppState().nfcRead = finalContent;
          });

          completer.complete(true);
        } catch (writeError) {
          debugPrint('Error al escribir NDEF: $writeError');

          // Detectar si el error es por tag alejado (IOException)
          final errorMsg = writeError.toString().toLowerCase();
          if (errorMsg.contains('ioexception') ||
              errorMsg.contains('tag was lost')) {
            // Tag se alejó durante la escritura
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:TAG_ALEJADO';
            });
          } else if (errorMsg.contains('readonly') ||
              errorMsg.contains('not writable')) {
            // Tag protegido contra escritura
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:TAG_PROTEGIDO';
            });
          } else {
            // Otro tipo de error
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:ESCRITURA_FALLIDA';
            });
          }

          completer.complete(false);
        }

        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('Error general escribiendo NFC: $e');
        completer.complete(false);
        await NfcManager.instance.stopSession();
      }
    },
  );

  return completer.future;
}
