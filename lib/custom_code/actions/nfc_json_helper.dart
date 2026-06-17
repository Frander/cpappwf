// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:io'; // ZLibCodec for tag content compression

/// Helper para construir y parsear el nuevo formato JSON de los tags NFC
///
/// Formato JSON:
/// ```json
/// {
///   "Read_info": {
///     "Id_product": 789542,
///     "RFID": "4C72D5F2",
///     "Name_product": "Caja 10",
///     "Date_created": "2026-05-15T09:00:00"
///   },
///   "Visits": [
///     {
///       "DH": "2026-05-15T08:30:00",
///       "OP": 293,
///       "VISITS": 10,
///       "RESULTS": 8,
///       "HE": 204
///     }
///   ]
/// }
/// ```

// ─── Key compression maps ─────────────────────────────────────────────────────
const Map<String, String> _kEncode = {
  'Read_info': 'R', 'Id_product': 'i', 'RFID': 'r', 'Name_product': 'n',
  'Date_created': 'd', 'tag_from': 'f', 'tag_to': 't', 'US': 'u',
  'Visits': 'V', 'DH': 'h', 'OP': 'o', 'OP2': 'p',
  'VISITS': 'v', 'RESULTS': 's', 'HE': 'e',
};

const Map<String, String> _kDecode = {
  'R': 'Read_info', 'i': 'Id_product', 'r': 'RFID', 'n': 'Name_product',
  'd': 'Date_created', 'f': 'tag_from', 't': 'tag_to', 'u': 'US',
  'V': 'Visits', 'h': 'DH', 'o': 'OP', 'p': 'OP2',
  'v': 'VISITS', 's': 'RESULTS', 'e': 'HE',
};

const int _kCompressionThreshold = 200;
const String _kPrefixMinified    = 'N1:';
const String _kPrefixCompressed  = 'C1:';

/// Delimitador entre chunks (ASCII 30 — Record Separator).
/// No puede aparecer en base64url, JSON numérico, ni strings de producto.
const String kNfcChunkDelimiter = '\x1E';

// ─── Private minification helpers ─────────────────────────────────────────────

Map<String, dynamic> _minifyNfcMap(Map<String, dynamic> canonical) {
  final result = <String, dynamic>{};
  canonical.forEach((key, value) {
    final shortKey = _kEncode[key] ?? key;
    if (key == 'Read_info' && value is Map<String, dynamic>) {
      result[shortKey] = _minifyReadInfo(value);
    } else if (key == 'Visits' && value is List) {
      result[shortKey] = value.map((v) {
        if (v is Map<String, dynamic>) return _minifyVisitEntry(v);
        return v;
      }).toList();
    } else {
      result[shortKey] = value;
    }
  });
  return result;
}

Map<String, dynamic> _minifyReadInfo(Map<String, dynamic> info) {
  final r = <String, dynamic>{};
  info.forEach((key, value) {
    final shortKey = _kEncode[key] ?? key;
    if ((key == 'tag_from' || key == 'tag_to') && (value == null || value == '')) return;
    if (key == 'Name_product' && value is String) {
      r[shortKey] = value.length > 24 ? value.substring(0, 24) : value;
      return;
    }
    if (key == 'Date_created' && value is String) {
      r[shortKey] = _isoToEpoch(value);
      return;
    }
    r[shortKey] = value;
  });
  return r;
}

Map<String, dynamic> _minifyVisitEntry(Map<String, dynamic> visit) {
  final r = <String, dynamic>{};
  visit.forEach((key, value) {
    final shortKey = _kEncode[key] ?? key;
    if (key == 'DH' && value is String) {
      r[shortKey] = _isoToEpoch(value);
      return;
    }
    if (key == 'OP2' && (value == null || value.toString().isEmpty || value == 'false')) return;
    r[shortKey] = value;
  });
  return r;
}

dynamic _isoToEpoch(String iso) {
  try {
    return DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return iso;
  }
}

// ─── Private expansion helpers ────────────────────────────────────────────────

Map<String, dynamic> _expandNfcMap(Map<String, dynamic> minified) {
  final result = <String, dynamic>{};
  minified.forEach((key, value) {
    final longKey = _kDecode[key] ?? key;
    if (longKey == 'Read_info' && value is Map) {
      result[longKey] = _expandReadInfo(Map<String, dynamic>.from(value));
    } else if (longKey == 'Visits' && value is List) {
      result[longKey] = value.map((v) {
        if (v is Map) return _expandVisitEntry(Map<String, dynamic>.from(v));
        return v;
      }).toList();
    } else {
      result[longKey] = value;
    }
  });
  return result;
}

