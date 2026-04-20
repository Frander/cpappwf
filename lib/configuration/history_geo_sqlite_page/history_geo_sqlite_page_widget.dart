import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:intl/intl.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/app_state.dart';
import '/backend/sqlite/global_db_singleton.dart';
import 'history_geo_sqlite_page_model.dart';
export 'history_geo_sqlite_page_model.dart';

// ============================================================================
// MODELO DE DATOS LOCAL
// ============================================================================

class GpsLocationRecord {
  final double lat, lon, alt, error, speed;
  final int battery, pointCount;
  final String method;
  final DateTime createdAt;
  final DateTime? dateStart, dateFinish;
  final double evaluatedRadius;

  GpsLocationRecord({
    required this.lat,
    required this.lon,
    required this.alt,
    required this.error,
    required this.speed,
    required this.battery,
    required this.pointCount,
    required this.method,
    required this.createdAt,
    required this.evaluatedRadius,
    this.dateStart,
    this.dateFinish,
  });

  factory GpsLocationRecord.fromMap(Map<String, dynamic> m) {
    return GpsLocationRecord(
      lat: (m['Latitude'] as num?)?.toDouble() ?? 0.0,
      lon: (m['Longitude'] as num?)?.toDouble() ?? 0.0,
      alt: (m['Altitude'] as num?)?.toDouble() ?? 0.0,
      error: (m['HorizontalError'] as num?)?.toDouble() ?? 0.0,
      speed: (m['Speed'] as num?)?.toDouble() ?? 0.0,
      battery: (m['Battery'] as int?) ?? 0,
      pointCount: (m['point_count'] as int?) ?? 1,
      method: (m['Method'] as String?) ?? 'UNKNOWN',
      createdAt: DateTime.tryParse(m['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      evaluatedRadius: (m['evaluated_radius'] as num?)?.toDouble() ?? 0.0,
      dateStart: DateTime.tryParse(m['date_start']?.toString() ?? ''),
      dateFinish: DateTime.tryParse(m['date_finish']?.toString() ?? ''),
    );
  }
}

// ============================================================================
// PAGE WIDGET
// ============================================================================

class HistoryGeoSqlitePageWidget extends StatefulWidget {
  const HistoryGeoSqlitePageWidget({super.key});

  static String routeName = 'HistoryGeoSqlitePage';
  static String routePath = '/historyGeoSqlitePage';

  @override
  State<HistoryGeoSqlitePageWidget> createState() =>
      _HistoryGeoSqlitePageWidgetState();
}

class _HistoryGeoSqlitePageWidgetState
    extends State<HistoryGeoSqlitePageWidget> {
  late HistoryGeoSqlitePageModel _model;

  // Paleta
  static const Color _bgDeep = Color(0xFF0A0E1A);
  static const Color _bgCard = Color(0xFF161B2E);
  static const Color _bgCardLight = Color(0xFF1E2440);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentCyan = Color(0xFF06B6D4);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFFF3F4F6);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _borderColor = Color(0xFF2D3757);

  // Estado
  List<GpsLocationRecord> _records = [];
  bool _loading = true;
  int _totalCount = 0;

  // Filtro: slider de horas (default) o rango de fechas
  double _hoursSlider = 24;
  bool _useCustomRange = false;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // Filtro de método
  String _methodFilter = 'ALL'; // ALL, LITE, UKF_IMU
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistoryGeoSqlitePageModel());
    _loadRecords();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  final GlobalDbSingleton _globalDb = GlobalDbSingleton();

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    try {
      // Usar el singleton global de DB (misma instancia que usa toda la app).
      // Esto garantiza la ruta correcta, WAL mode, y evita locks.
      final result = await _globalDb.executeOperation<Map<String, dynamic>>((db) async {
        // Primero: ¿hay ALGO en la tabla sin filtro?
        final totalAll = await db.rawQuery(
            'SELECT COUNT(*) as c FROM Location_tracking');
        debugPrint('📊 [HistorialSQLite] Total registros SIN filtro: ${totalAll.first['c']}');

        final now = DateTime.now().toUtc();
        late DateTime from;
        late DateTime to;

        if (_useCustomRange && _rangeStart != null && _rangeEnd != null) {
          from = _rangeStart!;
          to = _rangeEnd!;
        } else {
          from = now.subtract(Duration(hours: _hoursSlider.round()));
          to = now;
        }

        debugPrint('📊 [HistorialSQLite] Filtro: ${from.toIso8601String()} → ${to.toIso8601String()}');

        String methodClause = '';
        List<dynamic> params = [from.toIso8601String(), to.toIso8601String()];
        if (_methodFilter != 'ALL') {
          methodClause = ' AND Method = ?';
          params.add(_methodFilter);
        }

        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as c FROM Location_tracking WHERE CreatedAt >= ? AND CreatedAt <= ?$methodClause',
          params,
        );
        final count = (countResult.first['c'] as int?) ?? 0;
        debugPrint('📊 [HistorialSQLite] Total CON filtro: $count');

        final rows = await db.rawQuery(
          'SELECT * FROM Location_tracking WHERE CreatedAt >= ? AND CreatedAt <= ?$methodClause ORDER BY CreatedAt DESC LIMIT 500',
          params,
        );

        return {'count': count, 'rows': rows};
      });

