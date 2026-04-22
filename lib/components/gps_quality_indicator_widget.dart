import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '/components/gps_stabilization_monitor_widget.dart';

/// Notifier global de calidad GPS.
/// - null  → calidad buena (error ≤ 10m) o GPS aún no estabilizado
/// - double → error actual en metros cuando la calidad es baja (> 10m)
/// Se actualiza en _MyAppState (main.dart) cada vez que llega un evento newLocation.
final ValueNotifier<double?> gpsLowQualityNotifier = ValueNotifier<double?>(null);

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

  // Estado de calidad baja post-estabilización
  double? _lowQualityError; // null = calidad OK, double = error actual malo
  int _consecutiveBadReadings = 0;
  int _consecutiveGoodReadings = 0;
  static const int _thresholdToShow = 3;  // lecturas malas consecutivas para mostrar
  static const int _thresholdToHide = 3;  // lecturas buenas consecutivas para ocultar
  static const double _qualityThreshold = 10.0; // metros

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
    // Escuchar calidad baja post-estabilización desde el notifier global
    gpsLowQualityNotifier.addListener(_onLowQualityChanged);
  }

  void _setupGpsProgressListener() {
    if (Platform.isWindows) return;
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

  void _onLowQualityChanged() {
    if (!mounted) return;
    final error = gpsLowQualityNotifier.value;
    setState(() {
      _lowQualityError = error;
    });
    if (error != null) {
      // Calidad baja detectada — mostrar/mantener visible el banner
      _hideTimer?.cancel();
      if (!_isVisible) {
        _isVisible = true;
        _currentIsStabilized = false;
        _animationController.forward();
      }
    } else if (_isVisible && _currentIsStabilized == false && _lowQualityError == null) {
      // Calidad recuperada — mostrar brevemente "recuperado" y ocultar
      _showSnackBar(isStabilized: true);
    }
  }

  @override
  void dispose() {
    gpsLowQualityNotifier.removeListener(_onLowQualityChanged);
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
    // Se cierra rápidamente (800ms) cuando se estabiliza para indicar éxito inmediato
    if (isStabilized) {
      _hideTimer = Timer(const Duration(milliseconds: 800), () {
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
    // En Windows no hay GPS real — siempre simulado como estabilizado
    if (Platform.isWindows) return const SizedBox.shrink();

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
    // ── Tercer estado: calidad GPS baja post-estabilización ──────────────────
    final lowQuality = _lowQualityError;
    if (lowQuality != null && isStabilized == false) {
      return _buildLowQualityContent(lowQuality);
    }

    // Colores según estado
    final backgroundColor = isStabilized
        ? const Color(0xFF00C853) // Verde cuando estabilizado
        : const Color(0xFF1A1A2E); // Oscuro cuando estabilizando

    final accentColor = isStabilized
        ? Colors.white
        : const Color(0xFFFFB84D); // Naranja mientras estabiliza

    final message = isStabilized ? 'GPS Estabilizado' : 'Estabilizando GPS...';
    final iconData = isStabilized ? Icons.check_circle_rounded : Icons.gps_fixed;

    return GestureDetector(
      onTap: () => GPSStabilizationMonitor.show(context),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        shadowColor: isStabilized
            ? const Color(0xFF00C853).withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isStabilized
                  ? const Color(0xFF00E676).withValues(alpha: 0.5)
                  : accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: isStabilized ? Colors.white : Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                child: Text(message),
              ),
              if (!isStabilized && _currentAccuracy > 0) ...[
                const SizedBox(width: 12),
                _buildAccuracyBadge(_currentAccuracy),
              ],
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
      ),
    );
  }

  Widget _buildLowQualityContent(double error) {
    final errorColor = _getAccuracyColor(error);
    return GestureDetector(
      onTap: () => GPSStabilizationMonitor.show(context),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.orange.withValues(alpha: 0.4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B00),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gps_not_fixed, color: Colors.orange, size: 22),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Calidad GPS baja — espere a que se estabilice',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Error en tiempo real — se actualiza cada 2s con el nuevo valor
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: errorColor.withValues(alpha: 0.7), width: 1),
                ),
                child: Text(
                  '±${error.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccuracyBadge(double accuracy) {
    final accuracyColor = _getAccuracyColor(accuracy);
    final accuracyText = '±${accuracy.toStringAsFixed(1)}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accuracyColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accuracyColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten, size: 14, color: accuracyColor),
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
