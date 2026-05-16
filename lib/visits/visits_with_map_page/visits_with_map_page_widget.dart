import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import '/visits/do_visits_form_page/do_visits_form_page_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'visits_with_map_page_model.dart';
export 'visits_with_map_page_model.dart';

class VisitsWithMapPageWidget extends StatefulWidget {
  const VisitsWithMapPageWidget({
    super.key,
    required this.isMapEnabled,
  });

  final bool isMapEnabled;

  static String routeName = 'VisitsWithMapPage';
  static String routePath = '/visitsWithMapPage';

  @override
  State<VisitsWithMapPageWidget> createState() =>
      _VisitsWithMapPageWidgetState();
}

class _VisitsWithMapPageWidgetState extends State<VisitsWithMapPageWidget> {
  late VisitsWithMapPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Key para invocar métodos públicos del formulario (p.ej. el flujo QR).
  final GlobalKey<DoVisitsFormPageWidgetState> _formKey =
      GlobalKey<DoVisitsFormPageWidgetState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VisitsWithMapPageModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmationDialog(onConfirm: () { if (mounted) context.pop(); });
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF003420),
                  Color(0xFF002415),
                  Color(0xFF00150A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              children: [
                // Header compacto con tabs integrados
                _buildModernHeader(),

                // Formulario (pantalla completa; Brújula y Mapa en overlay vía "Otras Opciones")
                Expanded(
                  child: DoVisitsFormPageWidget(key: _formKey),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00a86b).withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Fila con botón back y título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _showExitConfirmationDialog(onConfirm: () { if (mounted) context.pop(); }),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF00ff9f),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    FFAppState().activitySelected.nameActivity.isNotEmpty
                        ? FFAppState().activitySelected.nameActivity
                        : 'Realizar Visitas',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Menú con Brújula, Mapa y QR
                _buildOtrasOpcionesButton(),
                const SizedBox(width: 8),
                // Botón de Novedades
                InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showExitConfirmationDialog(
                      onConfirm: () => context.pushNamed(
                        NewsPageWidget.routeName,
                        extra: <String, dynamic>{
                          kTransitionInfoKey: const TransitionInfo(
                            hasTransition: true,
                            transitionType: PageTransitionType.fade,
                            duration: Duration(milliseconds: 500),
                          ),
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF9800),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildMapLockedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00a86b).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 50,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mapa deshabilitado',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Para habilitar el mapa, debe generar una ruta óptima desde la pantalla anterior',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog({required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) {
        int secondsLeft = 5;
        Timer? autoCloseTimer;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            autoCloseTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsLeft <= 1) {
                t.cancel();
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                }
                return;
              }
              setStateDialog(() => secondsLeft--);
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¿Desea salir?',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los datos del formulario se perderán si sale ahora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cerrando en $secondsLeft s...',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              autoCloseTimer?.cancel();
                              Navigator.pop(dialogContext);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              autoCloseTimer?.cancel();
                              Navigator.pop(dialogContext);
                              if (mounted) onConfirm();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.withValues(alpha: 0.8),
                                    Colors.red.withValues(alpha: 0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Salir',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOtrasOpcionesButton() {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showExitConfirmationDialog(onConfirm: _showOtrasOpcionesDialog);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF00a86b).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.apps_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _showOtrasOpcionesDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OPCIONES',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOpcionItem(
                  'Brújula',
                  Icons.compass_calibration_rounded,
                  const Color(0xFF00a86b),
                  'Ver brújula de orientación',
                  () {
                    Navigator.pop(dialogContext);
                    _openBrujelaOverlay();
                  },
                ),
                const SizedBox(height: 10),
                _buildOpcionItem(
                  'Mapa',
                  Icons.map_rounded,
                  const Color(0xFF2196F3),
                  'Ver mapa de visitas',
                  () {
                    Navigator.pop(dialogContext);
                    _openMapaOverlay();
                  },
                ),
                const SizedBox(height: 10),
                _buildOpcionItem(
                  'QR',
                  Icons.qr_code_scanner_rounded,
                  const Color(0xFF9C27B0),
                  'Escanear código QR',
                  () async {
                    Navigator.pop(dialogContext);
                    if (!FFAppState().activitySelected.isSync) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.sync_disabled_rounded, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'La actividad no está sincronizada. No se puede registrar la visita.',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }
                    await _formKey.currentState?.triggerQrSaveFlow();
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => Navigator.pop(dialogContext),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpcionItem(
    String title,
    IconData icon,
    Color color,
    String description,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openBrujelaOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, _, __) => Material(
        color: FlutterFlowTheme.of(context).primaryBackground,
        child: SafeArea(
          child: Stack(
            children: [
              custom_widgets.CompassClickpalm(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                idHeadquarter:
                    FFAppState().headquartersSelectedList.isNotEmpty
                        ? FFAppState()
                            .headquartersSelectedList
                            .first
                            .idHeadquarter
                        : null,
              ),
              Positioned(
                top: 8,
                right: 12,
                child: _buildOverlayCloseButton(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMapaOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, _, __) => Material(
        color: FlutterFlowTheme.of(context).primaryBackground,
        child: SafeArea(
          child: Stack(
            children: [
              widget.isMapEnabled
                  ? SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: custom_widgets.OfflineMapTrackerVisits(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        mapFilePath: FFAppState().pathPmtiles,
                        headquarters: FFAppState().headquartersSelectedList,
                        authToken:
                            FFAppState().loginResponse['token'] as String? ??
                                '',
                      ),
                    )
                  : _buildMapLockedContent(),
              Positioned(
                top: 8,
                right: 12,
                child: _buildOverlayCloseButton(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayCloseButton(BuildContext ctx) {
    return InkWell(
      onTap: () => Navigator.pop(ctx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF00a86b).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.close_rounded,
          color: Color(0xFF00ff9f),
          size: 20,
        ),
      ),
    );
  }
}
