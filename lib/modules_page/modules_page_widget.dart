import '/components/calibrate_compass_component_widget.dart';
import '/components/calibration_required_dialog_widget.dart';
import '/components/modern_calibrate_compass_widget.dart';
import '/components/info_dialog_widget.dart';
import '/components/gps_quality_indicator_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'modules_page_model.dart';
export 'modules_page_model.dart';

class ModulesPageWidget extends StatefulWidget {
  const ModulesPageWidget({super.key});

  static String routeName = 'ModulesPage';
  static String routePath = '/modulesPage';

  @override
  State<ModulesPageWidget> createState() => _ModulesPageWidgetState();
}

class _ModulesPageWidgetState extends State<ModulesPageWidget> {
  late ModulesPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModulesPageModel());

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        Future(() async {
          if (FFAppState().calibrateCompass == false) {
            // Mostrar nuevo diálogo moderno de calibración requerida
            final bool? shouldCalibrate = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black.withOpacity(0.85),
              builder: (dialogContext) {
                return CalibrationRequiredDialogWidget(
                  onCalibrateNow: () {
                    // Solo cerrar el diálogo y retornar true
                    Navigator.of(dialogContext).pop(true);
                  },
                );
              },
            );

            // Si el usuario presionó "INICIAR CALIBRACIÓN"
            if (shouldCalibrate == true) {
              // Mostrar pantalla de calibración moderna
              await showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.black.withOpacity(0.9),
                builder: (calibrationContext) {
                  return Dialog(
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    child: Container(
                      height: MediaQuery.sizeOf(context).height * 0.95,
                      width: MediaQuery.sizeOf(context).width * 0.95,
                      child: ModernCalibrateCompassWidget(),
                    ),
                  );
                },
              );
            }

            return;
          } else {
            return;
          }
        }),
        // DESACTIVADO: getLocationList - ahora solo usa background_location_service
        // Future(() async {
        //   unawaited(
        //     () async {
        //       await actions.getLocationList(
        //         context,
        //       );
        //     }(),
        //   );
        // }),
      ]);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GPSQualityWrapper(
      child: Builder(
        builder: (context) => GestureDetector(
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
                  // Header moderno con efecto glassmorphism
                  Container(
                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo
                            Container(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  'assets/images/logo2_(1).png',
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        // Título "Módulos" con efecto brillante
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
                            'Módulos',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF00a86b).withOpacity(0.5),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Tarjeta de sincronización mejorada
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        context.pushNamed(
                          InformationPageWidget.routeName,
                          extra: <String, dynamic>{
                            kTransitionInfoKey: TransitionInfo(
                              hasTransition: true,
                              transitionType: PageTransitionType.bottomToTop,
                              duration: Duration(milliseconds: 1000),
                            ),
                          },
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            16.0, 16.0, 16.0, 16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: (FFAppState().visitsAdd.length > 0) ||
                                    (FFAppState().productsAdd.length > 0) ||
                                    (FFAppState().newsSelected.length > 0)
                                ? [
                                    FlutterFlowTheme.of(context).primary,
                                    FlutterFlowTheme.of(context)
                                        .primary
                                        .withOpacity(0.7),
                                  ]
                                : [
                                    FlutterFlowTheme.of(context).orange,
                                    FlutterFlowTheme.of(context)
                                        .orange
                                        .withOpacity(0.7),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 20,
                              color: ((FFAppState().visitsAdd.length > 0) ||
                                      (FFAppState().productsAdd.length > 0) ||
                                      (FFAppState().newsSelected.length > 0)
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).orange)
                                  .withOpacity(0.4),
                              offset: Offset(0, 8),
                              spreadRadius: 2,
                            )
                          ],
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sync_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Información y sincronización',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: TextStyle(fontFamily: 'Roboto',
                                            fontWeight: FontWeight.bold,
                                          ),
                                          color: Colors.white,
                                          fontSize: 16,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    (FFAppState().visitsAdd.length > 0) ||
                                            (FFAppState().productsAdd.length > 0)
                                        ? 'Hay información pendiente por sincronizar'
                                        : 'Sin información pendiente por sincronizar',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: TextStyle(fontFamily: 'Roboto',
                                            fontWeight: FontWeight.w500,
                                          ),
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Grid de módulos con scroll
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 16.0),
                      child: Column(
                        children: [
                          // Fila 1: Polinización y Cosecha
                          _buildModuleRow(
                            context,
                            module1Title: 'Polinización',
                            module1Icon: 'assets/images/task-svgrepo-com.png',
                            module1OnTap: () async {
                              FFAppState().moduleSelected = 'POLINIZACION';
                              FFAppState().activitySelectedJSON = null;
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de polinización',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                            module2Title: 'Cosecha',
                            module2Icon: 'assets/images/box-time-svgrepo-com.png',
                            module2OnTap: () async {
                              FFAppState().moduleSelected = 'COSECHA';
                              FFAppState().activitySelectedJSON = null;
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de cosecha',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Fila 2: Sanidad y Mantenimiento
                          _buildModuleRow(
                            context,
                            module1Title: 'Sanidad',
                            module1Icon: 'assets/images/health-svgrepo-com.png',
                            module1OnTap: () async {
                              FFAppState().moduleSelected = 'SANIDAD';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de sanidad',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                            module2Title: 'Mantenimiento',
                            module2Icon:
                                'assets/images/designtools-svgrepo-com.png',
                            module2OnTap: () async {
                              FFAppState().moduleSelected = 'MANTENIMIENTO';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de mantenimiento',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Fila 3: CTC y Fertilización
                          _buildModuleRow(
                            context,
                            module1Title: 'CTC',
                            module1Icon: 'assets/images/glass-1-svgrepo-com.png',
                            module1OnTap: () async {
                              FFAppState().moduleSelected = 'CTC';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de CTC',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                            module2Title: 'Fertilización',
                            module2Icon: 'assets/images/blur-svgrepo-com.png',
                            module2OnTap: () async {
                              FFAppState().moduleSelected = 'FERTILIZACION';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de fertilización',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Fila 4: Vigilancia y Otros
                          _buildModuleRow(
                            context,
                            module1Title: 'Vigilancia',
                            module1Icon: 'assets/images/book-svgrepo-com.png',
                            module1OnTap: () async {
                              FFAppState().moduleSelected = 'VIGILANCIA';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de vigilancia',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                            module2Title: 'Otros',
                            module2Icon:
                                'assets/images/like-dislike-svgrepo-com.png',
                            module2OnTap: () async {
                              FFAppState().moduleSelected = 'OTRO';
                              safeSetState(() {});
                              context.pushNamed(
                                DoActivitiesPageWidget.routeName,
                                queryParameters: {
                                  'tittle': serializeParam(
                                    'Módulo de otros',
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.bottomToTop,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Fila 5: Instalación y Asistencia de personal
                          _buildModuleRow(
                            context,
                            module1Title: 'Instalación',
                            module1Icon: 'assets/images/bezier-svgrepo-com.png',
                            module1OnTap: () async {
                              unawaited(
                                () async {
                                  _model.sqliteValidate =
                                      await actions.validateDbSqlite(
                                    context,
                                  );
                                }(),
                              );

                              context.pushNamed(
                                HeadquartersInstallPageWidget.routeName,
                                extra: <String, dynamic>{
                                  kTransitionInfoKey: TransitionInfo(
                                    hasTransition: true,
                                    transitionType: PageTransitionType.fade,
                                    duration: Duration(milliseconds: 1000),
                                  ),
                                },
                              );

                              safeSetState(() {});
                            },
                            module2Title: 'Asistencia de personal',
                            module2Icon: 'assets/images/users.png',
                            module2OnTap: () async {
                              await showDialog(
                                context: context,
                                builder: (dialogContext) {
                                  return Dialog(
                                    elevation: 0,
                                    insetPadding: EdgeInsets.zero,
                                    backgroundColor: Colors.transparent,
                                    alignment: AlignmentDirectional(0.0, 0.0)
                                        .resolve(Directionality.of(context)),
                                    child: GestureDetector(
                                      onTap: () {
                                        FocusScope.of(dialogContext).unfocus();
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: InfoDialogWidget(
                                        info:
                                            'Este módulo se encuentra en mantenimiento, pronto estarán disponibles todas las funciones para ti!',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildModuleRow(
    BuildContext context, {
    required String module1Title,
    required String module1Icon,
    required VoidCallback module1OnTap,
    required String module2Title,
    required String module2Icon,
    required VoidCallback module2OnTap,
    Color? module1TextColor,
    Color? module2TextColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildModuleCard(
            context,
            title: module1Title,
            icon: module1Icon,
            onTap: module1OnTap,
            textColor: module1TextColor,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildModuleCard(
            context,
            title: module2Title,
            icon: module2Icon,
            onTap: module2OnTap,
            textColor: module2TextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String icon,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFF00a86b).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              color: Color(0xFF00a86b).withOpacity(0.2),
              offset: Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono con efecto glow
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          icon,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Texto del módulo
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: TextStyle(fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold,
                            ),
                            color: textColor ?? Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
