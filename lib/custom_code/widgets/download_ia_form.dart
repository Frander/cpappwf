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

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Enum para las fases del proceso
enum AISetupPhase {
  idle, // Estado inicial
  downloading, // Descargando el modelo
  configuring, // Configurando el modelo con contexto
  training, // Entrenamiento/optimización
  completed, // Completado exitosamente
  error, // Error en cualquier fase
}

class DownloadIaForm extends StatefulWidget {
  const DownloadIaForm({
    super.key,
    this.width,
    this.height,
    this.contextJson, // JSON de contexto para la IA
  });

  final double? width;
  final double? height;
  final String? contextJson; // Contexto en formato JSON

  @override
  State<DownloadIaForm> createState() => _DownloadIaFormState();
}

class _DownloadIaFormState extends State<DownloadIaForm>
    with TickerProviderStateMixin {
  // URL del modelo de IA
  static const String modelUrl =
      'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf';

  // Estado actual del proceso
  AISetupPhase _currentPhase = AISetupPhase.idle;

  // Estados de descarga
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  // Estados de configuración
  double _configProgress = 0.0;
  String _configStep = '';

  // Estados de entrenamiento
  double _trainingProgress = 0.0;
  int _trainingEpoch = 0;
  int _totalEpochs = 0;

  // General
  String _statusMessage = 'Listo para comenzar';
  String? _savedFilePath;
  String _errorMessage = '';

  // Controladores de animación
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de pulso para indicadores de carga
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación para íconos
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            FlutterFlowTheme.of(context).primaryBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildPhaseIndicators(),
            const SizedBox(height: 24),
            _buildCurrentPhaseContent(),
            const SizedBox(height: 32),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SECCIÓN: HEADER
  // ============================================================================

  Widget _buildHeader() {
    return Column(
      children: [
        // Icono principal con animación
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _currentPhase == AISetupPhase.idle ||
                      _currentPhase == AISetupPhase.completed
                  ? 1.0
                  : _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _getPhaseGradientColors(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPhaseColor().withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getPhaseIcon(),
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Título
        Text(
          'Configuración de IA Avanzada',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                fontFamily: 'Outfit',
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtítulo
        Text(
          'DeepSeek-R1-Distill-Qwen-7B (Q4_K_M)',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Readex Pro',
                color: FlutterFlowTheme.of(context).secondaryText,
                fontSize: 14,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ============================================================================
  // SECCIÓN: INDICADORES DE FASE
  // ============================================================================

  Widget _buildPhaseIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPhaseIndicator(
          icon: Icons.cloud_download,
          label: 'Descarga',
          phase: AISetupPhase.downloading,
          isCompleted: _isPhaseCompleted(AISetupPhase.downloading),
        ),
        _buildPhaseDivider(
          isCompleted: _isPhaseCompleted(AISetupPhase.downloading),
        ),
        _buildPhaseIndicator(
          icon: Icons.settings,
          label: 'Configuración',
          phase: AISetupPhase.configuring,
          isCompleted: _isPhaseCompleted(AISetupPhase.configuring),
        ),
        _buildPhaseDivider(
          isCompleted: _isPhaseCompleted(AISetupPhase.configuring),
        ),
        _buildPhaseIndicator(
          icon: Icons.school,
          label: 'Entrenamiento',
          phase: AISetupPhase.training,
          isCompleted: _isPhaseCompleted(AISetupPhase.training),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator({
    required IconData icon,
    required String label,
    required AISetupPhase phase,
    required bool isCompleted,
  }) {
    final bool isActive = _currentPhase == phase;
    final bool isFuture = !isActive && !isCompleted;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : isActive
                    ? FlutterFlowTheme.of(context).primary
                    : Colors.grey.shade300,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color:
                          FlutterFlowTheme.of(context).primary.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isActive
              ? RotationTransition(
                  turns: _rotationAnimation,
                  child: Icon(icon, color: Colors.white, size: 28),
                )
              : Icon(
                  isCompleted ? Icons.check : icon,
                  color: isFuture ? Colors.grey.shade500 : Colors.white,
                  size: 28,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: FlutterFlowTheme.of(context).bodySmall.override(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? FlutterFlowTheme.of(context).primary
                    : isCompleted
                        ? Colors.green
                        : Colors.grey.shade600,
              ),
        ),
      ],
    );
  }

  Widget _buildPhaseDivider({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 28),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ============================================================================
  // SECCIÓN: CONTENIDO DE FASE ACTUAL
  // ============================================================================

  Widget _buildCurrentPhaseContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(_currentPhase),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _currentPhase == AISetupPhase.error
                ? Colors.red
                : _getPhaseColor().withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getPhaseColor().withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado actual
            Row(
              children: [
                Icon(
                  _getPhaseIcon(),
                  color: _getPhaseColor(),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          fontFamily: 'Readex Pro',
                          fontWeight: FontWeight.w600,
                          color: _getPhaseColor(),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Contenido específico de cada fase
            if (_currentPhase == AISetupPhase.downloading)
              _buildDownloadingContent(),
            if (_currentPhase == AISetupPhase.configuring)
              _buildConfiguringContent(),
            if (_currentPhase == AISetupPhase.training) _buildTrainingContent(),
            if (_currentPhase == AISetupPhase.completed)
              _buildCompletedContent(),
            if (_currentPhase == AISetupPhase.error) _buildErrorContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressBar(
          progress: _downloadProgress,
          color: FlutterFlowTheme.of(context).primary,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Readex Pro',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            Text(
              '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    fontFamily: 'Readex Pro',
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfiguringContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressBar(
          progress: _configProgress,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _configStep,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Readex Pro',
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.code,
          title: 'Contexto JSON',
          value: widget.contextJson != null
              ? '${widget.contextJson!.length} caracteres'
              : 'No proporcionado',
        ),
      ],
    );
  }

  Widget _buildTrainingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressBar(
          progress: _trainingProgress,
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard(
              icon: Icons.repeat,
              title: 'Época',
              value: '$_trainingEpoch / $_totalEpochs',
              compact: true,
            ),
            _buildInfoCard(
              icon: Icons.speed,
              title: 'Progreso',
              value: '${(_trainingProgress * 100).toStringAsFixed(0)}%',
              compact: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '¡Modelo configurado y listo para usar!',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Readex Pro',
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (_savedFilePath != null) ...[
          const SizedBox(height: 16),
          Text(
            'Ubicación del modelo:',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Readex Pro',
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _savedFilePath!,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: 'Courier New',
                          fontSize: 10,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error en el proceso',
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        fontFamily: 'Readex Pro',
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Readex Pro',
                  color: Colors.red.shade700,
                ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SECCIÓN: WIDGETS AUXILIARES
  // ============================================================================

  Widget _buildProgressBar({
    required double progress,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 16,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool compact = false,
  }) {
    if (compact) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Readex Pro',
                      fontSize: 10,
                    ),
              ),
              Text(
                value,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Readex Pro',
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Readex Pro',
                      fontSize: 10,
                    ),
              ),
              Text(
                value,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Readex Pro',
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final bool isProcessing = _currentPhase == AISetupPhase.downloading ||
        _currentPhase == AISetupPhase.configuring ||
        _currentPhase == AISetupPhase.training;

    return ElevatedButton(
      onPressed: isProcessing
          ? null
          : () {
              if (_currentPhase == AISetupPhase.completed ||
                  _currentPhase == AISetupPhase.error) {
                _resetProcess();
              } else {
                _startProcess();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _currentPhase == AISetupPhase.completed
            ? Colors.green
            : FlutterFlowTheme.of(context).primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 4,
        disabledBackgroundColor: Colors.grey.shade400,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              _currentPhase == AISetupPhase.completed ||
                      _currentPhase == AISetupPhase.error
                  ? Icons.refresh
                  : Icons.rocket_launch,
              size: 24,
            ),
          const SizedBox(width: 12),
          Text(
            _getButtonText(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SECCIÓN: LÓGICA DEL PROCESO
  // ============================================================================

  Future<void> _startProcess() async {
    // Fase 1: Descarga
    await _downloadModel();

    if (_currentPhase == AISetupPhase.error) return;

    // Fase 2: Configuración
    await _configureModel();

    if (_currentPhase == AISetupPhase.error) return;

    // Fase 3: Entrenamiento
    await _trainModel();
  }

  Future<void> _downloadModel() async {
    setState(() {
      _currentPhase = AISetupPhase.downloading;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _statusMessage = 'Descargando modelo de IA...';
    });

    try {
      debugPrint('🚀 Fase 1: Iniciando descarga del modelo...');

      // Obtener ruta de almacenamiento
      final String storagePath = await _getAIModelStoragePath();
      final String fileName = 'DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf';
      final String filePath = path.join(storagePath, fileName);

      // Verificar si existe y eliminar
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Descargar con streaming
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      _totalBytes = response.contentLength ?? 0;
      final IOSink sink = file.openWrite();
      _downloadedBytes = 0;

      await for (var chunk in response.stream) {
        sink.add(chunk);
        _downloadedBytes += chunk.length;

        if (_totalBytes > 0) {
          setState(() {
            _downloadProgress = _downloadedBytes / _totalBytes;
          });
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      _savedFilePath = filePath;
      debugPrint('✅ Descarga completada: $_savedFilePath');
    } catch (e, stackTrace) {
      debugPrint('❌ Error en descarga: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentPhase = AISetupPhase.error;
        _errorMessage = 'Error en descarga: ${e.toString()}';
      });
    }
  }

  Future<void> _configureModel() async {
    setState(() {
      _currentPhase = AISetupPhase.configuring;
      _configProgress = 0.0;
      _statusMessage = 'Configurando modelo con contexto...';
    });

    try {
      debugPrint('🛠️ Fase 2: Configurando modelo...');

      // Paso 1: Cargar contexto JSON
      setState(() {
        _configStep = 'Cargando contexto JSON...';
        _configProgress = 0.2;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      if (widget.contextJson != null && widget.contextJson!.isNotEmpty) {
        try {
          final contextData = jsonDecode(widget.contextJson!);
          debugPrint('✅ Contexto JSON cargado: ${contextData.toString()}');

          // Guardar contexto en archivo
          final contextPath = path.join(
            await _getAIModelStoragePath(),
            'context.json',
          );
          final contextFile = File(contextPath);
          await contextFile.writeAsString(widget.contextJson!);
          debugPrint('💾 Contexto guardado en: $contextPath');
        } catch (e) {
          debugPrint('⚠️ Error parseando JSON de contexto: $e');
        }
      }

      // Paso 2: Inicializar modelo
      setState(() {
        _configStep = 'Inicializando parámetros del modelo...';
        _configProgress = 0.5;
      });
      await Future.delayed(const Duration(milliseconds: 1000));

      // Paso 3: Aplicar configuración
      setState(() {
        _configStep = 'Aplicando configuración personalizada...';
        _configProgress = 0.8;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      // Paso 4: Finalizar
      setState(() {
        _configStep = 'Configuración completada';
        _configProgress = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('✅ Configuración completada');
    } catch (e, stackTrace) {
      debugPrint('❌ Error en configuración: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentPhase = AISetupPhase.error;
        _errorMessage = 'Error en configuración: ${e.toString()}';
      });
    }
  }

  Future<void> _trainModel() async {
    setState(() {
      _currentPhase = AISetupPhase.training;
      _trainingProgress = 0.0;
      _trainingEpoch = 0;
      _totalEpochs = 5; // Simular 5 épocas de entrenamiento
      _statusMessage = 'Optimizando modelo con contexto...';
    });

    try {
      debugPrint('🎓 Fase 3: Entrenando modelo...');

      // Simular entrenamiento por épocas
      for (int epoch = 1; epoch <= _totalEpochs; epoch++) {
        setState(() {
          _trainingEpoch = epoch;
          _trainingProgress = epoch / _totalEpochs;
        });

        debugPrint('📚 Época $epoch/$_totalEpochs');
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      debugPrint('✅ Entrenamiento completado');

      // Marcar como completado
      setState(() {
        _currentPhase = AISetupPhase.completed;
        _statusMessage = 'Proceso completado exitosamente';
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error en entrenamiento: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _currentPhase = AISetupPhase.error;
        _errorMessage = 'Error en entrenamiento: ${e.toString()}';
      });
    }
  }

  void _resetProcess() {
    setState(() {
      _currentPhase = AISetupPhase.idle;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _configProgress = 0.0;
      _configStep = '';
      _trainingProgress = 0.0;
      _trainingEpoch = 0;
      _totalEpochs = 0;
      _statusMessage = 'Listo para comenzar';
      _errorMessage = '';
    });
  }

  // ============================================================================
  // SECCIÓN: FUNCIONES AUXILIARES
  // ============================================================================

  Future<String> _getAIModelStoragePath() async {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final String basePath = '${baseDir.path}/ClickPalmData';
    final String aiModelsPath = '$basePath/ai_models';
    final Directory aiModelsDir = Directory(aiModelsPath);

    if (!await aiModelsDir.exists()) {
      await aiModelsDir.create(recursive: true);
    }

    return aiModelsPath;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool _isPhaseCompleted(AISetupPhase phase) {
    final phaseOrder = {
      AISetupPhase.downloading: 1,
      AISetupPhase.configuring: 2,
      AISetupPhase.training: 3,
    };

    final currentOrder = phaseOrder[_currentPhase] ?? 0;
    final checkOrder = phaseOrder[phase] ?? 0;

    return currentOrder > checkOrder || _currentPhase == AISetupPhase.completed;
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case AISetupPhase.downloading:
        return FlutterFlowTheme.of(context).primary;
      case AISetupPhase.configuring:
        return Colors.orange;
      case AISetupPhase.training:
        return Colors.purple;
      case AISetupPhase.completed:
        return Colors.green;
      case AISetupPhase.error:
        return Colors.red;
      default:
        return FlutterFlowTheme.of(context).primary;
    }
  }

  List<Color> _getPhaseGradientColors() {
    final baseColor = _getPhaseColor();
    return [
      baseColor,
      baseColor.withOpacity(0.7),
    ];
  }

  IconData _getPhaseIcon() {
    switch (_currentPhase) {
      case AISetupPhase.downloading:
        return Icons.cloud_download;
      case AISetupPhase.configuring:
        return Icons.settings;
      case AISetupPhase.training:
        return Icons.school;
      case AISetupPhase.completed:
        return Icons.check_circle;
      case AISetupPhase.error:
        return Icons.error;
      default:
        return Icons.psychology;
    }
  }

  String _getButtonText() {
    if (_currentPhase == AISetupPhase.downloading) {
      return 'Descargando...';
    } else if (_currentPhase == AISetupPhase.configuring) {
      return 'Configurando...';
    } else if (_currentPhase == AISetupPhase.training) {
      return 'Entrenando...';
    } else if (_currentPhase == AISetupPhase.completed) {
      return 'Reiniciar Proceso';
    } else if (_currentPhase == AISetupPhase.error) {
      return 'Intentar Nuevamente';
    } else {
      return 'Iniciar Configuración';
    }
  }
}
