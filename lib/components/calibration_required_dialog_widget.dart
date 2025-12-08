import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'calibration_required_dialog_model.dart';
export 'calibration_required_dialog_model.dart';

/// Diálogo Moderno de Calibración Requerida
///
/// Interfaz elegante y moderna que indica al usuario que debe calibrar
/// los sensores de GPS y brújula antes de continuar
class CalibrationRequiredDialogWidget extends StatefulWidget {
  const CalibrationRequiredDialogWidget({
    super.key,
    required this.onCalibrateNow,
  });

  final VoidCallback onCalibrateNow;

  @override
  State<CalibrationRequiredDialogWidget> createState() =>
      _CalibrationRequiredDialogWidgetState();
}

class _CalibrationRequiredDialogWidgetState
    extends State<CalibrationRequiredDialogWidget>
    with TickerProviderStateMixin {
  late CalibrationRequiredDialogModel _model;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalibrationRequiredDialogModel());

    // Animación de pulso para el ícono
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFFA726).withOpacity(0.5),
              blurRadius: 60,
              spreadRadius: 10,
              offset: Offset(0, 25),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1F2937).withOpacity(0.98),
                    Color(0xFF111827).withOpacity(0.98),
                    Color(0xFF0F172A).withOpacity(0.98),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Color(0xFFFFA726).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header decorativo brillante naranja
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Color(0xFFFFA726),
                            Color(0xFFFF9800),
                            Color(0xFFFFA726),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                    ),

                    SizedBox(height: 36),

                    // Ícono principal animado
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Círculo exterior pulsante naranja
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFFFFA726).withOpacity(0.4),
                                  Color(0xFFFFA726).withOpacity(0.15),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                          // Círculo medio con borde brillante
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFA726).withOpacity(0.35),
                                  Color(0xFFFF9800).withOpacity(0.2),
                                ],
                              ),
                              border: Border.all(
                                color: Color(0xFFFFA726).withOpacity(0.6),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFFA726).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.sensors_rounded,
                              size: 56,
                              color: Color(0xFFFFA726),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 28),

                    // Título principal
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: ShaderMask(
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
                          'Calibración Requerida',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    // Subtítulo
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Sensores GPS y Brújula',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFA726).withOpacity(0.8),
                          letterSpacing: 1.2,
                          height: 1.3,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Mensaje principal
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Se detectó que la brújula y el GPS no están correctamente calibrados.\n\nPara poder realizar visitas de forma precisa, es necesario seguir el proceso de calibración.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.3,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 28),

                    // Características de la calibración
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          _buildFeatureItem(
                            icon: Icons.my_location_rounded,
                            title: 'GPS de Alta Precisión',
                            description: 'Localización exacta para registros',
                          ),
                          SizedBox(height: 14),
                          _buildFeatureItem(
                            icon: Icons.explore_rounded,
                            title: 'Brújula Magnética',
                            description: 'Orientación precisa del dispositivo',
                          ),
                          SizedBox(height: 14),
                          _buildFeatureItem(
                            icon: Icons.timer_rounded,
                            title: 'Calibración Rápida',
                            description: 'Solo 40 segundos de proceso',
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Botón de calibrar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: InkWell(
                        onTap: () {
                          widget.onCalibrateNow();
                        },
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFA726),
                                Color(0xFFFF9800),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFA726).withOpacity(0.5),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
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
                                  style: TextStyle(fontFamily: 'Roboto',
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
                      ),
                    ),

                    SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Color(0xFFFFA726).withOpacity(0.3),
                Color(0xFFFFA726).withOpacity(0.15),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Color(0xFFFFA726).withOpacity(0.5),
              width: 1.8,
            ),
          ),
          child: Icon(
            icon,
            color: Color(0xFFFFA726),
            size: 22,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.2,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
