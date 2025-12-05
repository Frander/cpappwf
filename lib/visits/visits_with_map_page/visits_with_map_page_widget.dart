import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/visits/do_visits_form_page/do_visits_form_page_widget.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VisitsWithMapPageModel());
    _tabController = TabController(
      vsync: this,
      length: 2,
      initialIndex: 0,
    );
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
            decoration: BoxDecoration(
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
                        : NeverScrollableScrollPhysics(),
                    children: [
                      // Tab de Formulario
                      DoVisitsFormPageWidget(),
                      // Tab de Mapa
                      widget.isMapEnabled
                          ? Container(
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
            Color(0xFF00a86b).withOpacity(0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Fila con botón back y título
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color(0xFF00a86b).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF00ff9f),
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    getJsonField(
                      FFAppState().activitySelectedJSON,
                      r'''$.name_activity''',
                    )?.toString() ?? 'Realizar Visitas',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00ff9f),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Tabs compactos
          Container(
            height: 40,
            margin: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF00a86b).withOpacity(0.3),
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
                      FlutterFlowTheme.of(context).primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: EdgeInsets.all(4),
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF00ff9f).withOpacity(0.6),
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                onTap: (i) async {
                  if (!widget.isMapEnabled && i == 1) {
                    // Si el mapa está deshabilitado y el usuario intenta acceder
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'El mapa está deshabilitado. Debe generar una ruta óptima desde la pantalla anterior.',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        duration: Duration(milliseconds: 3000),
                        backgroundColor: FlutterFlowTheme.of(context).warning,
                      ),
                    );
                    // Volver a la primera pestaña
                    _tabController.animateTo(
                      0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  }
                },
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Formulario'),
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
                        SizedBox(width: 6),
                        Text(widget.isMapEnabled ? 'Mapa' : 'Mapa'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
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
                  Color(0xFF00a86b).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 50,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Mapa deshabilitado',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Para habilitar el mapa, debe generar una ruta óptima desde la pantalla anterior',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
