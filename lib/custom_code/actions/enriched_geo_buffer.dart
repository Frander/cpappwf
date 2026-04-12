import 'dart:collection';
import 'dart:math';

// ============================================================================
// MODELO DE DATOS GPS ENRIQUECIDO
// ============================================================================

class EnrichedGeoPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double errorHorizontal;
  final DateTime timestamp;
  final double speed;
  final double heading;
  final double acceleration;
  final bool isStatic;
  final double vx;
  final double vy;
  final double ukfPositionError;
  final bool isBrushChange;

  const EnrichedGeoPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.errorHorizontal,
    required this.timestamp,
    required this.speed,
    required this.heading,
    required this.acceleration,
    required this.isStatic,
    required this.vx,
    required this.vy,
    required this.ukfPositionError,
    required this.isBrushChange,
  });
}

// ============================================================================
// BUFFER ENRIQUECIDO EN MEMORIA (Singleton)
// ============================================================================

class EnrichedGeoBuffer {
  static final EnrichedGeoBuffer _instance = EnrichedGeoBuffer._();
  factory EnrichedGeoBuffer() => _instance;
  EnrichedGeoBuffer._();

  final Queue<EnrichedGeoPoint> _buffer = Queue<EnrichedGeoPoint>();
  static const int maxSize = 60; // ~90 segundos a 1.5s/lectura

  void add(EnrichedGeoPoint point) {
    _buffer.addLast(point);
    if (_buffer.length > maxSize) _buffer.removeFirst();
  }

  List<EnrichedGeoPoint> getAll() => _buffer.toList();

  List<EnrichedGeoPoint> getLastSeconds(int seconds) {
    final cutoff = DateTime.now().subtract(Duration(seconds: seconds));
    return _buffer.where((p) => p.timestamp.isAfter(cutoff)).toList();
  }

  int get length => _buffer.length;

  void clear() => _buffer.clear();
}

// ============================================================================
// RESULTADO DE POSICIÓN ÓPTIMA
// ============================================================================

class OptimalPosition {
  final double latitude;
  final double longitude;
  final double altitude;
  final double errorHorizontal;
  final String method; // 'STATIONARY' o 'MOVING'
  final int pointsUsed;
  final int pointsRejected;

  const OptimalPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.errorHorizontal,
    required this.method,
    required this.pointsUsed,
    required this.pointsRejected,
  });
}

// ============================================================================
// CALCULADOR DE POSICIÓN ÓPTIMA
// ============================================================================

class OptimalPositionCalculator {
  /// Calcula UNA posición óptima a partir de múltiples lecturas enriquecidas.
  /// Requiere mínimo 3 puntos para funcionar.
  static OptimalPosition? compute(List<EnrichedGeoPoint> points) {
    if (points.length < 3) return null;

    // PASO 1: Rechazo de outliers con Modified Z-Score (MAD)
    final filtered = _rejectOutliers(points);
    if (filtered.length < 2) {
      // Si el rechazo fue demasiado agresivo, usar todos los puntos
      return _computeFromPoints(points, points.length - points.length);
    }

    return _computeFromPoints(filtered, points.length - filtered.length);
  }

  static OptimalPosition _computeFromPoints(
      List<EnrichedGeoPoint> points, int rejected) {
    // PASO 2: Detectar régimen de movimiento
    final avgSpeed =
        points.map((p) => p.speed).reduce((a, b) => a + b) / points.length;
    final staticCount = points.where((p) => p.isStatic).length;
    final staticRatio = staticCount / points.length;

    if (staticRatio > 0.7 || avgSpeed < 0.3) {
      return _stationaryFusion(points, rejected);
    } else {
      return _movingFusion(points, rejected);
    }
  }

  /// Rechazo de outliers usando Modified Z-Score basado en MAD
  /// (Median Absolute Deviation). Más robusto que Z-Score estándar.
  static List<EnrichedGeoPoint> _rejectOutliers(List<EnrichedGeoPoint> points) {
    final lats = points.map((p) => p.latitude).toList();
    final lons = points.map((p) => p.longitude).toList();

    final medLat = _median(lats);
    final medLon = _median(lons);

    // MAD = 1.4826 * median(|x_i - median(x)|)
    final madLat =
        1.4826 * _median(lats.map((v) => (v - medLat).abs()).toList());
    final madLon =
        1.4826 * _median(lons.map((v) => (v - medLon).abs()).toList());

    const threshold = 3.0;

    return points.where((p) {
      // Evitar división por cero si MAD es muy pequeño (todos los puntos iguales)
      final zLat =
          madLat > 1e-10 ? (p.latitude - medLat).abs() / madLat : 0.0;
      final zLon =
          madLon > 1e-10 ? (p.longitude - medLon).abs() / madLon : 0.0;
      return zLat < threshold && zLon < threshold;
    }).toList();
  }

