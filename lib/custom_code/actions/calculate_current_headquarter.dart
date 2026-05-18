// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:math' as math;

/// Calcula el lote (headquarter) actual basado en geolocalización
Future<HeadquartersStruct?> calculateCurrentHeadquarter(
  List<HeadquartersStruct> headquartersSelectedList,
  List<ReadGeoStruct> geoLocationsList,
) async {
  // Si no hay lotes, retornar null
  if (headquartersSelectedList.isEmpty) {
    return null;
  }

  // Paso 1: Obtener ubicación promedio de últimos 12 segundos
  final currentLocation = _getWeightedAverageLocation(geoLocationsList);

  if (currentLocation == null) {
    // Si no hay datos GPS, retornar primer lote de la lista
    return headquartersSelectedList.first;
  }

  // Paso 2: Filtrar lotes con polígono válido
  final lotesConPoligono = headquartersSelectedList.where((lote) {
    return lote.polygon.isNotEmpty && _isValidPolygon(lote.polygon);
  }).toList();

  // Si no hay lotes con polígono, retornar el primero de la lista original
  if (lotesConPoligono.isEmpty) {
    return headquartersSelectedList.first;
  }

  // Paso 3: Verificar si el punto está dentro de algún polígono
  for (var lote in lotesConPoligono) {
    final polygon = _parsePolygon(lote.polygon);
    if (_isPointInPolygon(currentLocation, polygon)) {
      // Punto está dentro de este polígono
      return lote;
    }
  }

  // Paso 4: Si no está dentro de ninguno, buscar el polígono más cercano
  final nearestLote = _findNearestPolygon(currentLocation, lotesConPoligono);
  return nearestLote ?? headquartersSelectedList.first;
}

/// Obtiene ubicación promedio ponderada de últimos 12 segundos
_LatLng? _getWeightedAverageLocation(List<ReadGeoStruct> geoLocationsList) {
  if (geoLocationsList.isEmpty) {
    return null;
  }

  final now = DateTime.now();
  final twelveSecondsAgo = now.subtract(const Duration(seconds: 12));

  // Filtrar puntos de últimos 12 segundos
  final recentPoints = geoLocationsList.where((point) {
    return point.dateHourRead != null &&
        point.dateHourRead!.isAfter(twelveSecondsAgo);
  }).toList();

  if (recentPoints.isEmpty) {
    // Usar el punto más reciente disponible
    final sortedPoints = geoLocationsList.toList()
      ..sort((a, b) {
        if (a.dateHourRead == null) return 1;
        if (b.dateHourRead == null) return -1;
        return b.dateHourRead!.compareTo(a.dateHourRead!);
      });

    if (sortedPoints.isNotEmpty && sortedPoints.first.dateHourRead != null) {
      return _LatLng(
        sortedPoints.first.latitude,
        sortedPoints.first.longitude,
      );
    }
    return null;
  }

  // Calcular promedio ponderado (peso = 1 / errorHorizontal)
  double totalLat = 0;
  double totalLon = 0;
  double totalWeight = 0;

  for (var point in recentPoints) {
    // Usar errorHorizontal como accuracy, menor error = mayor peso
    double weight = point.errorHorizontal > 0
        ? 1.0 / point.errorHorizontal
        : 1.0;

    totalLat += point.latitude * weight;
    totalLon += point.longitude * weight;
    totalWeight += weight;
  }

  if (totalWeight == 0) {
    return _LatLng(
      recentPoints.first.latitude,
      recentPoints.first.longitude,
    );
  }

  return _LatLng(
    totalLat / totalWeight,
    totalLon / totalWeight,
  );
}

/// Verifica si un polígono es válido (tiene al menos 3 vértices)
bool _isValidPolygon(String polygonString) {
  try {
    final polygon = _parsePolygon(polygonString);
    return polygon.length >= 3;
  } catch (e) {
    return false;
  }
}

