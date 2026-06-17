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
import 'nfc_gateway.dart';

/// Consulta la memoria libre de un tag DeSFire mediante APDU GET_FREE_MEMORY.
/// Retorna null si el comando falla (requiere auth o tag no lo soporta).
Future<int?> _getDeSFireFreeMemory(IsoDepAndroid isoDep) async {
  try {
    final response = await isoDep.transceive(
      Uint8List.fromList([0x90, 0x6E, 0x00, 0x00, 0x00]),
    );
    if (response.length >= 5 && response[3] == 0x91 && response[4] == 0x00) {
      final freeBytes = response[0] | (response[1] << 8) | (response[2] << 16);
      debugPrint('DeSFire GET_FREE_MEMORY: $freeBytes bytes libres');
      return freeBytes;
    }
  } catch (e) {
    debugPrint('DeSFire GET_FREE_MEMORY falló: $e');
  }
  return null;
}

// ── Recovery de escrituras interrumpidas ─────────────────────────────────────
// Si una escritura NDEF se interrumpe (tag alejado a mitad de transmisión), el
// tag queda con un mensaje parcial: el header ya declara la longitud NUEVA pero
// los datos quedaron incompletos, así que los lectores lanzan FormatException y
// el tag parece "vacío". Los bytes previos al corte siguen intactos. Para no
// perder nada, el contenido completo que se intentaba escribir queda guardado
// aquí: al volver a acercar el MISMO tag se reescribe íntegro con un handle
// fresco (reintentar con el handle viejo siempre falla con "Tag is out of date").
String? _pendingRewriteContent;
String? _pendingRewriteRfid;

/// Adaptador que expone un tag NDEF real como [NfcTagOps], para reutilizar el
/// núcleo PURO y probado [writeTextVerified] (escribir + verificar por
/// relectura + reintentar) en producción sin duplicar esa lógica.
class _RealNfcTagOps implements NfcTagOps {
  final NfcTag _tag;
  final Ndef _ndef;
  _RealNfcTagOps(this._tag, this._ndef);

  @override
  String get tagId {
    final a = NfcTagAndroid.from(_tag);
    if (a == null || a.id.isEmpty) return '';
    return a.id
        .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join('');
  }

  @override
  bool get isWritable => _ndef.isWritable;

  @override
  Future<String?> readText() async {
    final msg = await _ndef.read();
    if (msg == null || msg.records.isEmpty) return null;
    final payload = msg.records.first.payload;
    if (payload.isEmpty) return null;
    final langLen = payload[0] & 0x3F;
    if (payload.length <= langLen + 1) return null;
    return utf8.decode(payload.sublist(1 + langLen), allowMalformed: true);
  }

  @override
  Future<void> writeText(String content) async {
    final err = await _writeNdefWithRetry(_ndef, _buildNdefTextMessage(content));
    if (err != null) throw err; // writeTextVerified captura y decide reintentar
  }
}

/// Construye el mensaje NDEF Text Record estándar para [content].
NdefMessage _buildNdefTextMessage(String content) {
  const languageCode = 'en';
  final languageCodeBytes = utf8.encode(languageCode);
  final textBytes = utf8.encode(content);
  final payload = Uint8List.fromList([
    languageCodeBytes.length, // status byte: UTF-8 + longitud del language code
    ...languageCodeBytes,
    ...textBytes,
  ]);
  return NdefMessage(records: [
    NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([84]), // 'T' para Text
      identifier: Uint8List(0),
      payload: payload,
    ),
  ]);
}

