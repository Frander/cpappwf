import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'dart:io';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/platform_utils.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'video_capture_component_model.dart';
export 'video_capture_component_model.dart';

class VideoCaptureComponentWidget extends StatefulWidget {
  const VideoCaptureComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
  })  : this.tittle = tittle ?? 'Capturar Video',
        this.idStepParent = idStepParent ?? 0;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;

  @override
  State<VideoCaptureComponentWidget> createState() =>
      _VideoCaptureComponentWidgetState();
}

class _VideoCaptureComponentWidgetState
    extends State<VideoCaptureComponentWidget>
    with TickerProviderStateMixin {
  late VideoCaptureComponentModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ImagePicker _picker = ImagePicker();

  // Controlador de video para preview
  VideoPlayerController? _videoController;

  // Variable para almacenar video existente (path del archivo)
  String? _existingVideoPath;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VideoCaptureComponentModel());

    // Animación de pulso para el botón de captura
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Cargar video existente si hay
    _loadExistingVideo();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadExistingVideo() async {
    final existingVideo = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingVideo.isNotEmpty) {
      debugPrint('🎬 Cargando video existente: $existingVideo');

      try {
        // Verificar que el archivo existe
        final file = File(existingVideo);
        if (await file.exists()) {
          // Inicializar el controlador de video para preview
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(file);
          await _videoController!.initialize();

          // Pausar en el primer frame
          await _videoController!.seekTo(Duration.zero);

          setState(() {
            _existingVideoPath = existingVideo;
            _model.videoPath = existingVideo;
            _model.isVideoTaken = true;
          });

          debugPrint('✅ Video existente cargado correctamente');
        } else {
          debugPrint('⚠️ El archivo de video no existe: $existingVideo');
        }
      } catch (e) {
        debugPrint('❌ Error al cargar video existente: $e');
      }
    }
  }

  Future<void> _captureVideo(ImageSource source) async {
    if (!Platforms.isMobile) return; // Captura de video no disponible en desktop
    try {
      HapticFeedback.mediumImpact();

      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // Máximo 5 minutos
      );

      if (video != null) {
        // Inicializar el controlador de video para preview
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(File(video.path))
          ..initialize().then((_) {
            setState(() {
              _model.videoPath = video.path;
              _model.isVideoTaken = true;
              _existingVideoPath = null;
            });
            _videoController?.play();
            _videoController?.setLooping(true);
          });

        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error capturando video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al capturar video: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _saveVideo(String videoPath) async {
    // Guardar solo el path del video (no base64) para evitar OutOfMemoryError
    // El video se convertirá a base64 cuando se sincronice la visita
    debugPrint('🎥 Guardando path del video: $videoPath');

    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      videoPath, // Guardar path del video temporalmente
      getJsonField(widget.statusJSON, r'''$.remember_status'''),
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy!.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});

    debugPrint('✅ Video guardado exitosamente en visitDetails (path)');
  }

  Future<void> _deleteVideo() async {
    HapticFeedback.lightImpact();

    _videoController?.dispose();
    _videoController = null;

    setState(() {
      _model.videoPath = null;
      _model.isVideoTaken = false;
      _existingVideoPath = null;
    });

    // Eliminar de visitDetails
    debugPrint('🗑️ Eliminando video de visitDetails...');
    List<int> indicesToRemove = [];
    for (int i = 0; i < FFAppState().visitDetails.length; i++) {
      if (FFAppState().visitDetails[i].idActivityStatus == widget.idStatus &&
          FFAppState().visitDetails[i].idStepParent == widget.idStepParent) {
        indicesToRemove.add(i);
      }
    }

    for (int i = indicesToRemove.length - 1; i >= 0; i--) {
      FFAppState().removeAtIndexFromVisitDetails(indicesToRemove[i]);
      debugPrint('🗑️ Eliminado registro en índice ${indicesToRemove[i]}');
    }

    FFAppState().update(() {});
  }

  String _generateVideoName() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final activityName = getJsonField(
      FFAppState().currentActivity,
      r'''$.name_activity''',
    )?.toString() ??
        'Actividad';

    final cleanActivityName = activityName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .toLowerCase();

    return '${cleanActivityName}_${dateStr}_$timeStr.mp4';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 10.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          16.0, 0.0, 16.0, 0.0),
                      child: Text(
                        widget.tittle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (_model.isVideoTaken)
                    InkWell(
                      onTap: _deleteVideo,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).error,
                              FlutterFlowTheme.of(context)
                                  .error
                                  .withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context)
                                  .error
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),

            // Preview Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _model.isVideoTaken && _model.videoPath != null
                    ? _buildVideoPreview()
                    : _buildEmptyState(),
              ),
            ),

            // Botones de captura
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
              child: Column(
                children: [
                  // Botón "CONTINUAR CON ESTE VIDEO"
                  if (_model.isVideoTaken && _model.videoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await _saveVideo(_model.videoPath!);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                FlutterFlowTheme.of(context).success,
                                FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'CONTINUAR CON ESTE VIDEO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Botón cámara
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: InkWell(
                      onTap: () => _captureVideo(ImageSource.camera),
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context)
                                  .primary
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Grabar Video',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón galería
                  InkWell(
                    onTap: () => _captureVideo(ImageSource.gallery),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Seleccionar de Galería',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Video preview
            if (_videoController != null && _videoController!.value.isInitialized)
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),

            // Overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),

            // Play/Pause button
            Center(
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

            // Badge de confirmación
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FlutterFlowTheme.of(context).success,
                      FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .success
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Capturado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _generateVideoName(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                  FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.3),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videocam_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin video',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Toca el botón de abajo para grabar\nun video o seleccionar de la galería',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
