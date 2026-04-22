import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:provider/provider.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/backend/schema/structs/index.dart';
import 'activities_page_model.dart';
export 'activities_page_model.dart';

// ─── Fallback: reconstruye currentActivity desde SQLite cuando activitiesJSON es null ───

/// Convierte una fila de Activities_status en el mapa JSON que espera el formulario.
Map<String, dynamic> _statusRowToJson(Map<String, dynamic> row) {
  return {
    'id_activity_status':     row['Id_activity_status'],
    'id_activity':            row['Id_activity'],
    'id_activity_step_parent': row['Id_activity_step_parent'],
    'id_activity_status_parent': row['Id_activity_status_parent'],
    'type_status':    row['Type_status'],
    'order_status':   row['Order_status'],
    'default_status': row['Default_status'],
    'status_name':    row['Status_name'],
    'color':          row['Color'],
    'peso':           row['Peso'],
    'castigo':        row['Castigo'],
    'boton':          row['Boton'],
    'factor':         row['Factor'],
    'status':         row['Status'],
    'remember_status': false, // no almacenado en SQLite
    'status_childs':  <dynamic>[],
    'activities_status_childs': <dynamic>[],
  };
}

/// Carga una actividad desde SQLite y reconstruye la estructura jerárquica
/// que el formulario necesita (activity_steps + activity_status anidados).
Future<Map<String, dynamic>?> _loadActivityFromSQLite(int activityId) async {
  try {
    final db = await GlobalDbSingleton().database;

    // 1. Actividad principal
    final actRows = await db.query(
      'Activities', where: 'Id_activity = ?', whereArgs: [activityId]);
    if (actRows.isEmpty) {
      debugPrint('⚠️ [SQLite fallback] Activity $activityId no encontrada');
      return null;
    }
    final actRow = actRows.first;

    // 2. Steps ordenados
    final stepsRows = await db.query(
      'Activities_steps',
      where: 'Id_activity = ?',
      whereArgs: [activityId],
      orderBy: 'Order_step ASC',
    );

    // 3. Todos los status de esta actividad (flat)
    final statusRows = await db.query(
      'Activities_status',
      where: 'Id_activity = ?',
      whereArgs: [activityId],
      orderBy: 'Order_status ASC',
    );

    // Mapa id → json mutable para construir árbol de hijos
    final statusById = <int, Map<String, dynamic>>{};
    for (final row in statusRows) {
      final id = row['Id_activity_status'] as int;
      statusById[id] = _statusRowToJson(row);
    }

    // Construir hijos de status
    for (final row in statusRows) {
      final parentId = row['Id_activity_status_parent'];
      if (parentId != null && (parentId as int) != 0 && statusById.containsKey(parentId)) {
        final childId = row['Id_activity_status'] as int;
        final parent = statusById[parentId]!;
        (parent['status_childs'] as List).add(statusById[childId]!);
        (parent['activities_status_childs'] as List).add(statusById[childId]!);
      }
    }

    // Helper: status raíz de un step (padre de status = 0/null y padre de step = stepId)
    List<Map<String, dynamic>> rootStatusForStep(int stepId) => statusRows
      .where((r) {
        final sp = r['Id_activity_step_parent'];
        final sap = r['Id_activity_status_parent'];
        return sp == stepId && (sap == null || (sap as int) == 0);
      })
      .map((r) => statusById[r['Id_activity_status'] as int]!)
      .toList();

    // 4. Steps con sus status
    // Para reference-list, los status pertenecen a la actividad referenciada (default_value)
    // y deben consultarse por separado.
    final List<Map<String, dynamic>> stepsJson = [];
    for (final step in stepsRows) {
      final stepId   = step['Id_activity_step'] as int;
      final typeStep = step['Type_step'] as String? ?? '';

      List<Map<String, dynamic>> stepSts;

      if (typeStep == 'reference-list') {
        // Los status son de la actividad referenciada en default_value
        final refActivityIdRaw = step['Default_value'];
        final refActivityId = refActivityIdRaw != null
            ? int.tryParse(refActivityIdRaw.toString())
            : null;

        if (refActivityId != null) {
          try {
            final refStatusRows = await db.query(
              'Activities_status',
              where: 'Id_activity = ? AND (Id_activity_status_parent IS NULL OR Id_activity_status_parent = 0)',
              whereArgs: [refActivityId],
              orderBy: 'Order_status ASC',
            );

            // Construir mapa de todos los status de la actividad referenciada
            final allRefStatusRows = await db.query(
              'Activities_status',
              where: 'Id_activity = ?',
              whereArgs: [refActivityId],
              orderBy: 'Order_status ASC',
            );
            final refStatusById = <int, Map<String, dynamic>>{};
            for (final row in allRefStatusRows) {
              final id = row['Id_activity_status'] as int;
              refStatusById[id] = _statusRowToJson(row);
            }
            // Construir hijos
            for (final row in allRefStatusRows) {
              final parentId = row['Id_activity_status_parent'];
              if (parentId != null && (parentId as int) != 0 && refStatusById.containsKey(parentId)) {
                final childId = row['Id_activity_status'] as int;
                (refStatusById[parentId]!['activities_status_childs'] as List).add(refStatusById[childId]!);
                (refStatusById[parentId]!['status_childs'] as List).add(refStatusById[childId]!);
              }
            }

            stepSts = refStatusRows
                .map((r) => refStatusById[r['Id_activity_status'] as int]!)
                .toList();

            debugPrint('✅ [SQLite fallback] reference-list step "${step['Name_step']}" → ${stepSts.length} status desde actividad $refActivityId');
          } catch (e) {
            debugPrint('❌ [SQLite fallback] Error cargando status de ref-activity $refActivityId: $e');
            stepSts = [];
          }
        } else {
          stepSts = [];
        }
      } else {
        stepSts = rootStatusForStep(stepId);
      }

      stepsJson.add({
        'id_activity_step': stepId,
        'id_activity':      step['Id_activity'],
        'type_step':        typeStep,
        'order_step':       step['Order_step'],
        'default_value':    step['Default_value'],
        'unity':            step['Unity'],
        'calculation':      step['Calculation'],
        'name_step':        step['Name_step'],
        'status':           step['Status'],
        'is_required':      step['Is_required'] == 1,
        'activity_status':   stepSts,
        'activities_status': stepSts,
      });
    }

    // 5. Status raíz (sin step parent)
    final rootStatus = statusRows
      .where((r) {
        final sp  = r['Id_activity_step_parent'];
        final sap = r['Id_activity_status_parent'];
        return (sp == null || (sp as int) == 0) && (sap == null || (sap as int) == 0);
      })
      .map((r) => statusById[r['Id_activity_status'] as int]!)
      .toList();

    debugPrint(
      '✅ [SQLite fallback] Activity $activityId: '
      '${stepsJson.length} steps, ${rootStatus.length} root status');

    return {
      'id_activity':         actRow['Id_activity'],
      'id_company':          actRow['Id_company'],
      'id_activity_parent':  actRow['Id_activity_parent'],
      'name_activity':       actRow['Name_activity'],
      'group_activity':      actRow['Group_activity'],
      'unity':               actRow['Unity'],
      'type_activity':       actRow['Type_activity'],
      'type_effectivity':    actRow['Type_effectivity'],
      'cycle':               actRow['Cycle'],
      'effectivity_unitys':  actRow['Effectivity_unitys'],
      'effectivity_visits':  actRow['Effectivity_visits'],
      'module_activity':     actRow['Module_activity'],
      'description_activity': actRow['Description_activity'],
      'created_at':          actRow['Created_at'],
      'is_default':          actRow['Is_default'] == 1,
      'is_sync':             actRow['Is_sync'] == 1,
      'read_default':        actRow['Read_default'],
      'is_sync_full':        false, // no almacenado en SQLite
      'activity_steps':      stepsJson,
      'activity_status':     rootStatus,
    };
  } catch (e) {
    debugPrint('❌ [SQLite fallback] Error cargando actividad $activityId: $e');
    return null;
  }
}

