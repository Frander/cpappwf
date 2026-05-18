// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom widgets
// Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';

// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import '/backend/sqlite/global_db_singleton.dart';

// ============================================================================
// MODELOS INTERNOS
// ============================================================================

class _DetailItem {
  final String statusOption;
  final String statusResponse;
  final int count; // 1 para multi-detalle, N para agregado

  const _DetailItem({
    required this.statusOption,
    required this.statusResponse,
    required this.count,
  });
}

class _DateNode {
  final DateTime date;
  final int visitCount;
  final double totalFactor;
  final List<_DetailItem> items;

  const _DateNode({
    required this.date,
    required this.visitCount,
    required this.totalFactor,
    required this.items,
  });
}

class _HqNode {
  final int id;
  final String name;
  final int totalVisits;
  final double totalFactor;
  final List<_DateNode> dates;

  const _HqNode({
    required this.id,
    required this.name,
    required this.totalVisits,
    required this.totalFactor,
    required this.dates,
  });
}

class _UserNode {
  final int id;
  final String name;
  final int totalVisits;
  final double totalFactor;
  final List<_HqNode> headquarters;

  const _UserNode({
    required this.id,
    required this.name,
    required this.totalVisits,
    required this.totalFactor,
    required this.headquarters,
  });
}

class _ActivityNode {
  final int id;
  final String name;
  final bool isMultiDetail;
  final double totalFactor;
  final String factorUnit;
  final List<_UserNode> users;

  const _ActivityNode({
    required this.id,
    required this.name,
    required this.isMultiDetail,
    required this.totalFactor,
    required this.factorUnit,
    required this.users,
  });
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

class _HistoryVisitsFormState extends State<HistoryVisitsForm> {
  // ── Paleta (idéntica a home_page_widget) ────────────────────────────────
  static const _kGreen1 = Color(0xFF00ff9f);
  static const _kGreen2 = Color(0xFF00a86b);
  static const _kBg1 = Color(0xFF003420);
  static const _kBg2 = Color(0xFF002415);
  static const _kBg3 = Color(0xFF00150A);
  static const _kCard1 = Color(0xFF1A3A2E);
  static const _kCard2 = Color(0xFF0D1F17);

  // ── Estado ───────────────────────────────────────────────────────────────
  bool _isLoadingInitial = true;
  int _totalVisits = 0;
  List<Map<String, dynamic>> _activityList = [];
  final Map<int, _ActivityNode> _activityCache = {};
  final Map<int, bool> _activityLoading = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es').then((_) {});
    _loadInitialData();
  }

