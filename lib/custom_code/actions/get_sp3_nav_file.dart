// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Obtiene la ruta local del archivo RINEX NAV diario.
///
/// - Intenta con DOI de hoy, si falla retrocede día a día (hasta 6 días
/// atrás). - Si tras 7 intentos sigue sin encontrarlo, lanza excepción. Se
/// guardará en la misma carpeta que el persistent_id.txt: …/ClickPalmData
Future<String> getSp3NavFile(BuildContext context) async {
  // 1) Pedir permisos
  final ok = await _checkAndRequestStoragePermissions(context);
  if (!ok) {
    throw Exception('Permisos de almacenamiento denegados');
  }

  // 2) Carpeta base compartida con el .txt
  final basePath = await _getBestDocumentsPath();
  final baseDir = Directory(basePath);

  // 3) Limpiar .gz y .SP3 antiguos de la carpeta base
  for (final f in baseDir.listSync().whereType<File>()) {
    final ext = p.extension(f.path).toLowerCase();
    if (ext == '.gz' || ext.toLowerCase() == '.sp3') {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  // 4) Cálculos base de GPS
  final nowUtc = DateTime.now().toUtc();
  final gpsEpoch = DateTime.utc(1980, 1, 6);
  final gpsWeek = nowUtc.difference(gpsEpoch).inSeconds ~/ 604800;

  const maxRetroceso = 6;
  const String _earthdataToken =
      'eyJ0eXAiOiJKV1QiLCJvcmlnaW4iOiJFYXJ0aGRhdGEgTG9naW4iLCJzaWciOiJlZGxqd3RwdWJrZXlfb3BzIiwiYWxnIjoiUlMyNTYifQ.eyJ0eXBlIjoiVXNlciIsInVpZCI6ImpkaWVnbzk3MDgiLCJleHAiOjE3NTI0MjgxMTgsImlhdCI6MTc0NzI0NDExOCwiaXNzIjoiaHR0cHM6Ly91cnMuZWFydGhkYXRhLm5hc2EuZ292IiwiaWRlbnRpdHlfcHJvdmlkZXIiOiJlZGxfb3BzIiwiYWNyIjoiZWRsIiwiYXNzdXJhbmNlX2xldmVsIjozfQ.wRnvqTgJdImbLNhZfiAfePQ3ySq5B6rGAk7R1mxBWcbardUTroCfcZKAsL38T6Qk1qtxDPxrXKTfIAaGBA2ymikwCRJB1xcInyocgnXBuWqvCNFor95-gPPRuwG9yppwkiUZz9ADwLmL1bM3rOGtEL4JOBDBUAaTQqDpuGpvwaw_zobpZ0DUc1usmruMxALKHJYi_AmovdczLKccJHqibQSfkG0PXQiCuifVpkn7V9kkG6xOjDEl26zFeC7Uuy0NWLmQeiRRYeJRgCppp0eGJ5tQN2BDHpwuk5oBM4E9PWKukR6AnlXVAD7sAziTwNGNaLz1R9tR8ZE9Artjt-i6kA';

  // 5) Bucle de descarga/descompresión
  for (int offset = 0; offset <= maxRetroceso; offset++) {
    final targetDate = nowUtc.subtract(Duration(days: offset));
    final doy =
        (targetDate.difference(DateTime(targetDate.year, 1, 1)).inDays + 1)
            .toString()
            .padLeft(3, '0');
    final year = targetDate.year.toString();

    final gzName = 'COD0OPSRAP_${year}${doy}0000_01D_05M_ORB.SP3.gz';
    final sp3Name = gzName.replaceAll('.gz', '');
    final url = Uri.parse('https://cddis.nasa.gov/archive/gnss/products/'
        '$gpsWeek/$gzName');

    print('🔗 Intentando descargar ($offset): $url');
    final resp = await http.get(url, headers: {
      'Authorization': 'Bearer $_earthdataToken',
    });
    if (resp.statusCode != 200) {
      print('⚠️ Código ${resp.statusCode}, probando día anterior...');
      continue;
    }

    // 6) Guardar .gz en carpeta base
    final gzFile = File(p.join(baseDir.path, gzName));
    await gzFile.writeAsBytes(resp.bodyBytes, flush: true);

    // 7) Descomprimir
    List<int> decompressed;
    try {
      decompressed = GZipCodec().decode(await gzFile.readAsBytes());
    } catch (e) {
      await gzFile.delete();
      print('❌ Error al descomprimir: $e');
      continue;
    }

    // 8) Guardar .SP3 en la misma carpeta base
    final sp3File = File(p.join(baseDir.path, sp3Name));
    await sp3File.writeAsBytes(decompressed, flush: true);

    // 9) Borrar .gz para ahorro
    try {
      await gzFile.delete();
    } catch (_) {}

    print('✅ Archivo SP3 listo en: ${sp3File.path}');
    return sp3File.path;
  }

  throw Exception('No se encontró archivo SP3 válido en los últimos '
      '${maxRetroceso + 1} días para la semana $gpsWeek');
}

/// Verifica y solicita permisos de almacenamiento
Future<bool> _checkAndRequestStoragePermissions(BuildContext context) async {
  if (!Platform.isAndroid) return true;
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdk = androidInfo.version.sdkInt;
  if (sdk >= 30) {
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    final res = await Permission.manageExternalStorage.request();
    return res.isGranted;
  }
  final status = await Permission.storage.status;
  if (status.isGranted) return true;
  final res = await Permission.storage.request();
  return res.isGranted;
}

/// Carpeta base compartida: /storage/emulated/0/ClickPalmData
Future<String> _getBestDocumentsPath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final path = p.join(baseDir.path, 'ClickPalmData');
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
