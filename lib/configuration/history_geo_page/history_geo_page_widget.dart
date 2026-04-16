import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/backend/schema/structs/index.dart';
import '/custom_code/actions/background_location_service.dart';
import '/custom_code/actions/enriched_geo_buffer.dart';
import '/configuration/history_geo_sqlite_page/history_geo_sqlite_page_widget.dart';
import 'history_geo_page_model.dart';
export 'history_geo_page_model.dart';

class HistoryGeoPageWidget extends StatefulWidget {
  const HistoryGeoPageWidget({super.key});

  static String routeName = 'HistoryGeoPage';
  static String routePath = '/historyGeoPage';

  @override
  State<HistoryGeoPageWidget> createState() => _HistoryGeoPageWidgetState();
}

class _HistoryGeoPageWidgetState extends State<HistoryGeoPageWidget> {
  late HistoryGeoPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Colores del diseño moderno
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

  bool _isChangingMode = false;
  bool _sortDescending = true; // true = más reciente primero (default)

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistoryGeoPageModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _formatAmPm(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m:$s $period';
  }

  void _showRealtimeMap(BuildContext ctx, FFAppState appState) {
    final records = appState.geoLocationsList
        .map((p) => GpsLocationRecord(
              lat: p.latitude,
              lon: p.longitude,
              alt: p.altitude,
              error: p.errorHorizontal,
              speed: p.speed,
              battery: p.battery,
              pointCount: 1,
              method: p.method,
              createdAt: p.dateHourRead ?? DateTime.now(),
              evaluatedRadius: 0.0,
            ))
        .toList();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GpsMapBottomSheet(records: records),
    );
  }

  Color _errorColor(double error) {
    if (error <= 5) return _accentGreen;
    if (error <= 10) return const Color(0xFF84CC16);
    if (error <= 15) return _accentAmber;
    if (error <= 25) return const Color(0xFFFB923C);
    return _accentRed;
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'UKF_IMU':
        return 'PRECISO';
      case 'LITE':
        return 'BÁSICO';
      case 'MIXED':
        return 'MIXTO';
      default:
        return method;
    }
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'UKF_IMU':
        return _accentCyan;
      case 'LITE':
        return _accentGreen;
      case 'MIXED':
        return _accentAmber;
      default:
        return _textSecondary;
    }
  }

  Future<void> _toggleMode(String newMode) async {
    if (_isChangingMode || FFAppState().gpsMode == newMode) return;
    setState(() => _isChangingMode = true);

    // 1. Escribir modo + asegurar flush a disco
    FFAppState().gpsMode = newMode;

    // 2. Resetear estado GPS para re-estabilización con el nuevo servicio
    FFAppState().update(() {
      FFAppState().isStabilized = false;
    });

    // 3. Limpiar buffers en memoria para que no haya datos del modo anterior
    FFAppState().geoLocationsList.clear();
    EnrichedGeoBuffer().clear();

    // 4. Reiniciar el servicio en background (lee modo desde SharedPreferences)
    try {
      await restartBackgroundLocationService();
    } catch (e) {
      debugPrint('❌ Error reiniciando servicio GPS: $e');
    }

    if (!mounted) return;
    setState(() => _isChangingMode = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _bgCardLight,
        content: Row(
          children: [
            Icon(
              newMode == 'ADVANCED' ? Icons.flash_on : Icons.eco_outlined,
              color: newMode == 'ADVANCED' ? _accentCyan : _accentGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Modo ${newMode == "ADVANCED" ? "PRECISO" : "BÁSICO"} activado',
              style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: _bgDeep,
        floatingActionButton: Consumer<FFAppState>(
          builder: (ctx, appState, _) {
            if (appState.geoLocationsList.isEmpty) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () => _showRealtimeMap(ctx, appState),
              backgroundColor: _accentBlue,
              icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
              label: const Text('Mapa',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            );
          },
        ),
        body: SafeArea(
          child: Consumer<FFAppState>(
            builder: (context, appState, _) {
              final points = List<ReadGeoStruct>.from(appState.geoLocationsList);
              final sorted = _sortDescending
                  ? points.reversed.toList()
                  : List<ReadGeoStruct>.from(points);

              // Estadísticas en vivo
              final total = points.length;
              final avgError = points.isEmpty
                  ? 0.0
                  : points.map((p) => p.errorHorizontal).fold<double>(0.0, (a, b) => a + b) / total;
              final bestError = points.isEmpty
                  ? 0.0
                  : points.map((p) => p.errorHorizontal).reduce((a, b) => a < b ? a : b);
              final currentMode = appState.gpsMode;
              final isStabilized = appState.isStabilized;

              return Column(
                children: [
                  _buildHeader(context),
                  _buildModeToggle(currentMode),
                  _buildStatusChips(isStabilized, total, currentMode),
                  _buildStatsRow(total, avgError, bestError),
                  _buildSortBar(),
                  Expanded(child: _buildPointsList(sorted)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
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
                const Text(
                  'GPS en Tiempo Real',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Geolocalizaciones activas en memoria',
                  style: TextStyle(
                    color: _textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.pushNamed(HistoryGeoSqlitePageWidget.routeName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentBlue.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todo',
                    style: TextStyle(
                      color: _accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, color: _accentBlue, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(String currentMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              label: 'BÁSICO',
              subtitle: 'Bajo consumo',
              icon: Icons.eco_outlined,
              color: _accentGreen,
              isActive: currentMode == 'LITE',
              onTap: () => _toggleMode('LITE'),
            ),
          ),
          Expanded(
            child: _modeButton(
              label: 'PRECISO',
              subtitle: 'UKF + IMU',
              icon: Icons.flash_on_rounded,
              color: _accentCyan,
              isActive: currentMode == 'ADVANCED',
              onTap: () => _toggleMode('ADVANCED'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isChangingMode ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isChangingMode && isActive)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, color: isActive ? color : _textSecondary, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? _textPrimary : _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isActive ? color : _textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChips(bool isStabilized, int total, String mode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(
            icon: isStabilized ? Icons.gps_fixed : Icons.gps_not_fixed,
            label: isStabilized ? 'Estabilizado' : 'Estabilizando',
            color: isStabilized ? _accentGreen : _accentAmber,
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.radio_button_checked,
            label: 'EN VIVO',
            color: _accentBlue,
            pulse: true,
          ),
          const Spacer(),
          Text(
            '$total pts',
            style: TextStyle(
              color: _textSecondary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    bool pulse = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Text('Ordenar por fecha',
              style: TextStyle(
                  color: _textSecondary.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          _sortButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Recientes',
            active: _sortDescending,
            onTap: () => setState(() => _sortDescending = true),
          ),
          const SizedBox(width: 6),
          _sortButton(
            icon: Icons.arrow_upward_rounded,
            label: 'Antiguos',
            active: !_sortDescending,
            onTap: () => setState(() => _sortDescending = false),
          ),
        ],
      ),
    );
  }

  Widget _sortButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _accentBlue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _accentBlue.withValues(alpha: 0.5) : _borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? _accentBlue : _textSecondary),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: active ? _accentBlue : _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, double avgError, double bestError) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
              child: _statCard(
            icon: Icons.tag,
            label: 'TOTAL',
            value: '$total',
            unit: 'puntos',
            color: _accentBlue,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard(
            icon: Icons.center_focus_strong,
            label: 'PROMEDIO',
            value: avgError.toStringAsFixed(1),
            unit: 'metros',
            color: _errorColor(avgError),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _statCard(
            icon: Icons.star_rounded,
            label: 'MEJOR',
            value: bestError.toStringAsFixed(1),
            unit: 'metros',
            color: _errorColor(bestError),
          )),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: _textSecondary.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: _textSecondary.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsList(List<ReadGeoStruct> points) {
    if (points.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.satellite_alt_outlined,
                color: _textSecondary.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            Text(
              'Esperando geolocalizaciones...',
              style: TextStyle(
                color: _textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El servicio en segundo plano alimentará esta lista',
              style: TextStyle(
                color: _textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: points.length,
      itemBuilder: (context, index) {
        final p = points[index];
        final isNewest = index == 0;
        return _pointCard(p, isNewest, points.length - index);
      },
    );
  }

  Widget _pointCard(ReadGeoStruct p, bool isNewest, int number) {
    final errColor = _errorColor(p.errorHorizontal);
    final method = p.method;
    final mColor = _methodColor(method);
    final mLabel = _methodLabel(method);
    final timeStr = p.dateHourRead != null
        ? _formatAmPm(p.dateHourRead!)
        : '--:--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNewest ? _bgCardLight : _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNewest ? mColor.withValues(alpha: 0.5) : _borderColor,
          width: isNewest ? 1.5 : 1,
        ),
        boxShadow: isNewest
            ? [
                BoxShadow(
                  color: mColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: errColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: errColor.withValues(alpha: 0.5), width: 1),
            ),
            child: Center(
              child: Text(
                '#$number',
                style: TextStyle(
                  color: errColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 11,
                        color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.terrain, size: 11,
                        color: _textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 3),
                    Text(
                      '${p.altitude.toStringAsFixed(0)}m',
                      style: TextStyle(
                        color: _textSecondary.withValues(alpha: 0.85),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: errColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: errColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  '±${p.errorHorizontal.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: errColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: mColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  mLabel,
                  style: TextStyle(
                    color: mColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
