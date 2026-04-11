import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '/app_state.dart';

/// Monitor en tiempo real del proceso de estabilización GPS.
/// Muestra métricas detalladas: precisión, fase, lecturas válidas,
/// reintentos, historial de precisión, y más.
class GPSStabilizationMonitor extends StatefulWidget {
  const GPSStabilizationMonitor({super.key});

  /// Abre el monitor como un bottom sheet modal.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const GPSStabilizationMonitor(),
    );
  }

  @override
  State<GPSStabilizationMonitor> createState() =>
      _GPSStabilizationMonitorState();
}

class _GPSStabilizationMonitorState extends State<GPSStabilizationMonitor>
    with SingleTickerProviderStateMixin {
  // Suscripciones a eventos del servicio de background
  StreamSubscription<Map<String, dynamic>?>? _progressSub;
  StreamSubscription<Map<String, dynamic>?>? _restartingSub;
  StreamSubscription<Map<String, dynamic>?>? _stabilizedSub;

  // Estado actual del GPS
  double _accuracy = 0.0;
  double _bestAccuracy = double.infinity;
  int _goodReadings = 0;
  int _requiredGoodReadings = 3;
  int _elapsed = 0;
  int _restartAttempts = 0;
  int _maxRestartAttempts = 3;
  double _speed = 0.0;
  int _consecutiveRejects = 0;
  int _updateCount = 0;
  String _phase = 'warmup';
  bool _isStabilized = false;
  bool _forcedStabilization = false;
  int _warmupSeconds = 10;
  int _stabilizationSeconds = 3;
  int _maxStabilizationSeconds = 15;

  // Historial de precisión
  final List<_AccuracyReading> _history = [];
  static const int _maxHistorySize = 25;

  // Animación de pulso
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isStabilized = FFAppState().isStabilized;
    if (_isStabilized) _phase = 'stable';
    _setupListeners();
    _setupAnimation();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (!_isStabilized) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _setupListeners() {
    if (Platform.isWindows) return; // Background service no disponible en Windows
    final service = FlutterBackgroundService();

    _progressSub = service.on('gpsProgress').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _accuracy = (event['accuracy'] as num?)?.toDouble() ?? 0.0;
          _bestAccuracy =
              (event['bestAccuracy'] as num?)?.toDouble() ?? _bestAccuracy;
          _goodReadings = (event['goodReadings'] as int?) ?? 0;
          _requiredGoodReadings =
              (event['requiredGoodReadings'] as int?) ?? 3;
          _elapsed = (event['elapsed'] as int?) ?? 0;
          _restartAttempts = (event['restartAttempts'] as int?) ?? 0;
          _maxRestartAttempts = (event['maxRestartAttempts'] as int?) ?? 3;
          _speed = (event['speed'] as num?)?.toDouble() ?? 0.0;
          _consecutiveRejects = (event['consecutiveRejects'] as int?) ?? 0;
          _updateCount = (event['updateCount'] as int?) ?? 0;
          _phase = (event['phase'] as String?) ?? _phase;
          _warmupSeconds = (event['warmupSeconds'] as int?) ?? 10;
          _stabilizationSeconds =
              (event['stabilizationSeconds'] as int?) ?? 3;
          _maxStabilizationSeconds =
              (event['maxStabilizationSeconds'] as int?) ?? 15;

          // Agregar al historial
          if (_accuracy > 0) {
            _history.add(_AccuracyReading(DateTime.now(), _accuracy));
            if (_history.length > _maxHistorySize) {
              _history.removeAt(0);
            }
          }
        });
      }
    });

    _restartingSub = service.on('gpsRestarting').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _phase = 'restarting';
          _restartAttempts = (event['attempt'] as int?) ?? _restartAttempts;
          _bestAccuracy =
              (event['bestAccuracy'] as num?)?.toDouble() ?? _bestAccuracy;
        });
      }
    });

    _stabilizedSub = service.on('gpsStabilized').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isStabilized = true;
          _phase = 'stable';
          _forcedStabilization = (event['forced'] as bool?) ?? false;
          _pulseController.stop();
          _pulseController.value = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _restartingSub?.cancel();
    _stabilizedSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Helpers de color ---

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 5) return const Color(0xFF00C853);
    if (accuracy <= 10) return const Color(0xFF64DD17);
    if (accuracy <= 15) return const Color(0xFFFFEB3B);
    if (accuracy <= 25) return const Color(0xFFFF9800);
    return const Color(0xFFFF5722);
  }

  Color _getPhaseColor() {
    switch (_phase) {
      case 'warmup':
        return const Color(0xFFFF9800);
      case 'stabilizing':
        return const Color(0xFF42A5F5);
      case 'restarting':
        return const Color(0xFFFF5722);
      case 'stable':
        return const Color(0xFF00C853);
      default:
        return Colors.grey;
    }
  }

  IconData _getPhaseIcon() {
    switch (_phase) {
      case 'warmup':
        return Icons.thermostat_rounded;
      case 'stabilizing':
        return Icons.gps_not_fixed_rounded;
      case 'restarting':
        return Icons.refresh_rounded;
      case 'stable':
        return Icons.gps_fixed_rounded;
      default:
        return Icons.gps_off_rounded;
    }
  }

  String _getPhaseDescription() {
    switch (_phase) {
      case 'warmup':
        return 'Descartando lecturas iniciales mientras los sensores calibran...';
      case 'stabilizing':
        return 'Buscando lecturas con precisión < 25m para confirmar estabilidad...';
      case 'restarting':
        return 'Reiniciando hardware GPS y probando proveedor alternativo...';
      case 'stable':
        return _forcedStabilization
            ? 'Estabilizado forzosamente tras agotar reintentos.'
            : 'GPS estabilizado con buena precisión.';
      default:
        return '';
    }
  }

  String _getAccuracyLabel(double accuracy) {
    if (accuracy <= 5) return 'Excelente';
    if (accuracy <= 10) return 'Muy Buena';
    if (accuracy <= 15) return 'Buena';
    if (accuracy <= 25) return 'Aceptable';
    return 'Pobre';
  }

  double _getOverallProgress() {
    if (_isStabilized) return 1.0;
    if (_phase == 'restarting') return 0.0;
    final totalRequired = _warmupSeconds + _stabilizationSeconds;
    if (totalRequired == 0) return 0.0;
    final timeProgress = (_elapsed / totalRequired).clamp(0.0, 1.0);
    final qualityProgress =
        _requiredGoodReadings > 0
            ? (_goodReadings / _requiredGoodReadings).clamp(0.0, 1.0)
            : 0.0;
    return (timeProgress * 0.5 + qualityProgress * 0.5);
  }

  // --- Build principal ---

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.93,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _buildDragHandle(),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPhaseStepper(),
              const SizedBox(height: 20),
              _buildAccuracyCircle(),
              const SizedBox(height: 20),
              _buildMetricsGrid(),
              const SizedBox(height: 20),
              _buildAccuracyHistory(),
            ],
          ),
        );
      },
    );
  }

  // --- Drag Handle ---

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // --- Header ---

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(_getPhaseIcon(), color: _getPhaseColor(), size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monitor GPS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getPhaseDescription(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Botón cerrar
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Phase Stepper ---

  Widget _buildPhaseStepper() {
    final phases = ['warmup', 'stabilizing', 'stable'];
    final labels = ['Calentamiento', 'Estabilización', 'Listo'];
    final icons = [
      Icons.thermostat_rounded,
      Icons.tune_rounded,
      Icons.check_circle_rounded,
    ];

    int currentIndex;
    if (_phase == 'restarting') {
      currentIndex = 0; // Restart goes back to warmup
    } else {
      currentIndex = phases.indexOf(_phase);
      if (currentIndex == -1) currentIndex = 0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPhaseColor().withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Stepper visual
          Row(
            children: List.generate(phases.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Conector entre pasos
                final stepBefore = i ~/ 2;
                final isCompleted = stepBefore < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF00C853)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }

              final stepIndex = i ~/ 2;
              final isActive = stepIndex == currentIndex;
              final isCompleted = stepIndex < currentIndex;
              final isRestarting = _phase == 'restarting' && stepIndex == 0;

              Color circleColor;
              if (isRestarting) {
                circleColor = const Color(0xFFFF5722);
              } else if (isCompleted) {
                circleColor = const Color(0xFF00C853);
              } else if (isActive) {
                circleColor = _getPhaseColor();
              } else {
                circleColor = Colors.white.withOpacity(0.15);
              }

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 40 : 32,
                    height: isActive ? 40 : 32,
                    decoration: BoxDecoration(
                      color: circleColor.withOpacity(isActive ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: circleColor,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : icons[stepIndex],
                      color: circleColor,
                      size: isActive ? 20 : 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isRestarting ? 'Reinicio' : labels[stepIndex],
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          // Barra de progreso general
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso general',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(_getOverallProgress() * 100).toInt()}%',
                    style: TextStyle(
                      color: _getPhaseColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _getOverallProgress(),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_getPhaseColor()),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          // Restart badge
          if (_restartAttempts > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF5722).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Color(0xFFFF5722), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reinicio $_restartAttempts/$_maxRestartAttempts'
                      ' — Probando proveedor alternativo',
                      style: const TextStyle(
                        color: Color(0xFFFF5722),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Círculo de Precisión ---

  Widget _buildAccuracyCircle() {
    final color = _accuracy > 0
        ? _getAccuracyColor(_accuracy)
        : Colors.white.withOpacity(0.2);
    final label =
        _accuracy > 0 ? _getAccuracyLabel(_accuracy) : 'Sin datos';
    final displayAccuracy =
        _accuracy > 0 ? '±${_accuracy.toStringAsFixed(1)}m' : '---';

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _isStabilized ? 1.0 : _pulseAnimation.value;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.08),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isStabilized
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                displayAccuracy,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Grid de Métricas ---

  Widget _buildMetricsGrid() {
    final bestAccDisplay = _bestAccuracy.isFinite
        ? '±${_bestAccuracy.toStringAsFixed(1)}m'
        : '---';
    final bestAccColor = _bestAccuracy.isFinite
        ? _getAccuracyColor(_bestAccuracy)
        : Colors.white.withOpacity(0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÉTRICAS EN TIEMPO REAL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        // Fila 1
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.star_rounded,
                label: 'Mejor Precisión',
                value: bestAccDisplay,
                color: bestAccColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.checklist_rounded,
                label: 'Lecturas Válidas',
                value: '$_goodReadings/$_requiredGoodReadings',
                color: _goodReadings >= _requiredGoodReadings
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF9800),
                progress: _requiredGoodReadings > 0
                    ? (_goodReadings / _requiredGoodReadings).clamp(0.0, 1.0)
                    : 0.0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.timer_rounded,
                label: 'Tiempo',
                value: '${_elapsed}s',
                color: _elapsed > _maxStabilizationSeconds
                    ? const Color(0xFFFF5722)
                    : const Color(0xFF42A5F5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.speed_rounded,
                label: 'Velocidad',
                value: '${_speed.toStringAsFixed(1)} m/s',
                color: const Color(0xFF42A5F5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.cancel_rounded,
                label: 'Rechazadas',
                value: '$_consecutiveRejects',
                color: _consecutiveRejects > 2
                    ? const Color(0xFFFF5722)
                    : Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.satellite_alt_rounded,
                label: 'Lecturas GPS',
                value: '$_updateCount',
                color: Colors.white.withOpacity(0.6),
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
    required String value,
    required Color color,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Historial de Precisión ---

  Widget _buildAccuracyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HISTORIAL DE PRECISIÓN',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (_history.isNotEmpty)
              Text(
                '${_history.length} lecturas',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esperando lecturas GPS...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                // Mini gráfico de barras
                _buildAccuracyChart(),
                const Divider(
                    color: Color(0xFF21262D), height: 1, thickness: 1),
                // Lista de lecturas recientes
                _buildReadingsList(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAccuracyChart() {
    if (_history.isEmpty) return const SizedBox.shrink();

    final maxAcc =
        _history.map((r) => r.accuracy).reduce(max).clamp(10.0, 50.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _history.map((reading) {
          final ratio = (reading.accuracy / maxAcc).clamp(0.0, 1.0);
          final color = _getAccuracyColor(reading.accuracy);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: '±${reading.accuracy.toStringAsFixed(1)}m',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  height: max(4, 80 * ratio),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadingsList() {
    // Mostrar las últimas 8 lecturas (más recientes primero)
    final recentReadings = _history.reversed.take(8).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: recentReadings.map((reading) {
          final color = _getAccuracyColor(reading.accuracy);
          final timeStr =
              '${reading.time.hour.toString().padLeft(2, '0')}:'
              '${reading.time.minute.toString().padLeft(2, '0')}:'
              '${reading.time.second.toString().padLeft(2, '0')}';
          final isGood = reading.accuracy < 25.0;

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                // Indicador de color
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                // Precisión
                SizedBox(
                  width: 70,
                  child: Text(
                    '±${reading.accuracy.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                // Barra visual
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (reading.accuracy / 50).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Check/X
                Icon(
                  isGood ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: isGood
                      ? const Color(0xFF00C853).withOpacity(0.6)
                      : const Color(0xFFFF5722).withOpacity(0.6),
                  size: 14,
                ),
                const SizedBox(width: 8),
                // Hora
                Text(
                  timeStr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Estructura para almacenar una lectura de precisión con timestamp
class _AccuracyReading {
  final DateTime time;
  final double accuracy;

  _AccuracyReading(this.time, this.accuracy);
}
