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
                  padding: EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 16.0),
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
                      SizedBox(height: 16),
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
                            fontSize: 22,
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
                      SizedBox(height: 16),
                      // Campo de búsqueda mejorado
                      Container(
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
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                // Contador de actividades
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list_alt_rounded,
                              color: Color(0xFF00ff9f),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${filteredActivities.length} actividad${filteredActivities.length != 1 ? 'es' : ''}',
                              style: TextStyle(fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00ff9f),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

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

        // Buscar la actividad completa en activitiesJSON usando el id_activity
        final activitiesJSON = FFAppState().activitiesJSON;
        if (activitiesJSON != null) {
          try {
            final activitiesList = activitiesJSON is List ? activitiesJSON : [];
            final activityJSON = activitiesList.firstWhere(
              (activity) => getJsonField(activity, r'''$.id_activity''') == activityItem.idActivity,
              orElse: () => null,
            );

            if (activityJSON != null) {
              // Guardar el JSON completo de la actividad (con activity_steps y activity_status)
              FFAppState().activitySelectedJSON = activityJSON;
              FFAppState().currentActivity = activityJSON;
              debugPrint('✅ Actividad encontrada en activitiesJSON: ${activityItem.nameActivity}');
            } else {
              debugPrint('⚠️ Actividad no encontrada en activitiesJSON, id_activity: ${activityItem.idActivity}');
            }
          } catch (e) {
            debugPrint('❌ Error buscando actividad en activitiesJSON: $e');
          }
        } else {
          debugPrint('⚠️ activitiesJSON es null, no se pudo cargar la actividad completa');
        }

        FFAppState().update(() {});
        context.safePop();
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
