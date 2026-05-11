import '/backend/sqlite/global_db_singleton.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'historial_extractora_page_model.dart';
import 'package:flutter/material.dart';

export 'historial_extractora_page_model.dart';

/// Visualización de visitas terminadas (Status=1) del Id_activity actual.
/// Grid moderno con tarjetas que muestran producto, fecha y hora con am/pm.
/// Al tocar una tarjeta se navega al detalle (HistorialVisitDetailPage).
class HistorialExtractoraPageWidget extends StatefulWidget {
  const HistorialExtractoraPageWidget({
    super.key,
    required this.idActivity,
  });

  final String? idActivity;

  static const String routeName = 'HistorialExtractoraPage';
  static const String routePath = '/historialExtractora';

  @override
  State<HistorialExtractoraPageWidget> createState() =>
      _HistorialExtractoraPageWidgetState();
}

class _HistorialExtractoraPageWidgetState
    extends State<HistorialExtractoraPageWidget> {
  late HistorialExtractoraPageModel _model;
  bool _loading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistorialExtractoraPageModel());
    _loadVisits();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    final idActivity = int.tryParse(widget.idActivity ?? '');
    if (idActivity == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final db = await GlobalDbSingleton().database;
      // Visitas terminadas con producto + datos resumen (Peso bruto, Peso total
      // de fruta) extraídos de Visits_details mediante subqueries.
      final rows = await db.rawQuery('''
        SELECT
          v.Id_visit,
          v.Created_at,
          v.Rfid,
          p.Name_product,
          (SELECT vd.Status_response
             FROM Visits_details vd
             WHERE vd.Id_visit = v.Id_visit
               AND LOWER(vd.Status_option) = 'peso bruto' LIMIT 1) AS peso_bruto,
          (SELECT vd.Status_response
             FROM Visits_details vd
             WHERE vd.Id_visit = v.Id_visit
               AND LOWER(vd.Status_option) = 'peso total de fruta' LIMIT 1) AS peso_total
        FROM Visits v
        LEFT JOIN Products p ON v.Id_product = p.Id_product
        WHERE v.Status = 1 AND v.Id_activity = ?
        ORDER BY v.Created_at DESC
      ''', [idActivity]);

      if (!mounted) return;
      setState(() {
        _visits = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ HistorialExtractoraPage._loadVisits error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(String? createdAtIso) {
    if (createdAtIso == null) return '--';
    final dt = DateTime.tryParse(createdAtIso);
    if (dt == null) return '--';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'am' : 'pm';
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final mm = months[(dt.month - 1).clamp(0, 11)];
    return '${dt.day.toString().padLeft(2, '0')} $mm ${dt.year} · '
        '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width > 700 ? 3 : 2;

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
          'Historial',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
              ),
            )
          : _visits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no hay visitas terminadas',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _visits.length,
                  itemBuilder: (_, i) => _buildVisitCard(_visits[i]),
                ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> v) {
    final idVisit = v['Id_visit'] as int;
    final productName = (v['Name_product'] as String?) ?? '';
    final rfid = (v['Rfid'] as String?) ?? '';
    final pesoBruto = (v['peso_bruto'] as String?) ?? '';
    final pesoTotal = (v['peso_total'] as String?) ?? '';
    final dateLabel = _formatDateTime(v['Created_at'] as String?);
    final title = productName.isNotEmpty
        ? productName
        : (rfid.isNotEmpty ? rfid : 'Visita #$idVisit');

    return GestureDetector(
      onTap: () => context.pushNamed(
        'HistorialVisitDetailPage',
        queryParameters: {'idVisit': idVisit.toString()},
      ),
      child: Container(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(),
            if (pesoBruto.isNotEmpty)
              _summaryChip(Icons.scale_rounded, 'Bruto', pesoBruto),
            if (pesoTotal.isNotEmpty) ...[
              const SizedBox(height: 6),
              _summaryChip(Icons.eco_rounded, 'Fruta', pesoTotal),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detalle',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