/// Parsea string de polígono a lista de puntos
List<_LatLng> _parsePolygon(String polygonString) {
  try {
    // Intentar parsear como JSON
    final decoded = jsonDecode(polygonString);

    List<_LatLng> points = [];

    if (decoded is List) {
      for (var point in decoded) {
        if (point is Map) {
          double? lat = point['lat']?.toDouble() ?? point['latitude']?.toDouble();
          double? lon = point['lon']?.toDouble() ?? point['lng']?.toDouble() ?? point['longitude']?.toDouble();

          if (lat != null && lon != null) {
            points.add(_LatLng(lat, lon));
          }
        }
      }
    }

    return points;
  } catch (e) {
    return [];
  }
}

/// Algoritmo Point-in-Polygon (Ray Casting)
bool _isPointInPolygon(_LatLng point, List<_LatLng> polygon) {
  if (polygon.length < 3) return false;

  int intersections = 0;

  for (int i = 0; i < polygon.length; i++) {
    final p1 = polygon[i];
    final p2 = polygon[(i + 1) % polygon.length];

    // Verificar si el rayo horizontal desde el punto intersecta con este segmento
    if (_rayIntersectsSegment(point, p1, p2)) {
      intersections++;
    }
  }

  // Si el número de intersecciones es impar, el punto está dentro
  return intersections % 2 == 1;
}

/// Verifica si un rayo horizontal desde el punto intersecta el segmento
bool _rayIntersectsSegment(_LatLng point, _LatLng p1, _LatLng p2) {
  // El rayo va hacia la derecha desde el punto
  if (p1.lat > p2.lat) {
    final temp = p1;
    p1 = p2;
    p2 = temp;
  }

  // El punto está fuera del rango vertical del segmento
  if (point.lat < p1.lat || point.lat >= p2.lat) {
    return false;
  }

  // Calcular la intersección X
  if (p1.lat == p2.lat) {
    return false; // Segmento horizontal
  }

  final xIntersection = p1.lon +
      (point.lat - p1.lat) * (p2.lon - p1.lon) / (p2.lat - p1.lat);

  return xIntersection > point.lon;
}

/// Encuentra el polígono más cercano al punto
HeadquartersStruct? _findNearestPolygon(
  _LatLng point,
  List<HeadquartersStruct> lotes,
) {
  double minDistance = double.infinity;
  HeadquartersStruct? nearestLote;

  for (var lote in lotes) {
    final polygon = _parsePolygon(lote.polygon);
    final distance = _distanceToPolygon(point, polygon);

    if (distance < minDistance) {
      minDistance = distance;
      nearestLote = lote;
    }
  }

  return nearestLote;
}

/// Calcula la distancia mínima de un punto a un polígono
double _distanceToPolygon(_LatLng point, List<_LatLng> polygon) {
  if (polygon.length < 2) return double.infinity;

  double minDistance = double.infinity;

  // Calcular distancia a cada arista del polígono
  for (int i = 0; i < polygon.length; i++) {
    final p1 = polygon[i];
    final p2 = polygon[(i + 1) % polygon.length];

    final distance = _distancePointToSegment(point, p1, p2);
    if (distance < minDistance) {
      minDistance = distance;
    }
  }

  return minDistance;
}

/// Calcula distancia de un punto a un segmento (usando Haversine)
double _distancePointToSegment(_LatLng point, _LatLng p1, _LatLng p2) {
  // Proyectar el punto sobre el segmento
  final dx = p2.lon - p1.lon;
  final dy = p2.lat - p1.lat;

  if (dx == 0 && dy == 0) {
    // p1 y p2 son el mismo punto
    return _haversineDistance(point, p1);
  }

  // Calcular parámetro t de la proyección (0 a 1)
  final t = ((point.lon - p1.lon) * dx + (point.lat - p1.lat) * dy) /
             (dx * dx + dy * dy);

  if (t < 0) {
    // La proyección está antes del segmento, usar p1
    return _haversineDistance(point, p1);
  } else if (t > 1) {
    // La proyección está después del segmento, usar p2
    return _haversineDistance(point, p2);
  } else {
    // La proyección está dentro del segmento
    final projection = _LatLng(
      p1.lat + t * dy,
      p1.lon + t * dx,
    );
    return _haversineDistance(point, projection);
  }
}

