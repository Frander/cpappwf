// Pruebas de la capa SQLite (sin dispositivo) usando sqflite_common_ffi:
// migración v29→v31, índice único parcial de Visit_uid (idempotencia) y la
// semántica SQL del journal de transferencias.
//
// Ejecutar: flutter test test/nfc_db_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:click_palm_a_p_p/custom_code/actions/validate_db_sqlite.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// BD en memoria que simula una instalación vieja (v29: Visits mínima sin
  /// Visit_uid) y aplica la migración real hasta v31.
  Future<Database> migratedDb() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE Visits (Id_visit INTEGER PRIMARY KEY AUTOINCREMENT, Rfid TEXT)');
    await upgradeClickPalmDatabase(db, 29, 31);
    return db;
  }

  group('Migración v29 → v31', () {
    test('agrega columna Visit_uid a Visits', () async {
      final db = await migratedDb();
      final cols = await db.rawQuery('PRAGMA table_info(Visits)');
      expect(cols.any((c) => c['name'] == 'Visit_uid'), isTrue);
      await db.close();
    });

    test('crea la tabla Nfc_transfer_journal', () async {
      final db = await migratedDb();
      final t = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='Nfc_transfer_journal'");
      expect(t, isNotEmpty);
      await db.close();
    });
  });

  group('Idempotencia por Visit_uid', () {
    test('mismo uid no se duplica (INSERT OR IGNORE + índice único)', () async {
      final db = await migratedDb();
      await db.rawInsert(
          "INSERT OR IGNORE INTO Visits (Rfid, Visit_uid) VALUES ('A','uid1')");
      await db.rawInsert(
          "INSERT OR IGNORE INTO Visits (Rfid, Visit_uid) VALUES ('A','uid1')");
      final rows =
          await db.rawQuery("SELECT * FROM Visits WHERE Visit_uid='uid1'");
      expect(rows.length, 1);
      await db.close();
    });

    test('índice parcial: múltiples filas con Visit_uid NULL no colisionan',
        () async {
      final db = await migratedDb();
      await db.rawInsert("INSERT INTO Visits (Rfid) VALUES ('B')");
      await db.rawInsert("INSERT INTO Visits (Rfid) VALUES ('C')");
      final nulls =
          await db.rawQuery('SELECT * FROM Visits WHERE Visit_uid IS NULL');
      expect(nulls.length, 2);
      await db.close();
    });
  });

  group('Journal de transferencia (semántica SQL)', () {
    test('pending se encuentra por destino; al hacer commit desaparece',
        () async {
      final db = await migratedDb();
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('Nfc_transfer_journal', {
        'Op_type': 'transfer',
        'Rfid_dest': 'DEST1',
        'Content_merged': 'C1:xxx',
        'Expected_visits': 12,
        'State': 'pending',
        'Attempts': 0,
        'Created_at': now,
        'Updated_at': now,
      });

      final found = await db.rawQuery(
          "SELECT * FROM Nfc_transfer_journal WHERE Rfid_dest=? "
          "AND State IN ('pending','needs_retry') ORDER BY Updated_at DESC LIMIT 1",
          ['DEST1']);
      expect(found, isNotEmpty);
      expect(found.first['Expected_visits'], 12);

      await db.update('Nfc_transfer_journal', {'State': 'committed'},
          where: 'Rfid_dest=?', whereArgs: ['DEST1']);
      final found2 = await db.rawQuery(
          "SELECT * FROM Nfc_transfer_journal WHERE Rfid_dest=? "
          "AND State IN ('pending','needs_retry')",
          ['DEST1']);
      expect(found2, isEmpty);
      await db.close();
    });
  });
}
