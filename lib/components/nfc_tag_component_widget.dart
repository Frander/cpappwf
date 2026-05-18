import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nfc_tag_component_model.dart';
export 'nfc_tag_component_model.dart';

class NfcTagComponentWidget extends StatefulWidget {
  const NfcTagComponentWidget({
    super.key,
    String? tittle,
    required this.idStatus,
    required this.statusName,
    required this.statusJSON,
    int? idStepParent,
    bool? isWriter,
  })  : tittle = tittle ?? 'NFC Tag',
        idStepParent = idStepParent ?? 0,
        isWriter = isWriter ?? false;

  final String tittle;
  final int idStatus;
  final String statusName;
  final dynamic statusJSON;
  final int idStepParent;
  final bool isWriter; // true = tag-writer, false = tag-reader

  @override
  State<NfcTagComponentWidget> createState() => _NfcTagComponentWidgetState();
}

class _NfcTagComponentWidgetState extends State<NfcTagComponentWidget>
    with TickerProviderStateMixin {
  late NfcTagComponentModel _model;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NfcTagComponentModel());

    // Animación de pulso
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de ondas
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    // Cargar datos existentes si hay
    _loadExistingData();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final existingData = functions.statusResponseByActivityStatusAlternative(
      widget.idStatus,
      FFAppState().visitDetails.toList(),
      widget.idStepParent,
    );

    if (existingData.isNotEmpty) {
      setState(() {
        _model.nfcData = existingData;
        _model.isSuccess = true;
      });
    }
  }

  Future<void> _startNfcOperation() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _model.isScanning = true;
      _model.isError = false;
      _model.isSuccess = false;
      _model.errorMessage = null;
    });

    try {
      if (widget.isWriter) {
        // Escritura NFC - usar action writeNFC si existe
        final dataToWrite = widget.statusName; // O cualquier dato que quieras escribir

        // Por ahora simulamos escritura exitosa
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _model.nfcData = dataToWrite;
          _model.isSuccess = true;
          _model.isScanning = false;
        });

        HapticFeedback.heavyImpact();
        await _saveData(dataToWrite);
      } else {
        // Lectura NFC - usar action readNFC
        final nfcResult = await actions.readNFC(context);

        if (nfcResult.isNotEmpty) {
          setState(() {
            _model.nfcData = nfcResult;
            _model.isSuccess = true;
            _model.isScanning = false;
          });

          HapticFeedback.heavyImpact();
          await _saveData(nfcResult);
        } else {
          throw Exception('No se pudo leer el tag NFC');
        }
      }
    } catch (e) {
      debugPrint('Error en operación NFC: $e');
      setState(() {
        _model.isError = true;
        _model.isScanning = false;
        _model.errorMessage = e.toString();
      });

      HapticFeedback.vibrate();
    }
  }

  Future<void> _saveData(String data) async {
    final visitDetailsCopy = await actions.updateOrAddVisitDetail(
      FFAppState().visitDetails.toList(),
      widget.idStatus,
      widget.idStepParent,
      widget.statusName,
      data,
      getJsonField(widget.statusJSON, r'''$.remember_status'''),
      getJsonField(widget.statusJSON, r'''$.default_status''').toString(),
      0,
    );

    FFAppState().visitDetails =
        visitDetailsCopy.toList().cast<VisitsDetailsStruct>();
    FFAppState().update(() {});
  }

  Future<void> _clearData() async {
    HapticFeedback.lightImpact();

    setState(() {
      _model.nfcData = null;
      _model.isSuccess = false;
      _model.isError = false;
    });

    await _saveData('');
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
                      child: Column(
                        children: [
                          Text(
                            widget.tittle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.isWriter
                                      ? FlutterFlowTheme.of(context).warning
                                      : FlutterFlowTheme.of(context).info,
                                  widget.isWriter
                                      ? FlutterFlowTheme.of(context)
                                          .warning
                                          .withValues(alpha: 0.7)
                                      : FlutterFlowTheme.of(context)
                                          .info
                                          .withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.isWriter ? 'ESCRITURA' : 'LECTURA',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_model.isSuccess)
                    InkWell(
                      onTap: _clearData,
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
                          Icons.clear,
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

            // Área de visualización
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildNfcDisplay(),
              ),
            ),

            // Botón de acción
            if (!_model.isScanning)
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
                child: InkWell(
                  onTap: _startNfcOperation,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isWriter ? Icons.nfc : Icons.nfc,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.isWriter ? 'Escribir Tag' : 'Leer Tag',
                          style: const TextStyle(
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
          ],
        ),
      ),
    );
  }

  Widget _buildNfcDisplay() {
    if (_model.isScanning) {
      return _buildScanningState();
    } else if (_model.isSuccess) {
      return _buildSuccessState();
    } else if (_model.isError) {
      return _buildErrorState();
    } else {
      return _buildEmptyState();
    }
  }

  Widget _buildScanningState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
            FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ondas animadas
          Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    final delay = index * 0.3;
                    final progress = (_waveAnimation.value + delay) % 1.0;

                    return Container(
                      width: 100 + (progress * 100),
                      height: 100 + (progress * 100),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FlutterFlowTheme.of(context)
                              .primary
                              .withValues(alpha: (1 - progress) * 0.5),
                          width: 3,
                        ),
                      ),
                    );
                  },
                );
              }),

              // Ícono NFC
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FlutterFlowTheme.of(context).primary,
                        FlutterFlowTheme.of(context).secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.nfc,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          Text(
            widget.isWriter
                ? 'Acerque el tag para escribir'
                : 'Acerque el tag para leer',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Mantenga el dispositivo cerca del tag NFC',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).success.withValues(alpha: 0.2),
            FlutterFlowTheme.of(context).success.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FlutterFlowTheme.of(context).success,
                  FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      FlutterFlowTheme.of(context).success.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            widget.isWriter ? '¡Tag Escrito!' : '¡Tag Leído!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'DATOS DEL TAG',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _model.nfcData ?? 'N/A',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).error.withValues(alpha: 0.2),
            FlutterFlowTheme.of(context).error.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: FlutterFlowTheme.of(context).error.withValues(alpha: 0.3),
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
                colors: [
                  FlutterFlowTheme.of(context).error,
                  FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Error en operación',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _model.errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                    FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
                    FlutterFlowTheme.of(context).secondary.withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contactless_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 72,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            widget.isWriter ? 'Listo para escribir' : 'Listo para leer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.isWriter
                  ? 'Toca el botón de abajo y acerca el tag NFC para escribir los datos'
                  : 'Toca el botón de abajo y acerca el tag NFC para leer los datos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