/// Escribe [message] con hasta 3 intentos ante errores transitorios.
/// Retorna null si tuvo éxito, o el último error si falló.
/// "Tag is out of date" = el handle quedó inválido porque el tag salió del
/// campo: reintentar con ese mismo handle nunca funciona, se aborta de inmediato.
Future<Object?> _writeNdefWithRetry(Ndef ndefWriter, NdefMessage message) async {
  Object? lastError;
  for (int attempt = 1; attempt <= 3; attempt++) {
    try {
      await ndefWriter.write(message: message);
      return null;
    } catch (e) {
      lastError = e;
      final m = e.toString().toLowerCase();
      final staleHandle =
          m.contains('out of date') || m.contains('securityexception');
      final transient = !staleHandle &&
          (m.contains('ioexception') || m.contains('tag was lost'));
      debugPrint('⚠️ Error al escribir NDEF (intento $attempt/3): $e');
      if (!transient || attempt == 3) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
  return lastError;
}

/// Re-lee el tag por NDEF y confirma que su contenido de texto coincide
/// EXACTAMENTE con [expected]. Detecta escrituras parciales/corruptas que NO
/// lanzaron excepción (el API reportó éxito pero el tag quedó mal). Se ejecuta
/// dentro de la misma sesión, con el tag aún en el campo. Retorna false si no
/// se pudo releer o el contenido difiere.
Future<bool> _verifyTagContent(NfcTag tag, String expected) async {
  try {
    final ndef = Ndef.from(tag);
    if (ndef == null) return false;
    final msg = await ndef.read();
    if (msg == null || msg.records.isEmpty) return false;
    final payload = msg.records.first.payload;
    if (payload.isEmpty) return false;
    final langLen = payload[0] & 0x3F;
    if (payload.length <= langLen + 1) return false;
    final readBack =
        utf8.decode(payload.sublist(1 + langLen), allowMalformed: true);
    final ok = readBack == expected;
    if (!ok) {
      debugPrint('🔍 Verificación NO coincide: releído ${readBack.length} bytes '
          'vs esperado ${expected.length} bytes');
    }
    return ok;
  } catch (e) {
    debugPrint('⚠️ _verifyTagContent error: $e');
    return false;
  }
}

/// Intenta rescatar el prefijo válido de un contenido NFC corrupto por una
/// escritura parcial: decodifica tolerante, corta en el primer byte inválido
/// o NUL, y descarta el último chunk si quedó truncado a mitad.
String? _salvageCorruptedNfcContent(List<int> textBytes) {
  try {
    var s = utf8.decode(textBytes, allowMalformed: true);
    for (final stop in ['\uFFFD', '\u0000']) {
      final i = s.indexOf(stop);
      if (i >= 0) s = s.substring(0, i);
    }
    // Depuración compartida de chunks truncados (nfc_json_helper.dart)
    final purged = purgeCorruptedNfcContent(s);
    // El flujo de escritura solo maneja contenido N1:/C1:/multi-chunk
    if (purged == null || !isNfcCompressedFormat(purged)) return null;
    return purged;
  } catch (e) {
    debugPrint('⚠️ Salvage de contenido corrupto falló: $e');
    return null;
  }
}

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
      // onDiscovered puede dispararse varias veces (recovery / SOLICITAR_OTRO_TAG
      // dejan la sesión abierta a propósito). Solo se ignora si YA completamos,
      // así no se llama completer.complete() dos veces ("Future already completed").
      if (completer.isCompleted) return;
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

        // ═══ RECOVERY: reescritura íntegra tras una escritura interrumpida ═══
        // El contenido completo de la escritura fallida quedó en memoria; con el
        // handle fresco de este nuevo descubrimiento se reescribe completo, sin leer
        // el contenido del tag (que puede estar corrupto por el corte anterior).
        if (_pendingRewriteContent != null &&
            tagRfid.isNotEmpty &&
            tagRfid == _pendingRewriteRfid) {
          debugPrint('♻️ RECOVERY: reescribiendo contenido pendiente '
              '(${_pendingRewriteContent!.length} bytes) en tag $tagRfid');
          final recoveryWriter = Ndef.from(tag);
          if (recoveryWriter != null && recoveryWriter.isWritable) {
            final recoveryMessage =
                _buildNdefTextMessage(_pendingRewriteContent!);
            final recoveryError =
                await _writeNdefWithRetry(recoveryWriter, recoveryMessage);
            if (recoveryError == null &&
                await _verifyTagContent(tag, _pendingRewriteContent!)) {
              debugPrint('✅ RECOVERY: contenido restaurado y verificado');
              final restored = _pendingRewriteContent!;
              _pendingRewriteContent = null;
              _pendingRewriteRfid = null;
              FFAppState().update(() {
                FFAppState().nfcRead = restored;
              });
              completer.complete(true);
              await NfcManager.instance.stopSession();
              return;
            }
            debugPrint(
                '❌ RECOVERY falló, contenido sigue pendiente: $recoveryError');
          } else {
            debugPrint('❌ RECOVERY: tag sin soporte NDEF o no escribible');
          }
          FFAppState().update(() {
            FFAppState().nfcRead = 'ERROR:TAG_ALEJADO';
          });
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
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
        // true solo cuando lanzó excepción al decodificar el payload (no cuando el contenido es "0")
        bool ndefDecodeFailure = false;

        if (needsAnotherTag) {
          debugPrint('✏️ NUEVO TAG: tag virgen, procesando con pipeline completo...');
        }
          // Intentar leer el contenido existente del tag
          // Esto funciona para tags NDEF: MifareClassic formateado, DESFire formateado, etc.
          Ndef? ndefObject; // capturado para safeguard post-lectura
          try {
            ndefObject = Ndef.from(tag);
            if (ndefObject != null && ndefObject.cachedMessage != null) {
              final records = ndefObject.cachedMessage!.records;

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
                          // NO es fallo de decodificación: el tag genuinamente está vacío
                        }
                      }
                    }
                  } catch (decodeError) {
                    debugPrint('Error decodificando registro: $decodeError');
                    // Escritura parcial previa: los bytes anteriores al corte
                    // siguen intactos. Rescatar el prefijo válido en lugar de
                    // abortar; el flujo normal reescribirá el mensaje completo.
                    final langLen = payload[0] & 0x3F;
                    final salvaged = payload.length > langLen + 1
                        ? _salvageCorruptedNfcContent(
                            payload.sublist(1 + langLen))
                        : null;
                    if (salvaged != null && salvaged.isNotEmpty) {
                      existingContent = salvaged;
                      debugPrint('🩹 Contenido rescatado de tag corrupto: '
                          '${salvaged.length} bytes');
                    } else {
                      ndefDecodeFailure = true; // payload corrupto/ilegible
                    }
                  }
                }
              }
            } else if (ndefObject != null) {
              // cachedMessage es null: el tag ES NDEF pero la lectura de descubrimiento
              // no capturó el contenido. Intentar lectura explícita en sesión.
              debugPrint('⚠️ cachedMessage null en tag NDEF — intentando lectura explícita...');
              try {
                final freshMsg = await ndefObject.read();
                if (freshMsg != null && freshMsg.records.isNotEmpty) {
                  final payload = freshMsg.records.first.payload;
                  if (payload.isNotEmpty) {
                    final langLen = payload[0] & 0x3F;
                    if (payload.length > langLen + 1) {
                      final textBytes = payload.sublist(1 + langLen);
                      existingContent = utf8.decode(textBytes);
                      if (existingContent.trim() == '0') existingContent = '';
                      if (existingContent.isNotEmpty) {
                        debugPrint('📖 Lectura explícita OK: ${existingContent.substring(0, existingContent.length > 80 ? 80 : existingContent.length)}...');
                      }
                    }
                  }
                }
              } catch (explicitReadError) {
                debugPrint('⚠️ Lectura explícita también falló: $explicitReadError');
                ndefDecodeFailure = true;
              }
            }
          } catch (readError) {
            debugPrint(
                'No se pudo leer contenido existente (tag nuevo o vacío): $readError');
            // Si falla la lectura, continuar con solo el nuevo contenido
          }

          // Safeguard: solo abortar si hubo un fallo REAL de decodificación del payload
          // (excepción al leer/decodificar). No abortar si el contenido era "0" (vacío legítimo).
          if (ndefDecodeFailure &&
              existingContent.isEmpty &&
              ndefObject != null &&
              !needsAnotherTag) {
            debugPrint('🛑 Fallo de decodificación NDEF — abortando para proteger contenido existente');
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:LECTURA_FALLIDA';
            });
            completer.complete(false);
            await NfcManager.instance.stopSession();
            return;
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
          // rawExistingContent conserva el C1 original para el path TAG-TRANSFER:
          // decodeNfcRecords() puede leer C1 multi-producto directamente, mientras que
          // nfcDecode() solo devuelve el primer registro de un array (contrato histórico).
          final rawExistingContent = existingContent;
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
                final destRecords = rawExistingContent.isNotEmpty
                    ? decodeNfcRecords(rawExistingContent)
                    : <Map<String, dynamic>>[];

                String originOf(Map<String, dynamic> rec) {
                  final ri = rec['Read_info'] as Map<String, dynamic>?;
                  final from = (ri?['tag_from'] as String? ?? '').trim();
                  if (from.isNotEmpty) return from;
                  return (ri?['RFID'] as String? ?? '').trim();
                }

                for (final src in srcRecords) {
                  // Inyectar tag_to / US / tag_from en cada registro de origen.
                  // RFID es inmutable: solo se fija una vez (primer origen) y nunca se sobreescribe.
                  // Name_product e Id_product se refrescan desde Products con el RFID inmutable,
                  // para que reflejen el nombre actual del producto, no el que quedó grabado en el tag.
                  final ri = src['Read_info'] as Map<String, dynamic>?;
                  if (ri != null) {
                    // tag_from fue inyectado por readNFC con el RFID físico del tag origen
                    // recién leído (readNFC._enrichReadContent: tag_from = hardware tagId).
                    // Es el RFID correcto para refrescar Name_product e Id_product desde Products.
                    // Fallback a ri['RFID'] solo para tags anteriores a esta convención.
                    final srcPhysicalRfid = (ri['tag_from'] as String? ?? '').trim().isNotEmpty
                        ? (ri['tag_from'] as String).trim()
                        : (ri['RFID'] as String? ?? '').trim();

                    ri['tag_to'] = tagRfid;
                    ri['US'] = FFAppState().userSelected.idUser;
                    if ((ri['tag_from'] as String? ?? '').isEmpty) {
                      ri['tag_from'] = ri['RFID'] ?? '';
                    }

                    // Refrescar Name_product e Id_product con el valor actual en Products
                    // usando el RFID físico del tag origen (no el inmutable Read_info.RFID).
                    if (sharedDb != null && srcPhysicalRfid.isNotEmpty) {
                      try {
                        final prodRows = await sharedDb.rawQuery(
                          'SELECT Id_product, Name_product FROM Products WHERE Rfid = ? LIMIT 1',
                          [srcPhysicalRfid],
                        );
                        if (prodRows.isNotEmpty) {
                          ri['Id_product'] = prodRows.first['Id_product'];
                          ri['Name_product'] = prodRows.first['Name_product'];
                          debugPrint('🔄 TAG-TRANSFER origen $srcPhysicalRfid → ${prodRows.first['Name_product']} (ID: ${prodRows.first['Id_product']})');
                        }
                      } catch (e) {
                        debugPrint('⚠️ TAG-TRANSFER: no se pudo refrescar producto para RFID $srcPhysicalRfid: $e');
                      }
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
          // DeSFire: consultar capacidad real via APDU GET_FREE_MEMORY.
          // Si falla (requiere auth o no soportado), usar 8192 como estimación optimista.
          // El propio ndefFormatable.format() validará si el contenido cabe al escribir.
          maxCapacity = await _getDeSFireFreeMemory(isoDep) ?? 8192;
          debugPrint('Tag DeSFire (IsoDep) capacidad: $maxCapacity bytes');
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

        // Crear el mensaje NDEF (Text Record estándar)
        final message = _buildNdefTextMessage(finalContent);

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
              // Verificar por relectura que el formateo+escritura quedó íntegro.
              if (await _verifyTagContent(tag, finalContent)) {
                debugPrint(
                    'Tag $tagTypeName formateado, escrito y verificado como NDEF');
                debugPrint('Contenido completo: $finalContent');

                FFAppState().update(() {
                  FFAppState().nfcRead = finalContent;
                });

                completer.complete(true);
                await NfcManager.instance.stopSession();
                return;
              }
              // Formateo sin excepción pero contenido no verificable: guardar
              // en memoria y reportar para reintento.
              debugPrint(
                  '❌ Verificación tras formateo falló: contenido no coincide');
              if (tagRfid.isNotEmpty && finalContent.isNotEmpty) {
                _pendingRewriteContent = finalContent;
                _pendingRewriteRfid = tagRfid;
              }
              FFAppState().update(() {
                FFAppState().nfcRead = 'ERROR:VERIFICACION_FALLIDA';
              });
              completer.complete(false);
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

              // Escritura dinámica: usa TODOS los sectores disponibles del tag.
              // Sector 0: bloques 1-2 (bloque 0 = fabricante, bloque 3 = auth trailer)
              // Sectores 1..N-1: bloques 0-2 de cada sector (bloque 3 = auth trailer)
              // Capacidad total para 1K: 2 + 15×3 = 47 bloques × 16 bytes = 752 bytes
              final sectorCount = mifareClassic.sectorCount;
              final blocksToWrite = <int, Uint8List>{};
              int byteIndex = 0;

              // Sector 0: bloques 1 y 2 (saltar bloque 0 = fabricante)
              for (var b = 1; b <= 2 && byteIndex < totalBytes; b++) {
                final end = byteIndex + 16 < totalBytes ? byteIndex + 16 : totalBytes;
                final paddedBlock = Uint8List(16);
                paddedBlock.setRange(0, end - byteIndex, contentBytes, byteIndex);
                blocksToWrite[b] = paddedBlock;
                byteIndex += 16;
              }

              // Sectores 1 .. sectorCount-1: bloques 0-2 de cada sector
              for (var s = 1; s < sectorCount && byteIndex < totalBytes; s++) {
                for (var b = 0; b <= 2 && byteIndex < totalBytes; b++) {
                  final blockIndex = s * 4 + b;
                  final end = byteIndex + 16 < totalBytes ? byteIndex + 16 : totalBytes;
                  final paddedBlock = Uint8List(16);
                  paddedBlock.setRange(0, end - byteIndex, contentBytes, byteIndex);
                  blocksToWrite[blockIndex] = paddedBlock;
                  byteIndex += 16;
                }
              }

              // Verificar si el contenido cabe en la capacidad total del tag
              if (byteIndex < totalBytes) {
                final remaining = totalBytes - byteIndex;
                final usableCapacity = 32 + (sectorCount - 1) * 48;
                debugPrint('❌ Contenido demasiado grande: $totalBytes bytes, capacidad $usableCapacity bytes, excede por $remaining bytes');
                FFAppState().update(() {
                  FFAppState().nfcRead = 'ERROR:CONTENIDO_MUY_LARGO:$totalBytes/$usableCapacity';
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
        // Escribir + VERIFICAR por relectura, con reintento en sesión.
        // _writeNdefWithRetry ya reintenta errores transitorios; aquí se suma
        // la relectura de confirmación: si el contenido releído NO coincide con
        // lo que se quiso escribir (escritura parcial/corrupta que no lanzó
        // excepción), se reescribe una vez más antes de darse por vencido.
        Object? writeError;
        bool verified = false;
        for (int attempt = 1; attempt <= 2; attempt++) {
          writeError = await _writeNdefWithRetry(ndefWriter, message);
          if (writeError != null) break; // error de escritura (ya reintentado)
          verified = await _verifyTagContent(tag, finalContent);
          if (verified) break;
          debugPrint(
              '⚠️ Verificación tras escritura falló (intento $attempt/2) — reescribiendo...');
        }
        final ndefWritten = writeError == null && verified;

        if (ndefWritten) {
          debugPrint('✅ Mensaje NDEF escrito y verificado por relectura');
          debugPrint('Contenido completo: $finalContent');

          // Escritura íntegra confirmada: descartar cualquier pendiente previo
          if (tagRfid.isNotEmpty && tagRfid == _pendingRewriteRfid) {
            _pendingRewriteContent = null;
            _pendingRewriteRfid = null;
          }

          // Actualizar AppState con el contenido completo
          FFAppState().update(() {
            FFAppState().nfcRead = finalContent;
          });

          completer.complete(true);
        } else {
          // Guardar el contenido completo (ya fusionado) en memoria para
          // reescribirlo íntegro al reintentar o reacercar el MISMO tag: una
          // escritura interrumpida o no verificada puede dejar el NDEF
          // parcial/corrupto, pero el contenido a salvo permite recuperarlo.
          if (tagRfid.isNotEmpty && finalContent.isNotEmpty) {
            _pendingRewriteContent = finalContent;
            _pendingRewriteRfid = tagRfid;
            debugPrint('💾 Contenido guardado para recovery: '
                '$tagRfid, ${finalContent.length} bytes');
          }

          if (writeError == null && !verified) {
            // La escritura no lanzó error, pero el contenido releído NO coincide.
            // El contenido íntegro queda pendiente para reintento.
            debugPrint(
                '❌ Verificación por relectura falló: el contenido del tag no coincide');
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:VERIFICACION_FALLIDA';
            });
          } else {
            debugPrint('Error al escribir NDEF tras reintentos: $writeError');
            // Detectar si el error es por tag alejado (IOException o handle
            // invalidado porque el tag salió del campo: "Tag is out of date")
            final errorMsg = (writeError ?? '').toString().toLowerCase();
            if (errorMsg.contains('ioexception') ||
                errorMsg.contains('tag was lost') ||
                errorMsg.contains('out of date')) {
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

/// Escribe [content] VERBATIM en un tag (sin leer ni fusionar el contenido
/// previo), con verificación por relectura y reintento. Pensado para reintentos
/// "desde el respaldo": [content] ya es el resultado final deseado (p. ej. la
/// fusión origen+destino guardada en el journal) y debe SOBREESCRIBIR lo que
/// haya en el tag — no se vuelve a fusionar, evitando dobles conteos.
/// Si [expectedRfid] no está vacío y el tag presentado tiene otro RFID, aborta
/// (ERROR:TAG_INCORRECTO) para no escribir en el tag equivocado.
Future<bool> rewriteVerifiedExact(
  BuildContext context,
  String content, {
  String expectedRfid = '',
}) async {
  if (!Platforms.isMobile) return false;
  if (!await checkNfcStatus(context, showAlert: true)) return false;

  final completer = Completer<bool>();
  NfcManager.instance.startSession(
    pollingOptions: {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
    },
    onDiscovered: (NfcTag tag) async {
      if (completer.isCompleted) return;
      try {
        // Verificar que es el tag esperado (si se exigió un RFID).
        if (expectedRfid.isNotEmpty) {
          final androidTag = NfcTagAndroid.from(tag);
          final rfid = (androidTag != null && androidTag.id.isNotEmpty)
              ? androidTag.id
                  .map((b) =>
                      b.toRadixString(16).toUpperCase().padLeft(2, '0'))
                  .join('')
              : '';
          if (rfid.isNotEmpty && rfid != expectedRfid) {
            debugPrint(
                '❌ rewriteVerifiedExact: RFID $rfid ≠ esperado $expectedRfid');
            FFAppState().update(() {
              FFAppState().nfcRead = 'ERROR:TAG_INCORRECTO';
            });
            completer.complete(false);
            await NfcManager.instance.stopSession();
            return;
          }
        }

        final ndef = Ndef.from(tag);
        if (ndef == null || !ndef.isWritable) {
          FFAppState().update(() {
            FFAppState().nfcRead = 'ERROR:TAG_PROTEGIDO';
          });
          completer.complete(false);
          await NfcManager.instance.stopSession();
          return;
        }

        // Núcleo puro probado: escribir + verificar por relectura + reintentar.
        final outcome =
            await writeTextVerified(_RealNfcTagOps(tag, ndef), content);

        if (outcome == NfcWriteOutcome.ok) {
          debugPrint('✅ rewriteVerifiedExact: escrito y verificado');
          FFAppState().update(() {
            FFAppState().nfcRead = content;
          });
          completer.complete(true);
        } else {
          FFAppState().update(() {
            FFAppState().nfcRead = outcome == NfcWriteOutcome.notVerified
                ? 'ERROR:VERIFICACION_FALLIDA'
                : 'ERROR:ESCRITURA_FALLIDA';
          });
          completer.complete(false);
        }
        await NfcManager.instance.stopSession();
      } catch (e) {
        debugPrint('❌ rewriteVerifiedExact error: $e');
        completer.complete(false);
        await NfcManager.instance.stopSession();
      }
    },
  );

  return completer.future;
}
