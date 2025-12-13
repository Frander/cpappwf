import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'news_page_model.dart';
export 'news_page_model.dart';

class NewsPageWidget extends StatefulWidget {
  const NewsPageWidget({super.key});

  static String routeName = 'NewsPage';
  static String routePath = '/newsPage';

  @override
  State<NewsPageWidget> createState() => _NewsPageWidgetState();
}

class _NewsPageWidgetState extends State<NewsPageWidget>
    with SingleTickerProviderStateMixin {
  late NewsPageModel _model;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NewsPageModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // Animación de entrada
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    // Filtrar novedades por búsqueda
    final allNews = FFAppState().newsList.toList();
    final filteredNews = _searchQuery.isEmpty
        ? allNews
        : allNews
            .where((item) => item.nameNew
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Container(
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
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header moderno
                  _buildHeader(context),

                  // Barra de búsqueda
                  _buildSearchBar(context),

                  // Contenido principal
                  Expanded(
                    child: filteredNews.isEmpty
                        ? _buildEmptyState(context)
                        : _buildNewsList(context, filteredNews),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 16, 16),
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
      child: Row(
        children: [
          // Botón de regreso
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.safePop();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
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
                size: 28,
              ),
            ),
          ),

          SizedBox(width: 16),

          // Título e icono
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFF9800).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF9800),
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Novedades',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Reporta interrupciones del trabajo',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color(0xFF00a86b).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: TextField(
            controller: _model.textController,
            focusNode: _model.textFieldFocusNode,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar novedad...',
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                color: Colors.white.withOpacity(0.4),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Color(0xFF00a86b),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        _model.textController?.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                  Color(0xFF00a86b).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 56,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty
                ? 'No hay novedades disponibles'
                : 'No se encontraron resultados',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Las novedades aparecerán aquí'
                : 'Intenta con otro término de búsqueda',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList(BuildContext context, List<dynamic> newsList) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: newsList.length,
      itemBuilder: (context, index) {
        final newsItem = newsList[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildNewsCard(context, newsItem, index),
        );
      },
    );
  }

  Widget _buildNewsCard(BuildContext context, dynamic newsItem, int index) {
    // Colores alternados para variedad visual
    final List<Color> accentColors = [
      Color(0xFFFF9800), // Naranja
      Color(0xFF2196F3), // Azul
      Color(0xFFE91E63), // Rosa
      Color(0xFF9C27B0), // Púrpura
      Color(0xFF00BCD4), // Cian
    ];
    final accentColor = accentColors[index % accentColors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();

            // Registrar la novedad
            FFAppState().addToNewsAdd(VisitsNewsStruct(
              idNew: newsItem.idNew,
              createdAt: functions.convertToDotNetDateTime(getCurrentTimestamp),
              descripcionNew: 'NOVEDAD',
              locationsAdd: [' 1', '2'],
            ));
            FFAppState().update(() {});

            // Mostrar feedback visual
            _showSuccessSnackbar(context, newsItem.nameNew);

            // Regresar
            context.safePop();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icono con color de acento
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withOpacity(0.3),
                              accentColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getIconForNews(index),
                          color: accentColor,
                          size: 26,
                        ),
                      ),

                      SizedBox(width: 14),

                      // Contenido
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              newsItem.nameNew ?? 'Sin nombre',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 14,
                                  color: accentColor.withOpacity(0.8),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Toca para reportar',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Flecha
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForNews(int index) {
    final icons = [
      Icons.warning_amber_rounded,
      Icons.report_problem_rounded,
      Icons.error_outline_rounded,
      Icons.info_outline_rounded,
      Icons.priority_high_rounded,
      Icons.notification_important_rounded,
      Icons.announcement_rounded,
      Icons.feedback_rounded,
    ];
    return icons[index % icons.length];
  }

  void _showSuccessSnackbar(BuildContext context, String newsName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Novedad registrada',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    newsName,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: Duration(milliseconds: 2500),
        backgroundColor: Color(0xFF00a86b),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
