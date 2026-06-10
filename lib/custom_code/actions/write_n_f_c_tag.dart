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
import 'package:sqflite/sqflite.dart';
import '/backend/sqlite/global_db_singleton.dart';

/// Escribe datos en un tag NFC.
/// [visitDelta] — delta pre-computado antes de abrir la sesión NFC (solo tag-writer).
/// Si se provee y el tag ya tiene contenido comprimido/multi-chunk, se hace
/// un append de string puro sin parseo JSON ni compresión durante la sesión.
Future<bool> writeNFCTag(
  BuildContext context,
  String dataToWrite, {
  String? visitDelta,
}) async {
  if (!Platforms.isMobile) return false; // NFC no disponible en desktop
  // Verificar si NFC está disponible y activado
  bool nfcReady = await checkNfcStatus(context, showAlert: true);
  if (!nfcReady) {
    return false;
  }

  Completer<bool> completer = Completer<bool>();

  // Variables para controlar el flujo de múltiples tags
  bool needsAnotherTag = false;

  // ── Pre-trabajo FUERA de la sesión NFC (minimiza el tiempo en campo) ──
  // (1)/(2) Conexión SQLite ya caliente vía GlobalDbSingleton (instancia única
  //     WAL que NUNCA se cierra): la validación de producto en sesión será una
  //     query directa, sin pagar openDatabase/WAL-init con el enlace ISO-DEP
  //     abierto (lo que alargaba el tiempo en campo y favorecía el IOException).
  Database? warmDb;
  try {
    warmDb = await GlobalDbSingleton().database;
  } catch (e) {
    debugPrint('⚠️ writeNFCTag: no se pudo pre-abrir SQLite: $e');
  }
  final Database? sharedDb = warmDb;

  // (3) Decodificación del contenido de ORIGEN precomputada fuera de la sesión:
  //     el merge en sesión ya no descomprime la fuente. (Solo se usa en el
  //     camino tag-transfer; para tag-writer queda sin uso, sin costo relevante.)
  final List<Map<String, dynamic>> preSrcRecords =
      decodeNfcRecords(dataToWrite);

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

                  // Buscar el producto en SQLite (conexión singleton ya caliente)
                  try {
                    if (sharedDb != null) {
                      final productResults = await sharedDb.rawQuery('''
                        SELECT Type_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1
                      ''', [tagRfid]);

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

                  // Buscar el producto en SQLite (conexión singleton ya caliente)
                  try {
                    if (sharedDb != null) {
                      final productResults = await sharedDb.rawQuery('''
                        SELECT Type_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1
                      ''', [tagRfid]);

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

        if (needsAnotherTag) {
          debugPrint('✏️ NUEVO TAG: tag virgen, procesando con pipeline completo...');
        }
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

          // ═══ FAST APPEND PATH (TAG-WRITER, writes 2+) ═══
          // El visitDelta fue pre-computado ANTES de abrir la sesión NFC.
          // Solo se hace concatenación de strings: cero parseo JSON, cero compresión.
          if (visitDelta != null &&
              visitDelta.isNotEmpty &&
              existingContent.isNotEmpty &&
              (isNfcCompressedFormat(existingContent) || isMultiChunkFormat(existingContent))) {
            finalContent = existingContent + kNfcChunkDelimiter + visitDelta;
            debugPrint('⚡ FAST APPEND: +${visitDelta.length} bytes, total ${finalContent.length} bytes');
            // Saltar directamente a VALIDAR ESPACIO
          } else {

          // ═══ DECODIFICAR existingContent si viene en formato comprimido/minificado ═══
          if (existingContent.isNotEmpty &&
              (isNfcCompressedFormat(existingContent) || isMultiChunkFormat(existingContent))) {
            final decoded = nfcDecode(existingContent);
            if (decoded != null) {
              existingContent = jsonEncode(decoded);
              debugPrint('🔓 existingContent decodificado: ${(decoded["Visits"] as List?)?.length ?? 0} visitas');
            }
          }

          // === DETECTAR TIPO DE OPERACIÓN ===
          // Si dataToWrite ya es un JSON completo válido (tag-transfer),
          // inyectar tag_from (RFID origen ya viene en el JSON), tag_to y US
          if (isNewJsonFormat(dataToWrite) || isJsonArrayFormat(dataToWrite)) {
            // ═══ TAG-TRANSFER: fusionar por RFID de origen ═══
            // El destino puede acumular VARIOS productos (uno por RFID de origen).
            // Identidad = Read_info.tag_from (RFID del tag de origen):
            //   • mismo origen    → se concatenan sus Visits en ese registro.
            //   • origen distinto → se AGREGA un registro nuevo (NO se reemplaza),
            //     preservando Read_info, Visits y status de cada producto.
            // Soporta destino y fuente como objeto único o como array.
            debugPrint('🔄 TAG-TRANSFER: fusionando por RFID de origen con destino');
            try {
              // Origen ya decodificado fuera de la sesión (preSrcRecords).
              final srcRecords = preSrcRecords;
              if (srcRecords.isEmpty) {
                finalContent = dataToWrite;
              } else {
                final destRecords = existingContent.isNotEmpty
                    ? decodeNfcRecords(existingContent)
                    : <Map<String, dynamic>>[];

                String originOf(Map<String, dynamic> rec) {
                  final ri = rec['Read_info'] as Map<String, dynamic>?;
                  final from = (ri?['tag_from'] as String? ?? '').trim();
                  if (from.isNotEmpty) return from;
                  return (ri?['RFID'] as String? ?? '').trim();
                }

                for (final src in srcRecords) {
                  // Inyectar tag_to / US / tag_from en cada registro de origen.
                  final ri = src['Read_info'] as Map<String, dynamic>?;
                  if (ri != null) {
                    ri['tag_to'] = tagRfid;
                    ri['US'] = FFAppState().userSelected.idUser;
                    if ((ri['tag_from'] as String? ?? '').isEmpty) {
                      ri['tag_from'] = ri['RFID'] ?? '';
                    }
                  }

                  final origin = originOf(src);
                  final idx = origin.isEmpty
                      ? -1
                      : destRecords.indexWhere((r) => originOf(r) == origin);

                  if (idx >= 0) {
                    // Mismo origen → concatenar Visits, refrescar Read_info/status.
                    final destVisits = List<dynamic>.from(
                        (destRecords[idx]['Visits'] as List?) ?? []);
                    final srcVisits = List<dynamic>.from(
                        (src['Visits'] as List?) ?? []);
                    destRecords[idx] = Map<String, dynamic>.from(src)
                      ..['Visits'] = [...destVisits, ...srcVisits];
                    debugPrint('✅ TAG-TRANSFER: mismo origen ($origin) → '
                        'Visits ${destVisits.length}+${srcVisits.length}');
                  } else {
                    // Origen distinto → registro nuevo (concatenar, NO reemplazar).
                    destRecords.add(src);
                    debugPrint('✅ TAG-TRANSFER: nuevo origen ($origin) → '
                        'registro agregado (total ${destRecords.length} producto(s))');
                  }
                }

                finalContent = nfcEncodeRecords(destRecords);
                debugPrint('📤 TAG-TRANSFER: destino con ${destRecords.length} '
                    'producto(s), ${finalContent.length} chars');
              }
              // Exponer el contenido escrito para que _startWriting() lo recupere
              FFAppState().update(() { FFAppState().nfcRead = finalContent; });
            } catch (e) {
              debugPrint('⚠️ Error en TAG-TRANSFER merge: $e');
              finalContent = dataToWrite;
            }
          } else {
            // === TAG-WRITER: Extraer campos desde visitDelta ===
            int? operatorId;
            int? visits;
            int? results;
            int? headquarterId;
            DateTime? dateTime;

            if (visitDelta != null && visitDelta.startsWith('V:')) {
              try {
                final delta = jsonDecode(visitDelta.substring(2)) as Map<String, dynamic>;
                operatorId = delta['o'] as int?;
                visits = delta['v'] as int?;
                results = delta['s'] as int?;
                headquarterId = delta['e'] as int?;
                final epoch = delta['h'] as int?;
                if (epoch != null) {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
                }
              } catch (e) {
                debugPrint('⚠️ Error parseando visitDelta: $e');
              }
            }

            debugPrint('📊 TAG-WRITER: OP=$operatorId, VISITS=$visits, RESULTS=$results, HE=$headquarterId');

          // Verificar si tenemos la información del producto desde la validación anterior
          int? productId;
          String? productName;
          String? productRfid = tagRfid;

          if (tagRfid.isNotEmpty) {
            try {
              if (sharedDb != null) {
                final productResults = await sharedDb.rawQuery('''
                  SELECT Id_product, Name_product, Type_product FROM Products WHERE Rfid = ? LIMIT 1
                ''', [tagRfid]);

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

          // Procesar contenido existente en formato JSON nuevo
          if (existingContent.isNotEmpty && isNewJsonFormat(existingContent)) {
            debugPrint('✅ Formato JSON detectado, parseando...');
            nfcJson = parseNfcJson(existingContent);

            if (nfcJson != null) {
              // Actualizar Read_info con nueva fecha y datos del producto
              if (productId != null && productName != null) {
                nfcJson = updateReadInfo(
                  nfcJson,
                  idProduct: productId,
                  rfid: productRfid,
                  nameProduct: productName,
                  tagFrom: '',
                  tagTo: tagRfid,
                  userId: FFAppState().userSelected.idUser,
                );
                debugPrint('📝 Read_info actualizado (tag-writer)');
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

              finalContent = nfcEncode(nfcJson);
            }
          } else {
            // Tag vacío, crear JSON inicial
            debugPrint('🆕 Tag vacío, creando JSON inicial...');

            if (productId != null && productName != null) {
              nfcJson = buildInitialNfcJson(
                idProduct: productId,
                rfid: productRfid,
                nameProduct: productName,
                tagFrom: '',
                tagTo: tagRfid,
                userId: FFAppState().userSelected.idUser,
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

              finalContent = nfcEncode(nfcJson);
              debugPrint('✅ JSON inicial creado');
            }
          }
          } // Fin del else para TAG-WRITER
          } // Fin del else del fast-append path

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

        // Calcular el tamaño REAL del mensaje NDEF que se enviará al tag.
        // ndef.maxSize es el espacio máximo del MENSAJE NDEF completo (headers incluidos),
        // no solo del texto. El record NDEF Text tiene overhead propio:
        //   payload = [status_byte(1)] + [lang_code "en"(2)] + [texto(N)] = N+3 bytes
        //   record  = [flags(1)] + [type_len(1)] + [payload_len_field(1 o 4)] + [type 'T'(1)] + payload
        //   si payload > 255 → payload_len_field = 4 bytes (Long Record, SR=0)
        //   si payload ≤ 255 → payload_len_field = 1 byte  (Short Record, SR=1)
        const int textRecordStaticOverhead = 3; // status_byte + "en"
        final int ndefPayloadSize = requiredBytes + textRecordStaticOverhead;
        final int payloadLenFieldSize = ndefPayloadSize > 255 ? 4 : 1;
        const int ndefRecordHeaderSize = 3; // flags(1) + type_len(1) + type_char(1)
        final int totalNdefBytes =
            ndefRecordHeaderSize + payloadLenFieldSize + ndefPayloadSize;

        // Verificar si hay espacio suficiente (usando el tamaño NDEF real)
        if (maxCapacity > 0 && totalNdefBytes > maxCapacity) {
          debugPrint(
              'ESPACIO INSUFICIENTE: NDEF message requiere $totalNdefBytes bytes '
              '(texto=$requiredBytes + overhead NDEF=${totalNdefBytes - requiredBytes} bytes), '
              'capacidad=$maxCapacity');
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
                  'ERROR:ESPACIO_INSUFICIENTE:$totalNdefBytes/$maxCapacity';
            });

            completer.complete(false);
            await NfcManager.instance.stopSession();
            return;
          }
        }

        debugPrint(
            'Espacio OK: $totalNdefBytes bytes NDEF de $maxCapacity disponibles '
            '($requiredBytes bytes de texto + ${totalNdefBytes - requiredBytes} overhead)');

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

        // Escribir usando NDEF estándar, con reintentos ante error transitorio
        // (IOException / tag lost). Se reescribe el MISMO finalContent (ya
        // fusionado con el contenido del destino), así que aunque una escritura
        // fallida deje el tag a medias, un reintento exitoso restaura el
        // contenido completo sin perder los registros previamente acumulados.
        Object? writeError;
        bool ndefWritten = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            await ndefWriter.write(message: message);
            ndefWritten = true;
            break;
          } catch (e) {
            writeError = e;
            final m = e.toString().toLowerCase();
            final transient =
                m.contains('ioexception') || m.contains('tag was lost');
            debugPrint('⚠️ Error al escribir NDEF (intento $attempt/3): $e');
            if (!transient || attempt == 3) break;
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }

        if (ndefWritten) {
          debugPrint('Mensaje NDEF escrito exitosamente');
          debugPrint('Contenido completo: $finalContent');

          // Actualizar AppState con el contenido completo
          FFAppState().update(() {
            FFAppState().nfcRead = finalContent;
          });

          completer.complete(true);
        } else {
          debugPrint('Error al escribir NDEF tras reintentos: $writeError');

          // Detectar si el error es por tag alejado (IOException)
          final errorMsg = (writeError?.toString() ?? '').toLowerCase();
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
