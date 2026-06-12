import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:io';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/platform_utils.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'photo_capture_component_model.dart';
export 'photo_capture_component_model.dart';

class PhotoCaptureComponentWidget extends StatefulWidget {
  const PhotoCaptureComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
  })  : tittle = tittle ?? 'Capturar Fotografía',
        idStepParent = idStepParent ?? 0;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;

  @override
  State<PhotoCaptureComponentWidget> createState() =>
      _PhotoCaptureComponentWidgetState();
}

class _PhotoCaptureComponentWidgetState
    extends State<PhotoCaptureComponentWidget>
    with TickerProviderStateMixin {
  late PhotoCaptureComponentModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ImagePicker _picker = ImagePicker();

  // Variable para almacenar foto existente como path (desde visitDetails)
  String? _existingPhotoPath;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PhotoCaptureComponentModel());

    // Animación de pulso para el botón de captura
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Cargar foto existente si hay
    _loadExistingPhoto();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto() async {
    final existingPhoto = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingPhoto.isNotEmpty) {
      debugPrint('📸 Cargando foto existente: $existingPhoto');

      try {
        // Verificar que el archivo existe
        final file = File(existingPhoto);
        if (await file.exists()) {
          setState(() {
            _existingPhotoPath = existingPhoto;
            _model.photoPath = existingPhoto;
            _model.isPhotoTaken = true;
          });
          debugPrint('✅ Foto existente cargada correctamente');
        } else {
          debugPrint('⚠️ El archivo de foto no existe: $existingPhoto');
        }
      } catch (e) {
        debugPrint('❌ Error al cargar foto existente: $e');
      }
    }
  }

  Future<void> _capturePhoto(ImageSource source) async {
    if (!Platforms.isMobile) return; // Captura de cámara no disponible en desktop
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = FlutterFlowTheme.of(context).error;
    try {
      HapticFeedback.mediumImpact();

      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null) {
        setState(() {
          _model.photoPath = photo.path;
          _model.isPhotoTaken = true;
          // Limpiar el path existente porque ahora tenemos una foto nueva
          _existingPhotoPath = null;
        });

        HapticFeedback.heavyImpact();

        // NO guardar automáticamente, esperar a que el usuario presione "CONTINUAR"
      }
    } catch (e) {
      debugPrint('Error capturando foto: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al capturar foto: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _savePhoto(String photoPath) async {
    // Guardar solo el path de la foto (no base64) para evitar OutOfMemoryError
    // La foto se comprimirá con GZIP y convertirá a base64 cuando se sincronice la visita
    debugPrint('📸 Guardando path de la foto: $photoPath');

    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      photoPath, // Guardar path de la foto temporalmente
      (getJsonField(widget.statusJSON, r'''$.remember_status''') as bool?) ?? false,
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});

    debugPrint('✅ Foto guardada exitosamente en visitDetails (path)');
  }

  Future<void> _deletePhoto() async {
    HapticFeedback.lightImpact();

    setState(() {
      _model.photoPath = null;
      _model.isPhotoTaken = false;
      _existingPhotoPath = null; // Limpiar también el path existente
    });

    // Eliminar de visitDetails
    debugPrint('🗑️ Eliminando foto de visitDetails...');
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

  // Generar nombre de foto usando fecha, hora y nombre de la actividad
  String _generatePhotoName() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // Obtener nombre de la actividad desde FFAppState
    final activityName = getJsonField(
      FFAppState().currentActivity,
      r'''$.name_activity''',
    )?.toString() ?? 'Actividad';

    // Limpiar el nombre de la actividad (quitar espacios y caracteres especiales)
    final cleanActivityName = activityName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .toLowerCase();

    return '${cleanActivityName}_${dateStr}_$timeStr.jpg';
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
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
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
                  if (_model.isPhotoTaken)
                    InkWell(
                      onTap: _deletePhoto,
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
                child: _model.isPhotoTaken && _model.photoPath != null
                    ? _buildPhotoPreview()
                    : _buildEmptyState(),
              ),
            ),

            // Botones de captura
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
              child: Column(
                children: [
                  // Botón "CONTINUAR CON ESTA FOTO" (solo visible si hay foto)
                  if (_model.isPhotoTaken && _model.photoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          // Guardar la foto en visitDetails
                          final nav = Navigator.of(context);
                          await _savePhoto(_model.photoPath!);
                          // Cerrar el diálogo
                          nav.pop();
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
                                FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
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
                                'CONTINUAR CON ESTA FOTO',
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
                      onTap: () => _capturePhoto(ImageSource.camera),
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
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Tomar Fotografía',
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
                    onTap: () => _capturePhoto(ImageSource.gallery),
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
                            Icons.photo_library_rounded,
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

  Widget _buildPhotoPreview() {
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
            // Foto (desde archivo - path existente o nuevo)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: _existingPhotoPath != null
                  // Mostrar desde path (foto existente cargada de visitDetails)
                  ? Image.file(
                      File(_existingPhotoPath!),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    )
                  // Mostrar desde archivo (foto recién capturada)
                  : _model.photoPath != null
                      ? Image.file(
                          File(_model.photoPath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.photo,
                              color: Colors.white,
                              size: 48,
                            ),
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

            // Badge de confirmación con nombre de archivo
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
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
                          'Capturada',
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
                      _generatePhotoName(),
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
              Icons.add_a_photo_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin fotografía',
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
              'Toca el botón de abajo para capturar\nuna fotografía o seleccionar de la galería',
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
