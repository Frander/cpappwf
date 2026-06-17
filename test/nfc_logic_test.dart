// Pruebas de la lógica PURA de NFC (sin dispositivo, sin BD, sin platform
// channels): conteo de visitas, fusión deduplicada de transferencias,
// identidad idempotente (Visit_uid) y round-trip de compresión N1/C1 (base64).
//
// Ejecutar: flutter test test/nfc_logic_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:click_palm_a_p_p/custom_code/actions/nfc_json_helper.dart';

/// Construye un registro de producto canónico con una visita por cada OP.
String _content(
  String rfid,
  List<int> ops, {
  String? tagFrom,
  String tagTo = '',
  int us = 0,
  String name = 'Caja',
}) {
  return jsonEncode({
    'Read_info': {
      'Id_product': 1,
      'RFID': rfid,
      'Name_product': name,
      'Date_created': '2026-01-01T00:00:00.000',
      'tag_from': tagFrom ?? rfid,
      'tag_to': tagTo,
      'US': us,
    },
    'Visits': [
      for (final op in ops)
        {
          'DH': '2026-01-01T00:00:00.000',
          'OP': op,
          'VISITS': 1,
          'RESULTS': 1,
          'HE': 5,
        },
    ],
  });
}

void main() {
  group('countVisitsInContent', () {
    test('cuenta visitas en JSON canónico', () {
      expect(countVisitsInContent(_content('A', [1, 2, 3])), 3);
    });

    test('vacío / "0" → 0', () {
      expect(countVisitsInContent(''), 0);
      expect(countVisitsInContent('0'), 0);
    });

    test('contenido grande se comprime a C1 (base64) y se cuenta bien', () {
      final big = _content('A', List.generate(20, (i) => 100 + i));
      final enc = nfcEncode(jsonDecode(big) as Map<String, dynamic>);
      expect(enc.startsWith('C1:'), isTrue); // forzó compresión base64+zlib
      expect(countVisitsInContent(enc), 20); // se decodifica antes de contar
    });
  });

  group('mergeTransferContent (anti-pérdida / anti-duplicado)', () {
    test('origen 10 + destino 2 = 12', () {
      final origin = _content('AAA', List.generate(10, (i) => 100 + i));
      final dest = _content('BBB', [200, 201]);
      final merged = mergeTransferContent(origin, dest);
      expect(countVisitsInContent(merged), 12);
    });

    test('reintento: re-fusionar el resultado NO duplica (sigue 12)', () {
      final origin = _content('AAA', List.generate(10, (i) => 100 + i));
      final dest = _content('BBB', [200, 201]);
      final merged = mergeTransferContent(origin, dest);
      final retry = mergeTransferContent(origin, merged);
      expect(countVisitsInContent(retry), 12);
    });

    test('destino vacío / "0" → no pierde el origen (10)', () {
      final origin = _content('AAA', List.generate(10, (i) => 100 + i));
      expect(countVisitsInContent(mergeTransferContent(origin, '')), 10);
      expect(countVisitsInContent(mergeTransferContent(origin, '0')), 10);
    });

    test('mismo origen reabsorbido (dedup por tupla de visita)', () {
      // El destino ya contiene las visitas del origen → no se vuelven a sumar.
      final origin = _content('AAA', [1, 2, 3]);
      final merged1 = mergeTransferContent(origin, '');
      final merged2 = mergeTransferContent(origin, merged1);
      expect(countVisitsInContent(merged2), 3);
    });

    test('resultado va en formato de tag (N1/C1) y cuenta correcto', () {
      final origin = _content('AAA', List.generate(10, (i) => 100 + i));
      final dest = _content('BBB', [200, 201]);
      final merged = mergeTransferContent(origin, dest);
      expect(isNfcCompressedFormat(merged) || isMultiChunkFormat(merged), isTrue);
      expect(countVisitsInContent(merged), 12);
    });
  });

  group('computeVisitUid (idempotencia)', () {
    test('estable ante enriquecimiento (tag_to/US/Name_product)', () {
      final a = _content('AAA', [1], tagTo: '', us: 0, name: 'Caja');
      final b = _content('AAA', [1], tagTo: 'ZZZ', us: 99, name: 'Renombrada');
      expect(computeVisitUid(a), computeVisitUid(b));
    });

    test('cambia si cambian las visitas', () {
      expect(
        computeVisitUid(_content('AAA', [1])) ==
            computeVisitUid(_content('AAA', [2])),
        isFalse,
      );
    });

    test('contenido vacío → uid vacío', () {
      expect(computeVisitUid(''), '');
    });
  });

  group('round-trip nfcEncode/nfcDecode', () {
    test('preserva las visitas', () {
      final map = jsonDecode(_content('AAA', [1, 2, 3])) as Map<String, dynamic>;
      final dec = nfcDecode(nfcEncode(map));
      expect(dec, isNotNull);
      expect((dec!['Visits'] as List).length, 3);
    });
  });

  // ─── Compatibilidad con tags de ESTRUCTURA VIEJA (sin uid) ────────────────
  // El Visit_uid NO se guarda en el tag: se deriva del contenido. Un tag
  // escrito por una versión vieja (JSON plano, sin tag_from/tag_to/US y con el
  // campo legacy OP2) debe contarse, deduplicarse y fusionarse igual.
  group('Tags viejos sin uid', () {
    String oldContent(String rfid, int n, {bool withRfid = true}) {
      final readInfo = <String, dynamic>{
        'Id_product': 7,
        'Name_product': 'Caja vieja',
        'Date_created': '2025-01-01T00:00:00.000',
        // sin tag_from / tag_to / US (convención previa)
      };
      if (withRfid) readInfo['RFID'] = rfid;
      return jsonEncode({
        'Read_info': readInfo,
        'Visits': [
          for (var i = 0; i < n; i++)
            {
              'DH': '2025-01-0${(i % 9) + 1}T08:00:00.000',
              'OP': 50 + i,
              'OP2': 'op2-$i', // campo legacy
              'VISITS': 1,
              'RESULTS': 1,
              'HE': 3,
            },
        ],
      });
    }

    test('cuenta visitas en tag viejo (JSON plano + OP2)', () {
      expect(countVisitsInContent(oldContent('OLD', 10)), 10);
    });

    test('computeVisitUid es estable y no vacío en tag viejo', () {
      final c = oldContent('OLD', 10);
      expect(computeVisitUid(c).isNotEmpty, isTrue);
      expect(computeVisitUid(c), computeVisitUid(c)); // determinista
    });

    test('mismo tag viejo re-leído y enriquecido → mismo uid (dedup en báscula)',
        () {
      final viejo = oldContent('OLD', 5);
      // Simular el enriquecimiento que hace la lectura actual (tag_from/tag_to/US).
      final m = jsonDecode(viejo) as Map<String, dynamic>;
      (m['Read_info'] as Map)['tag_from'] = 'OLD';
      (m['Read_info'] as Map)['tag_to'] = 'DEST';
      (m['Read_info'] as Map)['US'] = 99;
      final enriquecido = jsonEncode(m);
      expect(computeVisitUid(viejo), computeVisitUid(enriquecido));
    });

    test('transferencia entre tags viejos: 10 + 2 = 12 y reintento no duplica',
        () {
      final origen = oldContent('OA', 10);
      final destino = oldContent('OB', 2);
      final merged = mergeTransferContent(origen, destino);
      expect(countVisitsInContent(merged), 12);
      expect(countVisitsInContent(mergeTransferContent(origen, merged)), 12);
    });

    test('interop: origen viejo (JSON plano) → destino nuevo (C1) suma bien', () {
      final origenViejo = oldContent('OA', 10);
      final destinoNuevo = nfcEncode(
          jsonDecode(_content('OB', [200, 201])) as Map<String, dynamic>);
      expect(destinoNuevo.startsWith('N1:') || destinoNuevo.startsWith('C1:'),
          isTrue);
      final merged = mergeTransferContent(origenViejo, destinoNuevo);
      expect(countVisitsInContent(merged), 12);
    });

    test('tag viejo SIN RFID: uid se deriva de las visitas (estable, no vacío)',
        () {
      final sinRfid = oldContent('', 4, withRfid: false);
      expect(countVisitsInContent(sinRfid), 4);
      expect(computeVisitUid(sinRfid).isNotEmpty, isTrue);
      expect(computeVisitUid(sinRfid), computeVisitUid(sinRfid));
    });
  });
}
