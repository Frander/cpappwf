// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ============================================================================
// ENUMS Y CLASES DE DATOS
// ============================================================================

enum TimeRange {
  minutes5('5 minutos', Duration(minutes: 5)),
  minutes15('15 minutos', Duration(minutes: 15)),
  minutes30('30 minutos', Duration(minutes: 30)),
  hour1('1 hora', Duration(hours: 1)),
  hours2('2 horas', Duration(hours: 2)),
  hours3('3 horas', Duration(hours: 3)),
  hours4('4 horas', Duration(hours: 4)),
  hours5('5 horas', Duration(hours: 5)),
  hours6('6 horas', Duration(hours: 6)),
  hours7('7 horas', Duration(hours: 7)),
  hours8('8 horas', Duration(hours: 8)),
  hours9('9 horas', Duration(hours: 9)),
  day1('1 día', Duration(days: 1));

  final String label;
  final Duration duration;

  const TimeRange(this.label, this.duration);
}

class LocationRecord {
  final int id;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double battery;
  final DateTime createdAt;

  LocationRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.battery,
    required this.createdAt,
  });

  factory LocationRecord.fromMap(Map<String, dynamic> map) {
    return LocationRecord(
      id: (map['Id_location_tracking'] as num?)?.toInt() ?? 0,
      latitude: (map['Latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['Longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['Altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['Speed'] as num?)?.toDouble() ?? 0.0,
      battery: (map['Battery'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['CreatedAt'] != null
          ? DateTime.parse(map['CreatedAt'] as String)
          : DateTime.now(),
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class HistoryLocationsTracker extends StatefulWidget {
  const HistoryLocationsTracker({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<HistoryLocationsTracker> createState() =>
      _HistoryLocationsTrackerState();
}

class _HistoryLocationsTrackerState extends State<HistoryLocationsTracker>
    with SingleTickerProviderStateMixin {
  // Estado
  List<LocationRecord> _allLocations = [];
  List<LocationRecord> _filteredLocations = [];
  TimeRange _selectedTimeRange = TimeRange.hour1;
  bool _isLoading = true;
  String? _errorMessage;

  // Optimización
  bool _showOptimizePanel = false;
  TimeRange _selectedOptimizeRange = TimeRange.hours2;

  // UI State
  bool _showTimeRangePanel = false;

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Timer para auto-actualización
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Cargar datos
    _loadLocationData();

    // Configurar auto-actualización cada 10 segundos
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLocationData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ========================================================================
  // MÉTODOS DE DATOS
  // ========================================================================

  String _formatFriendlyDateTime(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final difference = now.difference(localDate);

    // Formato de hora en 12 horas con AM/PM
    String formatTime(DateTime dt) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:$minute $period';
    }

    // Verificar si es hoy
    final isToday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;

    if (isToday) {
      return 'Hoy a las ${formatTime(localDate)}';
    }

    // Verificar si es ayer
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day;

    if (isYesterday) {
      return 'Ayer a las ${formatTime(localDate)}';
    }

    // Entre 2 y 6 días atrás
    if (difference.inDays >= 2 && difference.inDays <= 6) {
      final days = difference.inDays;
      return 'Hace $days días a las ${formatTime(localDate)}';
    }

    // Esta semana (día de la semana)
    if (difference.inDays == 7) {
      final weekday = [
        '',
        'lunes',
        'martes',
        'miércoles',
        'jueves',
        'viernes',
        'sábado',
        'domingo'
      ][localDate.weekday];
      return 'El $weekday a las ${formatTime(localDate)}';
    }

    // Más de 7 días - formato completo
    return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year} a las ${formatTime(localDate)}';
  }

  Future<String> _getDatabasePath() async {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final String pathStr = '${baseDir.path}/ClickPalmData';
    return path.join(pathStr, 'clickpalm_database.db');
  }

  Future<void> _loadLocationData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      final List<Map<String, dynamic>> results = await database.query(
        'Location_tracking',
        orderBy: 'CreatedAt DESC',
      );

      await database.close();

      _allLocations =
          results.map((row) => LocationRecord.fromMap(row)).toList();

      _applyTimeFilter();

      setState(() {
        _isLoading = false;
      });

      debugPrint('✅ Cargadas ${_allLocations.length} geolocalizaciones');
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar los datos: $e';
      });
    }
  }

  void _applyTimeFilter() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(_selectedTimeRange.duration);

    _filteredLocations = _allLocations
        .where((location) => location.createdAt.isAfter(cutoffTime))
        .toList();

    debugPrint(
        '🔍 Filtro aplicado: ${_selectedTimeRange.label} → ${_filteredLocations.length} registros');
  }

  Future<void> _optimizeData() async {
    try {
      // Mostrar diálogo de confirmación
      final confirm = await _showConfirmDialog(
        '¿Optimizar Base de Datos?',
        'Se eliminarán todas las geolocalizaciones de hace ${_selectedOptimizeRange.label} o más.\n\n'
            'Esta acción no se puede deshacer.',
      );

      if (!confirm) return;

      setState(() {
        _isLoading = true;
      });

      final now = DateTime.now();
      final cutoffTime = now.subtract(_selectedOptimizeRange.duration);
      final cutoffString = cutoffTime.toIso8601String();

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      // Obtener cantidad de registros a eliminar
      final List<Map<String, dynamic>> countResult = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Location_tracking WHERE CreatedAt < ?',
        [cutoffString],
      );

      final int deleteCount = countResult.first['count'] as int;

      // Eliminar registros antiguos
      final int deleted = await database.delete(
        'Location_tracking',
        where: 'CreatedAt < ?',
        whereArgs: [cutoffString],
      );

      await database.close();

      // Recargar datos
      await _loadLocationData();

      // Mostrar resultado
      _showSuccessDialog(
        'Optimización Completada',
        'Se eliminaron $deleted registros antiguos.\n\n'
            'Registros restantes: ${_allLocations.length}',
      );

      setState(() {
        _showOptimizePanel = false;
      });

      debugPrint('✅ Optimización completada: $deleted registros eliminados');
    } catch (e) {
      debugPrint('❌ Error optimizando datos: $e');
      _showErrorDialog('Error al optimizar', e.toString());

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========================================================================
  // MÉTODOS DE UI
  // ========================================================================

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Aceptar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // BUILD WIDGETS
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F9FA),
            Color(0xFFE9ECEF),
          ],
        ),
      ),
      child: Stack(
        children: [
          _isLoading ? _buildLoadingScreen() : _buildMainContent(),
          // Botón flotante de optimización
          if (!_isLoading && _errorMessage == null)
            _buildFloatingOptimizeButton(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cargando historial...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Column(
      children: [
        _buildHeader(),
        _buildTimeRangeSelector(),
        _buildStatsBar(),
        Expanded(child: _buildLocationsList()),
      ],
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error al cargar datos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadLocationData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_history,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Ubicaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Administración de Geolocalizaciones',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadLocationData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Actualizar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header colapsable
          InkWell(
            onTap: () {
              setState(() {
                _showTimeRangePanel = !_showTimeRangePanel;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Período de Visualización',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedTimeRange.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showTimeRangePanel ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),
          ),
          // Panel expandible
          if (_showTimeRangePanel)
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TimeRange.values.map((range) {
                      final isSelected = _selectedTimeRange == range;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTimeRange = range;
                            _applyTimeFilter();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6)
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            range.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalCount = _allLocations.length;
    final filteredCount = _filteredLocations.length;
    final oldestLocation =
        _filteredLocations.isEmpty ? null : _filteredLocations.last.createdAt;
    final newestLocation =
        _filteredLocations.isEmpty ? null : _filteredLocations.first.createdAt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.filter_list,
                  'Mostrados',
                  filteredCount.toString(),
                ),
              ),
              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.storage,
                  'Total',
                  totalCount.toString(),
                ),
              ),
            ],
          ),
          if (oldestLocation != null && newestLocation != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Más antigua',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFriendlyDateTime(oldestLocation),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white70,
                    size: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Más reciente',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFriendlyDateTime(newestLocation),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsList() {
    if (_filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_off,
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay ubicaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron registros en ${_selectedTimeRange.label}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLocations.length,
      itemBuilder: (context, index) {
        final location = _filteredLocations[index];
        return _buildLocationCard(location, index);
      },
    );
  }

  Widget _buildLocationCard(LocationRecord location, int index) {
    final now = DateTime.now();
    final difference = now.difference(location.createdAt);

    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Ahora';
    } else if (difference.inMinutes < 60) {
      timeAgo = 'hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      timeAgo = 'hace ${difference.inHours}h';
    } else {
      timeAgo = 'hace ${difference.inDays}d';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLocationDetails(location),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Número de índice
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _formatFriendlyDateTime(location.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeAgo,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.location_on,
                            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                            const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              Icons.speed,
                              '${location.speed.toStringAsFixed(1)} m/s',
                              const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              Icons.battery_full,
                              '${location.battery.toStringAsFixed(0)}%',
                              const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingOptimizeButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Panel de optimización (si está visible)
          if (_showOptimizePanel)
            Container(
              width: 320,
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildOptimizePanel(),
            ),
          // Botón flotante
          FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                _showOptimizePanel = !_showOptimizePanel;
                if (_showOptimizePanel) {
                  _animationController.forward();
                } else {
                  _animationController.reverse();
                }
              });
            },
            backgroundColor: _showOptimizePanel
                ? const Color(0xFF6B7280)
                : const Color(0xFFEF4444),
            elevation: 6,
            icon: Icon(
              _showOptimizePanel ? Icons.close : Icons.cleaning_services,
              color: Colors.white,
            ),
            label: Text(
              _showOptimizePanel ? 'Cancelar' : 'Optimizar',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizePanel() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_sweep,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optimizar Base de Datos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Selecciona el período a conservar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA16207),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TimeRange.values.map((range) {
                final isSelected = _selectedOptimizeRange == range;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOptimizeRange = range;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFF59E0B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFFA16207),
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFA16207),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Se eliminarán todas las ubicaciones anteriores a ${_selectedOptimizeRange.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _optimizeData,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Confirmar Optimización',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDetails(LocationRecord location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalles de Ubicación',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Información completa del registro',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.fingerprint,
                      'ID',
                      location.id.toString(),
                      const Color(0xFF6366F1),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time,
                      'Fecha y Hora',
                      _formatFriendlyDateTime(location.createdAt),
                      const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.my_location,
                      'Latitud',
                      location.latitude.toStringAsFixed(8),
                      const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.location_searching,
                      'Longitud',
                      location.longitude.toStringAsFixed(8),
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.terrain,
                      'Altitud',
                      '${location.altitude.toStringAsFixed(2)} m',
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.speed,
                      'Velocidad',
                      '${location.speed.toStringAsFixed(2)} m/s (${(location.speed * 3.6).toStringAsFixed(2)} km/h)',
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.battery_full,
                      'Batería',
                      '${location.battery.toStringAsFixed(1)}%',
                      const Color(0xFF059669),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
