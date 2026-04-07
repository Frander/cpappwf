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
import 'package:sqflite/sqflite.dart';

/// Escribe datos en un tag NFC
Future<bool> writeNFCTag(
  BuildContext context,
  String dataToWrite,
) async {
  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
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
        // === VALIDACIÓN DE TIPO DE PRODUCTO PARA TAG-WRITER ===
        // Obtener el RFID del tag ANTES de cualquier escritura
        String tagRfid = '';
        try {
          final androidTag = NfcTagAndroid.from(tag);
          if (androidTag != null && androidTag.id.isNotEmpty) {
            tagRfid = androidTag.id
                .map((byte) => byte.toRadixString(16).toUpperCase().padLeft(2, '0'))
                .join('');
            debugPrint('📱 RFID del tag detectado: $tagRfid');
          }
        } catch (rfidError) {
          debugPrint('⚠️ No se pudo obtener RFID: $rfidError');
        }

        // Verificar si se requiere validación de tipo de producto
        if (tagRfid.isNotEmpty) {
          final currentActivity = FFAppState().currentActivity;
          final activityStatusList = getJsonField(currentActivity, r'''$.activity_status''') as List?;

          if (activityStatusList != null) {
            for (var statusItem in activityStatusList) {
              final typeStatus = getJsonField(statusItem, r'''$.type_status''')?.toString() ?? '';
              final defaultStatusStr = getJsonField(statusItem, r'''$.default_status''')?.toString() ?? '';

              // === VALIDACIÓN PARA TAG-WRITER ===
              if (typeStatus == 'tag-writer' && defaultStatusStr.contains('=TYPE_PRODUCT_DEFAULT:')) {
                debugPrint('🔍 TAG-WRITER: Validación de tipo de producto requerida');

                // Extraer el tipo de producto requerido
                final regex = RegExp(r'=TYPE_PRODUCT_DEFAULT:([^;}\s]+)');
                final match = regex.firstMatch(defaultStatusStr);

                if (match != null && match.groupCount >= 1) {
                  final requiredProductType = match.group(1)!.trim();
                  debugPrint('   Tipo requerido: $requiredProductType');

                  // Buscar el producto en SQLite por RFID
                  try {
                    final dbPath = FFAppState().pathDatabase;
                    if (dbPath.isNotEmpty) {
                      final database = await openDatabase(dbPath);

                      final productResults = await database.rawQuery('''
                        SELECT Type_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1
                      ''', [tagRfid]);

                      await database.close();

                      if (productResults.isEmpty) {
                        debugPrint('❌ RFID no encontrado en Products: $tagRfid');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:PRODUCTO_NO_ENCONTRADO:$requiredProductType';
                        });
                        completer.complete(false);
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      final productType = productResults.first['Type_product'] as String?;
                      final productName = productResults.first['Name_product'] as String?;

                      debugPrint('✅ Producto encontrado: $productName (Tipo: $productType)');
                      FFAppState().nfcLastProductName = productName ?? '';

                      if (productType != requiredProductType) {
                        debugPrint('❌ Tipo de producto no coincide');
                        debugPrint('   Esperado: $requiredProductType');
                        debugPrint('   Encontrado: $productType');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:TIPO_INCORRECTO:$requiredProductType:${productType ?? "Sin tipo"}';
                        });
                        completer.complete(false);
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      debugPrint('✅ TAG-WRITER: Validación de tipo exitosa');
                    }
                  } catch (dbError) {
                    debugPrint('❌ Error validando producto: $dbError');
                  }
                }
                break;
              }

              // === VALIDACIÓN PARA TAG-TRANSFER (TAG DE DESTINO) ===
              if (typeStatus == 'tag-transfer' && defaultStatusStr.contains('TYPE_PRODUCT_FINISH:')) {
                debugPrint('🔍 TAG-TRANSFER: Validación de tag de destino requerida');

                // Extraer el tipo de producto de destino requerido
                // Captura todo hasta ; o } (permitiendo espacios en el nombre)
                final regex = RegExp(r'TYPE_PRODUCT_FINISH:([^;}]+)');
                final match = regex.firstMatch(defaultStatusStr);

                if (match != null && match.groupCount >= 1) {
                  final requiredProductType = match.group(1)!.trim();
                  debugPrint('   Tipo de destino requerido: $requiredProductType');

                  // Buscar el producto en SQLite por RFID
                  try {
                    final dbPath = FFAppState().pathDatabase;
                    if (dbPath.isNotEmpty) {
                      final database = await openDatabase(dbPath);

                      final productResults = await database.rawQuery('''
                        SELECT Type_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1
                      ''', [tagRfid]);

                      await database.close();

                      if (productResults.isEmpty) {
                        debugPrint('❌ TAG-TRANSFER: RFID de destino no encontrado: $tagRfid');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:PRODUCTO_NO_ENCONTRADO:$requiredProductType';
                        });
                        completer.complete(false);
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      final productType = productResults.first['Type_product'] as String?;
                      final productName = productResults.first['Name_product'] as String?;

                      debugPrint('✅ TAG-TRANSFER: Producto destino encontrado: $productName (Tipo: $productType)');
                      FFAppState().nfcLastProductName = productName ?? '';

                      if (productType != requiredProductType) {
                        debugPrint('❌ TAG-TRANSFER: Tipo de producto de destino no coincide');
                        debugPrint('   Esperado: $requiredProductType');
                        debugPrint('   Encontrado: $productType');
                        FFAppState().update(() {
                          FFAppState().nfcRead = 'ERROR:TIPO_INCORRECTO:$requiredProductType:${productType ?? "Sin tipo"}';
                        });
                        completer.complete(false);
                        await NfcManager.instance.stopSession();
                        return;
                      }

                      debugPrint('✅ TAG-TRANSFER: Validación de tipo de destino exitosa');
                    }
                  } catch (dbError) {
                    debugPrint('❌ TAG-TRANSFER: Error validando producto de destino: $dbError');
                  }
                }
                break;
              }
            }
          }
        }

        String finalContent = dataToWrite;
        String existingContent = '';
        Map<String, dynamic>? nfcJson;

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
                        debugPrint('📖 Contenido existente encontrado: ${existingContent.substring(0, existingContent.length > 100 ? 100 : existingContent.length)}...');

                        // Si el contenido existente es solo "0" (tag vacío), ignorarlo
                        if (existingContent.trim() == '0') {
                          debugPrint('Tag vacío detectado ("0"), creando nuevo JSON');
                          existingContent = '';
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

          // === DETECTAR TIPO DE OPERACIÓN ===
          // Si dataToWrite ya es un JSON completo válido (tag-transfer),
          // escribirlo directamente sin modificar
          if (isNewJsonFormat(dataToWrite)) {
            debugPrint('🔄 TAG-TRANSFER: JSON completo detectado, escribiendo directamente');
            finalContent = dataToWrite;
          } else {
            // === PROCESAR FORMATO ANTIGUO (TAG-WRITER) ===
            // Parsear el dataToWrite para extraer los campos necesarios
            // Formato esperado: {DH:2025_11_06_13:20:00;OP:4214;VISITS:50;RESULTS:25;HE:204}
            int? operatorId;
            int? visits;
            int? results;
            int? headquarterId;
            DateTime? dateTime;

            debugPrint('📝 TAG-WRITER: Parseando dataToWrite: $dataToWrite');

          final recordRegex = RegExp(r'\{([^}]+)\}');
          final recordMatch = recordRegex.firstMatch(dataToWrite);

          if (recordMatch != null) {
            final recordContent = recordMatch.group(1);
            if (recordContent != null) {
              debugPrint('📋 Contenido del registro: $recordContent');
              final fields = recordContent.split(';');
              for (var field in fields) {
                final parts = field.split(':');
                if (parts.length >= 2) {
                  final key = parts[0].trim();
                  final value = parts.sublist(1).join(':').trim();

                  switch (key) {
                    case 'DH':
                      try {
                        final dateStr = value.replaceAll('_', '-');
                        final dateParts = dateStr.split('-');
                        if (dateParts.length >= 4) {
                          final year = int.parse(dateParts[0]);
                          final month = int.parse(dateParts[1]);
                          final day = int.parse(dateParts[2]);
                          final timeParts = dateParts[3].split(':');
                          final hour = int.parse(timeParts[0]);
                          final minute = int.parse(timeParts[1]);
                          final second = int.parse(timeParts[2]);
                          dateTime = DateTime(year, month, day, hour, minute, second);
                        }
                      } catch (e) {
                        dateTime = DateTime.now();
                      }
                      break;
                    case 'OP':
                      operatorId = int.tryParse(value);
                      break;
                    case 'VISITS':
                      visits = int.tryParse(value);
                      break;
                    case 'RESULTS':
                      results = int.tryParse(value);
                      break;
                    case 'HE':
                      headquarterId = int.tryParse(value);
                      break;
                  }
                }
              }
            }
          }

          debugPrint('📊 Valores parseados: OP=$operatorId, VISITS=$visits, RESULTS=$results, HE=$headquarterId');

          // Verificar si tenemos la información del producto desde la validación anterior
          int? productId;
          String? productName;
          String? productRfid = tagRfid;

          if (tagRfid.isNotEmpty) {
            try {
              final dbPath = FFAppState().pathDatabase;
              if (dbPath.isNotEmpty) {
                final database = await openDatabase(dbPath);
                final productResults = await database.rawQuery('''
                  SELECT Id_product, Name_product, Type_product FROM Products WHERE Rfid = ? LIMIT 1
                ''', [tagRfid]);
                await database.close();

                if (productResults.isNotEmpty) {
                  productId = productResults.first['Id_product'] as int?;
                  productName = productResults.first['Name_product'] as String?;
                  debugPrint('📦 Producto encontrado: $productName (ID: $productId)');
                }
              }
            } catch (dbError) {
              debugPrint('⚠️ Error obteniendo información del producto: $dbError');
            }
          }

          // Determinar el formato del contenido existente
          if (existingContent.isNotEmpty) {
            if (isNewJsonFormat(existingContent)) {
              // Formato JSON nuevo
              debugPrint('✅ Formato JSON detectado, parseando...');
              nfcJson = parseNfcJson(existingContent);

              if (nfcJson != null) {
                // Actualizar Read_info con nueva fecha y datos del producto
                if (productId != null && productName != null && productRfid != null) {
                  nfcJson = updateReadInfo(
                    nfcJson,
                    idProduct: productId,
                    rfid: productRfid,
                    nameProduct: productName,
                  );
                  debugPrint('📝 Read_info actualizado');
                }

                // Agregar nueva visita
                if (operatorId != null && visits != null && results != null && headquarterId != null) {
                  nfcJson = addVisitToNfcJson(
                    nfcJson,
                    operatorId: operatorId,
                    visits: visits,
                    results: results,
                    headquarterId: headquarterId,
                    dateTime: dateTime,
                  );
                  debugPrint('✅ Nueva visita agregada al JSON');
                }

                finalContent = nfcJsonToString(nfcJson);
              }
            } else if (isOldFormat(existingContent)) {
              // Formato antiguo, migrar a JSON
              debugPrint('🔄 Formato antiguo detectado, migrando a JSON...');

              if (productId != null && productName != null && productRfid != null) {
                nfcJson = migrateOldFormatToJson(
                  existingContent,
                  idProduct: productId,
                  rfid: productRfid,
                  nameProduct: productName,
                );

                if (nfcJson != null) {
                  // Agregar nueva visita al JSON migrado
                  if (operatorId != null && visits != null && results != null && headquarterId != null) {
                    nfcJson = addVisitToNfcJson(
                      nfcJson,
                      operatorId: operatorId,
                      visits: visits,
                      results: results,
                      headquarterId: headquarterId,
                      dateTime: dateTime,
                    );
                  }

                  finalContent = nfcJsonToString(nfcJson);
                  debugPrint('✅ Migración completada, JSON generado');
                }
              }
            } else {
              debugPrint('⚠️ Formato desconocido, usando contenido como está');
              finalContent = '$existingContent,$dataToWrite';
            }
          } else {
            // Tag vacío, crear JSON inicial
            debugPrint('🆕 Tag vacío, creando JSON inicial...');

            if (productId != null && productName != null && productRfid != null) {
              nfcJson = buildInitialNfcJson(
                idProduct: productId,
                rfid: productRfid,
                nameProduct: productName,
              );

              // Agregar primera visita
              if (operatorId != null && visits != null && results != null && headquarterId != null) {
                nfcJson = addVisitToNfcJson(
                  nfcJson,
                  operatorId: operatorId,
                  visits: visits,
                  results: results,
                  headquarterId: headquarterId,
                  dateTime: dateTime,
                );
              }

              finalContent = nfcJsonToString(nfcJson);
              debugPrint('✅ JSON inicial creado');
            }
          }
          } // Fin del else para TAG-WRITER
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
