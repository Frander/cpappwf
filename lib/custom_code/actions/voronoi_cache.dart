// Caché de diagramas de Voronoi por lote.
//
// Capas:
//   L1 in-memory : Map<idHeadquarter, LotVoronoi> en el singleton.
//   L2 persisted : SharedPreferences clave 'ff_voronoiCache_{lotId}' con un
//                  JSON que incluye un "fingerprint" (entrada canónica) para
//                  detectar cambios en VPs o en el polígono del lote.
//
// Reglas:
//   - Solo se cachean lotes presentes en FFAppState().headquartersSelectedList.
//   - Si un lote tiene <2 VPs o <3 vértices de polígono, no se cachea
//     (Voronoi no aplica) y `matchVirtualPoint` devuelve null.
//   - La construcción real corre en `compute()` para no bloquear el UI.
//   - El fingerprint compara la entrada exacta; cualquier cambio (nuevo VP,
//     cambio de coordenada, polígono actualizado) fuerza reconstrucción.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/app_state.dart';
import '/backend/sqlite/global_db_singleton.dart';
import 'voronoi_geometry.dart';

const String _prefsKeyPrefix = 'ff_voronoiCache_';

class LotVoronoi {
  final int idHeadquarter;
  final Map<int, List<LatLon>> polygons; // idVirtualPoint -> celda recortada
  final Map<int, LatLon> seeds;          // idVirtualPoint -> coordenada
  final List<LatLon> lotPolygon;
  final String fingerprint;

  LotVoronoi({
    required this.idHeadquarter,
    required this.polygons,
    required this.seeds,
    required this.lotPolygon,
    required this.fingerprint,
  });

  bool get isEmpty => polygons.isEmpty;
}

class VoronoiCache {
  VoronoiCache._();
  static final VoronoiCache _instance = VoronoiCache._();
  factory VoronoiCache() => _instance;

  final Map<int, LotVoronoi> _byLot = {};
  // Evita lanzar dos builds concurrentes para el mismo lote.
  final Map<int, Future<LotVoronoi?>> _inFlight = {};

  // ─────────────────────────── API pública ───────────────────────────

  /// Pre-carga las celdas para todos los lotes seleccionados.
  /// No-op si la selección está vacía. Idempotente — cargas posteriores
  /// reusan la entrada in-memory si el fingerprint coincide.
  Future<void> warmUpForSelectedLots() async {
    final selected = FFAppState().headquartersSelectedList;
    if (selected.isEmpty) {
      debugPrint('🗺️ VoronoiCache: sin lotes seleccionados, warm-up omitido');
      return;
    }
    debugPrint(
        '🗺️ VoronoiCache: warm-up para ${selected.length} lote(s) seleccionado(s)');
    await Future.wait(
      selected
          .map((h) => h.idHeadquarter)
          .where((id) => id > 0)
          .map(_loadOrBuild),
    );
  }

  /// Recorre la selección actual: carga nuevas, descarta las desaparecidas.
  Future<void> reconcileWithSelection() async {
    final selectedIds = FFAppState()
        .headquartersSelectedList
        .map((h) => h.idHeadquarter)
        .where((id) => id > 0)
        .toSet();

    // Liberar lotes que ya no están seleccionados.
    final toRemove =
        _byLot.keys.where((id) => !selectedIds.contains(id)).toList();
    for (final id in toRemove) {
      _byLot.remove(id);
      debugPrint('🗺️ VoronoiCache: lote $id liberado de memoria');
    }

    // Cargar los nuevos en paralelo.
    await Future.wait(selectedIds.map(_loadOrBuild));
  }

