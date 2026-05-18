// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
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
/// - Si ya existe el archivo para la fecha de hoy, retorna su ruta.
/// - Si no existe o es de fecha distinta, elimina anteriores y descarga el nuevo desde los servidores más confiables.
Future<String> getRinexNavFile(BuildContext context) async {
  final ok = await _checkAndRequestStoragePermissions(context);
  if (!ok) {
    throw Exception('Permisos de almacenamiento denegados');
  }

  final dirPath = await _getBestDocumentsPath();
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final today = DateTime.now();
  final year = today.year;
  final month = _twoDigits(today.month);
  final day = _twoDigits(today.day);
  final fileName = 'RN_${year}_${month}_$day.nav';
  final filePath = p.join(dirPath, fileName);
  final file = File(filePath);

  if (await file.exists()) {
    return filePath;
  }

  for (final f in dir.listSync().whereType<File>()) {
    final name = p.basename(f.path);
    if (name.startsWith('RN_') && name.endsWith('.nav')) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  final List<String> servers = [
    'https://cddis.nasa.gov/archive/gnss/data/daily',
    'https://igs.bkg.bund.de/root_ftp/IGS',
    'https://www.unavco.org/data/gps-gnss/file-server/archive/gnss/nav',
    'https://geodesy.noaa.gov/CORS/data/daily',
    'https://epncb.oma.be/pub',
    'https://www.linz.govt.nz/files',
    'ftp://ftp-sweposdata.lm.se/Rinex-data/Rinex2/se_swepos_daily'
  ];

  final doy = today.difference(DateTime(today.year, 1, 1)).inDays + 1;
  final dayOfYear = doy.toString().padLeft(3, '0');

  for (final base in servers) {
    try {
      Uri url;
      if (base.contains('cddis')) {
        url = Uri.parse('$base/$year/$dayOfYear/brdc$dayOfYear.23n.Z');
      } else if (base.contains('unavco')) {
        url = Uri.parse('$base/$year/$dayOfYear/brdc$dayOfYear.23n.Z');
      } else {
        url = Uri.parse('$base/$year/$month/$fileName');
      }

      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        return filePath;
      }
    } catch (_) {
      continue;
    }
  }

  throw Exception(
      'No se pudo descargar RINEX NAV de ningún servidor confiable.');
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

Future<bool> _checkAndRequestStoragePermissions(BuildContext context) async {
  if (!Platform.isAndroid) return false;
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

Future<String> _getBestDocumentsPath() async {
  late Directory baseDir;
  if (Platform.isAndroid) {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
    baseDir = externalDir;
  } else {
    baseDir = await getApplicationDocumentsDirectory();
  }
  final path = p.join(baseDir.path, 'ClickPalmData', 'RINEXNAV');
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return path;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