Map<String, dynamic> _expandReadInfo(Map<String, dynamic> info) {
  final r = <String, dynamic>{};
  info.forEach((key, value) {
    final longKey = _kDecode[key] ?? key;
    if (longKey == 'Date_created' && value is int) {
      r[longKey] = _epochToIso(value);
      return;
    }
    r[longKey] = value;
  });
  r.putIfAbsent('tag_from', () => '');
  r.putIfAbsent('tag_to', () => '');
  return r;
}

Map<String, dynamic> _expandVisitEntry(Map<String, dynamic> visit) {
  final r = <String, dynamic>{};
  visit.forEach((key, value) {
    final longKey = _kDecode[key] ?? key;
    if (longKey == 'DH' && value is int) {
      r[longKey] = _epochToIso(value);
      return;
    }
    r[longKey] = value;
  });
  r.putIfAbsent('OP2', () => '');
  return r;
}

String _epochToIso(int epoch) =>
    DateTime.fromMillisecondsSinceEpoch(epoch * 1000).toIso8601String();

String _addBase64Padding(String b64) {
  final rem = b64.length % 4;
  return rem == 0 ? b64 : b64 + '=' * (4 - rem);
}

// ─── Public delta-chunk API ───────────────────────────────────────────────────

/// Retorna true si el string contiene múltiples chunks separados por [kNfcChunkDelimiter].
bool isMultiChunkFormat(String raw) => raw.contains(kNfcChunkDelimiter);

/// Serializa una visita individual como delta chunk para concatenación rápida en NFC.
/// Se pre-computa ANTES de abrir la sesión NFC para minimizar el tiempo con el tag activo.
/// Formato de salida: 'V:{"h":epoch,"o":opId,"v":visits,"s":results,"e":heId}'
String encodeVisitDelta({
  required int operatorId,
  required int visits,
  required int results,
  required int headquarterId,
  required DateTime dateTime,
}) {
  final entry = <String, dynamic>{
    'h': dateTime.millisecondsSinceEpoch ~/ 1000,
    'o': operatorId,
    'v': visits,
    's': results,
    'e': headquarterId,
  };
  return 'V:${jsonEncode(entry)}';
}

/// Decodifica un string multi-chunk al Map canónico con todas las visitas combinadas.
/// El primer chunk contiene Read_info + primera visita (N1/C1/canónico).
/// Los chunks siguientes son deltas 'V:{...}' con claves minificadas.
Map<String, dynamic>? decodeMultiChunk(String raw) {
  final parts = raw.split(kNfcChunkDelimiter);
  if (parts.isEmpty) return null;

  // Primer chunk: JSON completo con Read_info + Visits
  final firstChunk = nfcDecode(parts[0]) ?? parseNfcJson(parts[0]);
  if (firstChunk == null) return null;

  final visits = List<dynamic>.from((firstChunk['Visits'] as List?) ?? []);

  for (final part in parts.skip(1)) {
    if (!part.startsWith('V:')) continue;
    try {
      final minVisit = jsonDecode(part.substring(2)) as Map<String, dynamic>;
      visits.add(_expandVisitEntry(minVisit));
    } catch (e) {
      debugPrint('⚠️ decodeMultiChunk: delta inválido — $e');
    }
  }

  return {...firstChunk, 'Visits': visits};
}

/// Depura un contenido NFC corrupto por una escritura interrumpida.
/// Corta en el primer carácter inválido (U+FFFD, producto de
/// `utf8.decode(allowMalformed: true)`) o NUL (relleno tras el punto de corte)
/// y descarta los chunks que no parsean (típicamente un delta 'V:' truncado).
/// - Retorna el contenido depurado (puede ser igual a [raw] si no había corrupción).
/// - Retorna null si el chunk base (N1:/C1:/JSON canónico) es irrecuperable.
String? purgeCorruptedNfcContent(String raw) {
  var s = raw;
  for (final stop in [String.fromCharCode(0xFFFD), String.fromCharCode(0x00)]) {
    final i = s.indexOf(stop);
    if (i >= 0) s = s.substring(0, i);
  }
  if (s.isEmpty) return null;

  final parts = s.split(kNfcChunkDelimiter);
  // El chunk base debe decodificar completo; sin él no hay nada que rescatar.
  if (nfcDecode(parts[0]) == null && parseNfcJson(parts[0]) == null) {
    return null;
  }

  final valid = <String>[parts[0]];
  for (var i = 1; i < parts.length; i++) {
    final p = parts[i];
    if (p.startsWith('V:')) {
      try {
        jsonDecode(p.substring(2));
        valid.add(p);
        continue;
      } catch (_) {
        // delta truncado/corrupto — se descarta
      }
    }
    debugPrint(
        '🧹 purgeCorruptedNfcContent: chunk $i descartado (${p.length} chars)');
  }
  return valid.join(kNfcChunkDelimiter);
}