  // ── Carga inicial ────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);
    try {
      final countResult = await globalDb.executeOperation<List<Map<String, dynamic>>>(
        (db) => db.rawQuery('SELECT COUNT(*) as total FROM Visits'),
      );
      final total = countResult.isNotEmpty
          ? (countResult[0]['total'] as int?) ?? 0
          : 0;

      final activitiesResult = await globalDb.executeOperation<List<Map<String, dynamic>>>(
        (db) => db.rawQuery('''
          SELECT a.Id_activity as id, a.Name_activity as name
          FROM Activities a
          WHERE EXISTS (SELECT 1 FROM Visits v WHERE v.Id_activity = a.Id_activity)
          ORDER BY a.Name_activity
        '''),
      );

      if (mounted) {
        setState(() {
          _totalVisits = total;
          _activityList = List<Map<String, dynamic>>.from(activitiesResult);
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      debugPrint('❌ HistoryVisitsForm._loadInitialData: $e');
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  // ── Carga lazy por actividad ─────────────────────────────────────────────

  Future<void> _ensureActivityLoaded(int activityId, String activityName) async {
    if (_activityCache.containsKey(activityId)) return;
    if (_activityLoading[activityId] == true) return;

    if (mounted) setState(() => _activityLoading[activityId] = true);

    try {
      final node = await _loadActivityData(activityId, activityName);
      if (mounted) {
        setState(() {
          _activityCache[activityId] = node;
          _activityLoading.remove(activityId);
        });
      }
    } catch (e) {
      debugPrint('❌ _ensureActivityLoaded[$activityId]: $e');
      if (mounted) setState(() => _activityLoading.remove(activityId));
    }
  }

  Future<_ActivityNode> _loadActivityData(int activityId, String activityName) async {
    final rows = await globalDb.executeOperation<List<Map<String, dynamic>>>(
          (db) => db.rawQuery('''
        SELECT
          v.Id_visit,
          u.Id_user,
          COALESCE(u.Name_user, 'Sin nombre') as Name_user,
          h.Id_headquarter,
          COALESCE(h.Name_headquarter, 'Sin lote') as Name_headquarter,
          DATE(v.Created_at) as visit_date,
          vd.Status_option,
          vd.Status_response,
          COALESCE(ast.Factor, 0) as factor
        FROM Visits v
        INNER JOIN Users u ON v.Id_user = u.Id_user
        INNER JOIN Headquarters h ON v.Id_headquarter = h.Id_headquarter
        LEFT JOIN Visits_details vd ON v.Id_visit = vd.Id_visit
        LEFT JOIN Activities_status ast ON vd.Id_activity_status = ast.Id_activity_status
        WHERE v.Id_activity = ?
        ORDER BY u.Name_user, h.Name_headquarter, visit_date DESC,
                 v.Id_visit, vd.Id_visit_detail
      ''', [activityId]),
        );

    // Determinar tipo: agrupar por Id_visit y ver si alguno tiene > 1 detalle
    final Map<int, int> visitDetailCount = {};
    for (final row in rows) {
      if (row['Status_option'] == null) continue;
      final visitId = row['Id_visit'] as int;
      visitDetailCount[visitId] = (visitDetailCount[visitId] ?? 0) + 1;
    }
    final isMultiDetail = visitDetailCount.values.any((c) => c > 1);

    final users = isMultiDetail ? _groupMultiDetail(rows) : _groupAggregated(rows);

    final unityResult = await globalDb.executeOperation<List<Map<String, dynamic>>>(
      (db) => db.rawQuery(
        'SELECT COALESCE(Unity, ?) as unity FROM Activities WHERE Id_activity = ?',
        ['F', activityId],
      ),
    );
    final factorUnit = unityResult.isNotEmpty
        ? ((unityResult[0]['unity'] as String?)?.trim().isNotEmpty == true
            ? unityResult[0]['unity'] as String
            : 'F')
        : 'F';

    return _ActivityNode(
      id: activityId,
      name: activityName,
      isMultiDetail: isMultiDetail,
      totalFactor: users.fold(0.0, (s, u) => s + u.totalFactor),
      factorUnit: factorUnit,
      users: users,
    );
  }

  List<_UserNode> _groupMultiDetail(List<Map<String, dynamic>> rows) {
    final Map<int, String> userNames = {};
    final Map<int, String> hqNames = {};
    final Map<int, Map<int, Map<String, List<_DetailItem>>>> tree = {};
    final Map<int, Map<int, Map<String, Set<int>>>> visitSets = {};
    final Map<int, Map<int, Map<String, double>>> factorTotals = {};

    for (final row in rows) {
      if (row['Status_option'] == null) continue;
      final userId = row['Id_user'] as int;
      final hqId = row['Id_headquarter'] as int;
      final dateStr = row['visit_date'] as String;
      final visitId = row['Id_visit'] as int;
      final factor = (row['factor'] as num?)?.toDouble() ?? 0.0;

      userNames[userId] = row['Name_user'] as String;
      hqNames[hqId] = row['Name_headquarter'] as String;

      tree.putIfAbsent(userId, () => {});
      tree[userId]!.putIfAbsent(hqId, () => {});
      tree[userId]![hqId]!.putIfAbsent(dateStr, () => []);

      visitSets.putIfAbsent(userId, () => {});
      visitSets[userId]!.putIfAbsent(hqId, () => {});
      visitSets[userId]![hqId]!.putIfAbsent(dateStr, () => {});
      visitSets[userId]![hqId]![dateStr]!.add(visitId);

      factorTotals.putIfAbsent(userId, () => {});
      factorTotals[userId]!.putIfAbsent(hqId, () => {});
      factorTotals[userId]![hqId]![dateStr] =
          (factorTotals[userId]![hqId]![dateStr] ?? 0.0) + factor;

      tree[userId]![hqId]![dateStr]!.add(_DetailItem(
        statusOption: row['Status_option'] as String? ?? '',
        statusResponse: row['Status_response'] as String? ?? '',
        count: 1,
      ));
    }

    return tree.entries.map((uEntry) {
      final userId = uEntry.key;
      final hqNodes = uEntry.value.entries.map((hEntry) {
        final hqId = hEntry.key;
        final dateNodes = hEntry.value.entries.map((dEntry) {
          final visitCount = visitSets[userId]![hqId]![dEntry.key]!.length;
          return _DateNode(
            date: DateTime.parse(dEntry.key),
            visitCount: visitCount,
            totalFactor: factorTotals[userId]?[hqId]?[dEntry.key] ?? 0.0,
            items: dEntry.value,
          );
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return _HqNode(
          id: hqId,
          name: hqNames[hqId]!,
          totalVisits: dateNodes.fold(0, (s, d) => s + d.visitCount),
          totalFactor: dateNodes.fold(0.0, (s, d) => s + d.totalFactor),
          dates: dateNodes,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return _UserNode(
        id: userId,
        name: userNames[userId]!,
        totalVisits: hqNodes.fold(0, (s, h) => s + h.totalVisits),
        totalFactor: hqNodes.fold(0.0, (s, h) => s + h.totalFactor),
        headquarters: hqNodes,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_UserNode> _groupAggregated(List<Map<String, dynamic>> rows) {
    final Map<int, String> userNames = {};
    final Map<int, String> hqNames = {};
    final Map<int, Map<int, Map<String, Map<String, int>>>> counts = {};
    final Map<int, Map<int, Map<String, Set<int>>>> visitSets = {};
    final Map<int, Map<int, Map<String, double>>> factorTotals = {};

    for (final row in rows) {
      if (row['Status_option'] == null) continue;
      final userId = row['Id_user'] as int;
      final hqId = row['Id_headquarter'] as int;
      final dateStr = row['visit_date'] as String;
      final statusOption = row['Status_option'] as String? ?? '';
      final visitId = row['Id_visit'] as int;
      final factor = (row['factor'] as num?)?.toDouble() ?? 0.0;

      userNames[userId] = row['Name_user'] as String;
      hqNames[hqId] = row['Name_headquarter'] as String;

      factorTotals.putIfAbsent(userId, () => {});
      factorTotals[userId]!.putIfAbsent(hqId, () => {});
      factorTotals[userId]![hqId]![dateStr] =
          (factorTotals[userId]![hqId]![dateStr] ?? 0.0) + factor;

      counts.putIfAbsent(userId, () => {});
      counts[userId]!.putIfAbsent(hqId, () => {});
      counts[userId]![hqId]!.putIfAbsent(dateStr, () => {});
      counts[userId]![hqId]![dateStr]![statusOption] =
          (counts[userId]![hqId]![dateStr]![statusOption] ?? 0) + 1;

      visitSets.putIfAbsent(userId, () => {});
      visitSets[userId]!.putIfAbsent(hqId, () => {});
      visitSets[userId]![hqId]!.putIfAbsent(dateStr, () => {});
      visitSets[userId]![hqId]![dateStr]!.add(visitId);
    }

    return counts.entries.map((uEntry) {
      final userId = uEntry.key;
      final hqNodes = uEntry.value.entries.map((hEntry) {
        final hqId = hEntry.key;
        final dateNodes = hEntry.value.entries.map((dEntry) {
          final dateStr = dEntry.key;
          final visitCount = visitSets[userId]![hqId]![dateStr]!.length;
          final items = dEntry.value.entries
              .map((e) => _DetailItem(
                    statusOption: e.key,
                    statusResponse: '',
                    count: e.value,
                  ))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));
          return _DateNode(
            date: DateTime.parse(dateStr),
            visitCount: visitCount,
            totalFactor: factorTotals[userId]?[hqId]?[dateStr] ?? 0.0,
            items: items,
          );
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return _HqNode(
          id: hqId,
          name: hqNames[hqId]!,
          totalVisits: dateNodes.fold(0, (s, d) => s + d.visitCount),
          totalFactor: dateNodes.fold(0.0, (s, d) => s + d.totalFactor),
          dates: dateNodes,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return _UserNode(
        id: userId,
        name: userNames[userId]!,
        totalVisits: hqNodes.fold(0, (s, h) => s + h.totalVisits),
        totalFactor: hqNodes.fold(0.0, (s, h) => s + h.totalFactor),
        headquarters: hqNodes,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Navegación a ModernSyncPage ──────────────────────────────────────────

  Future<void> _navigateToSync() async {
    if (!mounted) return;
    final newsAdd = FFAppState().newsAdd;
    final idCompany = FFAppState().companyDefault.idCompany;
    final idsHeadquarters = joinHeadquarterIds(FFAppState().headquartersSelectedList);
    final imei = FFAppState().deviceDefault.imeI1;
    final authToken = (FFAppState().loginResponse?['token'] as String?) ?? '';

    await context.pushNamed(
      'ModernSyncPage',
      queryParameters: {
        'newsAdd': serializeParam(newsAdd, ParamType.DataStruct, isList: true),
        'idCompany': serializeParam(idCompany, ParamType.int),
        'idsHeadquarters': serializeParam(idsHeadquarters, ParamType.String),
        'imei': serializeParam(imei, ParamType.String),
        'authToken': serializeParam(authToken, ParamType.String),
      }.withoutNulls,
    );

    if (mounted) _loadInitialData();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg1, _kBg2, _kBg3],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoadingInitial
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _kGreen1,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      color: _kGreen1,
                      backgroundColor: _kCard1,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          _buildSection1(),
                          const SizedBox(height: 24),
                          _buildSection2(),
                          const SizedBox(height: 24),
                          _buildSection3(),
                          const SizedBox(height: 16),
                          _buildAdvancedConfigButton(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCard1, _kCard2],
        ),
        border: Border(
          bottom: BorderSide(color: _kGreen2.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGreen2, _kGreen1]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial & Sincronización',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Visitas registradas y estado de sync',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Sección 1: Resumen ───────────────────────────────────────────────────

  Widget _buildSection1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('RESUMEN', Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Lecturas',
                value: _totalVisits,
                color: _kGreen1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.location_on_rounded,
                label: 'Visitas',
                value: _totalVisits,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCard1, _kCard2],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
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
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección 2: Detalle por actividad ────────────────────────────────────

  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DETALLE POR ACTIVIDAD', Icons.account_tree_outlined),
        const SizedBox(height: 12),
        if (_activityList.isEmpty)
          _buildEmptyState('No hay visitas registradas')
        else
          ..._activityList.map(_buildActivityExpansion),
      ],
    );
  }

  Widget _buildActivityExpansion(Map<String, dynamic> activity) {
    final activityId = activity['id'] as int;
    final activityName = activity['name'] as String? ?? 'Actividad';
    final isLoaded = _activityCache.containsKey(activityId);
    final isLoading = _activityLoading[activityId] == true;
    final node = _activityCache[activityId];

    // initiallyExpanded:true no dispara onExpansionChanged, así que cargamos
    // los datos vía post-frame para que el árbol aparezca al primer render.
    if (!isLoaded && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureActivityLoaded(activityId, activityName);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCard1, _kCard2],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen2.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kGreen1.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            if (expanded && !isLoaded && !isLoading) {
              _ensureActivityLoaded(activityId, activityName);
            }
          },
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGreen2, _kGreen1]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.agriculture_rounded, color: Colors.black, size: 20),
          ),
          title: Text(
            activityName,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            softWrap: true,
          ),
          subtitle: isLoaded && node != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        node.isMultiDetail
                            ? Icons.account_tree_rounded
                            : Icons.format_list_bulleted_rounded,
                        size: 12,
                        color: _kGreen2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        node.isMultiDetail ? 'Árbol detallado' : 'Lista agregada',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFactorBadge(node.totalFactor, node.factorUnit),
                    ],
                  ),
                )
              : null,
          iconColor: _kGreen1,
          collapsedIconColor: Colors.white38,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _kGreen2.withValues(alpha: 0.2), width: 1),
                ),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _kGreen1,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : node != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildTreeContent(node),
                        )
                      : _buildEmptyState('Sin datos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeContent(_ActivityNode node) {
    if (node.users.isEmpty) {
      return _buildEmptyState('Sin visitas en esta actividad');
    }
    return Column(
      children: node.users
          .map((user) => _buildUserTile(user, node.isMultiDetail, node.factorUnit))
          .toList(),
    );
  }

  // Nivel 1 — Usuario
  Widget _buildUserTile(_UserNode user, bool isMulti, String factorUnit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen2.withValues(alpha: 0.25), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kGreen2.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen2.withValues(alpha: 0.4), width: 1),
            ),
            child: Center(
              child: Text(
                _getInitials(user.name),
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kGreen1,
                ),
              ),
            ),
          ),
          title: Text(
            user.name,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            softWrap: true,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFactorBadge(user.totalFactor, factorUnit),
              const SizedBox(width: 6),
              _buildBadge(user.totalVisits, _kGreen2),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 20),
            ],
          ),
          iconColor: Colors.transparent,
          collapsedIconColor: Colors.transparent,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: user.headquarters
                    .map((hq) => _buildHqTile(hq, isMulti, factorUnit))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nivel 2 — Lote / Headquarter
  Widget _buildHqTile(_HqNode hq, bool isMulti, String factorUnit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          leading: const Icon(Icons.park_outlined, color: _kGreen2, size: 20),
          title: Text(
            hq.name,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            softWrap: true,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFactorBadge(hq.totalFactor, factorUnit),
              const SizedBox(width: 6),
              _buildBadge(hq.totalVisits, const Color(0xFF00B4D8)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 18),
            ],
          ),
          iconColor: Colors.transparent,
          collapsedIconColor: Colors.transparent,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Column(
                children: hq.dates.map((date) => _buildDateTile(date, isMulti)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nivel 3 — Fecha (agrupada por día)
  Widget _buildDateTile(_DateNode date, bool isMulti) {
    final maxCount = (!isMulti && date.items.isNotEmpty)
        ? date.items.map((i) => i.count).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          leading:
              const Icon(Icons.calendar_month_outlined, color: Colors.white54, size: 18),
          title: Text(
            _formatDate(date.date),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            softWrap: true,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(date.visitCount, Colors.white24),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 18),
            ],
          ),
          iconColor: Colors.transparent,
          collapsedIconColor: Colors.transparent,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: date.items
                    .map((item) => _buildDetailRow(item, isMulti, maxCount))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nivel 4 — Detalle o sumatoria
  Widget _buildDetailRow(_DetailItem item, bool isMulti, int maxCount) {
    if (isMulti) {
      // Árbol multi-detalle: status_option | status_response
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: BoxDecoration(
                color: _kGreen1.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                item.statusOption,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                softWrap: true,
              ),
            ),
            if (item.statusResponse.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '|',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  item.statusResponse,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Lista agregada: status_option + ×N + mini barra proporcional
      final fraction = maxCount > 0 ? (item.count / maxCount).clamp(0.0, 1.0) : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.statusOption,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kGreen1.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _kGreen1.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '×${item.count}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kGreen1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Mini barra proporcional
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(
                    height: 5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [_kGreen2, _kGreen1]),
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
  }

  // ── Sección 3: Sincronización ────────────────────────────────────────────

  Widget _buildSection3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SINCRONIZACIÓN', Icons.sync_rounded),
        const SizedBox(height: 12),
        _buildSyncButton(
          label: 'SINCRONIZAR',
          icon: Icons.sync_rounded,
          colors: const [_kGreen2, _kGreen1],
          onTap: _navigateToSync,
        ),
      ],
    );
  }

  Widget _buildSyncButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sección 4: Configuración Avanzada ───────────────────────────────────

  Widget _buildAdvancedConfigButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.pushNamed('InformationPage'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2A1A), Color(0xFF0D1A0D)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00FF7F).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    color: Color(0xFF00ff9f), size: 22),
                SizedBox(width: 12),
                Text(
                  'Configuración Avanzada',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, color: Colors.white30, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kGreen2, _kGreen1]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFactorBadge(double factor, String factorUnit) {
    final display = factor == factor.truncateToDouble()
        ? factor.toInt().toString()
        : factor.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            factorUnit,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFB300),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            display,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    final textColor =
        color == Colors.white24 ? Colors.white70 : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.white24, size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers de datos ─────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    try {
      final formatted = DateFormat("EEEE d 'de' MMMM", 'es').format(date);
      // Capitalizar primera letra
      return formatted.isNotEmpty
          ? formatted[0].toUpperCase() + formatted.substring(1)
          : formatted;
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words[0];
      return w.substring(0, w.length >= 2 ? 2 : w.length).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
