// Automatic FlutterFlow imports
// Imports custom functions
import 'package:flutter/foundation.dart' show debugPrint;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';

/// Respaldo durable de operaciones de transferencia NFC (tabla
/// Nfc_transfer_journal). Permite verificar el resultado por total esperado de
/// visitas y reintentar DESDE EL RESPALDO (no desde el tag), sobreviviendo a
/// cierres de app o cortes de energía.

/// Estados posibles de una entrada del journal.
const String kJournalPending = 'pending';
const String kJournalCommitted = 'committed';
const String kJournalNeedsRetry = 'needs_retry';
const String kJournalFailed = 'failed';

/// Crea una entrada 'pending' ANTES de escribir el tag destino, guardando el
/// contenido de origen y destino + el resultado fusionado + el total esperado.
/// Retorna el Id_journal (o -1 si falló la inserción).
Future<int> startTransferJournal({
  String opType = 'transfer',
  required String rfidOrigin,
  required String contentOrigin,
  required String rfidDest,
  required String contentDestBefore,
  required String contentMerged,
  required int expectedVisits,
}) async {
  try {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await globalDb.executeOperation((db) => db.insert(
          'Nfc_transfer_journal',
          {
            'Op_type': opType,
            'Rfid_origin': rfidOrigin,
            'Rfid_dest': rfidDest,
            'Content_origin': contentOrigin,
            'Content_dest_before': contentDestBefore,
            'Content_merged': contentMerged,
            'Expected_visits': expectedVisits,
            'State': kJournalPending,
            'Attempts': 0,
            'Created_at': now,
            'Updated_at': now,
          },
        ));
    debugPrint(
        '🧾 Journal #$id creado (pending): origen=$rfidOrigin destino=$rfidDest esperado=$expectedVisits visitas');
    return id;
  } catch (e) {
    debugPrint('❌ startTransferJournal error: $e');
    return -1;
  }
}

/// Marca una entrada como 'committed' (transferencia verificada correctamente).
Future<void> markJournalCommitted(int idJournal) async {
  if (idJournal <= 0) return;
  await _updateJournalState(idJournal, kJournalCommitted, null);
  debugPrint('🧾 Journal #$idJournal → committed');
}

/// Marca una entrada como 'needs_retry' (no se verificó el total esperado),
/// guardando el mensaje y aumentando el contador de intentos.
Future<void> markJournalNeedsRetry(int idJournal, String message) async {
  if (idJournal <= 0) return;
  try {
    final now = DateTime.now().toUtc().toIso8601String();
    await globalDb.executeOperation((db) => db.rawUpdate(
          'UPDATE Nfc_transfer_journal SET State = ?, Message = ?, '
          'Attempts = Attempts + 1, Updated_at = ? WHERE Id_journal = ?',
          [kJournalNeedsRetry, message, now, idJournal],
        ));
    debugPrint('🧾 Journal #$idJournal → needs_retry ($message)');
  } catch (e) {
    debugPrint('❌ markJournalNeedsRetry error: $e');
  }
}

Future<void> _updateJournalState(
    int idJournal, String state, String? message) async {
  try {
    final now = DateTime.now().toUtc().toIso8601String();
    await globalDb.executeOperation((db) => db.update(
          'Nfc_transfer_journal',
          {'State': state, 'Message': message, 'Updated_at': now},
          where: 'Id_journal = ?',
          whereArgs: [idJournal],
        ));
  } catch (e) {
    debugPrint('❌ _updateJournalState error: $e');
  }
}

/// Busca el respaldo NO resuelto (pending / needs_retry) más reciente para un
/// tag DESTINO dado. Permite reintentar una transferencia DESDE EL RESPALDO:
/// si un intento previo dejó el destino vacío/parcial, se recupera el resultado
/// fusionado correcto sin depender de lo que quedó en el tag. Retorna null si no
/// hay respaldo pendiente para ese destino.
Future<Map<String, dynamic>?> findUnresolvedJournalForDest(
    String rfidDest) async {
  if (rfidDest.isEmpty) return null;
  try {
    final rows = await globalDb.executeOperation((db) => db.rawQuery(
          'SELECT * FROM Nfc_transfer_journal WHERE Rfid_dest = ? '
          'AND State IN (?, ?) ORDER BY Updated_at DESC LIMIT 1',
          [rfidDest, kJournalPending, kJournalNeedsRetry],
        ));
    return rows.isEmpty ? null : rows.first;
  } catch (e) {
    debugPrint('❌ findUnresolvedJournalForDest error: $e');
    return null;
  }
}

/// Devuelve las entradas no resueltas (pending / needs_retry), más recientes
/// primero. Útil para una vista de recuperación al reabrir la app.
Future<List<Map<String, dynamic>>> getPendingTransferJournals() async {
  try {
    return await globalDb.executeOperation((db) => db.rawQuery(
          "SELECT * FROM Nfc_transfer_journal WHERE State IN (?, ?) "
          'ORDER BY Updated_at DESC',
          [kJournalPending, kJournalNeedsRetry],
        ));
  } catch (e) {
    debugPrint('❌ getPendingTransferJournals error: $e');
    return const [];
  }
}
