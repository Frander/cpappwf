import '/backend/sqlite/global_db_singleton.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'historial_visit_detail_page_model.dart';
import 'package:flutter/material.dart';

export 'historial_visit_detail_page_model.dart';

/// Página de detalle readonly para una visita terminada (Status=1).
/// Muestra cada Visits_details como una tarjeta legible, parseando los JSON
/// de headquarter-weight y distance-extractor.
class HistorialVisitDetailPageWidget extends StatefulWidget {
  const HistorialVisitDetailPageWidget({
    super.key,
    required this.idVisit,
  });

  final String? idVisit;

  static const String routeName = 'HistorialVisitDetailPage';
  static const String routePath = '/historialVisitDetail';

  @override
  State<HistorialVisitDetailPageWidget> createState() =>
      _HistorialVisitDetailPageWidgetState();
}

class _HistorialVisitDetailPageWidgetState
    extends State<HistorialVisitDetailPageWidget> {
  late HistorialVisitDetailPageModel _model;
  bool _loading = true;
  Map<String, dynamic>? _visit;
  List<Map<String, dynamic>> _details = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistorialVisitDetailPageModel());
    _loadDetail();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final idVisit = int.tryParse(widget.idVisit ?? '');
    if (idVisit == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final db = await GlobalDbSingleton().database;

      final visitRows = await db.rawQuery('''
        SELECT v.Id_visit, v.Created_at, v.Rfid, v.Latitude, v.Longitude,
               p.Name_product
        FROM Visits v
        LEFT JOIN Products p ON v.Id_product = p.Id_product
        WHERE v.Id_visit = ? LIMIT 1
      ''', [idVisit]);

      final detailRows = await db.rawQuery('''
        SELECT vd.Id_visit_detail, vd.Status_option, vd.Status_response,
               a.Type_status, a.Status_name
        FROM Visits_details vd
        LEFT JOIN Activities_status a
          ON a.Id_activity_status = vd.Id_activity_status
        WHERE vd.Id_visit = ?
        ORDER BY vd.Id_visit_detail
      ''', [idVisit]);

      if (!mounted) return;
      setState(() {
        _visit = visitRows.isNotEmpty
            ? Map<String, dynamic>.from(visitRows.first)
            : null;
        _details =
            detailRows.map((r) => Map<String, dynamic>.from(r)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ HistorialVisitDetailPage._loadDetail error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(String? createdAtIso) {
    if (createdAtIso == null) return '--';
    final dt = DateTime.tryParse(createdAtIso);
    if (dt == null) return '--';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'am' : 'pm';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  /// Convierte el Status_response al formato más legible posible según
  /// el Type_status. Devuelve un widget — algunas filas se renderizan como
  /// chip (dynamic-printing-adb), otras como JSON parseado, otras como texto.
  Widget _renderResponse(String typeStatus, String response) {
    if (response.isEmpty) {
      return Text(
        '—',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (typeStatus.toLowerCase()) {
      case 'dynamic-printing-adb':
        final printed = response.toUpperCase() == 'SI';
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (printed
                    ? const Color(0xFF00a86b)
                    : const Color(0xFF616161))
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                printed
                    ? Icons.check_circle_rounded
                    : Icons.do_disturb_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                printed ? 'Impreso' : 'No impreso',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );

      case 'distance-extractor':
        try {
          final m = jsonDecode(response) as Map<String, dynamic>;
          final dist = (m['distanceFromTag'] as num?)?.toDouble();
          final list = m['distancesFromProducts'];
          final children = <Widget>[];
          if (dist != null) {
            children.add(_kvLine(
              'Distancia desde tag',
              '${(dist / 1000).toStringAsFixed(2)} km',
            ));
          }
          if (list is List && list.isNotEmpty) {
            for (final e in list.cast<Map>()) {
              final name = e['headquarterName']?.toString() ?? 'Lote';
              final d = (e['distance'] as num?)?.toDouble() ?? 0.0;
              children.add(_kvLine(
                name,
                '${(d / 1000).toStringAsFixed(2)} km',
              ));
            }
          }
          if (children.isEmpty) return _plain(response);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        } catch (_) {
          return _plain(response);
        }

      case 'headquarter-weight':
        try {
          final m = jsonDecode(response) as Map<String, dynamic>;
          final entries = m.entries
              .where((e) => e.value != null)
              .map((e) => _kvLine(e.key, e.value.toString()))
              .toList();
          if (entries.isEmpty) return _plain(response);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries,
          );
        } catch (_) {
          return _plain(response);
        }

      case 'tag-transfer-adb-server':
        return _plain(
          response.length > 120 ? '${response.substring(0, 120)}…' : response,
          mono: true,
        );

      default:
        return _plain(response);
    }
  }

  Widget _plain(String text, {bool mono = false}) => Text(
        text,
        style: TextStyle(
          fontFamily: mono ? 'Courier New' : 'Roboto',
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      );

  Widget _kvLine(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$k: ',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final productName = (_visit?['Name_product'] as String?) ?? '';
    final rfid = (_visit?['Rfid'] as String?) ?? '';
    final dateLabel = _formatDateTime(_visit?['Created_at'] as String?);
    final title = productName.isNotEmpty
        ? productName
        : (rfid.isNotEmpty ? rfid : 'Visita');

    return Scaffold(
      backgroundColor: const Color(0xFF002415),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003420),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detalle de visita',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
              ),
            )
          : _visit == null
              ? const Center(
                  child: Text(
                    'Visita no encontrada',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _headerCard(title, dateLabel, rfid),
                    const SizedBox(height: 14),
                    ..._details.map(_detailCard),
                  ],
                ),
    );
  }

  Widget _headerCard(String title, String dateLabel, String rfid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB45309), Color(0xFF7C2D12)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded,
                  color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateLabel,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (rfid.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'RFID: $rfid',
              style: TextStyle(
                fontFamily: 'Courier New',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(Map<String, dynamic> d) {
    final option = (d['Status_option'] as String?) ?? '';
    final response = (d['Status_response'] as String?) ?? '';
    final typeStatus = (d['Type_status'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.isNotEmpty ? option : '(sin etiqueta)',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFFBBF24),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (typeStatus.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeStatus,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _renderResponse(typeStatus, response),
        ],
      ),
    );
  }
}
