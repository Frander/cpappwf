// Pruebas del núcleo de escritura verificada con un tag SIMULADO, reproduciendo
// las fallas reales del NFC sin hardware: escritura que deja el tag corrupto,
// tag alejado a mitad (writeText lanza), y reintentos que recuperan.
//
// Ejecutar: flutter test test/nfc_write_verify_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:click_palm_a_p_p/custom_code/actions/nfc_gateway.dart';

/// Tag simulado con comportamiento programable.
class FakeTag implements NfcTagOps {
  @override
  final String tagId;
  @override
  final bool isWritable;

  String? stored;

  /// writeText lanza las primeras [failWritesTimes] veces (tag alejado/IOException).
  final int failWritesTimes;

  /// readText devuelve [corruptValue] las primeras [corruptReadsTimes] lecturas
  /// (escritura que "dijo OK" pero el tag quedó corrupto/parcial).
  final int corruptReadsTimes;
  final String corruptValue;

  int writeCalls = 0;
  int _corruptReads = 0;

  FakeTag({
    this.tagId = 'TAG1',
    this.isWritable = true,
    this.stored,
    this.failWritesTimes = 0,
    this.corruptReadsTimes = 0,
    this.corruptValue = 'CORRUPTO',
  });

  @override
  Future<void> writeText(String content) async {
    writeCalls++;
    if (writeCalls <= failWritesTimes) {
      throw Exception('IOException: tag was lost');
    }
    stored = content;
  }

  @override
  Future<String?> readText() async {
    if (_corruptReads < corruptReadsTimes) {
      _corruptReads++;
      return corruptValue;
    }
    return stored;
  }
}

void main() {
  group('writeTextVerified', () {
    test('escritura + verificación OK al primer intento', () async {
      final tag = FakeTag();
      final r = await writeTextVerified(tag, 'C1:datos');
      expect(r, NfcWriteOutcome.ok);
      expect(tag.stored, 'C1:datos');
      expect(tag.writeCalls, 1);
    });

    test('tag de solo lectura → notWritable (no intenta escribir)', () async {
      final tag = FakeTag(isWritable: false);
      final r = await writeTextVerified(tag, 'X');
      expect(r, NfcWriteOutcome.notWritable);
      expect(tag.writeCalls, 0);
    });

    test('tag alejado siempre (writeText lanza) → writeError', () async {
      final tag = FakeTag(failWritesTimes: 99);
      final r = await writeTextVerified(tag, 'X', attempts: 2);
      expect(r, NfcWriteOutcome.writeError);
      expect(tag.writeCalls, 2); // intentó las 2 veces
    });

    test('tag alejado una vez y luego OK → recupera (ok)', () async {
      final tag = FakeTag(failWritesTimes: 1);
      final r = await writeTextVerified(tag, 'X', attempts: 2);
      expect(r, NfcWriteOutcome.ok);
      expect(tag.stored, 'X');
    });

    test('escritura "OK" pero relectura corrupta siempre → notVerified', () async {
      final tag = FakeTag(corruptReadsTimes: 99);
      final r = await writeTextVerified(tag, 'X', attempts: 2);
      expect(r, NfcWriteOutcome.notVerified);
    });

    test('relectura corrupta una vez y luego OK → recupera (ok)', () async {
      // Simula escritura parcial que un reintento corrige.
      final tag = FakeTag(corruptReadsTimes: 1);
      final r = await writeTextVerified(tag, 'X', attempts: 2);
      expect(r, NfcWriteOutcome.ok);
      expect(tag.writeCalls, 2); // reescribió tras la relectura fallida
    });
  });
}
