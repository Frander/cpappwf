// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:raw_gnss_flutter/raw_gnss.dart';
import 'package:raw_gnss_flutter/gnss_measurement_model.dart';
import 'package:nmea/nmea.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'package:collection/collection.dart';
import 'package:vector_math/vector_math_64.dart';

/// Principal: devuelve lista de strings con "LAT:...;LON:...;ALT:...;ERH:..."
Future<List<String>> getLocationList(int seconds, String navFilePath) async {
  // Parsear efemérides
  final ephMap = await _parseNavFile(navFilePath);

  // Recoger mediciones GNSS
  final meas = await _collectRawGnssMeasurements(seconds);
  if (meas.isEmpty) {
    throw Exception('No se obtuvieron mediciones GNSS');
  }

  // Calcular posiciones satélite usando efemérides en lugar de stub
  final satPos = meas.map((m) {
    final eph = ephMap[m.svid] ??
        (throw Exception('No hay efeméride para SVID ${m.svid}'));
    return _computeSatellitePositionFromNav(m, eph);
  }).toList();

  final sol = _solveLeastSquares(meas, satPos);
  final geo = _ecefToGeodetic(sol.x, sol.y, sol.z);
  final erh = _computeErh(sol, meas, satPos);

  final entry = "LAT:${geo.latitude.toStringAsFixed(6)};"
      "LON:${geo.longitude.toStringAsFixed(6)};"
      "ALT:${geo.altitude.toStringAsFixed(2)};"
      "ERH:${erh.toStringAsFixed(2)}";
  return [entry];
}

/// Clase para almacenar parámetros de efemérides RINEX NAV
typedef EpochTime = double; // segundos desde semana GPS o referencia

class EphemerisRecord {
  final int svid;
  final double toc; // Time of clock
  final double af0, af1, af2; // clock correction
  final double crs, deltaN, m0;
  final double cuc, e, cus;
  final double sqrtA;
  final double toe;
  final double cic, omega0, cis;
  final double i0;
  final double crc, omega, omegaDot, idot;
  EphemerisRecord({
    required this.svid,
    required this.toc,
    required this.af0,
    required this.af1,
    required this.af2,
    required this.crs,
    required this.deltaN,
    required this.m0,
    required this.cuc,
    required this.e,
    required this.cus,
    required this.sqrtA,
    required this.toe,
    required this.cic,
    required this.omega0,
    required this.cis,
    required this.i0,
    required this.crc,
    required this.omega,
    required this.omegaDot,
    required this.idot,
  });
}

/// ==================== Parser RINEX NAV ========================
/// Lee archivo .nav RINEX 2 o 3 y retorna mapa SVID -> EphemerisRecord
Future<Map<int, EphemerisRecord>> _parseNavFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Archivo RINEX NAV no encontrado: $filePath');
  }
  final lines = await file.readAsLines();
  final Map<int, EphemerisRecord> eph = {};
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Primer registro de efeméride comienza con satélite y tiempo
    if (line.length >= 3 && int.tryParse(line.substring(0, 2).trim()) != null) {
      final svid = int.parse(line.substring(0, 2).trim());
      // RINEX 2.11 formato fijo 3 líneas por efeméride
      final l1 = line;
      final l2 = lines[++i];
      final l3 = lines[++i];
      final l4 = lines[++i];
      // Extraer parámetros según columnas (valores en notación D para exponente)
      double parseD(String s) => double.parse(s.replaceAll('D', 'E'));
      final af0 = parseD(l1.substring(22, 41));
      final af1 = parseD(l1.substring(41, 60));
      final af2 = parseD(l1.substring(60, 79));
      final toc = parseD(l1.substring(3, 22));
      final crs = parseD(l2.substring(3, 22));
      final deltaN = parseD(l2.substring(22, 41));
      final m0 = parseD(l2.substring(41, 60));
      final cuc = parseD(l3.substring(3, 22));
      final e = parseD(l3.substring(22, 41));
      final cus = parseD(l3.substring(41, 60));
      final sqrtA = parseD(l3.substring(60, 79));
      final toe = parseD(l4.substring(3, 22));
      final cic = parseD(l4.substring(22, 41));
      final omega0 = parseD(l4.substring(41, 60));
      final cis = parseD(l4.substring(60, 79));
      // Leer línea 5 y 6 para completar los parámetros
      final l5 = lines[++i];
      final l6 = lines[++i];
      final i0 = parseD(l5.substring(3, 22));
      final crc = parseD(l5.substring(41, 60));
      final omega = parseD(l5.substring(60, 79));
      final omegaDot = parseD(l6.substring(22, 41));
      final idot = parseD(l6.substring(41, 60));
      eph[svid] = EphemerisRecord(
        svid: svid,
        toc: toc,
        af0: af0,
        af1: af1,
        af2: af2,
        crs: crs,
        deltaN: deltaN,
        m0: m0,
        cuc: cuc,
        e: e,
        cus: cus,
        sqrtA: sqrtA,
        toe: toe,
        cic: cic,
        omega0: omega0,
        cis: cis,
        i0: i0,
        crc: crc,
        omega: omega,
        omegaDot: omegaDot,
        idot: idot,
      );
    }
  }
  return eph;
}