  /// Match principal: devuelve el `Id_virtual_point` cuya celda contiene
  /// (lat, lon) en `idHeadquarter`. Si la coordenada cae fuera de todas las
  /// celdas (visita fuera del lote), retorna el VP de la celda más cercana
  /// por distancia a la frontera (equivalente al NIVEL 1B del backend).
  /// Retorna null si el lote no tiene caché (no seleccionado, o sin datos).
  int? matchVirtualPoint(double lat, double lon, int idHeadquarter) {
    final lot = _byLot[idHeadquarter];
    if (lot == null || lot.isEmpty) return null;
    final p = LatLon(lat, lon);

    // NIVEL 1A: ¿está dentro de alguna celda?
    for (final entry in lot.polygons.entries) {
      if (pointInPolygon(p, entry.value)) {
        return entry.key;
      }
    }

    // NIVEL 1B: celda más cercana por frontera.
    int? nearest;
    double minDist = double.infinity;
    for (final entry in lot.polygons.entries) {
      final d = pointToPolygonBoundaryDistance(p, entry.value);
      if (d < minDist) {
        minDist = d;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  // ─────────────────────────── Internos ───────────────────────────

  Future<LotVoronoi?> _loadOrBuild(int idHeadquarter) {
    // Coalesce: si ya hay un build en vuelo para el mismo lote, reusarlo.
    final existing = _inFlight[idHeadquarter];
    if (existing != null) return existing;

    final fut = _loadOrBuildInternal(idHeadquarter);
    _inFlight[idHeadquarter] = fut;
    return fut.whenComplete(() => _inFlight.remove(idHeadquarter));
  }

  Future<LotVoronoi?> _loadOrBuildInternal(int idHeadquarter) async {
    try {
      // 1. Leer las fuentes (VPs + polígono del lote) desde SQLite.
      final source = await _readSource(idHeadquarter);
      if (source == null) {
        debugPrint(
            '🗺️ VoronoiCache: lote $idHeadquarter sin datos suficientes (VPs<2 o polígono<3)');
        _byLot.remove(idHeadquarter);
        return null;
      }
      final fingerprint = _fingerprintOf(source);

      // 2. Si ya está en memoria con el mismo fingerprint, listo.
      final cached = _byLot[idHeadquarter];
      if (cached != null && cached.fingerprint == fingerprint) {
        return cached;
      }

      // 3. Intentar cargar desde SharedPreferences.
      final persisted =
          await _loadPersisted(idHeadquarter, fingerprint, source.lotPolygon);
      if (persisted != null) {
        _byLot[idHeadquarter] = persisted;
        debugPrint(
            '🗺️ VoronoiCache: lote $idHeadquarter cargado desde SharedPreferences (${persisted.polygons.length} celdas)');
        return persisted;
      }

      // 4. Build en isolate.
      final sw = Stopwatch()..start();
      final cellsRaw = await compute(_buildVoronoiIsolate, {
        'vps': source.vps
            .map((v) => {'id': v.id, 'lat': v.lat, 'lon': v.lon})
            .toList(),
        'lotPolygon': source.lotPolygon.map((p) => [p.lat, p.lon]).toList(),
      });
      sw.stop();

      final polygons = <int, List<LatLon>>{};
      cellsRaw.forEach((vpId, pts) {
        if (pts.length >= 3) {
          polygons[vpId] = pts.map((p) => LatLon(p[0], p[1])).toList();
        }
      });

      final seeds = <int, LatLon>{
        for (final v in source.vps) v.id: LatLon(v.lat, v.lon),
      };

      final lot = LotVoronoi(
        idHeadquarter: idHeadquarter,
        polygons: polygons,
        seeds: seeds,
        lotPolygon: source.lotPolygon,
        fingerprint: fingerprint,
      );
      _byLot[idHeadquarter] = lot;

      debugPrint(
          '🗺️ VoronoiCache: lote $idHeadquarter construido (${polygons.length} celdas) en ${sw.elapsedMilliseconds}ms');

      // 5. Persistir.
      await _persist(idHeadquarter, lot);
      return lot;
    } catch (e, st) {
      debugPrint('❌ VoronoiCache: error construyendo lote $idHeadquarter: $e\n$st');
      _byLot.remove(idHeadquarter);
      return null;
    }
  }

  Future<_SourceData?> _readSource(int idHeadquarter) async {
    return globalDb.executeOperation<_SourceData?>((db) async {
      final vpRows = await db.rawQuery(
        '''
        SELECT Id_virtual_point AS id, Latitude AS lat, Longitude AS lon
        FROM Virtual_points
        WHERE Id_headquarter = ? AND Is_active = 1
        ORDER BY Line_number, Point_number
        ''',
        [idHeadquarter],
      );
      if (vpRows.length < 2) return null;

      final polyRows = await db.rawQuery(
        '''
        SELECT Latitude AS lat, Longitude AS lon
        FROM Headquarters_polygons
        WHERE Id_headquarter = ?
        ORDER BY Id_headquarter_polygon
        ''',
        [idHeadquarter],
      );
      if (polyRows.length < 3) return null;

      final vps = [
        for (final r in vpRows)
          _VpRow(
            (r['id'] as num).toInt(),
            (r['lat'] as num).toDouble(),
            (r['lon'] as num).toDouble(),
          ),
      ];
      final polygon = [
        for (final r in polyRows)
          LatLon((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()),
      ];
      return _SourceData(vps, polygon);
    });
  }

  String _fingerprintOf(_SourceData s) {
    final sortedVps = [...s.vps]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode({
      'vps': [
        for (final v in sortedVps) [v.id, v.lat, v.lon],
      ],
      'poly': [
        for (final p in s.lotPolygon) [p.lat, p.lon],
      ],
    });
  }

  Future<LotVoronoi?> _loadPersisted(
    int idHeadquarter,
    String expectedFingerprint,
    List<LatLon> lotPolygon,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsKeyPrefix$idHeadquarter');
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['fingerprint'] != expectedFingerprint) return null;

      final polygons = <int, List<LatLon>>{};
      for (final entry in (decoded['polygons'] as List)) {
        final m = entry as Map<String, dynamic>;
        final vpId = (m['vpId'] as num).toInt();
        final pts = (m['pts'] as List)
            .map((e) =>
                LatLon((e[0] as num).toDouble(), (e[1] as num).toDouble()))
            .toList();
        if (pts.length >= 3) polygons[vpId] = pts;
      }

      final seeds = <int, LatLon>{};
      for (final entry in (decoded['seeds'] as List)) {
        final m = entry as Map<String, dynamic>;
        seeds[(m['vpId'] as num).toInt()] = LatLon(
          (m['lat'] as num).toDouble(),
          (m['lon'] as num).toDouble(),
        );
      }

      return LotVoronoi(
        idHeadquarter: idHeadquarter,
        polygons: polygons,
        seeds: seeds,
        lotPolygon: lotPolygon,
        fingerprint: expectedFingerprint,
      );
    } catch (e) {
      debugPrint('⚠️ VoronoiCache: cache persistido inválido para $idHeadquarter: $e');
      return null;
    }
  }

  Future<void> _persist(int idHeadquarter, LotVoronoi lot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'fingerprint': lot.fingerprint,
        'polygons': [
          for (final e in lot.polygons.entries)
            {
              'vpId': e.key,
              'pts': [
                for (final p in e.value) [p.lat, p.lon],
              ],
            },
        ],
        'seeds': [
          for (final e in lot.seeds.entries)
            {'vpId': e.key, 'lat': e.value.lat, 'lon': e.value.lon},
        ],
      });
      await prefs.setString('$_prefsKeyPrefix$idHeadquarter', payload);
    } catch (e) {
      debugPrint('⚠️ VoronoiCache: no se pudo persistir lote $idHeadquarter: $e');
    }
  }
}

