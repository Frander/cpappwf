import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as Math;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'calculate_coordenates_component_model.dart';
export 'calculate_coordenates_component_model.dart';

class CalculateCoordenatesComponentWidget extends StatefulWidget {
  const CalculateCoordenatesComponentWidget({
    super.key,
    this.visitCreated,
  });

  final VisitsStruct? visitCreated;

  @override
  State<CalculateCoordenatesComponentWidget> createState() =>
      _CalculateCoordenatesComponentWidgetState();
}

class _CalculateCoordenatesComponentWidgetState
    extends State<CalculateCoordenatesComponentWidget> with TickerProviderStateMixin {
  late CalculateCoordenatesComponentModel _model;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalculateCoordenatesComponentModel());

    // Animación de pulso para el círculo exterior
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación para decoración
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(_rotationController);

    // Animación de escala para entrada
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _scaleController.forward();
      unawaited(
        () async {
          await actions.getLocationList(
            context,
          );
        }(),
      );
      _model.timerController.onStartTimer();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E27),
            Color(0xFF1A1F3A),
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                // Partículas de fondo animadas
                ...List.generate(15, (index) {
                  return AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      final angle = _rotationAnimation.value + (index * 0.4);
                      final radius = 150.0 + (index * 15);
                      return Positioned(
                        left: MediaQuery.of(context).size.width / 2 + radius * Math.cos(angle) - 4,
                        top: MediaQuery.of(context).size.height / 2 + radius * Math.sin(angle) - 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00FF7F).withOpacity(0.3 - (index * 0.015)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00FF7F).withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Contenido principal
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo con efecto de brillo
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFF00FF7F).withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo2_(1).png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

                      // Timer circular animado
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Círculo exterior decorativo
                                Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFF00FF7F).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),

                                // Círculo medio con glassmorphism
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(120),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF00FF7F).withOpacity(0.2),
                                            Color(0xFF00B4D8).withOpacity(0.1),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: FlutterFlowTimer(
                                          initialTime: _model.timerInitialTimeMs,
                                          getDisplayTime: (value) => StopWatchTimer.getDisplayTime(
                                            value,
                                            hours: false,
                                            minute: false,
                                            milliSecond: false,
                                          ),
                                          controller: _model.timerController,
                                          updateStateInterval: Duration(milliseconds: 1000),
                                          onChanged: (value, displayTime, shouldUpdate) {
                                            _model.timerMilliseconds = value;
                                            _model.timerValue = displayTime;
                                            if (shouldUpdate) safeSetState(() {});
                                          },
                                          onEnded: () async {
                var _shouldSetState = false;
                if (functions.jsonDynamicToString(getJsonField(
                      FFAppState().activitySelectedJSON,
                      r'''$.type_activity''',
                    )) ==
                    'FORMULARIO') {
                  _model.visitCreated = await actions.createVisit(
                    context,
                    0,
                    FFAppState().companyDefault.idCompany,
                    functions.dynamicToInt(getJsonField(
                      FFAppState().activitySelectedJSON,
                      r'''$.id_activity''',
                    )),
                    0,
                    0,
                    FFAppState().userSelected.idUser,
                    FFAppState().deviceDefault.idDevice,
                    functions.dynamicToInt(getJsonField(
                      FFAppState().activityStatusSelectedJSON,
                      r'''$.id_activity_status''',
                    )),
                    functions
                        .filterAndFormatGeoReads(
                            FFAppState().geoLocationsList.toList())
                        .toList(),
                    getCurrentTimestamp,
                    ' ',
                    FFAppState().visitDetails.toList(),
                  );
                  _shouldSetState = true;
                  _model.countVisits = await actions.getVisitsCount();
                  _shouldSetState = true;
                  FFAppState().visitCount = _model.countVisits!;
                  safeSetState(() {});
                  FFAppState().visitDetails = functions
                      .removeVisits(FFAppState().visitDetails.toList())
                      .toList()
                      .cast<VisitsDetailsStruct>();
                  safeSetState(() {});
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Visita registrada con éxito. Total visitas: ${FFAppState().visitCount.toString()}',
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                      ),
                      duration: Duration(milliseconds: 2000),
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                    ),
                  );

                  context.pushNamed(
                    DoVisitsFormPageWidget.routeName,
                    extra: <String, dynamic>{
                      kTransitionInfoKey: TransitionInfo(
                        hasTransition: true,
                        transitionType: PageTransitionType.fade,
                        duration: Duration(milliseconds: 500),
                      ),
                    },
                  );

                  if (_shouldSetState) safeSetState(() {});
                  return;
                } else {
                  _model.visitCreated2 = await actions.createVisit(
                    context,
                    0,
                    FFAppState().companyDefault.idCompany,
                    functions.dynamicToInt(getJsonField(
                      FFAppState().activitySelectedJSON,
                      r'''$.id_activity''',
                    )),
                    0,
                    0,
                    FFAppState().userSelected.idUser,
                    FFAppState().deviceDefault.idDevice,
                    functions.dynamicToInt(getJsonField(
                      FFAppState().activityStatusSelectedJSON,
                      r'''$.id_activity_status''',
                    )),
                    functions
                        .filterAndFormatGeoReads(
                            FFAppState().geoLocationsList.toList())
                        .toList(),
                    getCurrentTimestamp,
                    ' ',
                    FFAppState().visitDetails.toList(),
                  );
                  _shouldSetState = true;
                  _model.countVisits1 = await actions.getVisitsCount();
                  _shouldSetState = true;
                  FFAppState().visitCount = _model.countVisits1!;
                  safeSetState(() {});
                  FFAppState().visitDetails = [];
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Visita registrada con éxito. Total visitas: ${FFAppState().visitCount.toString()}',
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                      ),
                      duration: Duration(milliseconds: 2000),
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                    ),
                  );
                  Navigator.pop(context);
                  if (_shouldSetState) safeSetState(() {});
                  return;
                }

                if (_shouldSetState) safeSetState(() {});
              },
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF7F),
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: Color(0xFF00FF7F).withOpacity(0.5),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: Color(0xFF00FF7F),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Ícono GPS en el centro
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF00FF7F),
                                        Color(0xFF00B4D8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF00FF7F).withOpacity(0.6),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 50),

                      // Texto principal con efecto glassmorphism
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                            margin: EdgeInsets.symmetric(horizontal: 30),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.place_rounded,
                                      color: Color(0xFF00FF7F),
                                      size: 24,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Manténgase cerca',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Calculando ubicación exacta del dispositivo',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      // Indicador de progreso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final delay = index * 0.3;
                              final animation = (_pulseController.value + delay) % 1.0;
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 6),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00FF7F).withOpacity(animation),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00FF7F).withOpacity(animation * 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