/// ==================== Cálculo Posición desde efeméride ========================
Vector3 _computeSatellitePositionFromNav(
    SatelliteMeasurement meas, EphemerisRecord eph) {
  // Tiempo de transmisión aproximado (segundos GPS)
  final tRxSec = meas.tRxNanos * 1e-9;
  var dt = tRxSec - eph.toe;
  // Corregir rollover semanal
  if (dt > 302400) dt -= 604800;
  if (dt < -302400) dt += 604800;

  final a = eph.sqrtA * eph.sqrtA;
  final n0 = sqrt(3986005e8 / (a * a * a));
  final n = n0 + eph.deltaN;
  var M = eph.m0 + n * dt;

  // Resolver anomalía excéntrica con iteración
  var E = M;
  for (int i = 0; i < 10; i++) {
    E = M + eph.e * sin(E);
  }

  final v = atan2(sqrt(1 - eph.e * eph.e) * sin(E), cos(E) - eph.e);
  final phi = v + eph.omega;

  final u = phi + eph.cuc * cos(2 * phi) + eph.cus * sin(2 * phi);
  final r = a * (1 - eph.e * cos(E)) +
      eph.crc * cos(2 * phi) +
      eph.crs * sin(2 * phi);
  final i =
      eph.i0 + eph.idot * dt + eph.cic * cos(2 * phi) + eph.cis * sin(2 * phi);

  final xOrb = r * cos(u);
  final yOrb = r * sin(u);

  final Omega = eph.omega0 +
      (eph.omegaDot - 7.2921151467e-5) * dt -
      7.2921151467e-5 * eph.toe;

  final x = xOrb * cos(Omega) - yOrb * cos(i) * sin(Omega);
  final y = xOrb * sin(Omega) + yOrb * cos(i) * cos(Omega);
  final z = yOrb * sin(i);

  return Vector3(x, y, z);
}

/// ==================== Medición ========================

class SatelliteMeasurement {
  final int svid;
  final double pseudorange; // m
  final double carrierPhase; // m
  final double cn0; // dB-Hz
  final int tRxNanos; // recibidos

  SatelliteMeasurement({
    required this.svid,
    required this.pseudorange,
    required this.carrierPhase,
    required this.cn0,
    required this.tRxNanos,
  });

  /// Crea desde GnssMeasurementModel + Measurement
  factory SatelliteMeasurement.fromMeasurement(
    GnssMeasurementModel model,
    Measurement m,
  ) {
    const c = 299792458.0; // velocidad de la luz (m/s)

    // Aseguramos que el reloj exista
    final clk = model.clock ?? (throw Exception('Clock GNSS nulo'));

    // tiempo de recepción (ns) = clock.timeNanos + measurement.timeOffsetNanos
    final tRxNs = clk.timeNanos! + (m.timeOffsetNanos ?? 0.0);
    final tRxSec = tRxNs * 1e-9;

    final fullBiasSec = clk.fullBiasNanos! * 1e-9;
    final biasSec = clk.biasNanos! * 1e-9;

    // tiempo de transmisión (s)
    final tTxSec = (m.receivedSvTimeNanos ?? 0) * 1e-9;

    // pseudorango en metros
    final pseudorange = c * ((tRxSec - fullBiasSec - biasSec) - tTxSec);

    return SatelliteMeasurement(
      svid: m.svid ?? 0,
      pseudorange: pseudorange,
      carrierPhase: m.accumulatedDeltaRangeMeters ?? 0.0,
      cn0: m.cn0DbHz ?? 0.0,
      tRxNanos: m.receivedSvTimeNanos ?? 0,
    );
  }
}

