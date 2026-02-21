import 'dart:async';
import 'dart:io';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de diálogo moderno para reintentos de conexión a internet
/// Muestra el progreso de reintentos y permite cerrar la app si falla
class ConnectionRetryDialogWidget extends StatefulWidget {
  const ConnectionRetryDialogWidget({
    super.key,
    required this.onConnectionSuccess,
    required this.checkConnectionCallback,
    this.maxRetryDuration = const Duration(minutes: 5),
    this.retryInterval = const Duration(seconds: 10),
  });

  /// Callback cuando la conexión es exitosa
  final VoidCallback onConnectionSuccess;

  /// Función que verifica la conexión y retorna true si hay internet
  final Future<bool> Function() checkConnectionCallback;

  /// Duración máxima de reintentos (default: 5 minutos)
  final Duration maxRetryDuration;

  /// Intervalo entre reintentos (default: 10 segundos)
  final Duration retryInterval;

  @override
  State<ConnectionRetryDialogWidget> createState() =>
      _ConnectionRetryDialogWidgetState();
}

class _ConnectionRetryDialogWidgetState
    extends State<ConnectionRetryDialogWidget> with TickerProviderStateMixin {
  Timer? _retryTimer;
  Timer? _countdownTimer;
  DateTime? _startTime;
  int _retryCount = 0;
  int _remainingSeconds = 0;
  bool _isChecking = false;
  bool _hasFailed = false;
  String _statusMessage = 'Verificando conexión a internet...';

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
    _startRetryProcess();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startRetryProcess() {
    _startTime = DateTime.now();
    _remainingSeconds = widget.maxRetryDuration.inSeconds;
    _checkConnection();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_startTime!);
      final remaining = widget.maxRetryDuration - elapsed;

      if (remaining.isNegative || remaining == Duration.zero) {
        timer.cancel();
        _onMaxTimeReached();
      } else {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }
    });
  }

  Future<void> _checkConnection() async {
    if (!mounted || _hasFailed) return;

    setState(() {
      _isChecking = true;
      _statusMessage = 'Verificando conexión...';
    });

    try {
      final hasConnection = await widget.checkConnectionCallback();

      if (!mounted) return;

      if (hasConnection) {
        _retryTimer?.cancel();
        _countdownTimer?.cancel();
        widget.onConnectionSuccess();
      } else {
        _retryCount++;
        setState(() {
          _isChecking = false;
          _statusMessage = 'Sin conexión. Reintentando...';
        });
        _scheduleNextRetry();
      }
    } catch (e) {
      if (!mounted) return;
      _retryCount++;
      setState(() {
        _isChecking = false;
        _statusMessage = 'Error de conexión. Reintentando...';
      });
      _scheduleNextRetry();
    }
  }

  void _scheduleNextRetry() {
    if (_hasFailed) return;

    _retryTimer = Timer(widget.retryInterval, () {
      if (mounted && !_hasFailed) {
        _checkConnection();
      }
    });
  }

  void _onMaxTimeReached() {
    if (!mounted) return;

    _retryTimer?.cancel();
    setState(() {
      _hasFailed = true;
      _statusMessage = 'No se pudo establecer conexión';
    });
  }

  void _closeApp() {
    // Cerrar la aplicación
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  void _retryManually() {
    setState(() {
      _hasFailed = false;
      _retryCount = 0;
    });
    _startRetryProcess();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A237E).withValues(alpha: 0.95),
              const Color(0xFF0D47A1).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono animado
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasFailed
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: _hasFailed
                            ? Colors.red.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _hasFailed
                          ? Icons.wifi_off_rounded
                          : _isChecking
                              ? Icons.wifi_find_rounded
                              : Icons.wifi_rounded,
                      size: 60,
                      color: _hasFailed ? Colors.red[300] : Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Título
                Text(
                  _hasFailed
                      ? 'Conexión Fallida'
                      : 'Verificando Conexión',
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                    ),
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Mensaje de estado
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                    font: const TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w400,
                    ),
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 32),

                if (!_hasFailed) ...[
                  // Contador de tiempo restante
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Tiempo restante',
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w400,
                            ),
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: FlutterFlowTheme.of(context).displaySmall.override(
                            font: const TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontWeight: FontWeight.bold,
                            ),
                            color: Colors.white,
                            fontSize: 42,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contador de reintentos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Intento #$_retryCount',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: const TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w500,
                          ),
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _isChecking ? null : 1.0,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.5),
                      ),
                      minHeight: 4,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Indicaciones
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTip(Icons.wifi_rounded, 'Verifica que el WiFi esté activado'),
                        const SizedBox(height: 8),
                        _buildTip(Icons.signal_cellular_alt_rounded, 'O activa los datos móviles'),
                        const SizedBox(height: 8),
                        _buildTip(Icons.location_on_rounded, 'Asegúrate de tener buena señal'),
                      ],
                    ),
                  ),
                ] else ...[
                  // Estado de fallo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red[300],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No fue posible conectar a internet después de $_retryCount intentos durante 5 minutos.',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w400,
                            ),
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'La aplicación requiere conexión a internet para iniciar por primera vez.',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: const TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w400,
                            ),
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: _retryManually,
                          text: 'Reintentar',
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          options: FFButtonOptions(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            color: Colors.white.withValues(alpha: 0.2),
                            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                              font: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            elevation: 0,
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: _closeApp,
                          text: 'Cerrar App',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          options: FFButtonOptions(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            color: Colors.red.withValues(alpha: 0.8),
                            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                              font: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            elevation: 0,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: FlutterFlowTheme.of(context).bodySmall.override(
              font: const TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
              ),
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
