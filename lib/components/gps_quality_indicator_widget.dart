import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';

class GPSQualityIndicator extends StatefulWidget {
  const GPSQualityIndicator({super.key});

  @override
  State<GPSQualityIndicator> createState() => _GPSQualityIndicatorState();
}

class _GPSQualityIndicatorState extends State<GPSQualityIndicator>
    with SingleTickerProviderStateMixin {
  bool? _lastStabilizedState;
  bool _isVisible = false;
  bool _currentIsStabilized = false;
  double _currentAccuracy = 0.0;
  Timer? _hideTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  StreamSubscription<Map<String, dynamic>?>? _gpsProgressSubscription;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0), // Viene desde abajo
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Escuchar eventos de progreso del GPS desde el servicio de background
    _setupGpsProgressListener();
  }

  void _setupGpsProgressListener() {
    final service = FlutterBackgroundService();
    _gpsProgressSubscription = service.on('gpsProgress').listen((event) {
      if (event != null && mounted) {
        final accuracy = (event['accuracy'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          _currentAccuracy = accuracy;
        });
      }
    });
  }

  @override
  void dispose() {
    _gpsProgressSubscription?.cancel();
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar({required bool isStabilized}) {
    if (!mounted) return;

    // Cancelar timer anterior si existe
    _hideTimer?.cancel();

    setState(() {
      _isVisible = true;
      _currentIsStabilized = isStabilized;
    });

    _animationController.forward();

    // Solo ocultar automáticamente si está estabilizado (GPS listo)
    if (isStabilized) {
      _hideTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _hideSnackBar();
        }
      });
    }
    // Si está estabilizando, permanece visible (sin timer)
  }

  void _hideSnackBar() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  // Obtener color según la precisión del GPS
  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 5) {
      return const Color(0xFF00C853); // Verde - Excelente
    } else if (accuracy <= 10) {
      return const Color(0xFF64DD17); // Verde claro - Muy bueno
    } else if (accuracy <= 15) {
      return const Color(0xFFFFEB3B); // Amarillo - Bueno
    } else if (accuracy <= 25) {
      return const Color(0xFFFF9800); // Naranja - Aceptable
    } else {
      return const Color(0xFFFF5722); // Rojo - Pobre
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FFAppState>(
      builder: (context, appState, _) {
        final currentStabilized = appState.isStabilized;

        // Detectar cambios de estado
        bool shouldShow = false;
        bool shouldUpdateState = false;

        // CASO 1: Primera vez y está estabilizando (false) -> mostrar SnackBar
        if (_lastStabilizedState == null && !currentStabilized) {
          shouldShow = true;
        }
        // CASO 2: Cambio de estado de true a false (vuelve a estabilizar)
        else if (_lastStabilizedState == true && !currentStabilized) {
          shouldShow = true;
        }
        // CASO 3: Cambio de estado de false a true (ya estabilizado)
        else if (_lastStabilizedState == false && currentStabilized) {
          shouldUpdateState = true;
        }

        if (shouldShow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnackBar(isStabilized: false);
            }
          });
        } else if (shouldUpdateState && _isVisible) {
          // Actualizar el estado del SnackBar actual a "estabilizado"
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showSnackBar(isStabilized: true);
            }
          });
        }

        _lastStabilizedState = currentStabilized;

        if (!_isVisible) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildSnackBarContent(_currentIsStabilized),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnackBarContent(bool isStabilized) {
    // Colores según estado
    final backgroundColor = isStabilized
        ? const Color(0xFF00C853) // Verde cuando estabilizado
        : const Color(0xFF1A1A2E); // Oscuro cuando estabilizando

    final accentColor = isStabilized
        ? Colors.white
        : const Color(0xFFFFB84D); // Naranja mientras estabiliza

    final message = isStabilized ? 'GPS Estabilizado' : 'Estabilizando GPS...';
    final iconData = isStabilized ? Icons.check_circle_rounded : Icons.gps_fixed;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      shadowColor: isStabilized
          ? const Color(0xFF00C853).withOpacity(0.4)
          : Colors.black.withOpacity(0.3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isStabilized
                ? const Color(0xFF00E676).withOpacity(0.5)
                : accentColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono con animación
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                iconData,
                key: ValueKey(isStabilized),
                color: isStabilized ? Colors.white : accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Texto del mensaje
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isStabilized ? Colors.white : Colors.white.withOpacity(0.95),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              child: Text(message),
            ),

            // Badge de precisión solo cuando está estabilizando
            if (!isStabilized && _currentAccuracy > 0) ...[
              const SizedBox(width: 12),
              _buildAccuracyBadge(),
            ],

            // Spinner solo cuando está estabilizando
            if (!isStabilized) ...[
              const SizedBox(width: 12),
              RepaintBoundary(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyBadge() {
    final accuracyColor = _getAccuracyColor(_currentAccuracy);
    final accuracyText = '±${_currentAccuracy.toStringAsFixed(1)}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accuracyColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accuracyColor.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.straighten,
            size: 14,
            color: accuracyColor,
          ),
          const SizedBox(width: 4),
          Text(
            accuracyText,
            style: TextStyle(
              color: accuracyColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