/// ==================== Recolección ========================

Future<List<SatelliteMeasurement>> _collectRawGnssMeasurements(
  int seconds,
) async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Servicios de ubicación deshabilitados');
  }

  final measBuffer = <SatelliteMeasurement>[];
  final sub =
      RawGnss().gnssMeasurementEvents.listen((GnssMeasurementModel evt) {
    for (final m in evt.measurements ?? <Measurement>[]) {
      measBuffer.add(SatelliteMeasurement.fromMeasurement(evt, m));
    }
  });

  await Future.delayed(Duration(seconds: seconds));
  await sub.cancel();
  return measBuffer;
}

/// =================== Solver PVT =========================

class PositionSolution {
  final double x, y, z, clkBias;
  PositionSolution(this.x, this.y, this.z, this.clkBias);
}

PositionSolution _solveLeastSquares(
  List<SatelliteMeasurement> obs,
  List<Vector3> satPos,
) {
  final N = obs.length;
  final AtA = Float64List(16);
  final Atb = Float64List(4);

  for (var i = 0; i < N; i++) {
    final o = obs[i];
    final r = satPos[i];
    final dx = r.x, dy = r.y, dz = r.z;
    final range = sqrt(dx * dx + dy * dy + dz * dz);
    final H = [-dx / range, -dy / range, -dz / range, 1.0];
    final w = pow(o.cn0 / 100.0, 2).toDouble();
    final delta = o.pseudorange - range;

    for (var m = 0; m < 4; m++) {
      Atb[m] += w * H[m] * delta;
      for (var n = 0; n < 4; n++) {
        AtA[m * 4 + n] += w * H[m] * H[n];
      }
    }
  }

  final mat = Matrix4.fromList(AtA)..invert();
  final sol = Vector4.zero();
  for (var i = 0; i < 4; i++) {
    sol[i] = mat.entry(i, 0) * Atb[0] +
        mat.entry(i, 1) * Atb[1] +
        mat.entry(i, 2) * Atb[2] +
        mat.entry(i, 3) * Atb[3];
  }
  return PositionSolution(sol.x, sol.y, sol.z, sol.w);
}

extension _MatExt on Matrix4 {
  double entry(int row, int col) => storage[col * 4 + row];
}

/// ================== Conversión =========================

class GeodeticPosition {
  final double latitude, longitude, altitude;
  GeodeticPosition(this.latitude, this.longitude, this.altitude);
}

GeodeticPosition _ecefToGeodetic(double x, double y, double z) {
  const a = 6378137.0, f = 1 / 298.257223563;
  final b = a * (1 - f), e2 = (a * a - b * b) / (a * a);
  final p = sqrt(x * x + y * y);
  final theta = atan2(z * a, p * b);
  final sinT = sin(theta), cosT = cos(theta);
  final lat = atan2(
    z + e2 * b * pow(sinT, 3),
    p - e2 * a * pow(cosT, 3),
  );
  final lon = atan2(y, x);
  final N = a / sqrt(1 - e2 * pow(sin(lat), 2));
  final alt = p / cos(lat) - N;
  return GeodeticPosition(lat * 180 / pi, lon * 180 / pi, alt);
}

/// ================== Error Remedio ======================

double _computeErh(
  PositionSolution sol,
  List<SatelliteMeasurement> obs,
  List<Vector3> satPos,
) {
  final N = obs.length;
  double sum = 0;
  for (var i = 0; i < N; i++) {
    final dx = satPos[i].x - sol.x;
    final dy = satPos[i].y - sol.y;
    final dz = satPos[i].z - sol.z;
    final pred = sqrt(dx * dx + dy * dy + dz * dz) + sol.clkBias;
    final err = obs[i].pseudorange - pred;
    sum += err * err;
  }
  return sqrt(sum / N);
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
