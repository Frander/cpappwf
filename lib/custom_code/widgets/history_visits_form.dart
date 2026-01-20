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
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:carousel_slider/carousel_slider.dart';

import '/backend/sqlite/global_db_singleton.dart';

// ============================================================================
// MODELS
// ============================================================================

class ActivityMetrics {
  final String activityName;
  final int idActivity;
  final int totalVisits;
  final int totalResults; // Total de registros en Visits_details
  final List<DailyData> dailyData;
  final List<StatusData> statusData;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String unity;

  ActivityMetrics({
    required this.activityName,
    required this.idActivity,
    required this.totalVisits,
    required this.totalResults,
    required this.dailyData,
    required this.statusData,
    this.firstDate,
    this.lastDate,
    this.unity = '',
  });

  /// Obtiene el label de unidad, retorna 'Resultados' si unity está vacío
  String get unityLabel => unity.isNotEmpty ? unity : 'Resultados';
}

/// Modelo para métricas de operador en el Dashboard
class OperatorDashboardData {
  final int operatorId;
  final String operatorName;
  final int totalVisits;
  final int totalResults;
  final List<StatusData> statusData;
  final List<String> headquarterNames; // Lotes donde trabajó
  final String unity;

  OperatorDashboardData({
    required this.operatorId,
    required this.operatorName,
    required this.totalVisits,
    required this.totalResults,
    required this.statusData,
    required this.headquarterNames,
    this.unity = '',
  });

  String get unityLabel => unity.isNotEmpty ? unity : 'Resultados';
}

/// Modelo para métricas de lote/headquarter en el Dashboard
class HeadquarterDashboardData {
  final int headquarterId;
  final String headquarterName;
  final int totalVisits;
  final int totalResults;
  final List<String> operatorNames; // Operadores que trabajaron en este lote
  final String unity;

  HeadquarterDashboardData({
    required this.headquarterId,
    required this.headquarterName,
    required this.totalVisits,
    required this.totalResults,
    required this.operatorNames,
    this.unity = '',
  });

  String get unityLabel => unity.isNotEmpty ? unity : 'Resultados';
  int get operatorCount => operatorNames.length;
}

class OperatorMetrics {
  final int operatorId;
  final String operatorName;
  final int totalVisits;
  final int completedResults;
  final double averageTimePerVisit;
  final double totalWorkedTime;
  final double effectiveTime;
  final double unproductiveTime;
  final DateTime? lastActivity;
  final List<OperatorMetrics> subordinates;

  OperatorMetrics({
    required this.operatorId,
    required this.operatorName,
    required this.totalVisits,
    required this.completedResults,
    required this.averageTimePerVisit,
    required this.totalWorkedTime,
    required this.effectiveTime,
    required this.unproductiveTime,
    this.lastActivity,
    this.subordinates = const [],
  });
}

class DailyData {
  final DateTime date;
  final int visits;
  final double timeSpent;

  DailyData({
    required this.date,
    required this.visits,
    required this.timeSpent,
  });
}

class StatusData {
  final String statusName;
  final int count;

  StatusData({
    required this.statusName,
    required this.count,
  });
}

class PendingSyncData {
  final int id;
  final String type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  PendingSyncData({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.data,
  });
}

class VisitDetailData {
  final int idVisit;
  final String activityName;
  final String headquarterName;
  final DateTime createdAt;
  final int status;
  final List<VisitDetailItem> details;

  VisitDetailData({
    required this.idVisit,
    required this.activityName,
    required this.headquarterName,
    required this.createdAt,
    required this.status,
    required this.details,
  });
}

class VisitDetailItem {
  final int idVisitDetail;
  final String statusName;
  final String statusType;
  final String statusResponse;
  final String statusOption;
  final String defaultStatus;

  VisitDetailItem({
    required this.idVisitDetail,
    required this.statusName,
    required this.statusType,
    required this.statusResponse,
    required this.statusOption,
    required this.defaultStatus,
  });
}

// ============================================================================
// MAIN WIDGET
// ============================================================================