/// Fórmula de Haversine para calcular distancia entre dos puntos GPS
double _haversineDistance(_LatLng p1, _LatLng p2) {
  const R = 6371000.0; // Radio de la Tierra en metros

  final lat1 = p1.lat * math.pi / 180;
  final lat2 = p2.lat * math.pi / 180;
  final dLat = (p2.lat - p1.lat) * math.pi / 180;
  final dLon = (p2.lon - p1.lon) * math.pi / 180;

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c; // Distancia en metros
}

/// Clase auxiliar para coordenadas
class _LatLng {
  final double lat;
  final double lon;

  _LatLng(this.lat, this.lon);
}

// ============================================================
// VERIFICACIÓN DE POLÍGONO PARA DETECCIÓN DE CAMBIO DE LOTE
// ============================================================

/// Resultado de la verificación de ubicación contra polígonos de lotes
class HeadquarterCheckResult {
  /// Lote cuyo polígono contiene la ubicación actual, o null si está fuera de todos
  final HeadquartersStruct? insideHeadquarter;

  /// Top-3 lotes más cercanos ordenados por distancia ascendente
  final List<HeadquarterDistance> nearestList;

  HeadquarterCheckResult({
    this.insideHeadquarter,
    required this.nearestList,
  });
}

/// Par de lote + distancia en metros
class HeadquarterDistance {
  final HeadquartersStruct headquarter;
  final double distanceMeters;

  HeadquarterDistance(this.headquarter, this.distanceMeters);
}

/// Verifica si la ubicación [latitude]/[longitude] cae dentro de algún
/// polígono de [hqList]. Devuelve:
/// - [insideHeadquarter] != null si el punto está dentro de ese lote.
/// - [insideHeadquarter] == null si está fuera de todos; [nearestList]
///   contiene los 3 lotes más cercanos con su distancia en metros.
Future<HeadquarterCheckResult> checkLocationInPolygons(
  double latitude,
  double longitude,
  List<HeadquartersStruct> hqList,
) async {
  final point = _LatLng(latitude, longitude);

  // Filtrar lotes con polígono válido (≥3 vértices)
  final hqConPoligono = hqList
      .where((hq) => hq.polygon.isNotEmpty && _isValidPolygon(hq.polygon))
      .toList();

  // Verificar si el punto está DENTRO de algún polígono
  for (var hq in hqConPoligono) {
    final polygon = _parsePolygon(hq.polygon);
    if (_isPointInPolygon(point, polygon)) {
      final allDistances = _computeHqDistances(point, hqConPoligono);
      return HeadquarterCheckResult(
        insideHeadquarter: hq,
        nearestList: allDistances.take(3).toList(),
      );
    }
  }

  // Fuera de todos → calcular distancias y retornar top-3
  final source = hqConPoligono.isNotEmpty ? hqConPoligono : hqList;
  final allDistances = _computeHqDistances(point, source);
  return HeadquarterCheckResult(
    insideHeadquarter: null,
    nearestList: allDistances.take(3).toList(),
  );
}

/// Calcula la distancia mínima del punto a cada lote y ordena ascendente
List<HeadquarterDistance> _computeHqDistances(
  _LatLng point,
  List<HeadquartersStruct> hqList,
) {
  final distances = <HeadquarterDistance>[];
  for (var hq in hqList) {
    final polygon = _parsePolygon(hq.polygon);
    final dist = polygon.length >= 2
        ? _distanceToPolygon(point, polygon)
        : double.infinity;
    distances.add(HeadquarterDistance(hq, dist));
  }
  distances.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return distances;
}
