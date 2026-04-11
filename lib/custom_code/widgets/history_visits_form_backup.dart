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
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ============================================================================
// ENUMS Y CLASES DE DATOS
// ============================================================================

enum TimeFilterRange {
  minutes30('30 minutos', Duration(minutes: 30)),
  hour1('1 hora', Duration(hours: 1)),
  hours2('2 horas', Duration(hours: 2)),
  hours3('3 horas', Duration(hours: 3)),
  hours4('4 horas', Duration(hours: 4)),
  hours5('5 horas', Duration(hours: 5)),
  hours6('6 horas', Duration(hours: 6)),
  hours7('7 horas', Duration(hours: 7)),
  hours8('8 horas', Duration(hours: 8)),
  day1('1 día', Duration(days: 1)),
  all('Todo', Duration(days: 365));

  final String label;
  final Duration duration;

  const TimeFilterRange(this.label, this.duration);
}

class VisitRecord {
  final int idVisit;
  final int idUser;
  final String? userName;
  final int idHeadquarter;
  final String headquarterName;
  final int? idStatus;
  final String? statusName;
  final String? statusColor;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final double battery;
  final int gpsPointsCount;
  final int responsesCount;

  VisitRecord({
    required this.idVisit,
    required this.idUser,
    this.userName,
    required this.idHeadquarter,
    required this.headquarterName,
    this.idStatus,
    this.statusName,
    this.statusColor,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.gpsPointsCount,
    required this.responsesCount,
  });

  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      idVisit: (map['Id_visit'] as num?)?.toInt() ?? 0,
      idUser: (map['Id_user'] as num?)?.toInt() ?? 0,
      userName: map['Name_user'] as String?,
      idHeadquarter: (map['Id_headquarter'] as num?)?.toInt() ?? 0,
      headquarterName: (map['Name_headquarter'] as String?) ?? 'Sin nombre',
      idStatus: (map['Id_status'] as num?)?.toInt(),
      statusName: map['Status_name'] as String?,
      statusColor: map['Color'] as String?,
      createdAt: map['Created_at'] != null
          ? DateTime.parse(map['Created_at'] as String)
          : DateTime.now(),
      latitude: (map['Latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['Longitude'] as num?)?.toDouble() ?? 0.0,
      battery: (map['Battery'] as num?)?.toDouble() ?? 0.0,
      gpsPointsCount: (map['gps_count'] as num?)?.toInt() ?? 0,
      responsesCount: (map['responses_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DayProductivityStats {
  final DateTime day;
  final DateTime? firstVisit;
  final DateTime? lastVisit;
  final Duration horasLaboradas;
  final Duration horasEfectivas;
  final Duration horasImproductivas;
  final int totalVisits;

  DayProductivityStats({
    required this.day,
    this.firstVisit,
    this.lastVisit,
    required this.horasLaboradas,
    required this.horasEfectivas,
    required this.horasImproductivas,
    required this.totalVisits,
  });

  double get tasaEfectividad {
    if (horasLaboradas.inSeconds == 0) return 0.0;
    return (horasEfectivas.inSeconds / horasLaboradas.inSeconds) * 100;
  }

  factory DayProductivityStats.empty() {
    return DayProductivityStats(
      day: DateTime.now(),
      horasLaboradas: Duration.zero,
      horasEfectivas: Duration.zero,
      horasImproductivas: Duration.zero,
      totalVisits: 0,
    );
  }
}

class StateStats {
  final int? idStatus;
  final String statusName;
  final String? color;
  final int count;

  StateStats({
    this.idStatus,
    required this.statusName,
    this.color,
    required this.count,
  });

  factory StateStats.fromMap(Map<String, dynamic> map) {
    return StateStats(
      idStatus: (map['Id_activity_status'] as num?)?.toInt(),
      statusName: (map['Status_name'] as String?) ?? 'Sin estado',
      color: map['Color'] as String?,
      count: (map['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}

class VisitDetail {
  final String statusOption;
  final String statusResponse;
  final String statusName;

  VisitDetail({
    required this.statusOption,
    required this.statusResponse,
    required this.statusName,
  });

  factory VisitDetail.fromMap(Map<String, dynamic> map) {
    return VisitDetail(
      statusOption: (map['Status_option'] as String?) ?? '',
      statusResponse: (map['Status_response'] as String?) ?? '',
      statusName: (map['Status_name'] as String?) ?? '',
    );
  }
}

class GPSTrackingInfo {
  final int totalPoints;
  final DateTime? firstPoint;
  final DateTime? lastPoint;
  final double? firstLat;
  final double? firstLng;
  final double? lastLat;
  final double? lastLng;

  GPSTrackingInfo({
    required this.totalPoints,
    this.firstPoint,
    this.lastPoint,
    this.firstLat,
    this.firstLng,
    this.lastLat,
    this.lastLng,
  });

  Duration? get duration {
    if (firstPoint == null || lastPoint == null) return null;
    return lastPoint!.difference(firstPoint!);
  }
}

// Clase para almacenar detalles individuales de cada punto GPS
class GPSPointDetail {
  final int id;
  final double latitude;
  final double longitude;
  final double altitude;
  final double horizontalError;
  final DateTime createdAt;

  GPSPointDetail({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.horizontalError,
    required this.createdAt,
  });
}

// Clase para almacenar historial de cambios en zonas de exclusión
class ExclusionZoneHistoryRecord {
  final int idHistory;
  final int idPolygonCoordinate;
  final int? idVirtualPoint;
  final int? lineNumber;
  final int? pointNumber;
  final int? previousTypeId;
  final String? previousTypeName;
  final int newTypeId;
  final String? newTypeName;
  final DateTime modifiedAt;
  final int? userId;

  ExclusionZoneHistoryRecord({
    required this.idHistory,
    required this.idPolygonCoordinate,
    this.idVirtualPoint,
    this.lineNumber,
    this.pointNumber,
    this.previousTypeId,
    this.previousTypeName,
    required this.newTypeId,
    this.newTypeName,
    required this.modifiedAt,
    this.userId,
  });

  factory ExclusionZoneHistoryRecord.fromMap(Map<String, dynamic> map) {
    return ExclusionZoneHistoryRecord(
      idHistory: (map['Id_history'] as num?)?.toInt() ?? 0,
      idPolygonCoordinate: (map['Id_polygon_coordinate'] as num?)?.toInt() ?? 0,
      idVirtualPoint: (map['Id_virtual_point'] as num?)?.toInt(),
      lineNumber: (map['Line_number'] as num?)?.toInt(),
      pointNumber: (map['Point_number'] as num?)?.toInt(),
      previousTypeId: (map['Previous_type_id'] as num?)?.toInt(),
      previousTypeName: map['Previous_type_name'] as String?,
      newTypeId: (map['New_type_id'] as num?)?.toInt() ?? 0,
      newTypeName: map['New_type_name'] as String?,
      modifiedAt: map['Modified_at'] != null
          ? DateTime.parse(map['Modified_at'] as String)
          : DateTime.now(),
      userId: (map['User_id'] as num?)?.toInt(),
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class HistoryVisitsForm extends StatefulWidget {
  const HistoryVisitsForm({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<HistoryVisitsForm> createState() => _HistoryVisitsFormState();
}

class _HistoryVisitsFormState extends State<HistoryVisitsForm>
    with TickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // Estado general
  bool _isLoading = true;
  String? _errorMessage;

  // Datos
  List<VisitRecord> _allVisitsOriginal = []; // Todas las visitas sin filtrar
  List<VisitRecord> _allVisits = []; // Visitas de la fecha actual
  List<VisitRecord> _filteredVisits = [];
  DayProductivityStats? _productivityStats;
  List<StateStats> _stateStats = [];

  // Filtros
  TimeFilterRange _selectedTimeFilter = TimeFilterRange.day1;
  int? _selectedStateFilter; // null = todos
  int? _selectedHeadquarterFilter; // null = todos
  int?
      _selectedBatteryRangeFilter; // null = todos, 1=0-25%, 2=26-50%, 3=51-75%, 4=76-100%
  int? _selectedGpsPointsFilter; // null = todos, 1=0-10, 2=11-50, 3=51+

  // UI State
  bool _showFiltersPanel = false;

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Carrusel de fechas
  late PageController _pageController;
  List<DateTime> _uniqueDates = [];
  int _currentDateIndex = 0;
  Map<DateTime, List<VisitRecord>> _visitsByDate = {};

  // Historial de zonas de exclusión
  List<ExclusionZoneHistoryRecord> _allExclusionHistory = [];
  List<ExclusionZoneHistoryRecord> _exclusionHistoryForCurrentDate = [];
  Map<DateTime, List<ExclusionZoneHistoryRecord>> _exclusionHistoryByDate = {};
  bool _hasExclusionData = false;

  @override
  void initState() {
    super.initState();

    // Configurar tab controller (4 pestañas: Resumen, Detalle, Exclusión, Avanzado)
    _tabController = TabController(length: 4, vsync: this);

    // Configurar page controller
    _pageController = PageController();

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
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ========================================================================
  // MÉTODOS DE DATOS
  // ========================================================================

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

  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      // Cargar visitas
      await _loadVisits(database);

      // Calcular stats de productividad
      await _calculateProductivityStats(database);

      // Cargar stats por estado
      await _loadStateStats(database);

      // Cargar historial de zonas de exclusión
      await _loadExclusionHistory(database);

      await database.close();

      // Agrupar visitas por fecha
      _groupVisitsByDate();

      // Agrupar historial de exclusiones por fecha
      _groupExclusionHistoryByDate();

      // Aplicar filtros
      _applyFilters();

      setState(() {
        _isLoading = false;
      });

      debugPrint(
          '✅ Datos cargados: ${_allVisitsOriginal.length} visitas totales, ${_uniqueDates.length} días únicos');
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar los datos: $e';
      });
    }
  }

  Future<void> _loadVisits(Database db) async {
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT
        v.Id_visit,
        v.Id_user,
        v.Id_headquarter,
        v.Id_status,
        v.Created_at,
        v.Latitude,
        v.Longitude,
        v.Battery,
        COALESCE(h.Name_headquarter, 'Sin nombre') as Name_headquarter,
        u.Name_user,
        s.Status_name,
        s.Color,
        (SELECT COUNT(*) FROM Visits_locations vl WHERE vl.Id_visit = v.Id_visit) as gps_count,
        (SELECT COUNT(*) FROM Visits_details vd WHERE vd.Id_visit = v.Id_visit) as responses_count
      FROM Visits v
      LEFT JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
      LEFT JOIN Users u ON v.Id_user = u.Id_user
      LEFT JOIN Activities_status s ON v.Id_status = s.Id_activity_status
      ORDER BY v.Created_at DESC
    ''');

    // Debug: Verificar primeros 3 registros
    if (results.isNotEmpty) {
      debugPrint('📊 DEBUG - Primeros registros de visitas (JOIN corregido):');
      for (int i = 0; i < math.min(3, results.length); i++) {
        final row = results[i];
        debugPrint('  Visita #${i + 1}:');
        debugPrint('    Id_visit: ${row['Id_visit']}');
        debugPrint('    Id_status: ${row['Id_status']}');
        debugPrint('    Status_name: ${row['Status_name']}');
        debugPrint('    Color: ${row['Color']}');
        debugPrint('    Name_headquarter: ${row['Name_headquarter']}');
        debugPrint('    Name_user: ${row['Name_user']}');
      }
    }

    _allVisitsOriginal =
        results.map((row) => VisitRecord.fromMap(row)).toList();
  }

  Future<void> _calculateProductivityStats(Database db) async {
    final DateTime today = DateTime.now();
    final String todayStr = DateFormat('yyyy-MM-dd').format(today);

    final List<Map<String, dynamic>> visits = await db.rawQuery('''
      SELECT Created_at
      FROM Visits
      WHERE DATE(Created_at) = ?
      ORDER BY Created_at ASC
    ''', [todayStr]);

    if (visits.isEmpty) {
      _productivityStats = DayProductivityStats.empty();
      return;
    }

    final DateTime firstVisit = DateTime.parse(visits.first['Created_at']);
    final DateTime lastVisit = DateTime.parse(visits.last['Created_at']);
    final Duration horasLaboradas = lastVisit.difference(firstVisit);

    Duration horasEfectivas = Duration.zero;
    Duration horasImproductivas = Duration.zero;

    // Calcular gaps entre visitas consecutivas
    for (int i = 1; i < visits.length; i++) {
      final prev = DateTime.parse(visits[i - 1]['Created_at']);
      final curr = DateTime.parse(visits[i]['Created_at']);
      final gap = curr.difference(prev);

      if (gap.inMinutes <= 5) {
        horasEfectivas += gap;
      } else {
        horasImproductivas += gap;
      }
    }

    _productivityStats = DayProductivityStats(
      day: today,
      firstVisit: firstVisit,
      lastVisit: lastVisit,
      horasLaboradas: horasLaboradas,
      horasEfectivas: horasEfectivas,
      horasImproductivas: horasImproductivas,
      totalVisits: visits.length,
    );
  }

  Future<void> _loadStateStats(Database db) async {
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT
        s.Id_activity_status,
        COALESCE(s.Status_name, 'Sin estado') as Status_name,
        s.Color,
        COUNT(v.Id_visit) as cantidad
      FROM Visits v
      LEFT JOIN Activities_status s ON v.Id_status = s.Id_activity_status
      GROUP BY s.Id_activity_status, s.Status_name, s.Color
      HAVING s.Id_activity_status IS NOT NULL
      ORDER BY cantidad DESC
    ''');

    _stateStats = results.map((row) => StateStats.fromMap(row)).toList();
  }

  Future<void> _loadExclusionHistory(Database db) async {
    try {
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT
          Id_history,
          Id_polygon_coordinate,
          Id_virtual_point,
          Line_number,
          Point_number,
          Previous_type_id,
          Previous_type_name,
          New_type_id,
          New_type_name,
          Modified_at,
          User_id
        FROM Exclusion_zones_history
        ORDER BY Modified_at DESC
      ''');

      _allExclusionHistory = results
          .map((row) => ExclusionZoneHistoryRecord.fromMap(row))
          .toList();

      _hasExclusionData = _allExclusionHistory.isNotEmpty;

      debugPrint(
          '📍 Historial de exclusiones cargado: ${_allExclusionHistory.length} registros');
    } catch (e) {
      debugPrint('⚠️ Error cargando historial de exclusiones: $e');
      _allExclusionHistory = [];
      _hasExclusionData = false;
    }
  }

  void _groupExclusionHistoryByDate() {
    _exclusionHistoryByDate.clear();

    for (var record in _allExclusionHistory) {
      // Normalizar la fecha a medianoche (sin hora)
      final date = DateTime(
        record.modifiedAt.year,
        record.modifiedAt.month,
        record.modifiedAt.day,
      );

      if (_exclusionHistoryByDate.containsKey(date)) {
        _exclusionHistoryByDate[date]!.add(record);
      } else {
        _exclusionHistoryByDate[date] = [record];
      }
    }

    debugPrint(
        '📅 Historial de exclusiones agrupado en ${_exclusionHistoryByDate.length} días');

    // Actualizar el historial para la fecha actual
    if (_uniqueDates.isNotEmpty) {
      final currentDate = _uniqueDates[_currentDateIndex];
      _exclusionHistoryForCurrentDate =
          _exclusionHistoryByDate[currentDate] ?? [];
    }
  }

  void _groupVisitsByDate() {
    // Agrupar visitas por fecha (sin hora)
    _visitsByDate.clear();

    for (var visit in _allVisitsOriginal) {
      // Normalizar la fecha a medianoche (sin hora)
      final date = DateTime(
        visit.createdAt.year,
        visit.createdAt.month,
        visit.createdAt.day,
      );

      if (_visitsByDate.containsKey(date)) {
        _visitsByDate[date]!.add(visit);
      } else {
        _visitsByDate[date] = [visit];
      }
    }

    // IMPORTANTE: Combinar fechas de visitas Y exclusiones para crear días únicos
    Set<DateTime> allUniqueDates = {};

    // Agregar fechas de visitas
    allUniqueDates.addAll(_visitsByDate.keys);

    // Agregar fechas de exclusiones
    allUniqueDates.addAll(_exclusionHistoryByDate.keys);

    // Ordenar las fechas de más reciente a más antigua
    _uniqueDates = allUniqueDates.toList()..sort((a, b) => b.compareTo(a));

    // Establecer índice en la fecha más reciente
    _currentDateIndex = 0;

    debugPrint('📅 Fechas detectadas: ${_uniqueDates.length}');
    for (var date in _uniqueDates) {
      final visitCount = _visitsByDate[date]?.length ?? 0;
      final exclusionCount = _exclusionHistoryByDate[date]?.length ?? 0;
      debugPrint(
          '   - ${_formatDate(date)}: $visitCount visitas, $exclusionCount exclusiones');
    }

    // Filtrar datos por la primera fecha (más reciente)
    if (_uniqueDates.isNotEmpty) {
      _filterDataByCurrentDate();
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    DateTime cutoffTime;

    if (_selectedTimeFilter == TimeFilterRange.all) {
      cutoffTime = DateTime(1900); // Sin filtro de tiempo
    } else {
      cutoffTime = now.subtract(_selectedTimeFilter.duration);
    }

    _filteredVisits = _allVisits.where((visit) {
      // Filtro de tiempo
      if (visit.createdAt.isBefore(cutoffTime)) return false;

      // Filtro de estado (por statusName ya que idStatus siempre es 0)
      if (_selectedStateFilter != null) {
        // Buscar el estado en _stateStats para comparar por nombre
        final selectedState = _stateStats.firstWhere(
          (s) => s.idStatus == _selectedStateFilter,
          orElse: () => StateStats(
            idStatus: null,
            statusName: '',
            color: null,
            count: 0,
          ),
        );
        if (visit.statusName != selectedState.statusName) {
          return false;
        }
      }

      // Filtro de headquarter
      if (_selectedHeadquarterFilter != null &&
          visit.idHeadquarter != _selectedHeadquarterFilter) {
        return false;
      }

      // Filtro de batería
      if (_selectedBatteryRangeFilter != null) {
        final battery = visit.battery;
        switch (_selectedBatteryRangeFilter) {
          case 1: // 0-25%
            if (battery > 25) return false;
            break;
          case 2: // 26-50%
            if (battery <= 25 || battery > 50) return false;
            break;
          case 3: // 51-75%
            if (battery <= 50 || battery > 75) return false;
            break;
          case 4: // 76-100%
            if (battery <= 75) return false;
            break;
        }
      }

      // Filtro de GPS points
      if (_selectedGpsPointsFilter != null) {
        final gpsCount = visit.gpsPointsCount;
        switch (_selectedGpsPointsFilter) {
          case 1: // 0-10 puntos
            if (gpsCount > 10) return false;
            break;
          case 2: // 11-50 puntos
            if (gpsCount <= 10 || gpsCount > 50) return false;
            break;
          case 3: // 51+ puntos
            if (gpsCount <= 50) return false;
            break;
        }
      }

      return true;
    }).toList();

    debugPrint(
        '🔍 Filtros aplicados: ${_filteredVisits.length} de ${_allVisits.length} visitas');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatFriendlyDateTime(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final difference = now.difference(localDate);

    String formatTime(DateTime dt) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:$minute $period';
    }

    final isToday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;

    if (isToday) {
      return 'Hoy a las ${formatTime(localDate)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day;

    if (isYesterday) {
      return 'Ayer a las ${formatTime(localDate)}';
    }

    if (difference.inDays >= 2 && difference.inDays <= 6) {
      final days = difference.inDays;
      return 'Hace $days días a las ${formatTime(localDate)}';
    }

    return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year} a las ${formatTime(localDate)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();

    final isToday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;

    if (isToday) {
      return 'Hoy';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day;

    if (isYesterday) {
      return 'Ayer';
    }

    final difference = now.difference(localDate).inDays;
    if (difference >= 2 && difference <= 6) {
      return 'Hace $difference días';
    }

    // Nombres de días de la semana
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final weekday = weekdays[localDate.weekday - 1];

    return '$weekday ${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}';
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return FlutterFlowTheme.of(context).primary;
    }

    try {
      // Intenta parsear como hex: #RRGGBB o RRGGBB
      String cleanColor = colorString.replaceAll('#', '');
      if (cleanColor.length == 6) {
        return Color(int.parse('FF$cleanColor', radix: 16));
      }
      // Intenta parsear como número entero
      return Color(int.parse(colorString));
    } catch (e) {
      debugPrint('⚠️ Error parseando color: $colorString');
      return FlutterFlowTheme.of(context).primary;
    }
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
      child: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
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
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cargando historial de visitas...',
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

    if (_uniqueDates.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildHeader(),
        _buildDateCarouselIndicator(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _uniqueDates.length,
            physics: const PageScrollPhysics(), // Permite deslizamiento suave
            onPageChanged: (index) {
              setState(() {
                _currentDateIndex = index;
                // Filtrar datos por la fecha actual
                _filterDataByCurrentDate();
              });
            },
            itemBuilder: (context, index) {
              return _buildDatePage(_uniqueDates[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatePage(DateTime date) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResumenTab(),
              _buildDetalleTab(),
              _buildExclusionTab(),
              _buildAvanzadoTab(date),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateCarouselIndicator() {
    if (_uniqueDates.isEmpty) return const SizedBox.shrink();

    final currentDate = _uniqueDates[_currentDateIndex];
    final visitsCount = _visitsByDate[currentDate]?.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón anterior
          if (_currentDateIndex < _uniqueDates.length - 1)
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              color: FlutterFlowTheme.of(context).primary,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            )
          else
            const SizedBox(width: 28),

          // Fecha actual y contador en una sola línea
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatDate(currentDate),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_turned_in,
                        size: 12,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$visitsCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón siguiente
          if (_currentDateIndex > 0)
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              color: FlutterFlowTheme.of(context).primary,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            )
          else
            const SizedBox(width: 28),
        ],
      ),
    );
  }

  void _filterDataByCurrentDate() {
    if (_uniqueDates.isEmpty) return;

    final currentDate = _uniqueDates[_currentDateIndex];
    final visitsForDate = _visitsByDate[currentDate] ?? [];
    final exclusionHistoryForDate = _exclusionHistoryByDate[currentDate] ?? [];

    // Actualizar las visitas y el historial de exclusiones a mostrar
    setState(() {
      _allVisits = visitsForDate;
      _exclusionHistoryForCurrentDate = exclusionHistoryForDate;
      _applyFilters();
    });

    debugPrint(
        '📅 Filtrando por fecha: ${_formatDate(currentDate)} - ${visitsForDate.length} visitas, ${exclusionHistoryForDate.length} cambios de exclusión');
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
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: FlutterFlowTheme.of(context).error,
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
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
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

  // Widget para estados vacíos de pestañas por día
  Widget _buildEmptyStateForDay({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono animado con diseño moderno
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withValues(alpha: 0.1),
                      iconColor.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 72,
                  color: iconColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Título principal
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Subtítulo descriptivo
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Mensaje adicional con icono
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Navega entre días usando las flechas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono animado
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.1),
                      FlutterFlowTheme.of(context)
                          .secondary
                          .withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.assignment_late_outlined,
                  size: 80,
                  color: FlutterFlowTheme.of(context).primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Texto animado
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    '¡Aún no hay visitas!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: FlutterFlowTheme.of(context).warning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Realiza visitas primero antes\nde ver estadísticas',
                            style: TextStyle(
                              fontSize: 15,
                              color: FlutterFlowTheme.of(context).warning,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Una vez que registres visitas, aquí podrás\nver todas tus métricas de productividad',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Indicadores animados
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildEmptyMetricBadge(
                    Icons.bar_chart,
                    'Gráficos',
                    FlutterFlowTheme.of(context).primary,
                  ),
                  _buildEmptyMetricBadge(
                    Icons.timer,
                    'Productividad',
                    FlutterFlowTheme.of(context).secondary,
                  ),
                  _buildEmptyMetricBadge(
                    Icons.analytics,
                    'Métricas',
                    FlutterFlowTheme.of(context).tertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMetricBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            const Color(0xFF059669),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assessment,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Visitas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Métricas y Productividad',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              tooltip: 'Actualizar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              tooltip: 'Cerrar',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    // Verificar si hay visitas en el día actual
    final bool hasVisitsForCurrentDay = _allVisits.isNotEmpty;

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: FlutterFlowTheme.of(context).primary,
        unselectedLabelColor: const Color(0xFF9CA3AF),
        indicatorColor: FlutterFlowTheme.of(context).primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: (index) {
          // Si el usuario intenta ir a "Detalle" (índice 1) sin visitas, prevenir
          if (index == 1 && !hasVisitsForCurrentDay) {
            // Volver a la pestaña actual
            setState(() {
              _tabController.index = _tabController.previousIndex;
            });

            // Mostrar mensaje
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child:
                          Text('No hay visitas para ver detalles en este día'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        tabs: [
          const Tab(
            icon: Icon(Icons.bar_chart, size: 18),
            text: 'Resumen',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          // Pestaña "Detalle" con estilo deshabilitado si no hay visitas
          Tab(
            icon: Icon(
              Icons.list,
              size: 18,
              color: hasVisitsForCurrentDay ? null : Colors.grey.shade300,
            ),
            child: Opacity(
              opacity: hasVisitsForCurrentDay ? 1.0 : 0.4,
              child: const Text('Detalle'),
            ),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
          const Tab(
            icon: Icon(Icons.not_listed_location, size: 18),
            text: 'Exclusión',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
          const Tab(
            icon: Icon(Icons.settings, size: 18),
            text: 'Avanzado',
            iconMargin: EdgeInsets.only(bottom: 2),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAB 1: RESUMEN
  // ========================================================================

  Widget _buildResumenTab() {
    // Si no hay visitas en el día actual, mostrar estado vacío
    if (_allVisits.isEmpty) {
      return _buildEmptyStateForDay(
        icon: Icons.event_busy,
        title: 'NO TIENES VISITAS PARA VISUALIZAR',
        subtitle: 'No hay visitas registradas para este día',
        iconColor: FlutterFlowTheme.of(context).secondaryText,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsBar(),
          const SizedBox(height: 16),
          _buildEstadosBarChart(),
          const SizedBox(height: 16),
          _buildProductivityCards(),
          const SizedBox(height: 16),
          _buildCircularProgress(),
          const SizedBox(height: 16),
          _buildSecondaryMetrics(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductivityCards() {
    final stats = _productivityStats ?? DayProductivityStats.empty();

    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.schedule,
          title: 'Horas Laboradas',
          value: _formatDuration(stats.horasLaboradas),
          color: FlutterFlowTheme.of(context).primary,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.check_circle,
                title: 'Horas Efectivas',
                value: _formatDuration(stats.horasEfectivas),
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.warning_amber,
                title: 'Horas Improductivas',
                value: _formatDuration(stats.horasImproductivas),
                color: FlutterFlowTheme.of(context).warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress() {
    final stats = _productivityStats ?? DayProductivityStats.empty();
    final efectividad = stats.tasaEfectividad;

    Color progressColor;
    if (efectividad >= 75) {
      progressColor = const Color(0xFF10B981);
    } else if (efectividad >= 50) {
      progressColor = FlutterFlowTheme.of(context).secondary;
    } else {
      progressColor = FlutterFlowTheme.of(context).error;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Tasa de Efectividad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: efectividad / 100,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${efectividad.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Efectividad',
                      style: TextStyle(
                        fontSize: 14,
                        color: progressColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tiempo productivo vs total trabajado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadosBarChart() {
    if (_stateStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Visitas por Estado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          ..._stateStats.take(5).map((stat) {
            final maxCount = _stateStats.first.count;
            final percentage = maxCount > 0 ? stat.count / maxCount : 0.0;
            final color = _parseColor(stat.color);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stat.statusName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Text(
                        '${stat.count}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics() {
    // Calcular métricas secundarias
    final avgGPS = _allVisits.isNotEmpty
        ? _allVisits.map((v) => v.gpsPointsCount).reduce((a, b) => a + b) /
            _allVisits.length
        : 0.0;

    final uniqueHeadquarters =
        _allVisits.map((v) => v.idHeadquarter).toSet().length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          icon: Icons.location_city,
          title: 'Sedes Visitadas',
          value: '$uniqueHeadquarters',
          color: const Color(0xFF3B82F6),
        ),
        _buildMetricCard(
          icon: Icons.gps_fixed,
          title: 'Promedio GPS',
          value: avgGPS.toStringAsFixed(1),
          color: const Color(0xFF10B981),
        ),
        _buildMetricCard(
          icon: Icons.trending_up,
          title: 'Total Hoy',
          value: '${_productivityStats?.totalVisits ?? 0}',
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAB 2: DETALLE
  // ========================================================================

  Widget _buildDetalleTab() {
    // Si no hay visitas en el día actual, mostrar estado vacío
    if (_allVisits.isEmpty) {
      return _buildEmptyStateForDay(
        icon: Icons.list_alt,
        title: 'NO TIENES VISITAS PARA VISUALIZAR',
        subtitle: 'No hay visitas registradas para ver detalles en este día',
        iconColor: FlutterFlowTheme.of(context).secondaryText,
      );
    }

    return Column(
      children: [
        _buildFiltersPanel(),
        Expanded(child: _buildVisitsList()),
      ],
    );
  }

  // ========================================================================
  // TAB 3: EXCLUSIÓN (HISTORIAL DE CAMBIOS EN ZONAS)
  // ========================================================================

  Widget _buildExclusionTab() {
    // Si no hay datos para la fecha actual, mostrar estado vacío elegante
    if (_exclusionHistoryForCurrentDate.isEmpty) {
      return _buildEmptyStateForDay(
        icon: Icons.layers_clear,
        title: 'NO HAY CAMBIOS DE EXCLUSIONES',
        subtitle: 'No hay modificaciones en zonas de exclusión para este día',
        iconColor: Colors.deepOrange,
      );
    }

    // Mostrar lista de cambios
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exclusionHistoryForCurrentDate.length,
      itemBuilder: (context, index) {
        final record = _exclusionHistoryForCurrentDate[index];
        return _buildExclusionHistoryCard(record);
      },
    );
  }

  Widget _buildExclusionHistoryCard(ExclusionZoneHistoryRecord record) {
    final timeStr = DateFormat('HH:mm:ss').format(record.modifiedAt.toLocal());

    // Determinar ícono y color según si es un cambio o adición
    final bool isNew = record.previousTypeName == null;
    final IconData icon = isNew ? Icons.add_location : Icons.edit_location;
    final Color iconColor = isNew ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con hora y tipo de cambio
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'Zona agregada' : 'Zona modificada',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Información del cambio
            if (!isNew) ...[
              _buildInfoRow(
                Icons.remove_circle_outline,
                'Tipo anterior',
                record.previousTypeName ?? 'Sin nombre',
                Colors.red[700]!,
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(width: 32),
                  Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _buildInfoRow(
              Icons.add_circle_outline,
              'Tipo nuevo',
              record.newTypeName ?? 'Sin nombre',
              Colors.green[700]!,
            ),

            const SizedBox(height: 12),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (record.idVirtualPoint != null)
                    _buildExclusionDetailRow(
                        'ID Punto Virtual', '${record.idVirtualPoint}'),
                  if (record.lineNumber != null)
                    _buildExclusionDetailRow('Línea', '${record.lineNumber}'),
                  if (record.pointNumber != null)
                    _buildExclusionDetailRow('Punto', '${record.pointNumber}'),
                  _buildExclusionDetailRow(
                      'ID Polígono', '${record.idPolygonCoordinate}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExclusionDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAB 4: AVANZADO (POR DÍA)
  // ========================================================================

  Widget _buildAvanzadoTab(DateTime date) {
    final visitsForDate = _visitsByDate[date] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header informativo con fecha
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Funciones del día: ${_formatDate(date)}',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Las acciones en esta sección son irreversibles. Se requiere código de confirmación.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Opción: Eliminar visitas del día
          _buildDayAdvancedOption(
            icon: Icons.delete_sweep,
            title: 'Eliminar Visitas del Día',
            description:
                'Elimina todas las visitas de este día de SQLite (Visits, Visits_details, Visits_locations)',
            color: Colors.red,
            onTap: () => _showConfirmDeleteDayData(date),
          ),
          const SizedBox(height: 16),

          // Opción: Limpiar AppState del día
          _buildDayAdvancedOption(
            icon: Icons.memory,
            title: 'Limpiar AppState del Día',
            description:
                'Limpia las variables de AppState relacionadas con este día',
            color: Colors.blue,
            onTap: () => _showConfirmClearDayAppState(date),
          ),
          const SizedBox(height: 32),

          // DIVIDER entre opciones del día y opciones globales
          const Divider(thickness: 2, height: 32),

          // Header para opciones GLOBALES
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded,
                    color: Colors.red.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FUNCIONES GLOBALES - PELIGRO',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Las siguientes acciones afectan TODOS los datos, no solo este día. Requieren código de confirmación.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón 1: Limpiar TODAS las visitas (SQLite + AppState)
          _buildGlobalAdvancedOption(
            icon: Icons.delete_forever,
            title: 'Eliminar TODAS las Visitas',
            description:
                'Elimina TODAS las visitas de SQLite (Visits, Visits_details, Visits_locations) y limpia AppState (visitCount, visitsAdd, visitDetails)',
            color: Colors.red,
            onTap: _showConfirmDeleteAllVisits,
          ),
          const SizedBox(height: 16),

          // Botón 2: Limpiar Exclusion_zones_history
          _buildGlobalAdvancedOption(
            icon: Icons.layers_clear,
            title: 'Eliminar Historial de Exclusiones',
            description:
                'Elimina TODOS los registros de la tabla Exclusion_zones_history',
            color: Colors.deepOrange,
            onTap: _showConfirmDeleteExclusionHistory,
          ),
          const SizedBox(height: 16),

          // Botón 3: Limpieza COMPLETA (igual que después de sincronización)
          _buildGlobalAdvancedOption(
            icon: Icons.cleaning_services,
            title: 'Limpieza COMPLETA de Datos',
            description:
                'Limpieza total igual que después de sincronización exitosa: Visits, Exclusions, Products, Headquarters, Virtual_points, Routes, AppState',
            color: Colors.purple,
            onTap: _showConfirmCompleteCleanup,
          ),
          const SizedBox(height: 24),

          // Stats del día
          if (visitsForDate.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datos de este día (${_formatDate(date)}):',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDataRow(Icons.assignment_turned_in, 'Visitas',
                      '${visitsForDate.length}'),
                  const SizedBox(height: 8),
                  _buildDataRow(
                      Icons.gps_fixed, 'Localizaciones GPS', 'Asociadas'),
                  const SizedBox(height: 8),
                  _buildDataRow(
                      Icons.description, 'Detalles de visitas', 'Asociados'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayAdvancedOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // Widget builder para opciones globales (mismo que _buildDayAdvancedOption)
  Widget _buildGlobalAdvancedOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // MÉTODOS DE CONFIRMACIÓN CON CÓDIGO
  // ========================================================================

  void _showConfirmDeleteDayData(DateTime date) {
    const String securityCode = '123456789'; // Código de seguridad fijo
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Eliminar Día: ${_formatDate(date)}'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se eliminarán TODAS las visitas de este día:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildConfirmItem('Visits (SQLite)'),
              _buildConfirmItem('Visits_details (SQLite)'),
              _buildConfirmItem('Visits_locations (SQLite)'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade50, Colors.red.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_outline,
                        color: Colors.red.shade700, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      '⚠️ Esta acción NO se puede deshacer',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa el código de seguridad',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: '•••••••••',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.red.shade600, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text == securityCode) {
                  Navigator.pop(context);
                  await _deleteDayData(date);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Código incorrecto'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmClearDayAppState(DateTime date) {
    const String securityCode = '123456789'; // Código de seguridad fijo
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.memory, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('Limpiar AppState'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Limpiar AppState del día: ${_formatDate(date)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildConfirmItem('visitsAdd'),
              _buildConfirmItem('visitCount'),
              _buildConfirmItem('visitDetails'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_outline,
                        color: Colors.blue.shade700, size: 28),
                    const SizedBox(height: 12),
                    const Text(
                      'Ingresa el código de seguridad',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: '•••••••••',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade300, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text == securityCode) {
                  Navigator.pop(context);
                  await _clearDayAppState(date);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Código incorrecto'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
  }

  // ========================================================================
  // MÉTODOS DE CONFIRMACIÓN GLOBALES (CON CÓDIGO SECRETO)
  // ========================================================================

  void _showConfirmDeleteAllVisits() {
    const String securityCode = '123456789'; // Código de seguridad secreto
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 24,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.red.shade50.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con gradiente y ícono animado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade300.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Eliminar TODAS las Visitas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'OPERACIÓN GLOBAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Items a eliminar con diseño mejorado
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade50,
                                Colors.red.shade100.withValues(alpha: 0.5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.red.shade200, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.red.shade100.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.playlist_remove,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Se eliminarán permanentemente:',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildModernConfirmItem('TODAS las Visits',
                                  Icons.storage_rounded, Colors.red),
                              _buildModernConfirmItem(
                                  'TODOS los Visits_details',
                                  Icons.description_rounded,
                                  Colors.red),
                              _buildModernConfirmItem(
                                  'TODAS las Visits_locations',
                                  Icons.location_on_rounded,
                                  Colors.red),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                    color: Colors.red.shade300, thickness: 1.5),
                              ),
                              _buildModernConfirmItem('visitCount = 0',
                                  Icons.numbers, Colors.orange),
                              _buildModernConfirmItem('visitsAdd = []',
                                  Icons.playlist_add, Colors.orange),
                              _buildModernConfirmItem('visitDetails = []',
                                  Icons.info, Colors.orange),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Advertencia moderna
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade100, Colors.red.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.red.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.red.shade200.withValues(alpha: 0.6),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.shade300
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.shield_outlined,
                                    color: Colors.red.shade700, size: 44),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '⚠️ ACCIÓN IRREVERSIBLE',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Ingresa el código de seguridad para confirmar esta operación',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Campo de código mejorado
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            hintText: '• • • • • • • • •',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, letterSpacing: 10),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.lock_outline,
                                color: Colors.red.shade500, size: 28),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 24),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.red.shade300, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.red.shade600, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botones modernos
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (codeController.text == securityCode) {
                                Navigator.pop(context);
                                await _performDeleteAllVisits();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.white),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                            child: Text(
                                                'Código de seguridad incorrecto')),
                                      ],
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_forever_rounded,
                                size: 22),
                            label: const Text('Eliminar Todo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 6,
                              shadowColor:
                                  Colors.red.shade400.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernConfirmItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteExclusionHistory() {
    const String securityCode = '123456789'; // Código de seguridad secreto
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 24,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.deepOrange.shade50.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con gradiente naranja
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepOrange.shade600,
                          Colors.deepOrange.shade800
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.deepOrange.shade300.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.layers_clear_rounded,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Eliminar Historial de Exclusiones',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'OPERACIÓN GLOBAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información de lo que se eliminará
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepOrange.shade50,
                                Colors.deepOrange.shade100
                                    .withValues(alpha: 0.5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.deepOrange.shade200, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.shade100
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.delete_sweep_rounded,
                                        color: Colors.white,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Se eliminará permanentemente:',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildModernConfirmItem(
                                'TODOS los registros de Exclusion_zones_history',
                                Icons.history_rounded,
                                Colors.deepOrange,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.deepOrange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.deepOrange.shade700,
                                        size: 20),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Se perderá todo el historial de cambios en zonas de exclusión',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Advertencia
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepOrange.shade100,
                                Colors.deepOrange.shade50
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.deepOrange.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.shade200
                                    .withValues(alpha: 0.6),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepOrange.shade300
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.shield_outlined,
                                    color: Colors.deepOrange.shade700,
                                    size: 44),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '⚠️ ACCIÓN IRREVERSIBLE',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Ingresa el código de seguridad para confirmar',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade800,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Campo de código
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            hintText: '• • • • • • • • •',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, letterSpacing: 10),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.lock_outline,
                                color: Colors.deepOrange.shade500, size: 28),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 24),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.deepOrange.shade300, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.deepOrange.shade300, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.deepOrange.shade600, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botones
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (codeController.text == securityCode) {
                                Navigator.pop(context);
                                await _performDeleteExclusionHistory();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.white),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                            child: Text(
                                                'Código de seguridad incorrecto')),
                                      ],
                                    ),
                                    backgroundColor: Colors.deepOrange.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded,
                                size: 22),
                            label: const Text('Eliminar Historial'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 6,
                              shadowColor: Colors.deepOrange.shade400
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showConfirmCompleteCleanup() {
    const String securityCode = '123456789'; // Código de seguridad secreto
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 24,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.purple.shade50.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header púrpura
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade600,
                          Colors.purple.shade900
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade300.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.cleaning_services_rounded,
                                  color: Colors.white,
                                  size: 68,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Limpieza COMPLETA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'del Sistema',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'LIMPIEZA TOTAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lista de items a eliminar
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade50,
                                Colors.purple.shade100.withValues(alpha: 0.4)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.purple.shade200, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.shade100
                                    .withValues(alpha: 0.6),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade600,
                                          Colors.purple.shade800
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.shade400
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                        Icons.delete_sweep_rounded,
                                        color: Colors.white,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Todo el sistema será limpiado:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _buildModernConfirmItem(
                                  'Location_tracking (>7 días)',
                                  Icons.location_history,
                                  Colors.purple),
                              _buildModernConfirmItem(
                                  'Visits, Visits_details, Visits_locations',
                                  Icons.event_note,
                                  Colors.purple),
                              _buildModernConfirmItem(
                                  'Optimized_routes, Optimized_route_points',
                                  Icons.route,
                                  Colors.purple),
                              _buildModernConfirmItem(
                                  'Products, Products_coordinates',
                                  Icons.inventory,
                                  Colors.purple),
                              _buildModernConfirmItem(
                                  'Headquarters, Coordinates, Polygons',
                                  Icons.business,
                                  Colors.purple),
                              _buildModernConfirmItem(
                                  'Types_points, Virtual_points',
                                  Icons.place,
                                  Colors.purple),
                              _buildModernConfirmItem('Exclusion_zones_history',
                                  Icons.layers_clear, Colors.purple),
                              _buildModernConfirmItem('AppState completo',
                                  Icons.memory, Colors.purple),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Nota informativa
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700, size: 24),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Limpieza idéntica a la que ocurre después de una sincronización exitosa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Advertencia máxima
                        Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade100,
                                Colors.purple.shade50
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.purple.shade300, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.shade200
                                    .withValues(alpha: 0.7),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.purple.shade50
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.shade300
                                          .withValues(alpha: 0.5),
                                      blurRadius: 14,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.security,
                                    color: Colors.purple.shade700, size: 48),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '⚠️ MÁXIMA PRECAUCIÓN',
                                style: TextStyle(
                                  color: Colors.purple.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 0.8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ACCIÓN IRREVERSIBLE',
                                style: TextStyle(
                                  color: Colors.purple.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Ingresa el código de seguridad para confirmar',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Campo de código
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: '• • • • • • • • •',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, letterSpacing: 12),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.vpn_key_rounded,
                                color: Colors.purple.shade500, size: 30),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 26),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.purple.shade300, width: 3),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.purple.shade300, width: 3),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                  color: Colors.purple.shade700, width: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botones
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (codeController.text == securityCode) {
                                Navigator.pop(context);
                                await _performCompleteCleanup();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.white),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                            child: Text(
                                                'Código de seguridad incorrecto')),
                                      ],
                                    ),
                                    backgroundColor: Colors.purple.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.cleaning_services_rounded,
                                size: 22),
                            label: const Text('Limpiar Todo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              elevation: 8,
                              shadowColor:
                                  Colors.purple.shade400.withValues(alpha: 0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // MÉTODOS DE ELIMINACIÓN POR DÍA
  // ========================================================================

  Future<void> _deleteDayData(DateTime date) async {
    try {
      setState(() => _isLoading = true);

      final visitsForDate = _visitsByDate[date] ?? [];
      if (visitsForDate.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No hay visitas para eliminar en este día'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obtener IDs de visitas del día
      final visitIds = visitsForDate.map((v) => v.idVisit).toList();

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      try {
        await database.transaction((txn) async {
          // Eliminar detalles de visitas
          for (var id in visitIds) {
            await txn.delete('Visits_details',
                where: 'Id_visit = ?', whereArgs: [id]);
          }
          debugPrint('   ✅ Eliminados detalles de ${visitIds.length} visitas');

          // Eliminar localizaciones
          for (var id in visitIds) {
            await txn.delete('Visits_locations',
                where: 'Id_visit = ?', whereArgs: [id]);
          }
          debugPrint(
              '   ✅ Eliminadas localizaciones de ${visitIds.length} visitas');

          // Eliminar visitas
          for (var id in visitIds) {
            await txn.delete('Visits', where: 'Id_visit = ?', whereArgs: [id]);
          }
          debugPrint('   ✅ Eliminadas ${visitIds.length} visitas');
        });
      } finally {
        await database.close();
      }

      // Recargar datos
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Eliminadas ${visitIds.length} visitas del ${_formatDate(date)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error eliminando datos del día: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearDayAppState(DateTime date) async {
    try {
      setState(() => _isLoading = true);

      // Limpiar AppState
      await _cleanupAppState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ AppState limpiado para ${_formatDate(date)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========================================================================
  // TAB 3: FUNCIONES AVANZADAS (GLOBAL - NO USADO EN CARRUSEL)
  // ========================================================================

  Widget _buildFuncionesAvanzadasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header informativo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Las acciones en esta sección son irreversibles. Use con precaución.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Opción 1: Limpiar todo
          _buildAdvancedOption(
            icon: Icons.delete_sweep,
            title: 'Limpieza Total',
            description:
                'Elimina todas las visitas de SQLite y limpia las variables de AppState',
            color: Colors.red,
            onTap: _showConfirmTotalCleanup,
          ),
          const SizedBox(height: 16),

          // Opción 2: Solo limpiar SQLite
          _buildAdvancedOption(
            icon: Icons.storage,
            title: 'Limpiar Solo SQLite',
            description:
                'Elimina Visits, Visits_details y Visits_locations de la base de datos',
            color: Colors.orange,
            onTap: _showConfirmSQLiteCleanup,
          ),
          const SizedBox(height: 16),

          // Opción 3: Solo limpiar AppState
          _buildAdvancedOption(
            icon: Icons.memory,
            title: 'Limpiar Solo AppState',
            description:
                'Limpia visitsAdd, visitCount y visitDetails del estado de la app',
            color: Colors.blue,
            onTap: _showConfirmAppStateCleanup,
          ),
          const SizedBox(height: 24),

          // Stats de lo que se eliminará
          if (_allVisits.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos que serán eliminados:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDataRow(Icons.assignment_turned_in, 'Visitas',
                      '${_allVisits.length}'),
                  const SizedBox(height: 8),
                  _buildDataRow(
                      Icons.gps_fixed, 'Localizaciones GPS', 'Asociadas'),
                  const SizedBox(height: 8),
                  _buildDataRow(
                      Icons.description, 'Detalles de visitas', 'Asociados'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // MÉTODOS DE LIMPIEZA
  // ========================================================================

  Future<void> _performTotalCleanup() async {
    try {
      setState(() => _isLoading = true);

      // 1. Limpiar SQLite
      await _cleanupSQLiteVisits();

      // 2. Limpiar AppState
      await _cleanupAppState();

      // 3. Recargar datos
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Limpieza total completada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error en limpieza total: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en limpieza: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cleanupSQLiteVisits() async {
    final String dbPath = await _getDatabasePath();
    final database = await openDatabase(dbPath);

    try {
      await database.transaction((txn) async {
        // Eliminar en orden correcto (respetando foreign keys)
        final deletedDetails = await txn.delete('Visits_details');
        debugPrint(
            '   ✅ Eliminados $deletedDetails registros de Visits_details');

        final deletedLocations = await txn.delete('Visits_locations');
        debugPrint(
            '   ✅ Eliminados $deletedLocations registros de Visits_locations');

        final deletedVisits = await txn.delete('Visits');
        debugPrint('   ✅ Eliminados $deletedVisits registros de Visits');
      });

      debugPrint('✅ Limpieza SQLite completada');
    } finally {
      await database.close();
    }
  }

  Future<void> _cleanupAppState() async {
    // Limpiar variables de AppState
    FFAppState().visitCount = 0;
    FFAppState().visitsAdd = [];
    FFAppState().visitDetails = [];

    // Forzar la actualización y persistencia
    FFAppState().update(() {
      // Esto fuerza la persistencia del estado
    });

    debugPrint('✅ AppState limpiado (visitCount, visitsAdd, visitDetails)');
  }

  // ========================================================================
  // MÉTODOS DE LIMPIEZA GLOBALES
  // ========================================================================

  Future<void> _performDeleteAllVisits() async {
    try {
      setState(() => _isLoading = true);

      debugPrint('🔴 Iniciando eliminación GLOBAL de todas las visitas...');

      // 1. Limpiar SQLite
      await _cleanupSQLiteVisits();

      // 2. Limpiar AppState
      await _cleanupAppState();

      // 3. Recargar datos
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('✅ Todas las visitas han sido eliminadas exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('✅ Eliminación global de visitas completada');
    } catch (e) {
      debugPrint('❌ Error en eliminación global de visitas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar visitas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performDeleteExclusionHistory() async {
    try {
      setState(() => _isLoading = true);

      debugPrint('🟠 Iniciando eliminación de Exclusion_zones_history...');

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      try {
        final deletedCount = await database.delete('Exclusion_zones_history');
        debugPrint(
            '   ✅ Eliminados $deletedCount registros de Exclusion_zones_history');
      } finally {
        await database.close();
      }

      // Recargar datos
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Historial de exclusiones eliminado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('✅ Eliminación de Exclusion_zones_history completada');
    } catch (e) {
      debugPrint('❌ Error en eliminación de exclusion history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar historial: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performCompleteCleanup() async {
    try {
      setState(() => _isLoading = true);

      debugPrint('🟣 Iniciando LIMPIEZA COMPLETA del sistema...');

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      try {
        await database.transaction((txn) async {
          // 1. Limpiar Location_tracking - SOLO registros >7 días
          final DateTime sevenDaysAgo =
              DateTime.now().subtract(const Duration(days: 7));
          final String sevenDaysAgoISO = sevenDaysAgo.toIso8601String();
          final deletedTracking = await txn.rawDelete(
              'DELETE FROM Location_tracking WHERE CreatedAt < ?',
              [sevenDaysAgoISO]);
          debugPrint(
              '   ✅ Eliminados $deletedTracking registros de Location_tracking >7 días');

          // 2. Eliminar todas las visitas y relacionados
          final List<Map<String, dynamic>> allVisits =
              await txn.rawQuery('SELECT Id_visit FROM Visits');
          if (allVisits.isNotEmpty) {
            final List<int> visitIds =
                allVisits.map((v) => v['Id_visit'] as int).toList();
            final String placeholders = visitIds.map((_) => '?').join(',');

            await txn.rawDelete(
                'DELETE FROM Visits_locations WHERE Id_visit IN ($placeholders)',
                visitIds);
            await txn.rawDelete(
                'DELETE FROM Visits_details WHERE Id_visit IN ($placeholders)',
                visitIds);
            await txn.delete('Visits');
            debugPrint(
                '   ✅ Eliminadas ${visitIds.length} visitas y relacionados');
          }

          // 3-11. Limpiar otras tablas
          await txn.delete('Optimized_route_points');
          await txn.delete('Optimized_routes');
          debugPrint('   ✅ Eliminadas rutas optimizadas');

          await txn.delete('Products_coordinates');
          await txn.delete('Products');
          debugPrint('   ✅ Eliminados productos');

          await txn.delete('Headquarters_coordinates');
          await txn.delete('Types_points');
          await txn.delete('Virtual_points');
          debugPrint('   ✅ Eliminados puntos virtuales y tipos');

          await txn.delete('Headquarters_polygons');
          await txn.delete('Headquarters');
          debugPrint('   ✅ Eliminadas sedes');

          // 12. Limpiar Exclusion_zones_history
          await txn.delete('Exclusion_zones_history');
          debugPrint('   ✅ Eliminado historial de exclusiones');
        });

        debugPrint('✅ Limpieza SQLite completada');
      } finally {
        await database.close();
      }

      // Limpiar AppState
      FFAppState().visitCount = 0;
      FFAppState().visitsAdd = [];
      FFAppState().visitDetails = [];
      FFAppState().update(() {});
      debugPrint('✅ AppState limpiado');

      // Recargar datos
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('✅ Limpieza COMPLETA del sistema finalizada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('✅ LIMPIEZA COMPLETA finalizada exitosamente');
    } catch (e) {
      debugPrint('❌ Error en limpieza completa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en limpieza completa: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========================================================================
  // DIÁLOGOS DE CONFIRMACIÓN
  // ========================================================================

  void _showConfirmTotalCleanup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Text('¿Limpieza Total?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se eliminarán TODOS los datos de visitas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildConfirmItem('Visits (SQLite)'),
              _buildConfirmItem('Visits_details (SQLite)'),
              _buildConfirmItem('Visits_locations (SQLite)'),
              _buildConfirmItem('visitsAdd (AppState)'),
              _buildConfirmItem('visitCount (AppState)'),
              _buildConfirmItem('visitDetails (AppState)'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⚠️ Esta acción NO se puede deshacer',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performTotalCleanup();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar Todo'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmSQLiteCleanup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.storage, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Text('¿Limpiar SQLite?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se eliminarán las siguientes tablas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildConfirmItem('Visits'),
              _buildConfirmItem('Visits_details'),
              _buildConfirmItem('Visits_locations'),
              const SizedBox(height: 12),
              Text(
                'Total de visitas: ${_allVisits.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  setState(() => _isLoading = true);
                  await _cleanupSQLiteVisits();
                  await _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ SQLite limpiado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpiar SQLite'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmAppStateCleanup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.memory, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('¿Limpiar AppState?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se limpiarán las siguientes variables:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildConfirmItem('visitsAdd'),
              _buildConfirmItem('visitCount'),
              _buildConfirmItem('visitDetails'),
              const SizedBox(height: 12),
              const Text(
                'Esto no afecta los datos en SQLite.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  setState(() => _isLoading = true);
                  await _cleanupAppState();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ AppState limpiado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpiar AppState'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalCount = _allVisits.length;
    final filteredCount = _filteredVisits.length;
    final oldestVisit =
        _filteredVisits.isEmpty ? null : _filteredVisits.last.createdAt;
    final newestVisit =
        _filteredVisits.isEmpty ? null : _filteredVisits.first.createdAt;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FlutterFlowTheme.of(context).primary,
            const Color(0xFF059669),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
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
          if (oldestVisit != null && newestVisit != null) ...[
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
                          _formatFriendlyDateTime(oldestVisit),
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
                          _formatFriendlyDateTime(newestVisit),
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

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showFiltersPanel = !_showFiltersPanel;
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
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: FlutterFlowTheme.of(context).primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filtros Avanzados',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Icon(
                    _showFiltersPanel ? Icons.expand_less : Icons.expand_more,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ],
              ),
            ),
          ),
          if (_showFiltersPanel)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Filtro por Estado
                  const Text(
                    'Por Estado:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Todos',
                        isSelected: _selectedStateFilter == null,
                        onTap: () {
                          setState(() {
                            _selectedStateFilter = null;
                            _applyFilters();
                          });
                        },
                      ),
                      ..._stateStats.map((state) => _buildFilterChip(
                            label: state.statusName,
                            isSelected: _selectedStateFilter == state.idStatus,
                            color: _parseColor(state.color),
                            onTap: () {
                              setState(() {
                                _selectedStateFilter = state.idStatus;
                                _applyFilters();
                              });
                            },
                          )),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Filtro por Nivel de Batería
                  const Text(
                    'Por Nivel de Batería:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Todos',
                        isSelected: _selectedBatteryRangeFilter == null,
                        onTap: () {
                          setState(() {
                            _selectedBatteryRangeFilter = null;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '0-25%',
                        isSelected: _selectedBatteryRangeFilter == 1,
                        color: Colors.red,
                        icon: Icons.battery_alert,
                        onTap: () {
                          setState(() {
                            _selectedBatteryRangeFilter = 1;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '26-50%',
                        isSelected: _selectedBatteryRangeFilter == 2,
                        color: Colors.orange,
                        icon: Icons.battery_3_bar,
                        onTap: () {
                          setState(() {
                            _selectedBatteryRangeFilter = 2;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '51-75%',
                        isSelected: _selectedBatteryRangeFilter == 3,
                        color: Colors.yellow[700],
                        icon: Icons.battery_5_bar,
                        onTap: () {
                          setState(() {
                            _selectedBatteryRangeFilter = 3;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '76-100%',
                        isSelected: _selectedBatteryRangeFilter == 4,
                        color: Colors.green,
                        icon: Icons.battery_full,
                        onTap: () {
                          setState(() {
                            _selectedBatteryRangeFilter = 4;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Filtro por Puntos GPS
                  const Text(
                    'Por Cantidad de Puntos GPS:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Todos',
                        isSelected: _selectedGpsPointsFilter == null,
                        onTap: () {
                          setState(() {
                            _selectedGpsPointsFilter = null;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '0-10 puntos',
                        isSelected: _selectedGpsPointsFilter == 1,
                        icon: Icons.location_off,
                        onTap: () {
                          setState(() {
                            _selectedGpsPointsFilter = 1;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '11-50 puntos',
                        isSelected: _selectedGpsPointsFilter == 2,
                        icon: Icons.location_on,
                        onTap: () {
                          setState(() {
                            _selectedGpsPointsFilter = 2;
                            _applyFilters();
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: '51+ puntos',
                        isSelected: _selectedGpsPointsFilter == 3,
                        icon: Icons.where_to_vote,
                        onTap: () {
                          setState(() {
                            _selectedGpsPointsFilter = 3;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botón para limpiar filtros
                  if (_selectedStateFilter != null ||
                      _selectedBatteryRangeFilter != null ||
                      _selectedGpsPointsFilter != null)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedStateFilter = null;
                            _selectedBatteryRangeFilter = null;
                            _selectedGpsPointsFilter = null;
                            _applyFilters();
                          });
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Limpiar todos los filtros'),
                        style: TextButton.styleFrom(
                          foregroundColor: FlutterFlowTheme.of(context).error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitsList() {
    if (_filteredVisits.isEmpty) {
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
                Icons.assignment_late,
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay visitas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron visitas en ${_selectedTimeFilter.label}',
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
      itemCount: _filteredVisits.length,
      itemBuilder: (context, index) {
        final visit = _filteredVisits[index];
        return _buildVisitCard(visit, index);
      },
    );
  }

  Widget _buildVisitCard(VisitRecord visit, int index) {
    final statusColor = _parseColor(visit.statusColor);

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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FlutterFlowTheme.of(context).primary,
                  const Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#${visit.idVisit}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visit.headquarterName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      visit.statusName ?? 'Sin estado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatFriendlyDateTime(visit.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      size: 14,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${visit.gpsPointsCount} puntos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.question_answer,
                      size: 14,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${visit.responsesCount} respuestas',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                if (visit.userName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 14,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        visit.userName!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          children: [
            _buildVisitExpandedContent(visit),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitExpandedContent(VisitRecord visit) {
    // Formatear nombre del lote
    String loteInfo = visit.headquarterName;
    if (visit.idHeadquarter > 0 && visit.headquarterName != 'Sin nombre') {
      loteInfo = '${visit.headquarterName} (ID: ${visit.idHeadquarter})';
    }

    // Formatear ubicación - verificar si tiene coordenadas válidas
    String ubicacion = visit.latitude != 0.0 && visit.longitude != 0.0
        ? '${visit.latitude.toStringAsFixed(6)}, ${visit.longitude.toStringAsFixed(6)}'
        : 'No disponible';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.location_city,
          'Lote',
          loteInfo,
          FlutterFlowTheme.of(context).secondary,
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.access_time,
          'Fecha',
          _formatFriendlyDateTime(visit.createdAt),
          const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.location_on,
          'Ubicación',
          ubicacion,
          const Color(0xFFEF4444),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.battery_full,
          'Batería',
          '${visit.battery.toStringAsFixed(0)}%',
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showVisitDetails(visit),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Ver Detalles Completos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlutterFlowTheme.of(context).primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showVisitDetails(VisitRecord visit) async {
    // Cargar detalles completos de la visita
    final String dbPath = await _getDatabasePath();
    final database = await openDatabase(dbPath);

    // Cargar respuestas
    final List<Map<String, dynamic>> detailsData = await database.rawQuery('''
      SELECT
        vd.Status_option,
        vd.Status_response,
        COALESCE(ast.Status_name, 'Sin nombre') as Status_name
      FROM Visits_details vd
      LEFT JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
      WHERE vd.Id_visit = ?
      ORDER BY vd.Id_visit_detail
    ''', [visit.idVisit]);

    final details = detailsData.map((row) => VisitDetail.fromMap(row)).toList();

    // Cargar TODOS los puntos GPS individuales
    final List<Map<String, dynamic>> gpsPointsData = await database.rawQuery('''
      SELECT
        Id,
        Latitude,
        Longitude,
        Altitude,
        HorizontalError,
        CreatedAt
      FROM Visits_locations
      WHERE Id_visit = ?
      ORDER BY CreatedAt ASC
    ''', [visit.idVisit]);

    final List<GPSPointDetail> gpsPoints = gpsPointsData.map((row) {
      return GPSPointDetail(
        id: (row['Id'] as num?)?.toInt() ?? 0,
        latitude: (row['Latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (row['Longitude'] as num?)?.toDouble() ?? 0.0,
        altitude: (row['Altitude'] as num?)?.toDouble() ?? 0.0,
        horizontalError: (row['HorizontalError'] as num?)?.toDouble() ?? 0.0,
        createdAt: row['CreatedAt'] != null
            ? DateTime.parse(row['CreatedAt'] as String)
            : DateTime.now(),
      );
    }).toList();

    await database.close();

    // Mostrar modal
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    const Color(0xFF059669),
                  ],
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
                      Icons.assignment,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visita #${visit.idVisit}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          visit.headquarterName,
                          style: const TextStyle(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Respuestas
                    if (details.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.question_answer,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Respuestas (${details.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...details.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final detail = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${idx + 1}. ${detail.statusName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'R: ${detail.statusResponse.isNotEmpty ? detail.statusResponse : detail.statusOption}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                    ],
                    // GPS Info - TODOS LOS PUNTOS
                    if (gpsPoints.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.gps_fixed,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tracking GPS (${gpsPoints.length} puntos)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Resumen de duración total
                      if (gpsPoints.length > 1) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context)
                                  .primary
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Duración total: ${_formatDuration(gpsPoints.last.createdAt.difference(gpsPoints.first.createdAt))}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Lista de TODOS los puntos GPS
                      ...gpsPoints.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final point = entry.value;
                        final isFirst = idx == 0;
                        final isLast = idx == gpsPoints.length - 1;

                        // Calcular tiempo transcurrido desde el punto anterior
                        Duration? timeSincePrevious;
                        if (idx > 0) {
                          timeSincePrevious = point.createdAt
                              .difference(gpsPoints[idx - 1].createdAt);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isFirst || isLast
                                ? const Color(
                                    0xFFF0F9FF) // Azul claro para primer/último
                                : const Color(
                                    0xFFF9FAFB), // Gris claro para los demás
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFirst || isLast
                                  ? const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFFE5E7EB),
                              width: isFirst || isLast ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Encabezado del punto
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? const Color(0xFF10B981)
                                          : isLast
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF6B7280),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isFirst
                                          ? 'INICIO'
                                          : isLast
                                              ? 'FIN'
                                              : 'Punto ${idx + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatFriendlyDateTime(point.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Coordenadas
                              Row(
                                children: [
                                  const Icon(Icons.place,
                                      size: 14, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1F2937),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Altitud
                              if (point.altitude != 0.0)
                                Row(
                                  children: [
                                    const Icon(Icons.height,
                                        size: 14, color: Color(0xFF6B7280)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Altitud: ${point.altitude.toStringAsFixed(1)} m',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              // Margen de error (precisión)
                              Row(
                                children: [
                                  Icon(
                                    point.horizontalError <= 10
                                        ? Icons.gps_fixed
                                        : point.horizontalError <= 30
                                            ? Icons.gps_not_fixed
                                            : Icons.gps_off,
                                    size: 14,
                                    color: point.horizontalError <= 10
                                        ? const Color(0xFF10B981)
                                        : point.horizontalError <= 30
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Precisión: ±${point.horizontalError.toStringAsFixed(1)} m',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: point.horizontalError <= 10
                                          ? const Color(0xFF10B981)
                                          : point.horizontalError <= 30
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              // Tiempo desde punto anterior
                              if (timeSincePrevious != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.timer,
                                        size: 14, color: Color(0xFF6B7280)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${_formatDuration(timeSincePrevious)} desde anterior',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
    IconData? icon,
  }) {
    final displayColor = color ?? FlutterFlowTheme.of(context).primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? displayColor.withValues(alpha: 0.15)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? displayColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? displayColor : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? displayColor : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