class HistoryVisitsForm extends StatefulWidget {
  const HistoryVisitsForm({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  final double? width;
  final double? height;

  @override
  _HistoryVisitsFormState createState() => _HistoryVisitsFormState();
}

class _HistoryVisitsFormState extends State<HistoryVisitsForm>
    with TickerProviderStateMixin {
  // TabController para Dashboard y Detalle
  late TabController _tabController;
  late AnimationController _syncButtonController;

  // Usamos singleton global para base de datos - no necesitamos guardar path
  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  List<ActivityMetrics> _activityMetrics = [];
  List<OperatorMetrics> _operatorMetrics = [];
  List<PendingSyncData> _pendingData = [];
  List<Map<String, dynamic>> _downloadedData = [];
  List<VisitDetailData> _visitDetails = [];

  // Datos para el nuevo Dashboard
  List<OperatorDashboardData> _operatorDashboardData = [];
  List<HeadquarterDashboardData> _headquarterDashboardData = [];
  String _currentUnity = ''; // Unity de la actividad actual

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // TabController para Dashboard y Detalle
    _tabController = TabController(length: 2, vsync: this);
    _syncButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _initializeDatabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _syncButtonController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto-refresh desactivado - el usuario debe actualizar manualmente usando pull-to-refresh
  }

  Future<void> _initializeDatabase() async {
    try {
      await _loadAllData();
    } catch (e) {
      print('Error initializing database: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method: Usar singleton global para todas las operaciones de BD
  // Usar singleton global para evitar locks de base de datos
  Future<T?> _withDatabase<T>(Future<T> Function(Database db) operation) async {
    try {
      return await globalDb.executeOperation(operation);
    } catch (e) {
      print('Error in database operation: $e');
      return null;
    }
  }

  Future<void> _loadAllData() async {

    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar unity de la actividad seleccionada
      _currentUnity = FFAppState().activitySelected.unity;

      await Future.wait([
        _loadActivityMetrics(),
        _loadOperatorMetrics(),
        _loadPendingSyncData(),
        _loadDownloadedData(),
        _loadVisitDetails(),
        _loadOperatorDashboardData(),
        _loadHeadquarterDashboardData(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActivityMetrics() async {

    try {
      final activities = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT
            a.Id_activity,
            a.Name_activity as activity_name,
            a.Unity as unity,
            COUNT(DISTINCT v.Id_visit) as total_visits,
            (
              -- Primer Total: Status sin step parent
              COALESCE((
                SELECT SUM(acs.Factor)
                FROM Activities_status acs
                WHERE acs.Id_activity = a.Id_activity
                  AND (acs.Id_activity_step_parent IS NULL OR acs.Id_activity_step_parent = 0)
              ), 0)
              +
              -- Segundo Total: Steps con SUMAFACTORES
              COALESCE((
                SELECT SUM(
                  CASE
                    WHEN ast.Calculation = '=SUMAFACTORES' THEN
                      COALESCE((
                        SELECT SUM(acs2.Factor)
                        FROM Activities_status acs2
                        WHERE acs2.Id_activity_step_parent = ast.Id_activity_step
                      ), 0)
                    ELSE 0
                  END
                )
                FROM Activities_steps ast
                WHERE ast.Id_activity = a.Id_activity
              ), 0)
            ) as total_results
          FROM Activities a
          LEFT JOIN Visits v ON a.Id_activity = v.Id_activity
          WHERE v.Id_visit IS NOT NULL
          GROUP BY a.Id_activity, a.Name_activity, a.Unity
          ORDER BY total_visits DESC
        ''');
      });

      if (activities == null) return;

      List<ActivityMetrics> metrics = [];

      for (var activity in activities) {
        final activityId = (activity['Id_activity'] as int?) ?? 0;
        final activityName = activity['activity_name'] as String;
        final unity = (activity['unity'] as String?) ?? '';

        final dailyData = await _loadDailyDataForActivity(activityName);
        final statusData = await _loadStatusDataForActivity(activityId);
        final dates = await _getActivityDateRange(activityId);

        final totalVisits = (activity['total_visits'] as int?) ?? 0;
        final totalResults = (activity['total_results'] as int?) ?? 0;

        metrics.add(ActivityMetrics(
          activityName: activityName,
          idActivity: activityId,
          totalVisits: totalVisits,
          totalResults: totalResults,
          dailyData: dailyData,
          statusData: statusData,
          firstDate: dates['first'],
          lastDate: dates['last'],
          unity: unity,
        ));
      }

      if (mounted) {
        setState(() {
          _activityMetrics = metrics;
        });
      }
    } catch (e) {
      print('Error loading activity metrics: $e');
    }
  }

  Future<List<DailyData>> _loadDailyDataForActivity(String activityName) async {

    try {
      final data = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          DATE(v.Created_at) as visit_date,
          COUNT(*) as visit_count,
          (julianday(MAX(v.Created_at)) - julianday(MIN(v.Created_at))) * 24 as time_spent
        FROM Visits v
        JOIN Activities a ON v.Id_activity = a.Id_activity
        WHERE a.Name_activity = ?
          AND v.Created_at >= date('now', '-30 days')
        GROUP BY DATE(v.Created_at)
        ORDER BY visit_date
        ''', [activityName]);
      });

      if (data == null) return [];

      return data.map((row) {
        return DailyData(
          date: DateTime.parse(row['visit_date'] as String),
          visits: (row['visit_count'] as int?) ?? 0,
          timeSpent: (row['time_spent'] as double?) ?? 0,
        );
      }).toList();
    } catch (e) {
      print('Error loading daily data: $e');
      return [];
    }
  }

  Future<List<StatusData>> _loadStatusDataForActivity(int activityId) async {

    try {
      final data = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          ast.Status_name as status_name,
          COUNT(vd.Id_visit_detail) as count
        FROM Visits v
        INNER JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        INNER JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
        WHERE v.Id_activity = ? AND ast.Status_name IS NOT NULL AND ast.Status_name != ''
        GROUP BY ast.Status_name
        HAVING count > 0
        ORDER BY count DESC
        LIMIT 10
        ''', [activityId]);
      });

      if (data == null) return [];

      print('📊 Status data loaded for activity $activityId: ${data.length} status types');
      for (var row in data) {
        print('   - ${row['status_name']}: ${row['count']} registros');
      }

      return data.map((row) {
        return StatusData(
          statusName: row['status_name'] as String,
          count: (row['count'] as int?) ?? 0,
        );
      }).toList();
    } catch (e) {
      print('❌ Error loading status data: $e');
      return [];
    }
  }

  Future<Map<String, DateTime?>> _getActivityDateRange(int activityId) async {

    try {
      final result = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          MIN(v.Created_at) as first_date,
          MAX(v.Created_at) as last_date
        FROM Visits v
        WHERE v.Id_activity = ?
        ''', [activityId]);
      });

      if (result != null && result.isNotEmpty && result[0]['first_date'] != null) {
        return {
          'first': DateTime.parse(result[0]['first_date'] as String),
          'last': DateTime.parse(result[0]['last_date'] as String),
        };
      }
    } catch (e) {
      print('Error loading date range: $e');
    }

    return {'first': null, 'last': null};
  }

  Future<void> _loadOperatorMetrics() async {

    try {
      final operators = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          u.Id_user as operator_id,
          u.Name_user as operator_name,
          NULL as supervisor_id,
          COUNT(DISTINCT v.Id_visit) as total_visits,
          COUNT(DISTINCT vd.Id_visit_detail) as completed_results,
          CASE
            WHEN COUNT(DISTINCT v.Id_visit) > 0 THEN
              (julianday(MAX(v.Created_at)) - julianday(MIN(v.Created_at))) * 24 * 60 / COUNT(DISTINCT v.Id_visit)
            ELSE 0.0
          END as avg_time_per_visit,
          (julianday(MAX(v.Created_at)) - julianday(MIN(v.Created_at))) * 24 as total_worked_time,
          CASE
            WHEN v.Status = 1 THEN
              (julianday(MAX(v.Created_at)) - julianday(MIN(v.Created_at))) * 24
            ELSE 0.0
          END as effective_time,
          MAX(v.Created_at) as last_activity
        FROM Users u
        INNER JOIN Visits v ON u.Id_user = v.Id_user
        LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        WHERE v.Id_visit IS NOT NULL
        GROUP BY u.Id_user, u.Name_user
        HAVING COUNT(DISTINCT v.Id_visit) > 0
        ORDER BY total_visits DESC
        ''');
      });

      if (operators == null) return;

      Map<int, OperatorMetrics> operatorMap = {};

      for (var op in operators) {
        final operatorId = op['operator_id'] as int;
        final totalWorkedTime = (op['total_worked_time'] as double?) ?? 0;
        final effectiveTime = (op['effective_time'] as double?) ?? 0;

        operatorMap[operatorId] = OperatorMetrics(
          operatorId: operatorId,
          operatorName: op['operator_name'] as String,
          totalVisits: (op['total_visits'] as int?) ?? 0,
          completedResults: (op['completed_results'] as int?) ?? 0,
          averageTimePerVisit: (op['avg_time_per_visit'] as double?) ?? 0,
          totalWorkedTime: totalWorkedTime,
          effectiveTime: effectiveTime,
          unproductiveTime: totalWorkedTime - effectiveTime,
          lastActivity: op['last_activity'] != null
              ? DateTime.parse(op['last_activity'] as String)
              : null,
          subordinates: [],
        );
      }

      // Build hierarchical structure
      List<OperatorMetrics> rootOperators = [];
      Map<int, List<OperatorMetrics>> subordinatesMap = {};

      for (var op in operators) {
        final operatorId = op['operator_id'] as int;
        final supervisorId = op['supervisor_id'] as int?;

        if (supervisorId == null) {
          rootOperators.add(operatorMap[operatorId]!);
        } else {
          subordinatesMap.putIfAbsent(supervisorId, () => []);
          subordinatesMap[supervisorId]!.add(operatorMap[operatorId]!);
        }
      }

      // Assign subordinates
      void assignSubordinates(OperatorMetrics operator) {
        if (subordinatesMap.containsKey(operator.operatorId)) {
          final subs = subordinatesMap[operator.operatorId]!;
          operator.subordinates.addAll(subs);
          for (var sub in subs) {
            assignSubordinates(sub);
          }
        }
      }

      for (var root in rootOperators) {
        assignSubordinates(root);
      }

      if (mounted) {
        setState(() {
          _operatorMetrics = rootOperators;
        });
      }
    } catch (e) {
      print('Error loading operator metrics: $e');
    }
  }

  /// Calcula el total de resultados para una actividad (basado en Visits_details registrados)
  /// Total = Total1 + Total2
  /// Total1: Status sin step parent (ligados directamente a la actividad)
  /// Total2: Status con step parent donde Calculation = '=SUMAFACTORES'
  /// Los status con step parent donde Calculation != '=SUMAFACTORES' (ej: =NINGUNO) NO se suman
  Future<int> _calculateTotalResultsForActivity(int activityId) async {
    try {
      final result = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT COALESCE(SUM(factor_value), 0) as total_results
          FROM (
            -- Total1: Status sin step parent (ligados directamente a la actividad)
            SELECT acs.Factor as factor_value
            FROM Visits_details vd
            INNER JOIN Visits v ON vd.Id_visit = v.Id_visit
            INNER JOIN Activities_status acs ON vd.Id_activity_status = acs.Id_activity_status
            WHERE v.Id_activity = ?
              AND (acs.Id_activity_step_parent IS NULL OR acs.Id_activity_step_parent = 0)

            UNION ALL

            -- Total2: Status con step parent donde Calculation = '=SUMAFACTORES'
            SELECT acs.Factor as factor_value
            FROM Visits_details vd
            INNER JOIN Visits v ON vd.Id_visit = v.Id_visit
            INNER JOIN Activities_status acs ON vd.Id_activity_status = acs.Id_activity_status
            INNER JOIN Activities_steps ast ON acs.Id_activity_step_parent = ast.Id_activity_step
            WHERE v.Id_activity = ?
              AND ast.Calculation = '=SUMAFACTORES'
          )
        ''', [activityId, activityId]);
      });

      if (result != null && result.isNotEmpty) {
        return (result[0]['total_results'] as int?) ?? 0;
      }
    } catch (e) {
      print('Error calculating total results: $e');
    }
    return 0;
  }

  /// Carga datos de operadores para el Dashboard
  /// Incluye: visitas, resultados, estados y lotes donde trabajó
  Future<void> _loadOperatorDashboardData() async {
    try {
      // Obtener unity de la actividad seleccionada
      final unity = FFAppState().activitySelected.unity;
      final activityId = FFAppState().activitySelected.idActivity;

      // Primero calcular el total_results para la actividad
      final totalResultsForActivity = await _calculateTotalResultsForActivity(activityId);

      final operators = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT
            u.Id_user as operator_id,
            u.Name_user as operator_name,
            COUNT(DISTINCT v.Id_visit) as total_visits
          FROM Users u
          INNER JOIN Visits v ON u.Id_user = v.Id_user
          WHERE v.Id_activity = ?
          GROUP BY u.Id_user, u.Name_user
          HAVING COUNT(DISTINCT v.Id_visit) > 0
          ORDER BY total_visits DESC
        ''', [activityId]);
      });

      if (operators == null) return;

      List<OperatorDashboardData> dashboardData = [];

      for (var op in operators) {
        final operatorId = (op['operator_id'] as int?) ?? 0;
        final operatorName = (op['operator_name'] as String?) ?? 'Sin nombre';
        final totalVisits = (op['total_visits'] as int?) ?? 0;

        // Cargar estados por operador
        final statusData = await _loadStatusDataForOperator(operatorId, activityId);

        // Cargar lotes donde trabajó el operador
        final headquarterNames = await _loadHeadquartersForOperator(operatorId, activityId);

        dashboardData.add(OperatorDashboardData(
          operatorId: operatorId,
          operatorName: operatorName,
          totalVisits: totalVisits,
          totalResults: totalResultsForActivity, // Usar el total calculado para la actividad
          statusData: statusData,
          headquarterNames: headquarterNames,
          unity: unity,
        ));
      }

      if (mounted) {
        setState(() {
          _operatorDashboardData = dashboardData;
        });
      }
    } catch (e) {
      print('Error loading operator dashboard data: $e');
    }
  }

  /// Carga estados por operador
  Future<List<StatusData>> _loadStatusDataForOperator(int operatorId, int activityId) async {
    try {
      final data = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT
            ast.Status_name as status_name,
            COUNT(vd.Id_visit_detail) as count
          FROM Visits v
          INNER JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
          INNER JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
          WHERE v.Id_user = ? AND v.Id_activity = ?
            AND ast.Status_name IS NOT NULL AND ast.Status_name != ''
          GROUP BY ast.Status_name
          HAVING count > 0
          ORDER BY count DESC
          LIMIT 10
        ''', [operatorId, activityId]);
      });

      if (data == null) return [];

      return data.map((row) {
        return StatusData(
          statusName: row['status_name'] as String,
          count: (row['count'] as int?) ?? 0,
        );
      }).toList();
    } catch (e) {
      print('Error loading status data for operator: $e');
      return [];
    }
  }

  /// Carga lotes donde trabajó un operador
  Future<List<String>> _loadHeadquartersForOperator(int operatorId, int activityId) async {
    try {
      final data = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT DISTINCT h.Name_headquarter as name
          FROM Visits v
          INNER JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
          WHERE v.Id_user = ? AND v.Id_activity = ?
            AND h.Name_headquarter IS NOT NULL AND h.Name_headquarter != ''
          ORDER BY h.Name_headquarter
          LIMIT 5
        ''', [operatorId, activityId]);
      });

      if (data == null) return [];

      return data.map((row) => row['name'] as String).toList();
    } catch (e) {
      print('Error loading headquarters for operator: $e');
      return [];
    }
  }

  /// Carga datos de lotes/headquarters para el Dashboard
  /// Incluye: visitas, resultados y operadores que intervinieron
  Future<void> _loadHeadquarterDashboardData() async {
    try {
      // Obtener unity de la actividad seleccionada
      final unity = FFAppState().activitySelected.unity;
      final activityId = FFAppState().activitySelected.idActivity;

      // Calcular el total_results para la actividad
      final totalResultsForActivity = await _calculateTotalResultsForActivity(activityId);

      final headquarters = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT
            h.Id_headquarter as headquarter_id,
            h.Name_headquarter as headquarter_name,
            COUNT(DISTINCT v.Id_visit) as total_visits
          FROM Headquarters h
          INNER JOIN Visits v ON h.Id_headquarter = v.Id_headquarter
          WHERE v.Id_activity = ?
          GROUP BY h.Id_headquarter, h.Name_headquarter
          HAVING COUNT(DISTINCT v.Id_visit) > 0
          ORDER BY total_visits DESC
        ''', [activityId]);
      });

      if (headquarters == null) return;

      List<HeadquarterDashboardData> dashboardData = [];

      for (var hq in headquarters) {
        final headquarterId = (hq['headquarter_id'] as int?) ?? 0;
        final headquarterName = (hq['headquarter_name'] as String?) ?? 'Sin nombre';
        final totalVisits = (hq['total_visits'] as int?) ?? 0;

        // Cargar operadores que trabajaron en este lote
        final operatorNames = await _loadOperatorsForHeadquarter(headquarterId, activityId);

        dashboardData.add(HeadquarterDashboardData(
          headquarterId: headquarterId,
          headquarterName: headquarterName,
          totalVisits: totalVisits,
          totalResults: totalResultsForActivity, // Usar el total calculado para la actividad
          operatorNames: operatorNames,
          unity: unity,
        ));
      }

      if (mounted) {
        setState(() {
          _headquarterDashboardData = dashboardData;
        });
      }
    } catch (e) {
      print('Error loading headquarter dashboard data: $e');
    }
  }

  /// Carga operadores que trabajaron en un lote
  Future<List<String>> _loadOperatorsForHeadquarter(int headquarterId, int activityId) async {
    try {
      final data = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
          SELECT DISTINCT u.Name_user as name
          FROM Visits v
          INNER JOIN Users u ON v.Id_user = u.Id_user
          WHERE v.Id_headquarter = ? AND v.Id_activity = ?
            AND u.Name_user IS NOT NULL AND u.Name_user != ''
          ORDER BY u.Name_user
        ''', [headquarterId, activityId]);
      });

      if (data == null) return [];

      return data.map((row) => row['name'] as String).toList();
    } catch (e) {
      print('Error loading operators for headquarter: $e');
      return [];
    }
  }

  Future<void> _loadPendingSyncData() async {

    try {
      final pending = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          v.Id_visit as sync_id,
          'Visita' as sync_type,
          a.Name_activity || ' - ' || h.Name_headquarter as description,
          v.Created_at as created_at
        FROM Visits v
        JOIN Activities a ON v.Id_activity = a.Id_activity
        JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
        WHERE v.Status = 0
        ORDER BY v.Created_at DESC
        LIMIT 100
        ''');
      });

      if (pending == null) {
        if (mounted) {
          setState(() {
            _pendingData = [];
            _pendingSyncCount = 0;
          });
        }
        return;
      }

      List<PendingSyncData> pendingList = pending.map((row) {
        return PendingSyncData(
          id: row['sync_id'] as int,
          type: row['sync_type'] as String,
          description: row['description'] as String,
          timestamp: DateTime.parse(row['created_at'] as String),
          data: {},
        );
      }).toList();

      if (mounted) {
        setState(() {
          _pendingData = pendingList;
          _pendingSyncCount = pendingList.length;
        });
      }
    } catch (e) {
      print('Error loading pending sync data: $e');
      if (mounted) {
        setState(() {
          _pendingData = [];
          _pendingSyncCount = 0;
        });
      }
    }
  }

  Future<void> _loadDownloadedData() async {

    try {
      final downloaded = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          v.Id_visit as download_id,
          'Visita Sincronizada' as download_type,
          a.Name_activity || ' - ' || h.Name_headquarter as description,
          v.Created_at as downloaded_at,
          0 as file_size,
          'Completado' as status
        FROM Visits v
        JOIN Activities a ON v.Id_activity = a.Id_activity
        JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
        WHERE v.Status = 1
        ORDER BY v.Created_at DESC
        LIMIT 100
        ''');
      });

      if (mounted) {
        setState(() {
          _downloadedData = downloaded ?? [];
        });
      }
    } catch (e) {
      print('Error loading downloaded data: $e');
      if (mounted) {
        setState(() {
          _downloadedData = [];
        });
      }
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      // Simulate sync process
      await Future.delayed(const Duration(seconds: 2));

      // Here you would implement actual sync logic
      // For now, we'll just reload the data
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sincronización completada',
              style: TextStyle(fontFamily: 'Roboto',color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error during sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error en sincronización',
              style: TextStyle(fontFamily: 'Roboto',color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF6B35),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1F17),
        body: _isLoading
            ? _buildLoadingState()
            : Column(
                children: [
                  // Header
                  _buildHeader(),
                  // TabBar
                  _buildTabBar(),
                  // TabBarView con contenido
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNewDashboardTab(), // Tab Dashboard
                        _buildDetalleTab(), // Tab Detalle (Operadores)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00FF7F).withOpacity(0.2),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00FF7F), Color(0xFF00B4D8)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard, size: 18),
                SizedBox(width: 8),
                Text('Dashboard'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 18),
                SizedBox(width: 8),
                Text('Detalle'),
              ],
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
            const Color(0xFF0D1F17).withOpacity(0.9),
            const Color(0xFF1A3A2E).withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF7F).withOpacity(0.1),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF7F), Color(0xFF00C853)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF7F).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF0D1F17),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Agronómico',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF00FF7F), Color(0xFF00B4D8)],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sistema de Monitoreo en Tiempo Real',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            _buildSyncButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: _performSync,
      child: AnimatedBuilder(
        animation: _syncButtonController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: _pendingSyncCount > 0
                  ? LinearGradient(
                      colors: [
                        Color.lerp(
                          const Color(0xFFFF6B35),
                          const Color(0xFFFF8C42),
                          _syncButtonController.value,
                        )!,
                        Color.lerp(
                          const Color(0xFFFF8C42),
                          const Color(0xFFFF6B35),
                          _syncButtonController.value,
                        )!,
                      ],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (_pendingSyncCount > 0
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFF10B981))
                      .withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: _pendingSyncCount > 0
                      ? 2 + (math.sin(_syncButtonController.value * 2 * math.pi) * 2)
                      : 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  _isSyncing ? Icons.hourglass_empty : Icons.sync,
                  color: Colors.white,
                  size: 20,
                ),
                if (_pendingSyncCount > 0 && !_isSyncing)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _pendingSyncCount > 99 ? '99+' : '$_pendingSyncCount',
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // _buildTabBar eliminado - ya no hay tabs internos

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF00FF7F),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cargando datos...',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 16,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivityCarousel(),
            const SizedBox(height: 32),
            _buildOperatorHierarchy(),
          ],
        ),
      ),
    );
  }

  /// Tab Detalle - Muestra la jerarquía de operadores existente
  Widget _buildDetalleTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOperatorHierarchy(),
          ],
        ),
      ),
    );
  }

  /// Nuevo Tab Dashboard - Resumen de visitas por operador, lote y actividad
  Widget _buildNewDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección: Resumen por Actividad
            _buildSectionTitle('RESUMEN POR ACTIVIDAD', Icons.agriculture),
            const SizedBox(height: 12),
            if (_activityMetrics.isEmpty)
              _buildEmptyState('No hay datos de actividades')
            else
              ..._activityMetrics.map((activity) => _buildActivityDashboardCard(activity)),

            const SizedBox(height: 24),

            // Sección: Resumen por Operador
            _buildSectionTitle('RESUMEN POR OPERADOR', Icons.person),
            const SizedBox(height: 12),
            if (_operatorDashboardData.isEmpty)
              _buildEmptyState('No hay datos de operadores')
            else
              ..._operatorDashboardData.map((op) => _buildOperatorDashboardCard(op)),

            const SizedBox(height: 24),

            // Sección: Resumen por Lote
            _buildSectionTitle('RESUMEN POR LOTE', Icons.location_on),
            const SizedBox(height: 12),
            if (_headquarterDashboardData.isEmpty)
              _buildEmptyState('No hay datos de lotes')
            else
              ..._headquarterDashboardData.map((hq) => _buildHeadquarterDashboardCard(hq)),
          ],
        ),
      ),
    );
  }

  /// Card de actividad para el Dashboard
  Widget _buildActivityDashboardCard(ActivityMetrics activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.9),
            const Color(0xFF0D1F17).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre de la actividad
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.agriculture, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  activity.activityName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Métricas y gráfico de torta
          Row(
            children: [
              // Métricas
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildDashboardMetricRow(
                      'Visitas',
                      activity.totalVisits.toString(),
                      const Color(0xFF00B4D8),
                    ),
                    const SizedBox(height: 8),
                    _buildDashboardMetricRow(
                      activity.unityLabel,
                      activity.totalResults.toString(),
                      const Color(0xFF00C853),
                    ),
                  ],
                ),
              ),
              // Gráfico de torta
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 80,
                  child: _buildMiniPieChart(
                    activity.totalVisits,
                    activity.totalResults,
                  ),
                ),
              ),
            ],
          ),

          // Rango de fechas
          if (activity.firstDate != null && activity.lastDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateRangeShort(activity.firstDate, activity.lastDate),
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Gráfico de barras horizontal para estados
          if (activity.statusData.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Estados',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            _buildHorizontalStatusBars(activity.statusData),
          ],
        ],
      ),
    );
  }

  /// Formatea un rango de fechas de forma corta
  String _formatDateRangeShort(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Sin fechas';

    final dateFormat = DateFormat('dd/MM/yy');
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return dateFormat.format(start);
    }
    return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00FF7F), Color(0xFF00B4D8)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Card de operador para el Dashboard
  Widget _buildOperatorDashboardCard(OperatorDashboardData operator) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.9),
            const Color(0xFF0D1F17).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FF7F).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF7F).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre del operador
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  operator.operatorName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Métricas y gráfico de torta
          Row(
            children: [
              // Métricas
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildDashboardMetricRow(
                      'Visitas',
                      operator.totalVisits.toString(),
                      const Color(0xFF00B4D8),
                    ),
                    const SizedBox(height: 8),
                    _buildDashboardMetricRow(
                      operator.unityLabel,
                      operator.totalResults.toString(),
                      const Color(0xFF00C853),
                    ),
                  ],
                ),
              ),
              // Gráfico de torta
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 80,
                  child: _buildMiniPieChart(
                    operator.totalVisits,
                    operator.totalResults,
                  ),
                ),
              ),
            ],
          ),

          // Lotes donde trabajó
          if (operator.headquarterNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: operator.headquarterNames.take(2).map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4D8).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00B4D8).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Color(0xFF00B4D8)),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Gráfico de barras horizontal para estados
          if (operator.statusData.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Estados',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            _buildHorizontalStatusBars(operator.statusData),
          ],
        ],
      ),
    );
  }

  /// Card de lote/headquarter para el Dashboard
  Widget _buildHeadquarterDashboardCard(HeadquarterDashboardData headquarter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.9),
            const Color(0xFF0D1F17).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00B4D8).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4D8).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre del lote
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headquarter.headquarterName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Métricas y gráfico de torta
          Row(
            children: [
              // Métricas
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildDashboardMetricRow(
                      'Visitas',
                      headquarter.totalVisits.toString(),
                      const Color(0xFF00B4D8),
                    ),
                    const SizedBox(height: 8),
                    _buildDashboardMetricRow(
                      headquarter.unityLabel,
                      headquarter.totalResults.toString(),
                      const Color(0xFF00C853),
                    ),
                  ],
                ),
              ),
              // Gráfico de torta
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 80,
                  child: _buildMiniPieChart(
                    headquarter.totalVisits,
                    headquarter.totalResults,
                  ),
                ),
              ),
            ],
          ),

          // Contador de operadores
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text(
                  '${headquarter.operatorCount} operador${headquarter.operatorCount != 1 ? 'es' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetricRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniPieChart(int visits, int results) {
    if (visits == 0 && results == 0) {
      return Center(
        child: Text(
          'Sin datos',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 10,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 15,
        sections: [
          PieChartSectionData(
            value: visits.toDouble(),
            color: const Color(0xFF00B4D8),
            radius: 20,
            showTitle: false,
          ),
          PieChartSectionData(
            value: results.toDouble(),
            color: const Color(0xFF00C853),
            radius: 20,
            showTitle: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalStatusBars(List<StatusData> statusData) {
    if (statusData.isEmpty) return const SizedBox.shrink();

    final maxCount = statusData.map((s) => s.count).reduce((a, b) => a > b ? a : b);

    return Column(
      children: statusData.take(5).map((status) {
        final percentage = maxCount > 0 ? status.count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  status.statusName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FF7F), Color(0xFF00B4D8)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '${status.count}',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityCarousel() {
    if (_activityMetrics.isEmpty) {
      return _buildEmptyState('No hay actividades registradas');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVIDADES',
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        CarouselSlider.builder(
          itemCount: _activityMetrics.length,
          itemBuilder: (context, index, realIndex) {
            return _buildActivityCard(_activityMetrics[index]);
          },
          options: CarouselOptions(
            height: 420,
            enlargeCenterPage: true,
            autoPlay: false,
            pauseAutoPlayOnTouch: true,
            aspectRatio: 16 / 9,
            viewportFraction: 0.85,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityMetrics activity) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.8),
            const Color(0xFF0D1F17).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00FF7F).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF7F).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.agriculture,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activity.activityName,
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Metrics: Solo Visitas y Resultados
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Visitas',
                          activity.totalVisits.toString(),
                          Icons.location_on,
                          const Color(0xFF00B4D8),
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          activity.unityLabel,
                          activity.totalResults.toString(),
                          Icons.fact_check,
                          const Color(0xFF00C853),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date badge
                  _buildDateRangeBadge(activity.firstDate, activity.lastDate),
                  const SizedBox(height: 12),

                  // Chart
                  Expanded(
                    child: _buildStatusChart(activity),
                  ),
                ],
              ),
        ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 11,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDateRangeBadge(DateTime? firstDate, DateTime? lastDate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A2E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, color: const Color(0xFF10B981), size: 14),
          const SizedBox(width: 6),
          Text(
            _formatDateRangeAgo(firstDate, lastDate),
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(ActivityMetrics activity) {
    if (activity.statusData.isEmpty) {
      return Center(
        child: Text(
          'No hay datos de estados',
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      );
    }

    final maxCount = activity.statusData.map((s) => s.count).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estados de la Actividad',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...activity.statusData.map((status) => _buildStatusBar(status, maxCount)),
        ],
      ),
    );
  }

  Widget _buildStatusBar(StatusData status, int maxCount) {
    final percentage = maxCount > 0 ? (status.count / maxCount) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  status.statusName,
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${status.count}',
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: const Color(0xFF1A3A2E).withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(
                  const Color(0xFF10B981),
                  const Color(0xFF00FF7F),
                  percentage,
                )!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart(ActivityMetrics activity) {
    if (activity.dailyData.isEmpty) {
      return Center(
        child: Text(
          'No hay datos históricos',
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFF00FF7F).withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: const Color(0xFF00B4D8).withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < activity.dailyData.length) {
                  final date = activity.dailyData[value.toInt()].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: const Color(0xFF00FF7F).withOpacity(0.2),
          ),
        ),
        minX: 0,
        maxX: (activity.dailyData.length - 1).toDouble(),
        minY: 0,
        maxY: activity.dailyData
            .map((d) => d.visits.toDouble())
            .reduce((a, b) => a > b ? a : b) * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: activity.dailyData.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.visits.toDouble(),
              );
            }).toList(),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Color(0xFF00FF7F), Color(0xFF00B4D8)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF00FF7F),
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF0A0E27),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF00FF7F).withOpacity(0.3),
                  const Color(0xFF00B4D8).withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = activity.dailyData[spot.x.toInt()].date;
                return LineTooltipItem(
                  '${date.day}/${date.month}\n${spot.y.toInt()} visitas',
                  TextStyle(fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorHierarchy() {
    if (_operatorMetrics.isEmpty) {
      return _buildEmptyState('No hay operadores registrados');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPERADORES',
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ..._operatorMetrics.map((operator) => _buildOperatorNode(operator, 0)),
      ],
    );
  }

  Widget _buildOperatorNode(OperatorMetrics operator, int level) {
    final hasSubordinates = operator.subordinates.isNotEmpty;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: level * 24.0,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1F3A).withOpacity(0.8),
                const Color(0xFF0A0E27).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: level == 0
                  ? const Color(0xFF00FF7F).withOpacity(0.5)
                  : const Color(0xFF00B4D8).withOpacity(0.3),
              width: level == 0 ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (level == 0
                        ? const Color(0xFF00FF7F)
                        : const Color(0xFF00B4D8))
                    .withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.all(16),
              initiallyExpanded: false,
              leading: _buildInitialsBadge(operator.operatorName),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      operator.operatorName,
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _buildBadge(
                    Icons.assignment,
                    operator.totalVisits.toString(),
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  _buildBadge(
                    Icons.check_circle,
                    operator.completedResults.toString(),
                    const Color(0xFF00C853),
                  ),
                ],
              ),
              children: [
                _buildOperatorMetricsGrid(operator),
              ],
            ),
          ),
        ),
        if (hasSubordinates)
          ...operator.subordinates.map(
            (sub) => _buildOperatorNode(sub, level + 1),
          ),
      ],
    );
  }

  Widget _buildOperatorMetricsGrid(OperatorMetrics operator) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Visitas Totales',
                  operator.totalVisits.toString(),
                  Icons.assignment_turned_in,
                  const Color(0xFF00B4D8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  _currentUnity.isNotEmpty ? _currentUnity : 'Resultados',
                  operator.completedResults.toString(),
                  Icons.check_circle_outline,
                  const Color(0xFF00C853),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Tiempo Promedio',
                  '${operator.averageTimePerVisit.toStringAsFixed(1)} min',
                  Icons.timer,
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Tiempo Laborado',
                  '${operator.totalWorkedTime.toStringAsFixed(1)} hrs',
                  Icons.access_time,
                  const Color(0xFFFF8C42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Tiempo Efectivo',
                  '${operator.effectiveTime.toStringAsFixed(1)} hrs',
                  Icons.trending_up,
                  const Color(0xFF00FF7F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Tiempo Improductivo',
                  '${operator.unproductiveTime.toStringAsFixed(1)} hrs',
                  Icons.trending_down,
                  const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEfficiencyBar(operator),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyBar(OperatorMetrics operator) {
    final efficiency = operator.totalWorkedTime > 0
        ? (operator.effectiveTime / operator.totalWorkedTime) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Eficiencia',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            Text(
              '${efficiency.toStringAsFixed(1)}%',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getEfficiencyColor(efficiency),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: efficiency / 100,
            minHeight: 10,
            backgroundColor: const Color(0xFF1A1F3A),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getEfficiencyColor(efficiency),
            ),
          ),
        ),
      ],
    );
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 80) return const Color(0xFF00C853);
    if (efficiency >= 60) return const Color(0xFF00FF7F);
    if (efficiency >= 40) return const Color(0xFFFF8C42);
    return const Color(0xFFFF6B35);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      // Si solo hay una palabra, tomar las primeras 2 letras
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    } else {
      // Tomar la primera letra de las primeras dos palabras
      return (words[0][0] + words[1][0]).toUpperCase();
    }
  }

  Widget _buildInitialsBadge(String operatorName) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(operatorName),
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return RefreshIndicator(
      onRefresh: _loadPendingSyncData,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: _pendingData.isEmpty
          ? _buildEmptyState('No hay datos pendientes de sincronizar')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _pendingData.length,
              itemBuilder: (context, index) {
                return _buildPendingCard(_pendingData[index]);
              },
            ),
    );
  }

  Widget _buildPendingCard(PendingSyncData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.8),
            const Color(0xFF0D1F17).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPendingIcon(data.type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.type.toUpperCase(),
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.description,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              height: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(data.timestamp),
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedTab() {
    return RefreshIndicator(
      onRefresh: _loadDownloadedData,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: _downloadedData.isEmpty
          ? _buildEmptyState('No hay datos descargados')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _downloadedData.length,
              itemBuilder: (context, index) {
                return _buildDownloadedCard(_downloadedData[index]);
              },
            ),
    );
  }

  Widget _buildDownloadedCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.8),
            const Color(0xFF0D1F17).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.download_done,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['download_type'] as String).toUpperCase(),
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'] as String,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: const Color(0xFF10B981).withOpacity(0.2),
              height: 1,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(
                        DateTime.parse(data['downloaded_at'] as String),
                      ),
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                if (data['file_size'] != null)
                  Row(
                    children: [
                      Icon(
                        Icons.storage,
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(data['file_size'] as int),
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF4ADE80).withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 64,
              color: const Color(0xFF10B981).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getPendingIcon(String type) {
    switch (type.toLowerCase()) {
      case 'visit':
        return Icons.place;
      case 'result':
        return Icons.assessment;
      case 'photo':
        return Icons.photo_camera;
      case 'signature':
        return Icons.draw;
      default:
        return Icons.sync;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Ahora';
    }
  }

  String _formatDateRangeAgo(DateTime? firstDate, DateTime? lastDate) {
    if (firstDate == null || lastDate == null) return 'Sin datos';

    final now = DateTime.now();
    final daysSinceFirst = now.difference(firstDate).inDays;
    final daysSinceLast = now.difference(lastDate).inDays;

    String firstText;
    if (daysSinceFirst == 0) {
      firstText = 'hoy';
    } else if (daysSinceFirst == 1) {
      firstText = 'ayer';
    } else if (daysSinceFirst < 7) {
      firstText = 'hace $daysSinceFirst días';
    } else if (daysSinceFirst < 30) {
      final weeks = (daysSinceFirst / 7).floor();
      firstText = weeks == 1 ? 'hace 1 semana' : 'hace $weeks semanas';
    } else if (daysSinceFirst < 365) {
      final months = (daysSinceFirst / 30).floor();
      firstText = months == 1 ? 'hace 1 mes' : 'hace $months meses';
    } else {
      final years = (daysSinceFirst / 365).floor();
      firstText = years == 1 ? 'hace 1 año' : 'hace $years años';
    }

    String lastText;
    if (daysSinceLast == 0) {
      lastText = 'hoy';
    } else if (daysSinceLast == 1) {
      lastText = 'ayer';
    } else if (daysSinceLast < 7) {
      lastText = 'hace $daysSinceLast días';
    } else if (daysSinceLast < 30) {
      final weeks = (daysSinceLast / 7).floor();
      lastText = weeks == 1 ? 'hace 1 semana' : 'hace $weeks semanas';
    } else {
      final months = (daysSinceLast / 30).floor();
      lastText = months == 1 ? 'hace 1 mes' : 'hace $months meses';
    }

    if (firstText == lastText) {
      return firstText;
    }

    return '$firstText - $lastText';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ============================================================================
  // VISIT DETAILS TAB
  // ============================================================================

  Future<void> _loadVisitDetails() async {

    try {
      final visits = await _withDatabase<List<Map<String, dynamic>>>((db) async {
        return await db.rawQuery('''
        SELECT
          v.Id_visit,
          a.Name_activity,
          h.Name_headquarter,
          v.Created_at,
          v.Status
        FROM Visits v
        JOIN Activities a ON v.Id_activity = a.Id_activity
        JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
        ORDER BY v.Created_at DESC
        LIMIT 100
        ''');
      });

      if (visits == null) return;

      List<VisitDetailData> detailsList = [];

      for (var visit in visits) {
        final visitId = visit['Id_visit'] as int;

        final details = await _withDatabase<List<Map<String, dynamic>>>((db) async {
          return await db.rawQuery('''
          SELECT
            vd.Id_visit_detail,
            ast.Status_name,
            ast.Type_status,
            vd.Status_response,
            vd.Status_option,
            ast.Default_status
          FROM Visits_details vd
          JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
          WHERE vd.Id_visit = ?
          ORDER BY vd.Id_visit_detail
          ''', [visitId]);
        });

        final detailItems = (details ?? []).map((d) {
          return VisitDetailItem(
            idVisitDetail: d['Id_visit_detail'] as int,
            statusName: (d['Status_name'] as String?) ?? '',
            statusType: (d['Type_status'] as String?) ?? '',
            statusResponse: (d['Status_response'] as String?) ?? '',
            statusOption: (d['Status_option'] as String?) ?? '',
            defaultStatus: (d['Default_status'] as String?) ?? '',
          );
        }).toList();

        detailsList.add(VisitDetailData(
          idVisit: visitId,
          activityName: visit['Name_activity'] as String,
          headquarterName: visit['Name_headquarter'] as String,
          createdAt: DateTime.parse(visit['Created_at'] as String),
          status: visit['Status'] as int,
          details: detailItems,
        ));
      }

      if (mounted) {
        setState(() {
          _visitDetails = detailsList;
        });
      }
    } catch (e) {
      print('Error loading visit details: $e');
    }
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _loadVisitDetails,
      color: const Color(0xFF00FF7F),
      backgroundColor: const Color(0xFF1A3A2E),
      child: _visitDetails.isEmpty
          ? _buildEmptyState('No hay visitas registradas')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _visitDetails.length,
              itemBuilder: (context, index) {
                return _buildVisitDetailCard(_visitDetails[index]);
              },
            ),
    );
  }

  Widget _buildVisitDetailCard(VisitDetailData visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2E).withOpacity(0.8),
            const Color(0xFF0D1F17).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: visit.status == 1
              ? const Color(0xFF00C853).withOpacity(0.4)
              : const Color(0xFFFF6B35).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (visit.status == 1
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF6B35))
                .withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: visit.status == 1
                    ? [const Color(0xFF00C853), const Color(0xFF00A040)]
                    : [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              visit.status == 1 ? Icons.check_circle : Icons.pending,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            visit.activityName,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                visit.headquarterName,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.white54,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(visit.createdAt),
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (visit.details.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hay detalles registrados',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              )
            else
              ...visit.details.map((detail) => _buildDetailItem(detail)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(VisitDetailItem detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F17).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getStatusIcon(detail.statusType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail.statusName,
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00FF7F),
                  ),
                ),
              ),
              _getStatusTypeBadge(detail.statusType),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailValue(detail),
        ],
      ),
    );
  }

  Widget _getStatusIcon(String statusType) {
    IconData icon;
    Color color;

    switch (statusType.toLowerCase()) {
      case 'number':
      case 'numbers':
        icon = Icons.pin;
        color = const Color(0xFF00B4D8);
        break;
      case 'numbers-operation':
        icon = Icons.calculate_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case 'label-info':
        icon = Icons.info_outline_rounded;
        color = const Color(0xFF66BB6A);
        break;
      case 'text':
        icon = Icons.text_fields;
        color = const Color(0xFFFF8C42);
        break;
      case 'tag-reader':
      case 'tag-writer':
      case 'tag-transfer':
        icon = Icons.nfc;
        color = const Color(0xFF00C853);
        break;
      case 'distance-extractor':
        icon = Icons.straighten_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'date':
        icon = Icons.calendar_today;
        color = const Color(0xFFFF6B35);
        break;
      case 'unique-list':
      case 'reference-list':
        icon = Icons.list;
        color = const Color(0xFF00FF7F);
        break;
      case 'dynamic-printing':
        icon = Icons.print;
        color = const Color(0xFF8B5CF6);
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.white54;
    }

    return Icon(icon, color: color, size: 18);
  }

  Widget _getStatusTypeBadge(String statusType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusType.toUpperCase(),
        style: TextStyle(fontFamily: 'Roboto',
          fontSize: 9,
          color: Colors.white54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailValue(VisitDetailItem detail) {
    final type = detail.statusType.toLowerCase();

    switch (type) {
      case 'number':
      case 'numbers':
        return _buildNumberValue(detail);
      case 'numbers-operation':
        return _buildNumbersOperationValue(detail);
      case 'label-info':
        return _buildLabelInfoValue(detail);
      case 'text':
        return _buildTextValue(detail);
      case 'unique-list':
      case 'reference-list':
        return _buildListValue(detail);
      case 'tag-reader':
      case 'tag-writer':
      case 'tag-transfer':
        return _buildTagValue(detail);
      case 'distance-extractor':
        return _buildDistanceValue(detail);
      case 'date':
        return _buildDateValue(detail);
      default:
        return _buildGenericValue(detail);
    }
  }

  Widget _buildNumberValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : detail.defaultStatus;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          value.isNotEmpty ? value : '0',
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF95D5B2),
          ),
        ),
      ),
    );
  }

  Widget _buildNumbersOperationValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Resultado Calculado',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF95D5B2),
            ),
          ),
          if (detail.defaultStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Fórmula: ${detail.defaultStatus}',
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 10,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabelInfoValue(VisitDetailItem detail) {
    final value = detail.defaultStatus.isNotEmpty
        ? detail.defaultStatus
        : 'Sin información';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(fontFamily: 'Roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTextValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : 'Sin respuesta';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(fontFamily: 'Roboto',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildListValue(VisitDetailItem detail) {
    final value = detail.statusOption.isNotEmpty
        ? detail.statusOption
        : 'No seleccionado';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF7F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00FF7F).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: const Color(0xFF00FF7F),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagValue(VisitDetailItem detail) {
    // Verificar si hay instrucción de validación de tipo de producto
    final hasProductTypeValidation = detail.defaultStatus.contains('=TYPE_PRODUCT_DEFAULT:');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.nfc,
            color: const Color(0xFF00C853),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hasProductTypeValidation
                ? FutureBuilder<String>(
                    future: _getProductNameAndRfid(detail.statusResponse, detail.defaultStatus),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          detail.statusResponse.isNotEmpty
                              ? detail.statusResponse
                              : 'Tag procesado',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        );
                      }

                      return Text(
                        snapshot.data ?? (detail.statusResponse.isNotEmpty
                            ? detail.statusResponse
                            : 'Tag procesado'),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      );
                    },
                  )
                : Text(
                    detail.statusResponse.isNotEmpty
                        ? detail.statusResponse
                        : 'Tag procesado',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Obtiene el nombre del producto y el RFID formateado para mostrar
  Future<String> _getProductNameAndRfid(String rfid, String defaultStatus) async {
    try {
      // Si no hay RFID, retornar el RFID vacío
      if (rfid.isEmpty) {
        return 'Tag procesado';
      }

      // Buscar el producto en SQLite por RFID
      final dbPath = FFAppState().pathDatabase;
      if (dbPath.isEmpty) {
        return rfid;
      }

      final database = await openDatabase(dbPath);

      final productResults = await database.rawQuery('''
        SELECT Name_product FROM Products WHERE Rfid = ? LIMIT 1
      ''', [rfid]);

      await database.close();

      if (productResults.isEmpty) {
        // Si no se encuentra el producto, solo mostrar el RFID
        return rfid;
      }

      final productName = productResults.first['Name_product'] as String?;
      if (productName == null || productName.isEmpty) {
        return rfid;
      }

      // Retornar formato: "Nombre del Producto - RFID"
      return '$productName - $rfid';
    } catch (e) {
      debugPrint('❌ Error obteniendo nombre del producto: $e');
      return rfid.isNotEmpty ? rfid : 'Tag procesado';
    }
  }

  Widget _buildDistanceValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : '0.00';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Distancia',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          Text(
            '$value km',
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : 'Sin fecha';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: const Color(0xFFFF6B35),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericValue(VisitDetailItem detail) {
    final value = detail.statusResponse.isNotEmpty
        ? detail.statusResponse
        : detail.defaultStatus.isNotEmpty
            ? detail.defaultStatus
            : 'Sin valor';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(fontFamily: 'Roboto',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Custom painters eliminados para mejorar rendimiento durante el scroll
