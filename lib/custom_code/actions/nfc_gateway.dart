// Automatic FlutterFlow imports
// Imports custom functions
import 'package:flutter/foundation.dart' show debugPrint;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Abstracción de las operaciones de bajo nivel sobre UN tag NFC, independiente
/// de `nfc_manager`. En producción la implementa un adaptador que envuelve el
/// tag real; en pruebas se usa un tag simulado para reproducir fallas
/// (escritura que corrompe, tag alejado, etc.) sin hardware.
abstract class NfcTagOps {
  /// RFID/UID físico del tag en hex, o '' si no se pudo obtener.
  String get tagId;

  /// true si el tag admite escritura NDEF.
  bool get isWritable;

  /// Texto NDEF actual del tag (null si no hay contenido o es ilegible).
  Future<String?> readText();

  /// Escribe [content] como Text Record NDEF. Lanza si la escritura falla.
  Future<void> writeText(String content);
}

/// Resultado de [writeTextVerified].
enum NfcWriteOutcome {
  ok, // escrito y verificado por relectura
  notWritable, // el tag no admite escritura
  writeError, // la escritura lanzó error tras los reintentos
  notVerified, // se escribió sin error pero la relectura no coincide
}

/// Núcleo PURO de escritura verificada: escribe [content] y confirma por
/// relectura que el tag quedó EXACTAMENTE con ese contenido, reintentando hasta
/// [attempts] veces. No depende de nfc_manager ni de la plataforma, por lo que
/// se prueba con un [NfcTagOps] simulado para cubrir las fallas reales:
/// escritura que "dice OK" pero deja el tag corrupto, tag alejado a mitad, etc.
Future<NfcWriteOutcome> writeTextVerified(
  NfcTagOps tag,
  String content, {
  int attempts = 2,
}) async {
  if (!tag.isWritable) return NfcWriteOutcome.notWritable;
  for (var i = 1; i <= attempts; i++) {
    try {
      await tag.writeText(content);
    } catch (e) {
      debugPrint('⚠️ writeTextVerified: error de escritura (intento $i/$attempts): $e');
      if (i == attempts) return NfcWriteOutcome.writeError;
      continue; // reintentar la escritura
    }
    final readBack = await tag.readText();
    if (readBack == content) return NfcWriteOutcome.ok;
    debugPrint('⚠️ writeTextVerified: relectura no coincide (intento $i/$attempts)');
  }
  return NfcWriteOutcome.notVerified;
}
