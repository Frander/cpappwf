import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
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

class _VisitsWithMapPageWidgetState extends State<VisitsWithMapPageWidget>
    with TickerProviderStateMixin {
  late VisitsWithMapPageModel _model;
  late TabController _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Tipo de lectura actual (GPS, NFC, QR) - se obtiene del read_default de la actividad
  String _currentReadType = 'GPS';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VisitsWithMapPageModel());
    _tabController = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    );
    // Inicializar el tipo de lectura desde la actividad actual
    _initReadType();
  }

  void _initReadType() {
    final currentActivity = FFAppState().currentActivity;
    final readDefault = getJsonField(currentActivity, r'''$.read_default''')?.toString().toUpperCase() ?? '';
    if (readDefault == 'NFC' || readDefault == 'QR' || readDefault == 'GPS') {
      _currentReadType = readDefault;
    } else {
      _currentReadType = 'GPS';
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
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

                // Contenido del tab seleccionado
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: widget.isMapEnabled
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    children: [
                      // Tab 1: Formulario
                      const DoVisitsFormPageWidget(),
                      
                      // Tab 2: Brújula
                      Container(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        child: custom_widgets.CompassClickpalm(
                          width: MediaQuery.sizeOf(context).width,
                          height: MediaQuery.sizeOf(context).height,
                          idHeadquarter: FFAppState()
                              .headquartersSelectedList
                              .isNotEmpty
                              ? FFAppState()
                                  .headquartersSelectedList
                                  .first
                                  .idHeadquarter
                              : null,
                        ),
                      ),
                      
                      // Tab 3: Mapa
                      widget.isMapEnabled
                          ? SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: custom_widgets.OfflineMapTrackerVisits(
                                width: MediaQuery.sizeOf(context).width,
                                height: MediaQuery.sizeOf(context).height,
                                mapFilePath: FFAppState().pathPmtiles,
                                headquarters:
                                    FFAppState().headquartersSelectedList,
                                authToken:
                                    FFAppState().loginResponse['token']
                                            as String? ??
                                        '',
                              ),
                            )
                          : _buildMapLockedContent(),
                    ],
                  ),
                ),
              ],
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
                  onTap: () async {
                    context.pop();
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
                // Botón para cambiar tipo de lectura (GPS/NFC/QR)
                _buildReadTypeSelectorButton(),
                const SizedBox(width: 8),
                // Botón de Novedades
                InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    context.pushNamed(
                      NewsPageWidget.routeName,
                      extra: <String, dynamic>{
                        kTransitionInfoKey: const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.fade,
                          duration: Duration(milliseconds: 500),
                        ),
                      },
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

          // Tabs compactos
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF00ff9f).withValues(alpha: 0.6),
                labelStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                onTap: (i) async {
                  if (!widget.isMapEnabled && i == 2) {
                    // Si el mapa está deshabilitado y el usuario intenta acceder
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'El mapa está deshabilitado. Debe generar una ruta óptima desde la pantalla anterior.',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        duration: const Duration(milliseconds: 3000),
                        backgroundColor: FlutterFlowTheme.of(context).warning,
                      ),
                    );
                    // Volver a la primera pestaña
                    _tabController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  }
                },
                tabs: [
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Formulario'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.compass_calibration, size: 18),
                        SizedBox(width: 6),
                        Text('Brújula'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isMapEnabled ? Icons.map_rounded : Icons.lock_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(widget.isMapEnabled ? 'Mapa' : 'Mapa'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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

  /// Botón compacto para cambiar el tipo de lectura (GPS/NFC/QR)
  Widget _buildReadTypeSelectorButton() {
    // Determinar icono y color según el tipo actual
    IconData icon;
    Color color;
    switch (_currentReadType) {
      case 'NFC':
        icon = Icons.nfc_rounded;
        color = const Color(0xFF2196F3); // Azul
        break;
      case 'QR':
        icon = Icons.qr_code_rounded;
        color = const Color(0xFF9C27B0); // Púrpura
        break;
      default:
        icon = Icons.gps_fixed_rounded;
        color = const Color(0xFF00a86b); // Verde
    }

    return InkWell(
      onTap: () => _showReadTypeSelectorDialog(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              _currentReadType,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra el diálogo para seleccionar el tipo de lectura
  void _showReadTypeSelectorDialog() {
    HapticFeedback.mediumImpact();

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
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
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
                // Título
                const Text(
                  'TIPO DE LECTURA',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Opciones
                _buildReadTypeOption(
                  dialogContext,
                  'GPS',
                  Icons.gps_fixed_rounded,
                  const Color(0xFF00a86b),
                  'Ubicación GPS',
                ),
                const SizedBox(height: 10),
                _buildReadTypeOption(
                  dialogContext,
                  'NFC',
                  Icons.nfc_rounded,
                  const Color(0xFF2196F3),
                  'Lectura TAG NFC',
                ),
                const SizedBox(height: 10),
                _buildReadTypeOption(
                  dialogContext,
                  'QR',
                  Icons.qr_code_rounded,
                  const Color(0xFF9C27B0),
                  'Escanear código QR',
                ),

                const SizedBox(height: 16),

                // Botón cancelar
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

  /// Construye una opción del selector de tipo de lectura
  Widget _buildReadTypeOption(
    BuildContext dialogContext,
    String type,
    IconData icon,
    Color color,
    String description,
  ) {
    final isSelected = _currentReadType == type;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _updateReadType(type);
        Navigator.pop(dialogContext);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
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
                    type,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.white,
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
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  /// Actualiza el tipo de lectura y lo guarda en el currentActivity
  void _updateReadType(String newType) {
    setState(() {
      _currentReadType = newType;
    });

    // Actualizar el read_default en el currentActivity del AppState
    final currentActivity = FFAppState().currentActivity;
    if (currentActivity is Map<String, dynamic>) {
      final updatedActivity = Map<String, dynamic>.from(currentActivity);
      updatedActivity['read_default'] = newType;
      FFAppState().currentActivity = updatedActivity;
    } else if (currentActivity != null) {
      // Si es un JSON dinámico, intentar convertirlo
      try {
        final Map<String, dynamic> activityMap = Map<String, dynamic>.from(currentActivity as Map);
        activityMap['read_default'] = newType;
        FFAppState().currentActivity = activityMap;
      } catch (e) {
        debugPrint('⚠️ No se pudo actualizar read_default: $e');
      }
    }

    debugPrint('✅ Tipo de lectura cambiado a: $newType');
  }
}
