// Geometría pura para diagramas de Voronoi locales por lote.
// - Coordenadas tratadas como plano euclidiano (lon, lat). Suficiente para
//   lotes pequeños (~km²); coincide con la convención de NetTopologySuite usada
//   por el backend en VoronoiService.cs.
// - Sin estado, sin IO, sin dependencias externas — solo `dart:math`. Esto
//   permite ejecutar la construcción de celdas dentro de `compute()` (isolate).

import 'dart:math' as math;

/// Coordenada inmutable (lat, lon).
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LatLon && other.lat == lat && other.lon == lon);

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => '($lat, $lon)';
}

/// Distancia euclidiana en grados — equivalente a la fórmula que usa el API
/// en `SyncService.cs:2909` como fallback NIVEL 2. Útil sólo para ORDENAR
/// candidatos (no devuelve metros); para fines de matching dentro de un lote
/// pequeño el orden coincide con cualquier métrica geodésica razonable.
double euclideanDegrees(LatLon a, LatLon b) {
  final dLat = a.lat - b.lat;
  final dLon = a.lon - b.lon;
  return math.sqrt(dLat * dLat + dLon * dLon);
}

/// Ray-casting point-in-polygon en plano (lon, lat).
/// Portado de `calculate_current_headquarter.dart:154` para preservar la misma
/// convención usada en el resto de la app.
bool pointInPolygon(LatLon p, List<LatLon> poly) {
  if (poly.length < 3) return false;
  int intersections = 0;
  for (int i = 0; i < poly.length; i++) {
    var p1 = poly[i];
    var p2 = poly[(i + 1) % poly.length];
    if (p1.lat > p2.lat) {
      final tmp = p1;
      p1 = p2;
      p2 = tmp;
    }
    if (p.lat < p1.lat || p.lat >= p2.lat) continue;
    if (p1.lat == p2.lat) continue;
    final xIntersection =
        p1.lon + (p.lat - p1.lat) * (p2.lon - p1.lon) / (p2.lat - p1.lat);
    if (xIntersection > p.lon) intersections++;
  }
  return intersections.isOdd;
}

/// Mínima distancia (en grados) entre el punto `p` y la frontera del polígono.
/// Usado como fallback NIVEL 1B cuando la coordenada cae fuera de todas las
/// celdas — equivalente a `point.Distance(polygon.Boundary)` del backend.
double pointToPolygonBoundaryDistance(LatLon p, List<LatLon> poly) {
  if (poly.length < 2) return double.infinity;
  double minDist = double.infinity;
  for (int i = 0; i < poly.length; i++) {
    final p1 = poly[i];
    final p2 = poly[(i + 1) % poly.length];
    final d = _pointSegmentDistanceDegrees(p, p1, p2);
    if (d < minDist) minDist = d;
  }
  return minDist;
}

double _pointSegmentDistanceDegrees(LatLon p, LatLon a, LatLon b) {
  final dx = b.lon - a.lon;
  final dy = b.lat - a.lat;
  if (dx == 0 && dy == 0) return euclideanDegrees(p, a);
  final t = ((p.lon - a.lon) * dx + (p.lat - a.lat) * dy) /
      (dx * dx + dy * dy);
  if (t < 0) return euclideanDegrees(p, a);
  if (t > 1) return euclideanDegrees(p, b);
  final proj = LatLon(a.lat + t * dy, a.lon + t * dx);
  return euclideanDegrees(p, proj);
}

/// Producto cruz (B-A) × (P-A) en plano (lon, lat) — signo del lado de `p`
/// respecto a la línea infinita AB.
double _sideOfLine(LatLon p, LatLon a, LatLon b) {
  return (b.lon - a.lon) * (p.lat - a.lat) -
      (b.lat - a.lat) * (p.lon - a.lon);
}

/// Intersección entre el segmento (s1, s2) y la línea infinita (a, b).
/// Asume que s1 y s2 están en lados opuestos. Devuelve el midpoint del
/// segmento si las dos rectas son paralelas (caso degenerado).
LatLon _segmentLineIntersection(LatLon s1, LatLon s2, LatLon a, LatLon b) {
  final x1 = s1.lon, y1 = s1.lat;
  final x2 = s2.lon, y2 = s2.lat;
  final x3 = a.lon, y3 = a.lat;
  final x4 = b.lon, y4 = b.lat;

  final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
  if (denom == 0) {
    return LatLon((y1 + y2) / 2, (x1 + x2) / 2);
  }
  final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
  final px = x1 + t * (x2 - x1);
  final py = y1 + t * (y2 - y1);
  return LatLon(py, px);
}

/// Sutherland-Hodgman: recorta `subject` al semiplano definido por la línea
/// infinita AB que contiene a `insideRef`. Devuelve el polígono resultante
/// (puede ser vacío si nada queda dentro).
List<LatLon> sutherlandHodgmanClipHalfPlane(
  List<LatLon> subject,
  LatLon a,
  LatLon b,
  LatLon insideRef,
) {
  if (subject.isEmpty) return const [];
  final refSide = _sideOfLine(insideRef, a, b);
  if (refSide == 0) {
    return List<LatLon>.from(subject);
  }
  final refPositive = refSide > 0;

  bool isInside(LatLon p) {
    final s = _sideOfLine(p, a, b);
    if (s == 0) return true;
    return (s > 0) == refPositive;
  }

  final out = <LatLon>[];
  for (int i = 0; i < subject.length; i++) {
    final curr = subject[i];
    final next = subject[(i + 1) % subject.length];
    final currIn = isInside(curr);
    final nextIn = isInside(next);

    if (currIn) {
      out.add(curr);
      if (!nextIn) {
        out.add(_segmentLineIntersection(curr, next, a, b));
      }
    } else if (nextIn) {
      out.add(_segmentLineIntersection(curr, next, a, b));
    }
  }
  return out;
}

/// Construye la celda de Voronoi de `seed` dentro de `lotPolygon` recortando
/// iterativamente por las bisectrices perpendiculares a cada otro VP.
///
/// Cada bisectriz es la mediatriz del segmento (seed, other), conservando el
/// semiplano que contiene a `seed`. La intersección final es exactamente la
/// celda de Voronoi de `seed` restringida al lote — equivalente al diagrama
/// que el backend genera con `VoronoiDiagramBuilder` + clip.
List<LatLon> buildVoronoiCellByBisectorClip(
  LatLon seed,
  List<LatLon> otherSeeds,
  List<LatLon> lotPolygon,
) {
  var cell = List<LatLon>.from(lotPolygon);
  for (final other in otherSeeds) {
    if (cell.isEmpty) break;
    final dx = other.lon - seed.lon;
    final dy = other.lat - seed.lat;
    if (dx == 0 && dy == 0) continue; // VP duplicado, ignorar
    final mx = (seed.lon + other.lon) / 2;
    final my = (seed.lat + other.lat) / 2;
    // Punto adicional sobre la bisectriz: rotar (dx, dy) 90° → (-dy, dx).
    final bx = mx + (-dy);
    final by = my + dx;
    cell = sutherlandHodgmanClipHalfPlane(
      cell,
      LatLon(my, mx),
      LatLon(by, bx),
      seed,
    );
  }
  return cell;
}
