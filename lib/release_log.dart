import 'dart:io';

import 'package:flutter/foundation.dart';

File? _releaseLogFile;

/// Inicializa el archivo de log junto al ejecutable / en el directorio
/// privado del proceso. Debe llamarse al arranque, antes de cualquier
/// uso de [releaseLog]. Nunca lanza.
Future<void> initReleaseLog() async {
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    _releaseLogFile = File('$exeDir/clickpalm_crash.log');
    _releaseLogFile!.writeAsStringSync(
      '=== ClickPalm start ${DateTime.now().toIso8601String()} ===\n',
    );
  } catch (_) {
    _releaseLogFile = null;
  }
}

/// Escribe una entrada a `clickpalm_crash.log` y a `debugPrint`.
/// Seguro de llamar desde cualquier punto (setters, builders, listeners).
/// Nunca propaga excepciones — un fallo en el log no debe tumbar al caller.
void releaseLog(String tag, [Object? error, StackTrace? stack]) {
  final ts = DateTime.now().toIso8601String();
  final buffer = StringBuffer('$ts $tag');
  if (error != null) buffer.write(' :: $error');
  if (stack != null) buffer.write('\n$stack');
  final line = buffer.toString();
  try {
    debugPrint(line);
  } catch (_) {}
  try {
    _releaseLogFile?.writeAsStringSync('$line\n', mode: FileMode.append);
  } catch (_) {}
}