// ────────────────────────── Soporte interno ──────────────────────────

class _VpRow {
  final int id;
  final double lat;
  final double lon;
  const _VpRow(this.id, this.lat, this.lon);
}

class _SourceData {
  final List<_VpRow> vps;
  final List<LatLon> lotPolygon;
  const _SourceData(this.vps, this.lotPolygon);
}

/// Función top-level para `compute()` — debe ser entry-point estática.
/// Entrada y salida usan solo tipos primitivos (List/Map/num) para que
/// puedan cruzar el puerto del isolate sin reflexión adicional.
Map<int, List<List<double>>> _buildVoronoiIsolate(
    Map<String, dynamic> input) {
  final vpsRaw = (input['vps'] as List).cast<Map>();
  final polyRaw = (input['lotPolygon'] as List).cast<List>();

  final seedIds = <int>[];
  final seeds = <LatLon>[];
  for (final v in vpsRaw) {
    seedIds.add((v['id'] as num).toInt());
    seeds.add(LatLon((v['lat'] as num).toDouble(),
        (v['lon'] as num).toDouble()));
  }

  final lotPolygon = <LatLon>[
    for (final p in polyRaw)
      LatLon((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];

  final out = <int, List<List<double>>>{};
  for (int i = 0; i < seeds.length; i++) {
    final seed = seeds[i];
    final others = <LatLon>[];
    for (int j = 0; j < seeds.length; j++) {
      if (j != i) others.add(seeds[j]);
    }
    final cell = buildVoronoiCellByBisectorClip(seed, others, lotPolygon);
    out[seedIds[i]] = [for (final p in cell) [p.lat, p.lon]];
  }
  return out;
}
