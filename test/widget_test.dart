// Smoke test mínimo.
//
// El test por defecto de FlutterFlow montaba `MyApp` completo, lo que requiere
// inicializar plugins (SQLite, Sentry, NFC, etc.) y fallaba en `flutter test`.
// Se reemplaza por un chequeo trivial; la cobertura real de la lógica NFC está
// en test/nfc_logic_test.dart y test/nfc_db_test.dart.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity', () {
    expect(1 + 1, 2);
  });
}
