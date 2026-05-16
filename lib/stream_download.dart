// Descarga HTTP en streaming + descompresión gzip al vuelo + escritura a
// archivo temporal. Elimina los picos de RAM de `http.get + gzip.decode`
// (que pueden superar 256 MB en endpoints grandes y matan al Dart VM en
// dispositivos de gama media-baja).
//
// Uso:
//   final r = await streamDownloadGzippedToTempFile(
//     url: uri,
//     headers: {'Authorization': 'Bearer $token'},
//     tagForLog: 'products',
//   );
//   if (r.statusCode == 200 && r.file != null) {
//     final json = await parseJsonFromFileInIsolate(r.file!.path);
//     ...
//     await r.file!.delete();
//   }
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:path_provider/path_provider.dart';

/// Resultado de [streamDownloadGzippedToTempFile].
///
/// Si [statusCode] == 200, [file] contiene el archivo temporal con el
/// cuerpo descomprimido. El caller debe borrarlo tras consumirlo.
/// En cualquier otro caso, [file] es null y [statusCode] indica el motivo
/// (401, 4xx, 5xx, o -1 ante un fallo de red/timeout).
class StreamDownloadResult {
  final File? file;
  final int statusCode;
  const StreamDownloadResult({required this.file, required this.statusCode});
}

/// Descarga la respuesta HTTP **descomprimiendo gzip al vuelo** y
/// volcando los chunks descomprimidos directamente a un archivo temporal.
/// Peak de RAM: ~64 KB por chunk en lugar de los ~330 MB del patrón
/// `http.get` + `gzip.decode(bodyBytes)`.
///
/// Si el servidor no envía gzip, `autoUncompress` simplemente no descomprime
/// y el archivo queda con el body raw — funciona igual.
Future<StreamDownloadResult> streamDownloadGzippedToTempFile({
  required Uri url,
  required Map<String, String> headers,
  required String tagForLog,
  Duration timeout = const Duration(minutes: 4),
}) async {
  final client = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = const Duration(seconds: 30);
  File? tmpFile;
  IOSink? sink;
  try {
    final req = await client.getUrl(url);
    headers.forEach((k, v) => req.headers.add(k, v));
    // HttpClient con autoUncompress=true ya añade `Accept-Encoding: gzip`.
    final resp = await req.close().timeout(timeout);
    if (resp.statusCode != 200) {
      // Drenar para liberar el socket; no nos interesa el body en este caso.
      await resp.drain<void>().catchError((_) {});
      return StreamDownloadResult(file: null, statusCode: resp.statusCode);
    }
    final tmpDir = await getTemporaryDirectory();
    tmpFile = File(
        '${tmpDir.path}/sync_${tagForLog}_${DateTime.now().millisecondsSinceEpoch}.json');
    sink = tmpFile.openWrite();
    await resp.pipe(sink);
    // resp.pipe cierra el sink al terminar — no llamar sink.close() de nuevo.
    sink = null;
    return StreamDownloadResult(file: tmpFile, statusCode: 200);
  } catch (e, st) {
    debugPrint('   ❌ streamDownload[$tagForLog] error: $e');
    debugPrint('   $st');
    // Limpieza: si quedó un sink abierto, ciérralo; si quedó un temp parcial,
    // bórralo para no dejar basura.
    if (sink != null) {
      try {
        await sink.close();
      } catch (_) {}
    }
    if (tmpFile != null) {
      try {
        await tmpFile.delete();
      } catch (_) {}
    }
    return const StreamDownloadResult(file: null, statusCode: -1);
  } finally {
    client.close(force: false);
  }
}

dynamic _parseJsonFile(String path) =>
    jsonDecode(File(path).readAsStringSync());

/// Parsea un archivo JSON en un isolate separado (vía `compute`) para no
/// bloquear el UI thread. El peak de RAM del parser se queda en el isolate
/// hijo y se libera al terminar.
Future<dynamic> parseJsonFromFileInIsolate(String path) =>
    compute(_parseJsonFile, path);