      _totalCount = result['count'] as int;
      final rows = result['rows'] as List<Map<String, dynamic>>;

      setState(() {
        _records = rows.map((r) => GpsLocationRecord.fromMap(r)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando historial SQLite: $e');
      setState(() => _loading = false);
    }
  }

  Color _errorColor(double error) {
    if (error <= 5) return _accentGreen;
    if (error <= 10) return const Color(0xFF84CC16);
    if (error <= 15) return _accentAmber;
    if (error <= 25) return const Color(0xFFFB923C);
    return _accentRed;
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'UKF_IMU': return 'PRECISO';
      case 'LITE': return 'BÁSICO';
      case 'MIXED': return 'MIXTO';
      default: return m;
    }
  }

  Color _methodColor(String m) {
    switch (m) {
      case 'UKF_IMU': return _accentCyan;
      case 'LITE': return _accentGreen;
      default: return _textSecondary;
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _rangeStart != null && _rangeEnd != null
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _accentBlue,
              surface: _bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _useCustomRange = true;
        _rangeStart = picked.start;
        _rangeEnd = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      floatingActionButton: _records.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showMapSheet(context),
              backgroundColor: _accentBlue,
              icon: const Icon(Icons.map_rounded, color: Colors.white),
              label: const Text('Mostrar en Mapa',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            _buildStatsBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historial GPS',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                Text('Geolocalizaciones almacenadas en SQLite',
                    style: TextStyle(
                        color: _textSecondary.withValues(alpha: 0.9),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    // Resumen visible siempre (colapsado)
    final summaryText = _useCustomRange && _rangeStart != null
        ? '${DateFormat('dd/MM HH:mm').format(_rangeStart!)} — ${DateFormat('dd/MM HH:mm').format(_rangeEnd!)}'
        : 'Últimas ${_hoursSlider.round()}h';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Header colapsable — siempre visible
          GestureDetector(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 14, color: _accentBlue),
                  const SizedBox(width: 6),
                  Text('Filtros',
                      style: const TextStyle(
                          color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(summaryText,
                        style: TextStyle(color: _accentBlue, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                  if (_methodFilter != 'ALL') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _methodColor(_methodFilter).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(_methodLabel(_methodFilter),
                          style: TextStyle(
                              color: _methodColor(_methodFilter), fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _filtersExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 18, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ),
          // Contenido expandible
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_useCustomRange) ...[
                    Row(
                      children: [
                        Text('Últimas ${_hoursSlider.round()}h',
                            style: const TextStyle(
                                color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _pickDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _accentBlue.withValues(alpha: 0.4)),
                            ),
                            child: const Text('Rango fechas',
                                style: TextStyle(color: _accentBlue, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: _accentBlue,
                        inactiveTrackColor: _borderColor,
                        thumbColor: _accentBlue,
                        overlayColor: _accentBlue.withValues(alpha: 0.15),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _hoursSlider,
                        min: 1,
                        max: 72,
                        divisions: 71,
                        onChanged: (v) => setState(() => _hoursSlider = v),
                        onChangeEnd: (_) => _loadRecords(),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.date_range, size: 14, color: _accentBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd/MM HH:mm').format(_rangeStart!)} — ${DateFormat('dd/MM HH:mm').format(_rangeEnd!)}',
                            style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickDateRange,
                          child: const Icon(Icons.edit_calendar, size: 16, color: _accentBlue),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _useCustomRange = false;
                              _rangeStart = null;
                              _rangeEnd = null;
                            });
                            _loadRecords();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Limpiar',
                                style: TextStyle(color: _accentRed, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _filterChip('ALL', 'Todos', _accentBlue),
                      const SizedBox(width: 6),
                      _filterChip('LITE', 'Básico', _accentGreen),
                      const SizedBox(width: 6),
                      _filterChip('UKF_IMU', 'Preciso', _accentCyan),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState:
                _filtersExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final active = _methodFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _methodFilter = value);
        _loadRecords();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.6) : _borderColor,
            width: 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStatsBar() {
    final avgErr = _records.isEmpty
        ? 0.0
        : _records.map((r) => r.error).fold<double>(0, (a, b) => a + b) / _records.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          _miniStat(Icons.tag, '$_totalCount', 'total'),
          const SizedBox(width: 16),
          _miniStat(Icons.visibility, '${_records.length}', 'visibles'),
          const SizedBox(width: 16),
          _miniStat(Icons.center_focus_strong, '±${avgErr.toStringAsFixed(1)}m', 'promedio'),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _textSecondary),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: _textSecondary.withValues(alpha: 0.8), fontSize: 9)),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _accentBlue));
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage_outlined,
                color: _textSecondary.withValues(alpha: 0.4), size: 56),
            const SizedBox(height: 12),
            const Text('Sin registros en este rango',
                style: TextStyle(color: _textSecondary, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _records.length,
      itemBuilder: (_, i) => _recordCard(_records[i], i),
    );
  }

  String _fmtAmPm(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m:$s $p';
  }

  Widget _recordCard(GpsLocationRecord r, int index) {
    final errColor = _errorColor(r.error);
    final mColor = _methodColor(r.method);
    final mLabel = _methodLabel(r.method);
    final dateStr = DateFormat('dd/MM/yy').format(r.createdAt.toLocal());
    final startStr = r.dateStart != null ? _fmtAmPm(r.dateStart!.toLocal()) : null;
    final endStr = r.dateFinish != null ? _fmtAmPm(r.dateFinish!.toLocal()) : null;
    final createdStr = _fmtAmPm(r.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        children: [
          // Índice + fecha
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text('${index + 1}',
                    style: TextStyle(
                        color: _textSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                Text(dateStr,
                    style: TextStyle(
                        color: _textSecondary.withValues(alpha: 0.5),
                        fontSize: 8)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Coordenadas + hora inicio/fin + speed + battery
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.lat.toStringAsFixed(6)}, ${r.lon.toStringAsFixed(6)}',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [ui.FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 3),
                // Hora inicio → fin (o createdAt si no hay rango)
                Row(
                  children: [
                    Icon(Icons.schedule, size: 10, color: _accentBlue.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    if (startStr != null && endStr != null) ...[
                      Text(startStr,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                      Text(' → ',
                          style: TextStyle(
                              color: _textSecondary.withValues(alpha: 0.6), fontSize: 9)),
                      Text(endStr,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                    ] else
                      Text(createdStr,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                // Speed + Battery + PointCount + Altitude
                Row(
                  children: [
                    Icon(Icons.speed, size: 10,
                        color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 2),
                    Text('${r.speed.toStringAsFixed(1)}m/s',
                        style: TextStyle(
                            color: _textSecondary.withValues(alpha: 0.85), fontSize: 9)),
                    const SizedBox(width: 6),
                    Icon(Icons.battery_std, size: 10,
                        color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 2),
                    Text('${r.battery}%',
                        style: TextStyle(
                            color: _textSecondary.withValues(alpha: 0.85), fontSize: 9)),
                    const SizedBox(width: 6),
                    Icon(Icons.terrain, size: 10,
                        color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 2),
                    Text('${r.alt.toStringAsFixed(0)}m',
                        style: TextStyle(
                            color: _textSecondary.withValues(alpha: 0.85), fontSize: 9)),
                    if (r.pointCount > 1) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.layers, size: 10,
                          color: _textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 2),
                      Text('×${r.pointCount}',
                          style: TextStyle(
                              color: _textSecondary.withValues(alpha: 0.85), fontSize: 9)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Error + method
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: errColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: errColor.withValues(alpha: 0.5)),
                ),
                child: Text('±${r.error.toStringAsFixed(1)}m',
                    style: TextStyle(
                        color: errColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: mColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(mLabel,
                    style: TextStyle(
                        color: mColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MAPA
  // ==========================================================================

  void _showMapSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GpsMapBottomSheet(records: _records),
    );
  }
}

// ============================================================================
// MAP BOTTOM SHEET
// ============================================================================

class GpsMapBottomSheet extends StatefulWidget {
  final List<GpsLocationRecord> records;
  const GpsMapBottomSheet({required this.records});

  @override
  State<GpsMapBottomSheet> createState() => GpsMapBottomSheetState();
}

class GpsMapBottomSheetState extends State<GpsMapBottomSheet> {
  final MapController _mapController = MapController();
  PmTilesArchive? _archive;
  VectorTileProvider? _tileProvider;
  vtr.Theme? _vectorTheme;
  bool _loading = true;
  String? _error;

  static const Color _bgDeep = Color(0xFF0A0E1A);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _textPrimary = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _archive?.close();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initMap() async {
    try {
      final pmtilesPath = FFAppState().pathPmtiles;
      if (pmtilesPath.trim().isEmpty || !File(pmtilesPath).existsSync()) {
        setState(() {
          _error = 'Archivo PMTiles no encontrado';
          _loading = false;
        });
        return;
      }

      _archive = await PmTilesArchive.from(pmtilesPath);
      _tileProvider = GpsPMTilesProvider(_archive!);
      _vectorTheme = _createTheme();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Error cargando mapa: $e';
        _loading = false;
      });
    }
  }

  vtr.Theme _createTheme() {
    return vtr.ThemeReader().read({
      "version": 8,
      "sources": {"pmtiles": {"type": "vector"}},
      "layers": [
        {"id": "background", "type": "background", "paint": {"background-color": "#F8F4F0"}},
        {"id": "water", "type": "fill", "source": "pmtiles", "source-layer": "water", "paint": {"fill-color": "#AAD3DF"}},
        {"id": "park", "type": "fill", "source": "pmtiles", "source-layer": "park", "paint": {"fill-color": "#D8E8C8"}},
        {"id": "building", "type": "fill", "source": "pmtiles", "source-layer": "building", "paint": {"fill-color": "#E0E0E0", "fill-opacity": 0.7}},
        {"id": "road", "type": "line", "source": "pmtiles", "source-layer": "transportation", "paint": {"line-color": "#FFFFFF", "line-width": 2}},
        {"id": "place_label", "type": "symbol", "source": "pmtiles", "source-layer": "place", "layout": {"text-field": ["get", "name"], "text-size": 12}, "paint": {"text-color": "#333333", "text-halo-color": "#FFFFFF", "text-halo-width": 2}},
      ],
    });
  }

  Color _errorColor(double error) {
    if (error <= 5) return const Color(0xFF10B981);
    if (error <= 10) return const Color(0xFF84CC16);
    if (error <= 15) return const Color(0xFFF59E0B);
    if (error <= 25) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.records.isNotEmpty
        ? latlong.LatLng(widget.records.first.lat, widget.records.first.lon)
        : latlong.LatLng(4.6, -74.1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: _bgDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: _accentBlue, size: 20),
                const SizedBox(width: 8),
                Text('${widget.records.length} puntos GPS',
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: _textPrimary, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _accentBlue))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: _textPrimary)))
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 16,
                            minZoom: 3,
                            maxZoom: 18,
                          ),
                          children: [
                            VectorTileLayer(
                              theme: _vectorTheme!,
                              tileProviders:
                                  TileProviders({'pmtiles': _tileProvider!}),
                              maximumZoom: 14,
                            ),
                            // Ruta (polyline)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: widget.records.reversed
                                      .map((r) => latlong.LatLng(r.lat, r.lon))
                                      .toList(),
                                  color: _accentBlue.withValues(alpha: 0.7),
                                  strokeWidth: 3,
                                ),
                              ],
                            ),
                            // Markers
                            MarkerLayer(
                              markers: widget.records.map((r) {
                                final c = _errorColor(r.error);
                                return Marker(
                                  point: latlong.LatLng(r.lat, r.lon),
                                  width: 14,
                                  height: 14,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PMTILES PROVIDER (reutilizado de offline_map_tracker)
// ============================================================================

class GpsPMTilesProvider extends VectorTileProvider {
  final PmTilesArchive archive;
  GpsPMTilesProvider(this.archive);

  @override
  int get maximumZoom => 14;

  @override
  int get minimumZoom => 0;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      int z = tile.z, x = tile.x, y = tile.y;
      if (tile.z > 14) {
        final d = math.pow(2, tile.z - 14).toInt();
        z = 14;
        x = tile.x ~/ d;
        y = tile.y ~/ d;
      }
      final tileId = ZXY(z, x, y).toTileId();
      final pmTile = await archive.tile(tileId);
      return Uint8List.fromList(pmTile.bytes());
    } catch (_) {
      return Uint8List(0);
    }
  }
}