// ─── Public compression API ───────────────────────────────────────────────────

/// Retorna true si el string usa el formato comprimido (C1) o minificado (N1)
bool isNfcCompressedFormat(String raw) =>
    raw.startsWith(_kPrefixCompressed) || raw.startsWith(_kPrefixMinified);

/// Codifica un Map NFC canónico al string optimizado para escribir en el tag.
/// - Payload ≤ 200 bytes → 'N1:<json-minificado>'
/// - Payload > 200 bytes → 'C1:<base64url(zlib(json-minificado))>'
/// Fallback transparente a jsonEncode si falla la codificación.
String nfcEncode(Map<String, dynamic> nfcJson) {
  try {
    final minJson  = jsonEncode(_minifyNfcMap(nfcJson));
    final minBytes = utf8.encode(minJson);
    if (minBytes.length <= _kCompressionThreshold) {
      return '$_kPrefixMinified$minJson';
    }
    final compressed = ZLibCodec(level: 6).encode(minBytes);
    final b64 = base64Url.encode(compressed).replaceAll('=', '');
    return '$_kPrefixCompressed$b64';
  } catch (e) {
    debugPrint('⚠️ nfcEncode error: $e — fallback a jsonEncode');
    return jsonEncode(nfcJson);
  }
}

/// Decodifica un string del tag NFC (multi-chunk, N1, C1 o JSON canónico plano) al Map canónico.
/// Retorna null si el formato es irreconocible o hay error.
Map<String, dynamic>? nfcDecode(String raw) {
  if (raw.isEmpty || raw.trim() == '0') return null;
  // Multi-chunk: delegar a decodeMultiChunk (parts[0] no tiene delimitador → no recursión)
  if (isMultiChunkFormat(raw)) return decodeMultiChunk(raw);
  try {
    if (raw.startsWith(_kPrefixCompressed) || raw.startsWith(_kPrefixMinified)) {
      final String minJson;
      if (raw.startsWith(_kPrefixCompressed)) {
        final b64        = raw.substring(_kPrefixCompressed.length);
        final compressed = base64Url.decode(_addBase64Padding(b64));
        minJson          = utf8.decode(ZLibCodec().decode(compressed));
      } else {
        minJson = raw.substring(_kPrefixMinified.length);
      }
      final decoded = jsonDecode(minJson);
      // Tag multi-producto: el payload es un ARRAY de registros. nfcDecode
      // retorna un solo Map (contrato histórico), así que devuelve el PRIMER
      // registro. Los consumidores que necesitan todos los productos deben usar
      // decodeNfcRecords. Sin esto, el cast `as Map` lanzaba
      // "List<dynamic> is not a subtype of Map<String, dynamic>".
      if (decoded is List) {
        final maps = decoded.whereType<Map>().toList();
        if (maps.isEmpty) return null;
        return _expandNfcMap(Map<String, dynamic>.from(maps.first));
      }
      if (decoded is Map) {
        return _expandNfcMap(Map<String, dynamic>.from(decoded));
      }
      return null;
    }
    if (raw.startsWith('{')) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('Read_info') &&
          decoded.containsKey('Visits')) {
        return decoded;
      }
    }
  } catch (e) {
    debugPrint('⚠️ nfcDecode error: $e');
  }
  return null;
}

