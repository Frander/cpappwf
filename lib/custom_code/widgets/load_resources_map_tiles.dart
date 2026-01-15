// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';
import '/services/map_download_service.dart';
import '/components/download_progress_overlay.dart';

/// Widget para gestionar la descarga de mapas PMTiles
/// Ahora permite navegación libre mientras la descarga continúa en segundo plano
class LoadResourcesMapTiles extends StatefulWidget {
  const LoadResourcesMapTiles({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<LoadResourcesMapTiles> createState() => _LoadResourcesMapTilesState();
}

class _LoadResourcesMapTilesState extends State<LoadResourcesMapTiles>
    with SingleTickerProviderStateMixin {
  final MapDownloadService _downloadService = MapDownloadService();
  StreamSubscription<MapDownloadState>? _subscription;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  bool _isChecking = true;
  bool _mapExists = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _checkMapStatus();

    // Escuchar cambios del servicio
    _subscription = _downloadService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _mapExists = state.isComplete;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkMapStatus() async {
    final exists = await _downloadService.checkExistingFile();
    if (mounted) {
      setState(() {
        _isChecking = false;
        _mapExists = exists;
      });
    }
  }

  void _startBackgroundDownload() {
    // Iniciar descarga en segundo plano
    _downloadService.startDownload();

    // Mostrar overlay de progreso
    DownloadProgressOverlay.show(context);

    // Navegar hacia atrás para permitir al usuario usar la app
    Navigator.pop(context);
  }

  /// Elimina el archivo PMTiles descargado y permite volver a descargarlo
  Future<void> _deleteAndRedownload() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: FlutterFlowTheme.of(context).warning, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Eliminar Mapa',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar el mapa descargado?\n\nEsto liberará espacio en tu dispositivo y tendrás que volver a descargarlo para usar el mapa offline.',
          style: TextStyle(
            color: FlutterFlowTheme.of(context).secondaryText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isChecking = true);

    try {
      // Obtener la ruta del archivo
      final filePath = _downloadService.filePath;

      if (filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Archivo PMTiles eliminado: $filePath');
        }

        // También eliminar archivo parcial si existe
        final partialFile = File('$filePath.partial');
        if (await partialFile.exists()) {
          await partialFile.delete();
          debugPrint('🗑️ Archivo parcial eliminado');
        }
      }

      // Limpiar estado del servicio
      _downloadService.resetState();

      // Limpiar AppState
      FFAppState().update(() {
        FFAppState().pathPmtiles = '';
      });

      if (mounted) {
        setState(() {
          _isChecking = false;
          _mapExists = false;
        });

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Mapa eliminado correctamente'),
              ],
            ),
            backgroundColor: FlutterFlowTheme.of(context).success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error eliminando archivo: $e');

      if (mounted) {
        setState(() => _isChecking = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al eliminar: $e')),
              ],
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            FlutterFlowTheme.of(context).alternate,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isChecking
                  ? _buildLoadingScreen()
                  : _mapExists
                      ? _buildCompleteScreen()
                      : _downloadService.isDownloading
                          ? _buildDownloadingScreen()
                          : _buildReadyScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.map_rounded,
              color: FlutterFlowTheme.of(context).info,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mapa Offline',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Colombia - PMTiles',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: FlutterFlowTheme.of(context).info),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Verificando mapa...',
            style: TextStyle(
              fontSize: 16,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono principal
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cloud_download_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 70,
                ),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Listo para Descargar',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Descarga el mapa de Colombia para usar sin conexión.\nPuedes seguir usando la app mientras se descarga.',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Información del archivo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.insert_drive_file_rounded, 'Archivo', 'colombia.pmtiles'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.storage_rounded, 'Tamaño aprox.', '~200 MB'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.map_rounded, 'Región', 'Colombia'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.wifi_rounded, 'Recomendado', 'WiFi'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Nota sobre descarga en segundo plano
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).accent1.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La descarga continuará en segundo plano. Puedes navegar libremente por la app.',
                      style: TextStyle(
                        fontSize: 13,
                        color: FlutterFlowTheme.of(context).primaryText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botón de descarga
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _startBackgroundDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: FlutterFlowTheme.of(context).info,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Iniciar Descarga',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).info,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de descarga
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _downloadService.progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  Text(
                    '${(_downloadService.progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Descargando en Segundo Plano',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Puedes cerrar esta pantalla y seguir usando la app.\nEl progreso se mostrará en la barra inferior.',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Estadísticas
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Descargado',
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                      Text(
                        '${_formatBytes(_downloadService.downloadedBytes)} / ${_formatBytes(_downloadService.totalBytes)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Velocidad',
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                      Text(
                        _downloadService.speed.isNotEmpty ? _downloadService.speed : '--',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiempo restante',
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                      Text(
                        _downloadService.timeRemaining.isNotEmpty
                            ? _downloadService.timeRemaining
                            : 'Calculando...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botón para ver el overlay
            OutlinedButton.icon(
              onPressed: () {
                DownloadProgressOverlay.show(context);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver y Ver Progreso'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlutterFlowTheme.of(context).primary,
                side: BorderSide(color: FlutterFlowTheme.of(context).primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).success,
                    FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: FlutterFlowTheme.of(context).info,
                size: 70,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Mapa Descargado',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'El mapa de Colombia está listo para usar sin conexión',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              _formatBytes(_downloadService.totalBytes),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),

            const SizedBox(height: 40),

            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón para eliminar y volver a descargar
            Container(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteAndRedownload,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: FlutterFlowTheme.of(context).error,
                  size: 20,
                ),
                label: Text(
                  'Eliminar y Volver a Descargar',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: FlutterFlowTheme.of(context).error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Texto explicativo
            Text(
              'Usa esta opción si el mapa no carga correctamente',
              style: TextStyle(
                fontSize: 12,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: FlutterFlowTheme.of(context).primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
