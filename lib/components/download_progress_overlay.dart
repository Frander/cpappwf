import 'dart:async';
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/map_download_service.dart';

/// Overlay global para mostrar progreso de descarga de mapas
/// Se puede mostrar en cualquier pantalla y permite navegación libre
class DownloadProgressOverlay extends StatefulWidget {
  const DownloadProgressOverlay({super.key});

  @override
  State<DownloadProgressOverlay> createState() => _DownloadProgressOverlayState();

  /// Mostrar el overlay de descarga
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void show(BuildContext context) {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => const DownloadProgressOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  static bool get isShowing => _isShowing;
}

class _DownloadProgressOverlayState extends State<DownloadProgressOverlay>
    with SingleTickerProviderStateMixin {
  final MapDownloadService _downloadService = MapDownloadService();
  StreamSubscription<MapDownloadState>? _subscription;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isExpanded = false;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    _subscription = _downloadService.stateStream.listen((state) {
      if (mounted) {
        setState(() {});

        // Auto-cerrar cuando complete
        if (state.isComplete) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _animationController.reverse().then((_) {
                DownloadProgressOverlay.hide();
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: _isMinimized ? _buildMinimizedView() : _buildExpandedView(),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedView() {
    final progress = _downloadService.progress;

    return GestureDetector(
      onTap: () => setState(() => _isMinimized = false),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FlutterFlowTheme.of(context).primary,
              FlutterFlowTheme.of(context).secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: FlutterFlowTheme.of(context).primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Descargando mapa...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.expand_less, color: Colors.white),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    final service = _downloadService;
    final isComplete = service.isComplete;
    final hasError = service.hasError;
    final isPaused = service.isPaused;
    final progress = service.progress;

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [
                        FlutterFlowTheme.of(context).success,
                        FlutterFlowTheme.of(context).success.withOpacity(0.8),
                      ]
                    : hasError
                        ? [
                            FlutterFlowTheme.of(context).error,
                            FlutterFlowTheme.of(context).error.withOpacity(0.8),
                          ]
                        : [
                            FlutterFlowTheme.of(context).primary,
                            FlutterFlowTheme.of(context).secondary,
                          ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.check_circle_rounded
                        : hasError
                            ? Icons.error_rounded
                            : Icons.map_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isComplete
                            ? 'Descarga Completa'
                            : hasError
                                ? 'Error en Descarga'
                                : isPaused
                                    ? 'Descarga Pausada'
                                    : 'Descargando Mapa',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Colombia - PMTiles',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botones de control
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isComplete && !hasError)
                      IconButton(
                        onPressed: () => setState(() => _isMinimized = true),
                        icon: const Icon(Icons.expand_more, color: Colors.white),
                        tooltip: 'Minimizar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    IconButton(
                      onPressed: () {
                        if (!isComplete) {
                          service.cancelDownload();
                        }
                        _animationController.reverse().then((_) {
                          DownloadProgressOverlay.hide();
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Cerrar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!isComplete && !hasError) ...[
                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: FlutterFlowTheme.of(context).alternate,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPaused
                            ? FlutterFlowTheme.of(context).warning
                            : FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Estadísticas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Porcentaje y tamaño
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                          Text(
                            '${_formatBytes(service.downloadedBytes)} / ${_formatBytes(service.totalBytes)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),

                      // Velocidad y tiempo
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed,
                                size: 16,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                service.speed.isNotEmpty ? service.speed : '-- MB/s',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.timeRemaining.isNotEmpty
                                ? service.timeRemaining
                                : 'Calculando...',
                            style: TextStyle(
                              fontSize: 12,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            service.cancelDownload();
                            _animationController.reverse().then((_) {
                              DownloadProgressOverlay.hide();
                            });
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FlutterFlowTheme.of(context).error,
                            side: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (isPaused) {
                              service.resumeDownload();
                            } else {
                              service.pauseDownload();
                            }
                          },
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            size: 18,
                          ),
                          label: Text(isPaused ? 'Reanudar' : 'Pausar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlutterFlowTheme.of(context).primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Mensaje de completado
                if (isComplete) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: FlutterFlowTheme.of(context).success,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'El mapa se ha descargado correctamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatBytes(service.downloadedBytes),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ],

                // Mensaje de error
                if (hasError) ...[
                  Icon(
                    Icons.error_rounded,
                    size: 48,
                    color: FlutterFlowTheme.of(context).error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      service.startDownload();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
