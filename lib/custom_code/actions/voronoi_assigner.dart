// Asigna Id_virtual_point e Id_product a una visita recién insertada en
// SQLite, replicando localmente la lógica que el endpoint SyncVisitsAdd del
// API ejecuta al sincronizar (ver VoronoiMatchingService.cs).
//
// Flujo por visita:
//   1) Producto:
//      a. Si hay RFID → SELECT en Products por (Rfid, Id_headquarter).
//      b. Si no hay match → buscar el producto más cercano por coordenadas
//         dentro del mismo lote (JOIN con Products_coordinates).
//   2) Virtual point:
//      a. VoronoiCache.matchVirtualPoint(...) — usa celdas precomputadas.
//      b. Si el lote no tiene caché (no seleccionado, o sin VPs/polígono) →
//         se deja NULL y el server resolverá al sincronizar.
//   3) UPDATE Visits SET Id_virtual_point = ?,
//                        Id_product = COALESCE(Id_product, ?)
//                    WHERE Id_visit = ?
//
// Diseñado para ejecutarse fire-and-forget tras el INSERT de la visita; si
// falla por cualquier motivo, la visita queda como antes (Id_virtual_point
// NULL) y el server la procesa al sincronizar.

import 'package:flutter/foundation.dart';

import '/backend/sqlite/global_db_singleton.dart';
import 'voronoi_cache.dart';
import 'voronoi_geometry.dart';

class VisitVoronoiAssignment {
  final int? idVirtualPoint;
  final int? idProduct;
  final String source;

  const VisitVoronoiAssignment({
    required this.idVirtualPoint,
    required this.idProduct,
    required this.source,
  });

  @override
  String toString() =>
      'VoronoiAssignment(vp=$idVirtualPoint, product=$idProduct, source=$source)';
}

class VoronoiAssigner {
  VoronoiAssigner._();
  static final VoronoiAssigner _instance = VoronoiAssigner._();
  factory VoronoiAssigner() => _instance;

  Future<VisitVoronoiAssignment> assignToVisit({
    required int visitId,
    required double latitude,
    required double longitude,
    required int idHeadquarter,
    required String? rfid,
  }) async {
    try {
      // ── Producto ──
      final productResult = await _resolveProduct(
        rfid: rfid,
        latitude: latitude,
        longitude: longitude,
        idHeadquarter: idHeadquarter,
      );

      // ── Virtual point ──
      final idVirtualPoint = VoronoiCache().matchVirtualPoint(
        latitude,
        longitude,
        idHeadquarter,
      );

      String source;
      if (idVirtualPoint != null) {
        // Distinguir "contiene" vs "más cercano" solo para logging — el
        // matchVirtualPoint encapsula ambos; aquí informamos el caso típico.
        source = 'voronoi:${productResult.source}';
      } else {
        source = 'no-voronoi:${productResult.source}';
      }

      final result = VisitVoronoiAssignment(
        idVirtualPoint: idVirtualPoint,
        idProduct: productResult.idProduct,
        source: source,
      );

      // ── Persistir ──
      // COALESCE preserva Id_product que el formulario ya pudo asignar vía
      // RFID directo. Si Id_product en la fila ya es != 0/NULL, el segundo
      // operando (nuestro fallback) se ignora.
      await globalDb.executeOperation<void>((db) async {
        await db.rawUpdate(
          '''
          UPDATE Visits
          SET Id_virtual_point = ?,
              Id_product = COALESCE(NULLIF(Id_product, 0), ?)
          WHERE Id_visit = ?
          ''',
          [result.idVirtualPoint, result.idProduct, visitId],
        );
      });

      debugPrint('🎯 VoronoiAssigner: visita $visitId → $result');
      return result;
    } catch (e, st) {
      debugPrint('❌ VoronoiAssigner: error procesando visita $visitId: $e\n$st');
      return const VisitVoronoiAssignment(
        idVirtualPoint: null,
        idProduct: null,
        source: 'error',
      );
    }
  }

  // ─────────────────────────── Internos ───────────────────────────

  Future<_ProductResult> _resolveProduct({
    required String? rfid,
    required double latitude,
    required double longitude,
    required int idHeadquarter,
  }) async {
    return globalDb.executeOperation<_ProductResult>((db) async {
      // 1. RFID directo.
      if (rfid != null && rfid.isNotEmpty) {
        final rows = await db.rawQuery(
          'SELECT Id_product FROM Products WHERE Rfid = ? AND Id_headquarter = ? LIMIT 1',
          [rfid, idHeadquarter],
        );
        if (rows.isNotEmpty) {
          return _ProductResult(
            idProduct: (rows.first['Id_product'] as num).toInt(),
            source: 'rfid-direct',
          );
        }
      }

      // 2. Producto más cercano por coordenadas dentro del mismo lote.
      final rows = await db.rawQuery(
        '''
        SELECT p.Id_product AS id, pc.Latitude AS lat, pc.Longitude AS lon
        FROM Products p
        INNER JOIN Products_coordinates pc ON pc.Id_product = p.Id_product
        WHERE p.Id_headquarter = ?
          AND pc.Latitude != 0
          AND pc.Longitude != 0
        ''',
        [idHeadquarter],
      );
      if (rows.isEmpty) {
        return const _ProductResult(idProduct: null, source: 'no-product');
      }

      final target = LatLon(latitude, longitude);
      int? bestId;
      double bestDist = double.infinity;
      for (final r in rows) {
        final lat = (r['lat'] as num).toDouble();
        final lon = (r['lon'] as num).toDouble();
        final d = euclideanDegrees(target, LatLon(lat, lon));
        if (d < bestDist) {
          bestDist = d;
          bestId = (r['id'] as num).toInt();
        }
      }
      return _ProductResult(
        idProduct: bestId,
        source: 'nearest-coord',
      );
    });
  }
}

class _ProductResult {
  final int? idProduct;
  final String source;
  const _ProductResult({required this.idProduct, required this.source});
}