  /// Fusión estacionaria: centroide ponderado con decay temporal.
  /// Caso principal: operador parado bajo la palma (~90% de visitas).
  static OptimalPosition _stationaryFusion(
      List<EnrichedGeoPoint> points, int rejected) {
    final now = DateTime.now();

    double totalWeight = 0.0;
    double wLat = 0.0;
    double wLon = 0.0;
    double wAlt = 0.0;
    double bestError = double.infinity;

    // Para cálculo de varianza ponderada
    final weights = <double>[];
    final latValues = <double>[];
    final lonValues = <double>[];

    for (final p in points) {
      final ageSeconds = now.difference(p.timestamp).inMilliseconds / 1000.0;

      // Peso por precisión: inversamente proporcional al error²
      final wAccuracy = 1.0 / (p.errorHorizontal * p.errorHorizontal + 0.01);

      // Peso temporal: decay exponencial, half-life 15 segundos
      final wTime = exp(-0.693 * ageSeconds / 15.0);

      // Bonus por lectura estática (más confiable cuando está quieto)
      final wStatic = p.isStatic ? 1.5 : 1.0;

      // Penalización por aceleración alta (teléfono moviéndose)
      final wAccel = 1.0 / (1.0 + p.acceleration);

      final w = wAccuracy * wTime * wStatic * wAccel;

      wLat += p.latitude * w;
      wLon += p.longitude * w;
      wAlt += p.altitude * w;
      totalWeight += w;

      weights.add(w);
      latValues.add(p.latitude);
      lonValues.add(p.longitude);

      if (p.errorHorizontal < bestError) {
        bestError = p.errorHorizontal;
      }
    }

    final lat = wLat / totalWeight;
    final lon = wLon / totalWeight;
    final alt = wAlt / totalWeight;

    // Error estimado: desviación estándar ponderada convertida a metros
    double varLat = 0.0;
    double varLon = 0.0;
    for (int i = 0; i < points.length; i++) {
      varLat += weights[i] * (latValues[i] - lat) * (latValues[i] - lat);
      varLon += weights[i] * (lonValues[i] - lon) * (lonValues[i] - lon);
    }
    varLat /= totalWeight;
    varLon /= totalWeight;

    // Convertir varianza en grados a metros (~111320 m/grado en el ecuador,
    // ajustado por cos(lat) para longitud - plantaciones de palma están cerca)
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLon = 111320.0 * cos(lat * pi / 180.0);
    final spatialErrorMeters = sqrt(
      varLat * metersPerDegreeLat * metersPerDegreeLat +
          varLon * metersPerDegreeLon * metersPerDegreeLon,
    );

    // Error final: el mayor entre la dispersión espacial y la mitad del mejor error individual
    // (no puede ser mejor que la mitad del mejor sensor individual)
    final finalError = max(spatialErrorMeters, bestError * 0.5);

    return OptimalPosition(
      latitude: lat,
      longitude: lon,
      altitude: alt,
      errorHorizontal: finalError,
      method: 'STATIONARY',
      pointsUsed: points.length,
      pointsRejected: rejected,
    );
  }

  /// Fusión en movimiento: regresión lineal ponderada + extrapolación.
  /// Para cuando el operador está caminando entre palmas.
  static OptimalPosition _movingFusion(
      List<EnrichedGeoPoint> points, int rejected) {
    // Ordenar por tiempo ascendente
    final sorted = List<EnrichedGeoPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Usar los últimos 5 puntos para extrapolación de trayectoria
    final recent = sorted.length > 5 ? sorted.sublist(sorted.length - 5) : sorted;
    final t0 = recent.first.timestamp;
    final now = DateTime.now();

    // Regresión lineal ponderada para lat y lon
    final times = recent
        .map((p) => p.timestamp.difference(t0).inMilliseconds / 1000.0)
        .toList();
    final lats = recent.map((p) => p.latitude).toList();
    final lons = recent.map((p) => p.longitude).toList();
    final weights =
        recent.map((p) => 1.0 / (p.errorHorizontal * p.errorHorizontal + 0.01)).toList();

    final fitLat = _weightedLinearFit(times, lats, weights);
    final fitLon = _weightedLinearFit(times, lons, weights);

    // Extrapolar al instante actual
    final tNow = now.difference(t0).inMilliseconds / 1000.0;
    final lat = fitLat.intercept + fitLat.slope * tNow;
    final lon = fitLon.intercept + fitLon.slope * tNow;

    // Altitud: media ponderada simple (no cambia mucho al caminar)
    double wAlt = 0.0;
    double totalW = 0.0;
    for (int i = 0; i < recent.length; i++) {
      wAlt += recent[i].altitude * weights[i];
      totalW += weights[i];
    }
    final alt = wAlt / totalW;

    // Error: crece con el tiempo desde la última lectura
    final avgSpeed =
        recent.map((p) => p.speed).reduce((a, b) => a + b) / recent.length;
    final timeSinceLast =
        now.difference(sorted.last.timestamp).inMilliseconds / 1000.0;
    final baseError = sorted.last.errorHorizontal;
    final extrapolationUncertainty = avgSpeed * timeSinceLast * 0.5;
    final finalError =
        sqrt(baseError * baseError + extrapolationUncertainty * extrapolationUncertainty);

    return OptimalPosition(
      latitude: lat,
      longitude: lon,
      altitude: alt,
      errorHorizontal: finalError,
      method: 'MOVING',
      pointsUsed: points.length,
      pointsRejected: rejected,
    );
  }

  /// Mediana de una lista de doubles.
  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;
    if (n == 0) return 0.0;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  /// Regresión lineal ponderada: y = slope * x + intercept
  static _LinearFit _weightedLinearFit(
      List<double> x, List<double> y, List<double> w) {
    double sumW = 0, sumWx = 0, sumWy = 0, sumWxx = 0, sumWxy = 0;
    for (int i = 0; i < x.length; i++) {
      sumW += w[i];
      sumWx += w[i] * x[i];
      sumWy += w[i] * y[i];
      sumWxx += w[i] * x[i] * x[i];
      sumWxy += w[i] * x[i] * y[i];
    }
    final denom = sumW * sumWxx - sumWx * sumWx;
    if (denom.abs() < 1e-15) {
      // Degenerado: todos los tiempos iguales, retornar media
      return _LinearFit(slope: 0, intercept: sumWy / sumW);
    }
    final slope = (sumW * sumWxy - sumWx * sumWy) / denom;
    final intercept = (sumWy - slope * sumWx) / sumW;
    return _LinearFit(slope: slope, intercept: intercept);
  }
}

class _LinearFit {
  final double slope;
  final double intercept;
  const _LinearFit({required this.slope, required this.intercept});
}
