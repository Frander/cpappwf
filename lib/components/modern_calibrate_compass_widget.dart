import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_timer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'modern_calibrate_compass_model.dart';
export 'modern_calibrate_compass_model.dart';

/// Pantalla Moderna de Calibración de Sensores
///
/// Interfaz completamente rediseñada con animaciones, gradientes modernos
/// y experiencia de usuario premium para calibración de GPS y brújula
class ModernCalibrateCompassWidget extends StatefulWidget {
  const ModernCalibrateCompassWidget({super.key});

  @override
  State<ModernCalibrateCompassWidget> createState() =>
      _ModernCalibrateCompassWidgetState();
}

class _ModernCalibrateCompassWidgetState
    extends State<ModernCalibrateCompassWidget> with TickerProviderStateMixin {
  late ModernCalibrateCompassModel _model;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModernCalibrateCompassModel());

    // Animación de rotación para el ícono de brújula
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCalibrating = _model.timerMilliseconds > 0 &&
                               _model.timerMilliseconds < _model.timerInitialTimeMs;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F2937),
            Color(0xFF111827),
            Color(0xFF0F172A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con título y subtítulo
              _buildHeader(),

              SizedBox(height: 36),

              // Indicador circular de progreso con GIF
              _buildProgressIndicator(isCalibrating),

              SizedBox(height: 32),

              // Timer grande
              _buildTimer(),

              SizedBox(height: 28),

              // Instrucciones
              _buildInstructions(isCalibrating),

              SizedBox(height: 32),

              // Botón de calibrar
              _buildCalibrateButton(isCalibrating),

              SizedBox(height: 24),

              // Características de calibración
              _buildFeatures(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Título con gradiente
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFA726),
                Color(0xFFFF9800),
              ],
            ).createShader(bounds);
          },
          child: Text(
            'Calibración de Sensores',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),

        SizedBox(height: 8),

        // Subtítulo
        Text(
          'GPS y Brújula Magnética',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFA726).withOpacity(0.8),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(bool isCalibrating) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Círculo decorativo exterior
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color(0xFFFFA726).withOpacity(0.3),
                Color(0xFFFFA726).withOpacity(0.1),
                Colors.transparent,
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Contenedor del GIF con borde
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Color(0xFFFFA726).withOpacity(0.4),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFA726).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/Calibrate_compass.gif',
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Ícono de brújula rotando (cuando está calibrando)
        if (isCalibrating)
          RotationTransition(
            turns: _rotationAnimation,
            child: Icon(
              Icons.explore_rounded,
              size: 80,
              color: Color(0xFFFFA726).withOpacity(0.3),
            ),
          ),
      ],
    );
  }

  Widget _buildTimer() {
    return FlutterFlowTimer(
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
        FFAppState().calibrateCompass = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  '¡Sensores calibrados con éxito!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            duration: Duration(milliseconds: 3000),
            backgroundColor: Color(0xFF00a86b),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      },
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 72,
        fontWeight: FontWeight.w900,
        color: _model.timerMilliseconds > 0 && _model.timerMilliseconds < _model.timerInitialTimeMs
            ? Color(0xFFFFA726)
            : Colors.white.withOpacity(0.4),
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: Color(0xFFFFA726).withOpacity(0.5),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(bool isCalibrating) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFFFA726).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCalibrating ? Icons.settings_suggest_rounded : Icons.info_outline_rounded,
                  color: Color(0xFFFFA726),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  isCalibrating ? 'Calibrando sensores...' : '¿Cómo calibrar?',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            isCalibrating
                ? 'Mueva el dispositivo siguiendo el patrón del número 8 como se muestra en la imagen. Mantenga el movimiento continuo durante toda la calibración.'
                : 'Presione "INICIAR CALIBRACIÓN" y luego realice movimientos en forma de número 8 con el dispositivo durante 40 segundos, tal como se muestra en la imagen.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.3,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrateButton(bool isCalibrating) {
    return InkWell(
      onTap: isCalibrating
          ? null
          : () async {
              await Future.wait([
                Future(() async {
                  unawaited(
                    () async {
                      _model.calibrateCompass = await actions.calibrateCompass();
                    }(),
                  );
                }),
                Future(() async {
                  _model.timerController.onStartTimer();
                }),
                Future(() async {
                  unawaited(
                    () async {
                      _model.calibrateGPS = await actions.calibrateGPS();
                    }(),
                  );
                }),
              ]);
              safeSetState(() {});
            },
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: isCalibrating
              ? LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.4),
                    Colors.grey.withOpacity(0.3),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFA726),
                    Color(0xFFFF9800),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isCalibrating
              ? []
              : [
                  BoxShadow(
                    color: Color(0xFFFFA726).withOpacity(0.5),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Center(
          child: isCalibrating
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'CALIBRANDO...',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'INICIAR CALIBRACIÓN',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00a86b).withOpacity(0.1),
            Color(0xFF00a86b).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF00a86b).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFeatureItem(Icons.gps_fixed_rounded, 'GPS\nPreciso'),
          _buildFeatureItem(Icons.explore_rounded, 'Brújula\nMagnética'),
          _buildFeatureItem(Icons.timer_rounded, '40 seg\nCalibración'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
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
            icon,
            color: Color(0xFF00ff9f),
            size: 28,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.3,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