class ActivitiesPageWidget extends StatefulWidget {
  const ActivitiesPageWidget({super.key});

  static String routeName = 'ActivitiesPage';
  static String routePath = '/activitiesPage';

  @override
  State<ActivitiesPageWidget> createState() => _ActivitiesPageWidgetState();
}

class _ActivitiesPageWidgetState extends State<ActivitiesPageWidget> {
  late ActivitiesPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Estado local para actividades cargadas desde SQLite
  List<ActivitiesStruct> _allActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivitiesPageModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // Cargar actividades desde SQLite después del primer frame
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _loadActivitiesFromSQLite();
    });
  }

  /// Carga actividades desde SQLite filtrando por módulo seleccionado
  Future<void> _loadActivitiesFromSQLite() async {
    try {
      final activities = await globalDb.executeOperation((db) async {
        // Usar rawQuery con alias para mapear los nombres de columnas SQLite (mayúsculas)
        // a los nombres esperados por ActivitiesStruct.fromMap() (minúsculas)
        return await db.rawQuery('''
          SELECT
            Id_activity as id_activity,
            Name_activity as name_activity,
            Group_activity as group_activity,
            Unity as unity,
            Cycle as cycle,
            Effectivity_unitys as effectivity_unitys,
            Effectivity_visits as effectivity_visits,
            Type_effectivity as type_effectivity,
            Module_activity as module_activity,
            Is_sync as is_sync,
            Is_sync_full as is_sync_full,
            Tracking_headquarter as tracking_headquarter
          FROM Activities
          WHERE Module_activity = ?
          ORDER BY Name_activity ASC
        ''', [FFAppState().moduleSelected]);
      });

      if (mounted) {
        setState(() {
          _allActivities = activities
              .map((map) => ActivitiesStruct.fromMap(map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando actividades desde SQLite: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    // Filtrar actividades por búsqueda
    final searchQuery = _model.textController.text.toLowerCase();
    final filteredActivities = searchQuery.isEmpty
        ? _allActivities
        : _allActivities.where((activity) {
            final activityName = activity.nameActivity.toLowerCase();
            return activityName.contains(searchQuery);
          }).toList();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF003420),
                  Color(0xFF002415),
                  Color(0xFF00150A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Header moderno
                Container(
                  padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF00a86b).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Botón Back
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.safePop();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFF00a86b).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF00ff9f),
                                size: 28,
                              ),
                            ),
                          ),
                          // Logo
                          Container(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.asset(
                                'assets/images/logo2_(1).png',
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          // Espaciador para balance
                          SizedBox(width: 44),
                        ],
                      ),
                      SizedBox(height: 6),
                      // Título con efecto brillante
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF00ff9f),
                              Color(0xFF00a86b),
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'Lista de actividades',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0xFF00a86b).withOpacity(0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // Búsqueda + contador en la misma fila
                      Row(
                        children: [
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF00a86b).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 15,
                              color: Color(0xFF00a86b).withOpacity(0.2),
                              offset: Offset(0, 6),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF00ff9f),
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model.textController,
                                      focusNode: _model.textFieldFocusNode,
                                      autofocus: false,
                                      obscureText: false,
                                      onChanged: (_) => safeSetState(() {}),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Búsqueda por nombre',
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: TextStyle(fontFamily: 'Roboto',
                                                fontWeight: FontWeight.w500,
                                              ),
                                              color: Color(0xFF00ff9f).withOpacity(0.7),
                                              letterSpacing: 0.5,
                                            ),
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: TextStyle(fontFamily: 'Roboto',),
                                              color: Colors.white.withOpacity(0.5),
                                              letterSpacing: 0.0,
                                            ),
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(fontFamily: 'Roboto',
                                              fontWeight: FontWeight.w600,
                                            ),
                                            color: Colors.white,
                                            fontSize: 15,
                                            letterSpacing: 0.3,
                                          ),
                                      cursorColor: Color(0xFF00ff9f),
                                      validator: _model.textControllerValidator
                                          .asValidator(context),
                                    ),
                                  ),
                                  if (_model.textController?.text.isNotEmpty ?? false)
                                    Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: InkWell(
                                        onTap: () {
                                          _model.textController?.clear();
                                          safeSetState(() {});
                                        },
                                        child: Icon(
                                          Icons.clear_rounded,
                                          color: Color(0xFF00ff9f).withOpacity(0.7),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                      SizedBox(width: 8),
                      // Contador al lado del buscador
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF00a86b).withOpacity(0.3),
                              Color(0xFF00a86b).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(0xFF00a86b).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list_alt_rounded,
                              color: Color(0xFF00ff9f),
                              size: 16,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${filteredActivities.length}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00ff9f),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 6),

                // Lista de actividades
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00ff9f),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Cargando actividades...',
                                style: TextStyle(fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredActivities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0xFF00a86b).withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      color: Color(0xFF00ff9f).withOpacity(0.5),
                                      size: 40,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No se encontraron actividades',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.7),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Intenta con otra búsqueda',
                                    style: TextStyle(fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: filteredActivities.length,
                              separatorBuilder: (_, __) => SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final activityItem = filteredActivities[index];
                                return _buildActivityCard(
                                  context,
                                  activityItem: activityItem,
                                  index: index,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required ActivitiesStruct activityItem,
    required int index,
  }) {
    final activityName = activityItem.nameActivity;

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        // Guardar actividad seleccionada como STRUCT
        FFAppState().activitySelected = activityItem;

        dynamic activityJSON;

        // 1. Buscar en activitiesJSON (cargado del endpoint GZIP en login)
        final activitiesJSON = FFAppState().activitiesJSON;
        if (activitiesJSON != null) {
          try {
            final activitiesList = activitiesJSON is List ? activitiesJSON : [];
            for (final a in activitiesList) {
              if (a is Map && a['id_activity'] == activityItem.idActivity) {
                activityJSON = a;
                break;
              }
            }
            if (activityJSON != null) {
              debugPrint('✅ Actividad encontrada en activitiesJSON: ${activityItem.nameActivity}');
            } else {
              debugPrint('⚠️ Actividad no encontrada en activitiesJSON, id_activity: ${activityItem.idActivity}');
            }
          } catch (e) {
            debugPrint('❌ Error buscando actividad en activitiesJSON: $e');
          }
        } else {
          debugPrint('⚠️ activitiesJSON es null — usando fallback SQLite');
        }

        // 2. Fallback: reconstruir desde SQLite si activitiesJSON no aportó datos
        if (activityJSON == null) {
          debugPrint('🔄 Cargando actividad ${activityItem.idActivity} desde SQLite...');
          activityJSON = await _loadActivityFromSQLite(activityItem.idActivity);
        }

        if (activityJSON != null) {
          // Diagnóstico: verificar activities_status en steps de tipo reference-list
          try {
            final steps = (activityJSON['activity_steps'] as List?) ?? [];
            for (final step in steps) {
              if (step is Map && step['type_step'] == 'reference-list') {
                final statuses = (step['activities_status'] as List?) ?? [];
                debugPrint('🔍 [activities_page] reference-list step "${step['name_step']}" → activities_status: ${statuses.length}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error inspeccionando steps: $e');
          }
          FFAppState().activitySelectedJSON = activityJSON;
          FFAppState().currentActivity = activityJSON;
        } else {
          debugPrint('❌ No se pudo cargar el JSON de la actividad: ${activityItem.nameActivity}');
        }

        FFAppState().update(() {});
        if (context.mounted) context.safePop();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Color(0xFF00a86b).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              color: Color(0xFF00a86b).withOpacity(0.2),
              offset: Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Row(
              children: [
                // Número de índice
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00a86b),
                        Color(0xFF003420),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Color(0xFF00a86b).withOpacity(0.4),
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Icono de actividad
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFF00a86b).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    color: Color(0xFF00ff9f),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                // Nombre de la actividad
                Expanded(
                  child: Text(
                    activityName,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: TextStyle(fontFamily: 'Roboto',
                            fontWeight: FontWeight.bold,
                          ),
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12),
                // Icono de flecha
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF00ff9f),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