/// Decodifica el contenido de un tag a una LISTA de registros canónicos.
///
/// Un tag de destino puede acumular varios productos (uno por RFID de origen).
/// Soporta: objeto único (canónico / N1 / C1 / multi-chunk) y array de registros
/// (canónico o comprimido N1/C1). Retorna [] si está vacío o es irreconocible.
List<Map<String, dynamic>> decodeNfcRecords(String raw) {
  if (raw.isEmpty || raw.trim() == '0') return const [];

  // Multi-chunk PRIMERO: el primer chunk puede venir con prefijo N1/C1, así que
  // debe delegarse a decodeMultiChunk ANTES del branch comprimido — de lo
  // contrario jsonDecode falla en el delimitador \x1E seguido de los deltas 'V:'.
  if (isMultiChunkFormat(raw)) {
    final m = decodeMultiChunk(raw);
    return m != null ? [m] : const [];
  }

  // Formato comprimido/minificado: el payload puede ser objeto o array.
  if (raw.startsWith(_kPrefixCompressed) || raw.startsWith(_kPrefixMinified)) {
    try {
      final String minJson;
      if (raw.startsWith(_kPrefixCompressed)) {
        final b64 = raw.substring(_kPrefixCompressed.length);
        final compressed = base64Url.decode(_addBase64Padding(b64));
        minJson = utf8.decode(ZLibCodec().decode(compressed));
      } else {
        minJson = raw.substring(_kPrefixMinified.length);
      }
      final decoded = jsonDecode(minJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => _expandNfcMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (decoded is Map) {
        return [_expandNfcMap(Map<String, dynamic>.from(decoded))];
      }
    } catch (e) {
      debugPrint('⚠️ decodeNfcRecords (comprimido): $e');
    }
    return const [];
  }

  // Array JSON plano (registros canónicos)
  final trimmed = raw.trimLeft();
  if (trimmed.startsWith('[')) {
    try {
      final list = jsonDecode(trimmed) as List;
      return list.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        // Canónico (tiene Read_info) → tal cual; si viniera minificado → expandir.
        return m.containsKey('Read_info') ? m : _expandNfcMap(m);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ decodeNfcRecords (array plano): $e');
    }
    return const [];
  }

  // Objeto único canónico
  final single = parseNfcJson(raw);
  return single != null ? [single] : const [];
}

/// Inyecta el bloque status.visits_details (respuestas del formulario) en CADA
/// registro del contenido de origen (objeto único o array). Reutiliza
/// [decodeNfcRecords] para soportar canónico / N1 / C1 / array. Devuelve canónico:
/// objeto único si hay 1 registro, array JSON si hay varios. Si el contenido no
/// es JSON reconocible, lo devuelve sin cambios.
String injectFormStatus(
    String sourceContent, List<Map<String, dynamic>> visitsDetails) {
  final records = decodeNfcRecords(sourceContent);
  if (records.isEmpty) return sourceContent;
  for (final rec in records) {
    rec['status'] = {'visits_details': visitsDetails};
  }
  return records.length == 1 ? jsonEncode(records.first) : jsonEncode(records);
}

/// Codifica una LISTA de registros canónicos al string para escribir en el tag.
/// - 1 registro  → delega en [nfcEncode] (compat: objeto único N1/C1).
/// - 2+ registros → array minificado: comprimido (C1) o plano (N1) según tamaño.
/// Fallback a jsonEncode canónico si algo falla.
String nfcEncodeRecords(List<Map<String, dynamic>> records) {
  if (records.isEmpty) return '';
  if (records.length == 1) return nfcEncode(records.first);
  try {
    final minList = records.map(_minifyNfcMap).toList();
    final minJson = jsonEncode(minList);
    final minBytes = utf8.encode(minJson);
    if (minBytes.length <= _kCompressionThreshold) {
      return '$_kPrefixMinified$minJson';
    }
    final compressed = ZLibCodec(level: 6).encode(minBytes);
    final b64 = base64Url.encode(compressed).replaceAll('=', '');
    return '$_kPrefixCompressed$b64';
  } catch (e) {
    debugPrint('⚠️ nfcEncodeRecords error: $e — fallback a jsonEncode');
    return jsonEncode(records);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Construye el JSON inicial para un nuevo tag
/// [tagFrom] RFID de origen: para tag-reader = RFID leído, para tag-writer = '', para tag-transfer = RFID origen
/// [tagTo]   RFID de destino: para tag-reader = '', para tag-writer = RFID escrito, para tag-transfer = RFID destino
/// [userId]  ID del usuario activo en AppState (FFAppState().userSelected.idUser)
Map<String, dynamic> buildInitialNfcJson({
  required int idProduct,
  required String rfid,
  required String nameProduct,
  String tagFrom = '',
  String tagTo = '',
  int userId = 0,
}) {
  return {
    'Read_info': {
      'Id_product': idProduct,
      'RFID': rfid,
      'Name_product': nameProduct,
      'Date_created': DateTime.now().toIso8601String(),
      'tag_from': tagFrom,
      'tag_to': tagTo,
      'US': userId,
    },
    'Visits': [],
  };
}

/// Actualiza la información Read_info con nueva fecha y datos del producto
Map<String, dynamic> updateReadInfo(
  Map<String, dynamic> nfcJson, {
  required int idProduct,
  required String rfid,
  required String nameProduct,
  String tagFrom = '',
  String tagTo = '',
  int userId = 0,
}) {
  nfcJson['Read_info'] = {
    'Id_product': idProduct,
    'RFID': rfid,
    'Name_product': nameProduct,
    'Date_created': DateTime.now().toIso8601String(),
    'tag_from': tagFrom,
    'tag_to': tagTo,
    'US': userId,
  };
  return nfcJson;
}

/// Agrega una nueva visita al array de Visits
Map<String, dynamic> addVisitToNfcJson(
  Map<String, dynamic> nfcJson, {
  required int operatorId,
  required int visits,
  required int results,
  required int headquarterId,
  DateTime? dateTime,
}) {
  final visitEntry = {
    'DH': (dateTime ?? DateTime.now()).toIso8601String(),
    'OP': operatorId,
    'VISITS': visits,
    'RESULTS': results,
    'HE': headquarterId,
  };

  if (nfcJson['Visits'] == null) {
    nfcJson['Visits'] = [];
  }

  (nfcJson['Visits'] as List).add(visitEntry);

  return nfcJson;
}

/// Parsea un string JSON del tag NFC en cualquier formato (multi-chunk, N1, C1, canónico) al Map canónico.
/// Retorna null si el contenido no es un JSON válido
Map<String, dynamic>? parseNfcJson(String nfcContent) {
  if (isMultiChunkFormat(nfcContent)) return decodeMultiChunk(nfcContent);
  if (isNfcCompressedFormat(nfcContent)) return nfcDecode(nfcContent);
  try {
    final decoded = jsonDecode(nfcContent);
    if (decoded is Map<String, dynamic>) {
      // Validar que tenga la estructura esperada
      if (decoded.containsKey('Read_info') && decoded.containsKey('Visits')) {
        return decoded;
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error parseando JSON del NFC: $e');
  }
  return null;
}

/// Convierte el Map del JSON a String para escribir en el tag
String nfcJsonToString(Map<String, dynamic> nfcJson) {
  return jsonEncode(nfcJson);
}

/// Extrae la lista de visitas del JSON en un formato compatible con la UI
/// Retorna una lista de Maps con los campos parseados
List<Map<String, dynamic>> extractVisitsFromJson(Map<String, dynamic> nfcJson) {
  final List<Map<String, dynamic>> parsedVisits = [];

  if (nfcJson['Visits'] == null) {
    return parsedVisits;
  }

  final visits = nfcJson['Visits'] as List;

  for (var visit in visits) {
    if (visit is! Map<String, dynamic>) continue;

    // Parsear fecha ISO 8601
    DateTime dateTime = DateTime.now();
    try {
      final dhStr = visit['DH'] as String?;
      if (dhStr != null && dhStr.isNotEmpty) {
        dateTime = DateTime.parse(dhStr);
      }
    } catch (e) {
      debugPrint('⚠️ Error parseando fecha: $e');
    }

    parsedVisits.add({
      'operatorId': visit['OP']?.toString() ?? '',
      'operator2Id': '', // No usado en el nuevo formato
      'visits': visit['VISITS'] ?? 0,
      'results': visit['RESULTS'] ?? 0,
      'headquarterId': visit['HE'] ?? 0,
      'dateTime': dateTime,
    });
  }

  return parsedVisits;
}

/// Agrupa visitas por headquarterId para el resumen de tag-writer
/// Retorna un Map con headquarterId como key y datos agrupados como value
Map<int, Map<String, dynamic>> groupVisitsByHeadquarter(
    List<Map<String, dynamic>> visits) {
  final Map<int, Map<String, dynamic>> grouped = {};

  for (var visit in visits) {
    final headquarterId = visit['headquarterId'] as int? ?? 0;
    if (headquarterId == 0) continue;

    if (!grouped.containsKey(headquarterId)) {
      grouped[headquarterId] = {
        'totalVisits': 0,
        'totalResults': 0,
        'records': <Map<String, dynamic>>[],
      };
    }

    grouped[headquarterId]!['totalVisits'] =
        (grouped[headquarterId]!['totalVisits'] as int) + (visit['visits'] as int? ?? 0);
    grouped[headquarterId]!['totalResults'] =
        (grouped[headquarterId]!['totalResults'] as int) + (visit['results'] as int? ?? 0);
    (grouped[headquarterId]!['records'] as List).add(visit);
  }

  return grouped;
}

/// Valida si el contenido del tag tiene el formato JSON nuevo (multi-chunk, N1, C1 o canónico)
bool isNewJsonFormat(String nfcContent) {
  if (isMultiChunkFormat(nfcContent)) return true;
  if (isNfcCompressedFormat(nfcContent)) return true;
  try {
    final decoded = jsonDecode(nfcContent);
    if (decoded is Map<String, dynamic>) {
      return decoded.containsKey('Read_info') && decoded.containsKey('Visits');
    }
  } catch (e) {
    // No es JSON válido
  }
  return false;
}

/// Valida si el contenido es un array JSON (múltiples registros tag-transfer)
bool isJsonArrayFormat(String nfcContent) {
  try {
    return jsonDecode(nfcContent) is List;
  } catch (_) {
    return false;
  }
}

// ─── Idempotencia de visitas ──────────────────────────────────────────────────

/// Calcula un identificador estable y único para UN registro de producto del tag
/// (RFID de origen + sus visitas de campo). Sirve como clave de idempotencia:
/// re-leer el mismo tag (p.ej. uno que no se borró) produce el MISMO uid, de modo
/// que el guardado en BD puede deduplicar y no crear visitas repetidas.
///
/// - Acepta cualquier formato de entrada (canónico / N1 / C1 / multi-chunk).
/// - Solo usa campos INMUTABLES: el RFID del producto y, por cada visita,
///   (DH, OP, VISITS, RESULTS, HE). Excluye a propósito los campos volátiles que
///   se inyectan al leer/transferir (tag_to, US, Name_product, Id_product), que
///   cambian entre lecturas del mismo contenido.
/// - Si el registro trae varios productos, calcula el uid del PRIMERO; en el
///   flujo de báscula cada elemento se guarda por separado, así que se llama una
///   vez por registro de producto.
///
/// Retorna '' si el contenido no es un registro reconocible (en ese caso el
/// llamador debe insertar sin deduplicar, para nunca DESCARTAR información).
String computeVisitUid(String recordContent) {
  final records = decodeNfcRecords(recordContent);
  if (records.isEmpty) return '';
  return _uidForRecord(records.first);
}

String _uidForRecord(Map<String, dynamic> rec) {
  final ri = rec['Read_info'] as Map<String, dynamic>?;
  // RFID inmutable del producto; fallback a tag_from (RFID físico del origen).
  final rfidRaw = (ri?['RFID'] as String?)?.trim() ?? '';
  final rfid = rfidRaw.isNotEmpty
      ? rfidRaw
      : ((ri?['tag_from'] as String?)?.trim() ?? '');
  final visits = (rec['Visits'] as List?) ?? const [];
  final sb = StringBuffer('R:$rfid');
  for (final v in visits) {
    if (v is! Map) continue;
    sb.write(
        '|${v['DH']};${v['OP']};${v['VISITS']};${v['RESULTS']};${v['HE']}');
  }
  return _stableHashHex(sb.toString());
}

/// Hash determinístico y estable (FNV-1a 32-bit con 4 semillas → 128-bit hex).
/// Sin dependencias externas y con idéntica semántica en Android y Windows.
/// Todas las operaciones se enmascaran a 32 bits (siempre positivas en Dart),
/// evitando el problema de signo de los enteros de 64 bits al formatear a hex.
String _stableHashHex(String input) {
  final bytes = utf8.encode(input);
  const seeds = [0, 0x9e3779b9, 0x7f4a7c15, 0x2545f491];
  final buf = StringBuffer();
  for (final seed in seeds) {
    int h = (2166136261 ^ seed) & 0xFFFFFFFF;
    for (final b in bytes) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    buf.write(h.toRadixString(16).padLeft(8, '0'));
  }
  return buf.toString();
}
