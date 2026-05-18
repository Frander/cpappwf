// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io'; // ✅ Importación para manejar archivos y directorios
import 'dart:async';
import 'package:dio/dio.dart'; // ✅ Importación para descargar archivos
import 'package:path_provider/path_provider.dart'; // ✅ Importación para manejar almacenamiento
import 'package:intl/intl.dart'; // ✅ Importación para formatear fechas
import 'package:archive/archive.dart'; // Para descomprimir archivos gzip

// -------------------------------------------------------------------
// Función principal: descarga y descomprime el SP3.
// -------------------------------------------------------------------
Future<String> downloadSp3Data() async {
  final dio = Dio();
  final dir = await getApplicationDocumentsDirectory();
  const baseProductsUrl = 'https://cddis.nasa.gov/archive/gnss/products';

  // 1) Averiguo la semana GPS completa (full week) y pruebo esa y la anterior
  final nowUtc = DateTime.now().toUtc();
  final gpsNow = utcToGpsWeekSec(nowUtc);
  final int gpsWeek = gpsNow[0] as int;
  debugPrint('→ Semana GPS actual (full): $gpsWeek');

  for (int weekOffset = 0; weekOffset <= 1; weekOffset++) {
    final weekTry = gpsWeek - weekOffset;
    final weekUrl = '$baseProductsUrl/$weekTry';
    debugPrint('Probando directorio GPS week: $weekTry');

    // 2) Para hoy, ayer, … hasta 6 días atrás
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final dateTry = nowUtc.subtract(Duration(days: dayOffset));
      final year = dateTry.year;
      final doy =
          int.parse(DateFormat('D').format(dateTry)).toString().padLeft(3, '0');

      // 3) Pruebo los inicios de archivo 18, 12, 06 y 00 UTC (ultra-rápido CODE)
      for (final hour in [18, 12, 6, 0]) {
        final hh = hour.toString().padLeft(2, '0');
        final fileName = 'COD0OPSULT_$year$doy${hh}0000_02D_05M_ORB.SP3.gz';
        final fileUrl = '$weekUrl/$fileName';

        debugPrint('  Intentando SP3: $fileUrl');
        try {
          final head = await dio.head(fileUrl);
          if (head.statusCode == 200) {
            // 4) Lo tenemos: descargo y descomprimo
            final gzPath = '${dir.path}/$fileName';
            debugPrint('  ↓ Descargando SP3 en $gzPath');
            final resp = await dio.get<List<int>>(
              fileUrl,
              options: Options(responseType: ResponseType.bytes),
            );
            await File(gzPath).writeAsBytes(resp.data!);
            return await _decompressGzip(gzPath);
          }
        } catch (e) {
          debugPrint('  ⚠️ No disponible $fileName: $e');
        }
      }
    }
  }

  debugPrint('🚨 No se pudo descargar ningún SP3 válido');
  throw Exception('No SP3 descargado');
}

Future<String> _decompressGzip(String gzFilePath) async {
  final gzFile = File(gzFilePath);
  if (!await gzFile.exists()) {
    debugPrint('❌ .gz no encontrado: $gzFilePath');
    throw Exception('Archivo no encontrado');
  }

  final bytes = await gzFile.readAsBytes();
  if (bytes[0] != 0x1F || bytes[1] != 0x8B) {
    debugPrint('❌ Firma GZip inválida en $gzFilePath');
    throw Exception('Formato erróneo');
  }

  final decompressed = GZipDecoder().decodeBytes(bytes);
  final outPath = gzFilePath.replaceAll('.gz', '');
  await File(outPath).writeAsBytes(decompressed);

  debugPrint('✔️ SP3 descomprimido en: $outPath');
  return outPath;
}

// -------------------------------------------------------------------
// Tu función de conversión GPS→UTC
// -------------------------------------------------------------------
List<Object> utcToGpsWeekSec(DateTime utc) {
  // … tu implementación existente que devuelve [week, secOfWeek]
  // por ejemplo: [2367, 348535.42]
  throw UnimplementedError();
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
