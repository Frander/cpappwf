import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

class GPSQualityIndicator extends StatefulWidget {
  const GPSQualityIndicator({super.key});

  @override
  State<GPSQualityIndicator> createState() => _GPSQualityIndicatorState();
}

class _GPSQualityIndicatorState extends State<GPSQualityIndicator>
    with SingleTickerProviderStateMixin {
  bool? _lastStabilizedState;
  bool _isVisible = false;
  Timer? _hideTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Más tiempo para ver la animación
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn, // Fade in rápido
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // Efecto bounce sutil
    ));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showNotification({required bool isGoodQuality}) {
    if (!mounted) return;

    setState(() {
      _isVisible = true;
    });

    _animationController.forward();

    // Cancelar timer anterior si existe
    _hideTimer?.cancel();

    // Si es buena calidad, ocultar después de 2 segundos (más rápido)
    if (isGoodQuality) {
      _hideTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _hideNotification();
        }
      });
    } else {
      // Si está estabilizando, mostrar por 4 segundos
      _hideTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) {
          _hideNotification();
        }
      });
    }
  }

  void _hideNotification() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FFAppState>(
      builder: (context, appState, _) {
        final currentStabilized = appState.isStabilized;

        // Detectar si debemos mostrar notificación
        bool shouldShowNotification = false;

        // CASO 1: Primera vez y está estabilizando (false) -> mostrar "Estabilizando GPS"
        if (_lastStabilizedState == null && !currentStabilized) {
          shouldShowNotification = true;
        }
        // CASO 2: Cambio de estado (de false a true o viceversa)
        else if (_lastStabilizedState != null && _lastStabilizedState != currentStabilized) {
          shouldShowNotification = true;
        }

        if (shouldShowNotification) {
          // Postponer la llamada a setState hasta después del build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showNotification(isGoodQuality: currentStabilized);
            }
          });
        }

        _lastStabilizedState = currentStabilized;

        if (!_isVisible) {
          return const SizedBox.shrink();
        }

        final isGoodQuality = currentStabilized;

        return Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -2.0), // Empieza 2x altura del widget arriba
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOutBack, // Efecto bounce sutil al final
              )),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildNotificationCard(isGoodQuality),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(bool isGoodQuality) {
    final accentColor = isGoodQuality
        ? const Color(0xFF00D9A5) // Verde neón sutil
        : const Color(0xFFFFB84D); // Naranja sutil

    final iconData = isGoodQuality ? Icons.check_circle_rounded : Icons.gps_fixed;

    final message = isGoodQuality ? 'GPS Listo' : 'Estabilizando GPS';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dot indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Texto del mensaje
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: 1,
                ),

                // Mini spinner solo si está estabilizando
                if (!isGoodQuality) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        accentColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 100)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  width: 3,
                  height: 12 - (index * 3.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
            onEnd: () {
              // Repetir la animación
              if (mounted) {
                setState(() {});
              }
            },
          ),
        );
      }),
    );
  }
}

/// Widget wrapper que debe envolver cualquier página donde quieras mostrar el indicador
class GPSQualityWrapper extends StatelessWidget {
  final Widget child;

  const GPSQualityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const GPSQualityIndicator(),
      ],
    );
  }
}
