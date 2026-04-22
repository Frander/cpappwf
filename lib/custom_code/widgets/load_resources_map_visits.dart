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
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// ============================================================================
// ENUMS Y CLASES DE CONFIGURACIÓN
// ============================================================================

enum RoutePattern {
  lineaRecta,
  zigzagSimple,
  zigzagSerpentina,
  zigzagEspiral,
  rutaOptimizada,
}

extension RoutePatternExtension on RoutePattern {
  String get displayName {
    switch (this) {
      case RoutePattern.lineaRecta:
        return 'Línea Recta';
      case RoutePattern.zigzagSimple:
        return 'Zigzag Simple';
      case RoutePattern.zigzagSerpentina:
        return 'Zigzag Serpentina';
      case RoutePattern.zigzagEspiral:
        return 'Zigzag Espiral';
      case RoutePattern.rutaOptimizada:
        return 'Ruta Optimizada';
    }
  }

  String get description {
    switch (this) {
      case RoutePattern.lineaRecta:
        return 'Recorre punto por punto en orden';
      case RoutePattern.zigzagSimple:
        return 'Línea 1→, Línea 2←, Línea 3→';
      case RoutePattern.zigzagSerpentina:
        return 'Optimiza distancia entre líneas';
      case RoutePattern.zigzagEspiral:
        return 'Desde el centro hacia afuera';
      case RoutePattern.rutaOptimizada:
        return 'Optimización con IA (requiere conexión)';
    }
  }

  IconData get icon {
    switch (this) {
      case RoutePattern.lineaRecta:
        return Icons.trending_flat;
      case RoutePattern.zigzagSimple:
        return Icons.show_chart;
      case RoutePattern.zigzagSerpentina:
        return Icons.waves;
      case RoutePattern.zigzagEspiral:
        return Icons.radar;
      case RoutePattern.rutaOptimizada:
        return Icons.auto_awesome;
    }
  }
}

class RouteConfig {
  final int startLine;
  final int startPoint;
  final int? maxLines;
  final int? maxPoints;
  final RoutePattern pattern;

  RouteConfig({
    required this.startLine,
    required this.startPoint,
    this.maxLines,
    this.maxPoints,
    required this.pattern,
  });
}

// ============================================================================
// CLASE PARA PUNTOS VIRTUALES
// ============================================================================

class VirtualPoint {
  final int id;
  final int lineNumber;
  final int pointNumber;
  final double latitude;
  final double longitude;
  final String? description;
  final String? typeName;
  final int? idTypePoint;
  final String? generationMethod;
  final DateTime? createdDate;
  final bool isActive;

  VirtualPoint({
    required this.id,
    required this.lineNumber,
    required this.pointNumber,
    required this.latitude,
    required this.longitude,
    this.description,
    this.typeName,
    this.idTypePoint,
    this.generationMethod,
    this.createdDate,
    this.isActive = true,
  });

  factory VirtualPoint.fromMap(Map<String, dynamic> map) {
    return VirtualPoint(
      id: map['Id_virtual_point'] as int,
      lineNumber: map['Line_number'] as int,
      pointNumber: map['Point_number'] as int,
      latitude: (map['Latitude'] as num).toDouble(),
      longitude: (map['Longitude'] as num).toDouble(),
      description: map['Description'] as String?,
      typeName: map['Type_name'] as String?,
      idTypePoint: map['Id_type_point'] as int?,
      generationMethod: map['Generation_method'] as String?,
      createdDate: map['Created_at'] != null
          ? DateTime.parse(map['Created_at'] as String)
          : null,
      isActive: map['Is_active'] == 1,
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class LoadResourcesMapVisits extends StatefulWidget {
  const LoadResourcesMapVisits({
    super.key,
    this.width,
    this.height,
    this.headquarters,
  });

  final double? width;
  final double? height;
  final List<HeadquartersStruct>? headquarters;

  @override
  State<LoadResourcesMapVisits> createState() => _LoadResourcesMapVisitsState();
}

class _LoadResourcesMapVisitsState extends State<LoadResourcesMapVisits>
    with SingleTickerProviderStateMixin {
  // Controladores
  final _formKey = GlobalKey<FormState>();
  final _startLineController = TextEditingController(text: '1');
  final _startPointController = TextEditingController(text: '1');
  final _maxLinesController = TextEditingController();
  final _maxPointsController = TextEditingController();

  // Estado
  RoutePattern _selectedPattern = RoutePattern.lineaRecta;
  bool _isLoading = false;
  bool _isLoadingData = false;
  String _loadingMessage = '';
  int _loadingStep = 0;
  int _currentHeadquarterIndex = 0;
  int _totalHeadquarters = 0;
  String _currentHeadquarterName = '';

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  // Timer para mensajes de carga
  Timer? _loadingMessageTimer;

  final List<String> _loadingMessages = [
    '🌴 Cargando lotes...',
    '📍 Obteniendo ubicaciones virtuales...',
    '🗺️ Procesando coordenadas...',
    '🔍 Analizando zonas de exclusión...',
    '📊 Organizando puntos de visita...',
    '💾 Guardando en base de datos...',
    '✅ Casi listo...',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCachedConfig();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _loadingMessageTimer?.cancel();
    _startLineController.dispose();
    _startPointController.dispose();
    _maxLinesController.dispose();
    _maxPointsController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MÉTODOS DE CACHÉ
  // ==========================================================================

  Future<void> _loadCachedConfig() async {
    try {
      final appState = FFAppState();

      if (appState.routeConfigStartLine > 0) {
        _startLineController.text = appState.routeConfigStartLine.toString();
      }
      if (appState.routeConfigStartPoint > 0) {
        _startPointController.text = appState.routeConfigStartPoint.toString();
      }
      if (appState.routeConfigMaxLines > 0) {
        _maxLinesController.text = appState.routeConfigMaxLines.toString();
      }
      if (appState.routeConfigMaxPoints > 0) {
        _maxPointsController.text = appState.routeConfigMaxPoints.toString();
      }

      final patternIndex = appState.routeConfigPattern;
      if (patternIndex >= 0 && patternIndex < RoutePattern.values.length) {
        setState(() {
          _selectedPattern = RoutePattern.values[patternIndex];
        });
      }

      debugPrint('✅ Configuración cargada desde caché');
    } catch (e) {
      debugPrint('⚠️ Error cargando configuración: $e');
    }
  }

  void _saveConfigToCache(RouteConfig config) {
    try {
      final appState = FFAppState();
      appState.routeConfigStartLine = config.startLine;
      appState.routeConfigStartPoint = config.startPoint;
      appState.routeConfigMaxLines = config.maxLines ?? 0;
      appState.routeConfigMaxPoints = config.maxPoints ?? 0;
      appState.routeConfigPattern = config.pattern.index;
      debugPrint('💾 Configuración guardada en caché');
    } catch (e) {
      debugPrint('⚠️ Error guardando configuración: $e');
    }
  }

  // ==========================================================================
  // MÉTODOS DE CARGA DE DATOS
  // ==========================================================================

  void _startLoadingAnimation() {
    setState(() {
      _isLoadingData = true;
      _loadingStep = 0;
      _loadingMessage = _loadingMessages[0];
    });

    // Actualizar mensaje cada 2 segundos
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _loadingStep < _loadingMessages.length - 1) {
        setState(() {
          _loadingStep++;
          _loadingMessage = _loadingMessages[_loadingStep];
        });
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingMessageTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoadingData = false;
        _loadingMessage = '';
        _loadingStep = 0;
      });
    }
  }

  Future<void> _generateAndLoadData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar que haya headquarters
    if (widget.headquarters == null || widget.headquarters!.isEmpty) {
      _showErrorDialog('Error', 'No hay lotes (headquarters) para procesar');
      return;
    }

    final config = RouteConfig(
      startLine: int.parse(_startLineController.text),
      startPoint: int.parse(_startPointController.text),
      maxLines: _maxLinesController.text.isNotEmpty
          ? int.parse(_maxLinesController.text)
          : null,
      maxPoints: _maxPointsController.text.isNotEmpty
          ? int.parse(_maxPointsController.text)
          : null,
      pattern: _selectedPattern,
    );

    // Guardar configuración
    _saveConfigToCache(config);

    // Iniciar animación de carga
    _startLoadingAnimation();

    try {
      setState(() {
        _isLoading = true;
        _totalHeadquarters = widget.headquarters!.length;
        _currentHeadquarterIndex = 0;
      });

      // Iterar sobre cada headquarters
      for (int i = 0; i < widget.headquarters!.length; i++) {
        final hq = widget.headquarters![i];

        setState(() {
          _currentHeadquarterIndex = i + 1;
          _currentHeadquarterName =
              hq.nameHeadquarter ?? 'Lote ${hq.idHeadquarter}';
        });

        debugPrint(
            '🌴 Procesando ${_currentHeadquarterIndex}/$_totalHeadquarters: $_currentHeadquarterName');

        if (config.pattern == RoutePattern.rutaOptimizada) {
          // Cargar ruta optimizada desde API
          await _loadOptimizedRoute(config, hq.idHeadquarter!);
        } else {
          // Cargar datos estándar
          await _loadStandardRoute(config, hq.idHeadquarter!);
        }

        debugPrint(
            '✅ Completado ${_currentHeadquarterIndex}/$_totalHeadquarters');
      }

      // Detener animación
      _stopLoadingAnimation();

      // Mostrar éxito
      _showSuccessDialog();
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      _stopLoadingAnimation();
      _showErrorDialog('Error', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentHeadquarterIndex = 0;
          _totalHeadquarters = 0;
          _currentHeadquarterName = '';
        });
      }
    }
  }

  Future<void> _loadOptimizedRoute(
      RouteConfig config, int idHeadquarter) async {
    debugPrint(
        '🔄 Cargando ruta optimizada desde API para HQ: $idHeadquarter...');

    // Verificar conexión
    final hasConnection = await _checkInternetConnection();
    if (!hasConnection) {
      throw Exception('Sin conexión a Internet');
    }

    // Llamar al API
    const String baseUrl = 'https://api.clickpalm.com';
    final requestBody = {
      'id_headquarter': idHeadquarter,
      'start_line': config.startLine,
      'start_point': config.startPoint,
      'max_lines': config.maxLines ?? 0,
      'max_points': config.maxPoints ?? 0,
      'average_speed_kmh': 4.14,
      'time_limit_seconds': 30,
      'optimization_strategy': 'GuidedLocalSearch',
      'apply_exclusion_zones': true,
    };

    debugPrint('📤 Request: ${jsonEncode(requestBody)}');

    final response = await http
        .post(
          Uri.parse('$baseUrl/RouteOptimization/optimize'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      debugPrint('❌ Error del servidor: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Error del servidor: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    debugPrint('✅ Respuesta recibida del API');
    debugPrint('   - Total puntos: ${data['ordered_points']?.length ?? 0}');
    debugPrint('   - Distancia total: ${data['total_distance_km']} km');
    debugPrint('   - Duración estimada: ${data['estimated_duration']}');

    // Guardar en SQLite
    await _saveOptimizedRouteToSQLite(config, data, idHeadquarter);

    debugPrint('✅ Ruta optimizada cargada y guardada para HQ: $idHeadquarter');
  }

  Future<void> _loadStandardRoute(RouteConfig config, int idHeadquarter) async {
    debugPrint('🔄 Cargando ruta estándar para HQ: $idHeadquarter...');
    debugPrint('   Patrón: ${config.pattern.displayName}');
    debugPrint('   Inicio: L${config.startLine}P${config.startPoint}');
    debugPrint(
        '   Límites: maxLines=${config.maxLines ?? 'sin límite'}, maxPoints=${config.maxPoints ?? 'sin límite'}');

    // 1. Leer puntos virtuales de SQLite
    final virtualPoints = await _loadVirtualPointsFromSQLite(idHeadquarter);

    if (virtualPoints.isEmpty) {
      throw Exception(
          'No se encontraron puntos virtuales para HQ: $idHeadquarter');
    }

    debugPrint('📍 Puntos virtuales cargados: ${virtualPoints.length}');

    // 2. Filtrar puntos según configuración
    List<VirtualPoint> filteredPoints = virtualPoints;

    // Filtrar por rango de líneas si hay límite
    if (config.maxLines != null) {
      filteredPoints = filteredPoints.where((point) {
        return point.lineNumber >= config.startLine &&
            point.lineNumber < config.startLine + config.maxLines!;
      }).toList();

      debugPrint(
          '📊 Puntos después de filtrar por líneas: ${filteredPoints.length}');
    }

    // 3. Ordenar según patrón
    final orderedPoints = _orderVirtualPoints(filteredPoints, config);

    if (orderedPoints.isEmpty) {
      throw Exception('No hay puntos válidos después del ordenamiento');
    }

    debugPrint('🎯 Puntos ordenados: ${orderedPoints.length}');

    // 4. Aplicar límite de puntos si existe
    final finalPoints = config.maxPoints != null
        ? orderedPoints.take(config.maxPoints!).toList()
        : orderedPoints;

    debugPrint('✅ Puntos finales a guardar: ${finalPoints.length}');

    // 5. Guardar ruta en SQLite (actualmente solo logging, puedes guardar si necesitas)
    await _saveStandardRouteToSQLite(config, finalPoints);

    debugPrint('✅ Ruta estándar procesada y guardada para HQ: $idHeadquarter');
  }

  /// Cargar puntos virtuales desde SQLite
  Future<List<VirtualPoint>> _loadVirtualPointsFromSQLite(
      int idHeadquarter) async {
    final dbPath = await _getDatabasePath();
    final db = await openDatabase(dbPath);

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Virtual_points',
        where: 'Id_headquarter = ? AND Is_active = ?',
        whereArgs: [idHeadquarter, 1],
        orderBy: 'Line_number ASC, Point_number ASC',
      );

      return maps.map((map) => VirtualPoint.fromMap(map)).toList();
    } finally {
      await db.close();
    }
  }

  /// Ordenar puntos según el patrón seleccionado
  List<VirtualPoint> _orderVirtualPoints(
    List<VirtualPoint> points,
    RouteConfig config,
  ) {
    switch (config.pattern) {
      case RoutePattern.lineaRecta:
        return _orderStraightLine(points, config.startLine, config.startPoint);
      case RoutePattern.zigzagSimple:
        return _orderZigzagSimple(points, config.startLine, config.startPoint);
      case RoutePattern.zigzagSerpentina:
        return _orderZigzagSerpentina(
            points, config.startLine, config.startPoint);
      case RoutePattern.zigzagEspiral:
        return _orderZigzagEspiral(points, config.startLine, config.startPoint);
      case RoutePattern.rutaOptimizada:
        // Este caso no debería llegar aquí
        return points;
    }
  }

  /// Guardar ruta estándar en SQLite (opcional)
  Future<void> _saveStandardRouteToSQLite(
    RouteConfig config,
    List<VirtualPoint> orderedPoints,
  ) async {
    // Aquí puedes implementar el guardado si necesitas persistir la ruta ordenada
    // Por ahora solo hacemos logging
    debugPrint(
        '💾 Ruta ordenada lista para usar: ${orderedPoints.length} puntos');

    // Ejemplo: guardar orden de puntos en una tabla auxiliar
    // final dbPath = await _getDatabasePath();
    // final db = await openDatabase(dbPath);
    // ... guardar orden ...
  }

  Future<void> _saveOptimizedRouteToSQLite(
      RouteConfig config, dynamic routeData, int idHeadquarter) async {
    final dbPath = await _getDatabasePath();
    final db = await openDatabase(dbPath);

    try {
      final parsedData =
          routeData is String ? jsonDecode(routeData) : routeData;

      // Extraer metadata de route_metadata
      final routeMetadata = parsedData['route_metadata'] ?? {};
      final warnings = parsedData['warnings'];
      String warningsString = '';
      if (warnings is List) {
        warningsString = warnings.join('; ');
      }

      // Guardar metadata de la ruta optimizada
      final int routeId = await db.insert('Optimized_routes', {
        'Id_headquarter': idHeadquarter,
        'Start_line': config.startLine,
        'Start_point': config.startPoint,
        'Max_lines': config.maxLines ?? 0,
        'Max_points': config.maxPoints ?? 0,
        'Average_speed_kmh': routeMetadata['average_speed_kmh'] ?? 4.14,
        'Time_limit_seconds': 30,
        'Optimization_strategy': 'GuidedLocalSearch',
        'Apply_exclusion_zones': 1,
        'Total_distance_km': parsedData['total_distance_km'] ?? 0.0,
        'Estimated_duration': parsedData['estimated_duration'] ?? '0',
        'Estimated_duration_seconds':
            parsedData['estimated_duration_seconds'] ?? 0,
        'Excluded_points_count': parsedData['excluded_points_count'] ?? 0,
        'Algorithm': parsedData['algorithm'] ?? '',
        'Strategy_used': parsedData['strategy_used'] ?? '',
        'Optimization_time_seconds':
            parsedData['optimization_time_seconds'] ?? 0.0,
        'Total_lines': routeMetadata['total_lines'] ?? 0,
        'Lines_in_range': jsonEncode(routeMetadata['lines_in_range'] ?? []),
        'Start_location': routeMetadata['start_location'] ?? '',
        'End_location': routeMetadata['end_location'] ?? '',
        'Improvement_percentage':
            routeMetadata['improvement_percentage'] ?? 0.0,
        'Solution_quality': routeMetadata['solution_quality'] ?? '',
        'Warnings': warningsString,
        'Created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
          '✅ Ruta optimizada guardada en SQLite con ID: $routeId para HQ: $idHeadquarter');

      // Guardar puntos de la ruta en Optimized_route_points
      if (parsedData['ordered_points'] != null &&
          parsedData['ordered_points'] is List) {
        final routePoints = parsedData['ordered_points'] as List;

        if (routePoints.isNotEmpty) {
          final batch = db.batch();

          for (int i = 0; i < routePoints.length; i++) {
            final point = routePoints[i];

            batch.insert('Optimized_route_points', {
              'Id_optimized_route': routeId,
              'Id_virtual_point': point['id'] ?? 0,
              'Line_number': point['line_number'] ?? 0,
              'Point_number': point['point_number'] ?? 0,
              'Latitude': point['latitude'] ?? 0.0,
              'Longitude': point['longitude'] ?? 0.0,
              'Id_type_point': point['id_type_point'],
              'Route_position': point['route_position'] ?? (i + 1),
              'Distance_to_next_meters': point['distance_to_next_meters'],
              'Time_to_next': point['time_to_next'],
            });
          }

          await batch.commit(noResult: true);
          debugPrint('✅ ${routePoints.length} puntos de ruta guardados');
        }
      }
    } finally {
      await db.close();
    }
  }

  Future<String> _getDatabasePath() async {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    final String pathStr = '${baseDir.path}/ClickPalmData';
    return path.join(pathStr, 'clickpalm_database.db');
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // MÉTODOS DE UI
  // ==========================================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FlutterFlowTheme.of(context).success,
                FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: FlutterFlowTheme.of(context).info,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Datos Cargados!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).info,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _totalHeadquarters > 1
                    ? 'Los datos de $_totalHeadquarters lotes se han\ncargado correctamente en la base de datos local'
                    : 'Los datos se han cargado correctamente\nen la base de datos local',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Cerrar formulario

                  // Redirigir según el tipo de actividad
                  _navigateToActivityPage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).info,
                  foregroundColor: FlutterFlowTheme.of(context).success,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeAllAndExit() {
    debugPrint('🔙 Cerrando todos los popups/dialogs y saliendo...');

    // Cerrar todos los diálogos, popups, drawers y bottom sheets abiertos
    // hasta llegar a la ruta que no sea un popup/dialog
    Navigator.of(context).popUntil((route) {
      // Si la ruta actual es este widget, cerrarlo también
      return route.isFirst || !route.willHandlePopInternally;
    });

    // Cerrar este widget
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    debugPrint('✅ Navegación cerrada completamente');
  }

  void _navigateToActivityPage() {
    try {
      // Obtener el JSON de la actividad seleccionada del AppState
      final activitySelectedJSON = FFAppState().activitySelectedJSON;

      // Obtener el tipo de actividad
      String? typeActivity;
      if (activitySelectedJSON is Map) {
        typeActivity = activitySelectedJSON['type_activity'] as String?;
      } else if (activitySelectedJSON is String) {
        // Si es un string, parsearlo
        final parsedJson = jsonDecode(activitySelectedJSON);
        typeActivity = parsedJson['type_activity'] as String?;
      }

      debugPrint('🔍 Type Activity: $typeActivity');

      // Navegar según el tipo de actividad
      if (typeActivity != null && typeActivity == 'FORMULARIO') {
        debugPrint('➡️ Navegando a DoVisitsFormPage');
        context.pushNamed('DoVisitsFormPage');
      } else {
        debugPrint('➡️ Navegando a DoVisitsActivityPage');
        context.pushNamed('DoVisitsActivityPage');
      }
    } catch (e) {
      debugPrint('❌ Error en navegación: $e');
      // Si hay error, navegar a la página por defecto
      context.pushNamed('DoVisitsActivityPage');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline,
                color: FlutterFlowTheme.of(context).error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: FlutterFlowTheme.of(context).secondaryText,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: Text(
              'Cerrar',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).info,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

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
      child: _isLoadingData ? _buildLoadingScreen() : _buildFormScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).secondary,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animación de carga
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Círculo exterior pulsante
                    Container(
                      width: 120 + (value * 20),
                      height: 120 + (value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.1 * (1 - value)),
                      ),
                    ),
                    // Círculo medio
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).info),
                          strokeWidth: 4,
                        ),
                      ),
                    ),
                  ],
                );
              },
              onEnd: () {
                setState(() {}); // Reiniciar animación
              },
            ),
            const SizedBox(height: 40),
            // Mensaje de carga animado
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(_loadingStep),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _loadingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).info,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Indicador de progreso
            Container(
              width: 240,
              height: 6,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: List.generate(_loadingMessages.length, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _loadingStep
                            ? FlutterFlowTheme.of(context).info
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Paso ${_loadingStep + 1} de ${_loadingMessages.length}',
              style: TextStyle(
                fontSize: 12,
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            // Mostrar progreso de headquarters si hay múltiples
            if (_totalHeadquarters > 1) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          color: FlutterFlowTheme.of(context).info,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lote $_currentHeadquarterIndex de $_totalHeadquarters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FlutterFlowTheme.of(context).info,
                          ),
                        ),
                      ],
                    ),
                    if (_currentHeadquarterName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _currentHeadquarterName,
                        style: TextStyle(
                          fontSize: 12,
                          color: FlutterFlowTheme.of(context)
                              .info
                              .withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormScreen() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_animationController),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('📍 Punto de Inicio'),
                          const SizedBox(height: 16),
                          _buildStartPointInputs(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('🎯 Límites (Opcional)'),
                          const SizedBox(height: 16),
                          _buildLimitsInputs(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('🗺️ Tipo de Recorrido'),
                          const SizedBox(height: 16),
                          _buildPatternSelector(),
                          const SizedBox(height: 40),
                          _buildGenerateButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              Icons.route,
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
                  'Configuración de Recorrido',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Programa el recorrido ideal',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeAllAndExit,
            icon: Icon(Icons.close, color: FlutterFlowTheme.of(context).info),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: FlutterFlowTheme.of(context).primaryText,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStartPointInputs() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _startLineController,
            label: 'Línea Inicial',
            hint: 'ej: 1',
            icon: Icons.horizontal_rule,
            color: FlutterFlowTheme.of(context).primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTextField(
            controller: _startPointController,
            label: 'Punto Inicial',
            hint: 'ej: 1',
            icon: Icons.place,
            color: FlutterFlowTheme.of(context).secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLimitsInputs() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _maxLinesController,
            label: 'Max Líneas',
            hint: 'Sin límite',
            icon: Icons.view_stream,
            color: const Color(0xFF10B981),
            required: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTextField(
            controller: _maxPointsController,
            label: 'Max Puntos',
            hint: 'Sin límite',
            icon: Icons.pin_drop,
            color: const Color(0xFF059669),
            required: false,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    bool required = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context)
                .primaryText
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FlutterFlowTheme.of(context).primaryText,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          labelStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: FlutterFlowTheme.of(context).secondaryText,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Requerido';
          }
          if (value != null && value.isNotEmpty) {
            final num = int.tryParse(value);
            if (num == null || num < 1) {
              return 'Inválido';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPatternSelector() {
    return Column(
      children: RoutePattern.values.map((pattern) {
        final isSelected = _selectedPattern == pattern;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPattern = pattern;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FlutterFlowTheme.of(context).primary,
                        FlutterFlowTheme.of(context).secondary,
                      ],
                    )
                  : null,
              color: isSelected
                  ? null
                  : FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : FlutterFlowTheme.of(context).alternate,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: FlutterFlowTheme.of(context)
                            .primaryText
                            .withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.2)
                        : FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    pattern.icon,
                    color: isSelected
                        ? FlutterFlowTheme.of(context).info
                        : FlutterFlowTheme.of(context).primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pattern.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? FlutterFlowTheme.of(context).info
                              : FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pattern.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? FlutterFlowTheme.of(context)
                                  .info
                                  .withValues(alpha: 0.8)
                              : FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).success,
            FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateAndLoadData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      FlutterFlowTheme.of(context).info),
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generar y Cargar Datos',
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
    );
  }

  // ==========================================================================
  // MÉTODOS DE ORDENAMIENTO DE RUTAS
  // ==========================================================================

  /// Ordenamiento: Línea Recta
  /// Recorre LÍNEA 1 completa, luego LÍNEA 2 completa, luego LÍNEA 3, etc.
  /// Al terminar cada línea, se conecta al punto más cercano de la línea siguiente
  List<VirtualPoint> _orderStraightLine(
      List<VirtualPoint> points, int startLine, int startPoint) {
    if (points.isEmpty) return [];

    // Agrupar por línea
    final lineGroups = <int, List<VirtualPoint>>{};
    for (var point in points) {
      lineGroups.putIfAbsent(point.lineNumber, () => []).add(point);
    }

    // Ordenar puntos dentro de cada línea
    lineGroups.forEach((line, linePoints) {
      linePoints.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    });

    final result = <VirtualPoint>[];
    final availableLines = lineGroups.keys.toList()..sort();

    debugPrint('🔍 _orderStraightLine: Líneas disponibles: $availableLines');

    // Recorrer líneas en orden secuencial
    for (int i = 0; i < availableLines.length; i++) {
      final lineNumber = availableLines[i];
      if (!lineGroups.containsKey(lineNumber)) continue;

      final linePoints = lineGroups[lineNumber]!;

      // Si es la primera línea (startLine), empezar desde startPoint
      if (result.isEmpty && lineNumber == startLine) {
        final validPoints =
            linePoints.where((p) => p.pointNumber >= startPoint).toList();
        result.addAll(validPoints);
        debugPrint(
            '   ✅ Primera línea (L$lineNumber): agregados ${validPoints.length} puntos');
      } else if (result.isNotEmpty || lineNumber > startLine) {
        // Determinar dirección basándonos en el último punto agregado
        final lastAddedPoint = result.last;
        final lastPointNumber = lastAddedPoint.pointNumber;

        final firstPointOfLine = linePoints.first.pointNumber;
        final lastPointOfLine = linePoints.last.pointNumber;

        final distToFirst = (lastPointNumber - firstPointOfLine).abs();
        final distToLast = (lastPointNumber - lastPointOfLine).abs();

        // Agregar línea en la dirección que minimiza distancia
        if (distToFirst <= distToLast) {
          result.addAll(linePoints);
        } else {
          result.addAll(linePoints.reversed);
        }
      }
    }

    debugPrint(
        '✅ _orderStraightLine completado: ${result.length} puntos totales');

    return result;
  }

  /// Ordenamiento: Zigzag Simple
  /// Alterna entre 2 líneas, punto por punto
  List<VirtualPoint> _orderZigzagSimple(
      List<VirtualPoint> points, int startLine, int startPoint) {
    if (points.isEmpty) return [];

    // Agrupar por línea
    final lineGroups = <int, List<VirtualPoint>>{};
    for (var point in points) {
      lineGroups.putIfAbsent(point.lineNumber, () => []).add(point);
    }

    // Ordenar puntos dentro de cada línea
    lineGroups.forEach((line, linePoints) {
      linePoints.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    });

    final result = <VirtualPoint>[];
    final availableLines = lineGroups.keys.toList()..sort();

    debugPrint('🔍 _orderZigzagSimple: Líneas disponibles: $availableLines');

    // Alternar entre pares de líneas
    int currentLineIndex = availableLines.indexOf(startLine);
    if (currentLineIndex == -1) {
      debugPrint('   ⚠️ startLine $startLine no encontrada');
      return result;
    }

    bool reverseNextPair = false;

    while (currentLineIndex < availableLines.length) {
      final line1 = availableLines[currentLineIndex];
      final line2Index = currentLineIndex + 1;

      if (!lineGroups.containsKey(line1)) {
        currentLineIndex += 2;
        continue;
      }

      var line1Points = lineGroups[line1]!;
      var line2Points = (line2Index < availableLines.length &&
              lineGroups.containsKey(availableLines[line2Index]))
          ? lineGroups[availableLines[line2Index]]!
          : <VirtualPoint>[];

      // Si debemos invertir el par
      if (reverseNextPair) {
        line1Points = line1Points.reversed.toList();
        if (line2Points.isNotEmpty) {
          line2Points = line2Points.reversed.toList();
        }
      }

      // Encontrar el máximo de puntos entre ambas líneas
      final maxPoints = line1Points.length > line2Points.length
          ? line1Points.length
          : line2Points.length;

      // Alternar punto por punto
      for (int i = 0; i < maxPoints; i++) {
        final startOffset =
            (result.isEmpty && line1 == startLine && !reverseNextPair)
                ? startPoint - 1
                : 0;

        // Agregar punto de línea 1
        if (i + startOffset < line1Points.length && i >= startOffset) {
          result.add(line1Points[i + startOffset]);
        }

        // Agregar punto de línea 2
        if (line2Points.isNotEmpty && i < line2Points.length) {
          result.add(line2Points[i]);
        }
      }

      // Alternar dirección para el siguiente par
      reverseNextPair = !reverseNextPair;

      // Avanzar al siguiente par de líneas
      currentLineIndex += 2;
    }

    debugPrint(
        '✅ _orderZigzagSimple completado: ${result.length} puntos totales');

    return result;
  }

  /// Ordenamiento: Zigzag Serpentina
  /// Recorre cada línea completa alternando dirección
  List<VirtualPoint> _orderZigzagSerpentina(
      List<VirtualPoint> points, int startLine, int startPoint) {
    if (points.isEmpty) return [];

    // Agrupar por línea
    final lineGroups = <int, List<VirtualPoint>>{};
    for (var point in points) {
      lineGroups.putIfAbsent(point.lineNumber, () => []).add(point);
    }

    // Ordenar puntos dentro de cada línea
    lineGroups.forEach((line, linePoints) {
      linePoints.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    });

    final result = <VirtualPoint>[];
    final availableLines = lineGroups.keys.toList()..sort();

    // Recorrer líneas secuencialmente, alternando dirección
    bool goingForward = true;

    for (var lineNumber in availableLines) {
      final linePoints = lineGroups[lineNumber]!;

      // Si es la primera línea (startLine), empezar desde startPoint
      if (result.isEmpty && lineNumber == startLine) {
        final validPoints =
            linePoints.where((p) => p.pointNumber >= startPoint).toList();

        if (goingForward) {
          result.addAll(validPoints);
        } else {
          result.addAll(validPoints.reversed);
        }

        goingForward = !goingForward;
      } else if (result.isNotEmpty || lineNumber > startLine) {
        // Agregar línea completa en la dirección correspondiente
        if (goingForward) {
          result.addAll(linePoints);
        } else {
          result.addAll(linePoints.reversed);
        }

        goingForward = !goingForward;
      }
    }

    debugPrint(
        '✅ _orderZigzagSerpentina completado: ${result.length} puntos totales');

    return result;
  }

  /// Ordenamiento: Zigzag Espiral
  /// Empieza en un punto específico y se expande en todas direcciones
  List<VirtualPoint> _orderZigzagEspiral(
      List<VirtualPoint> points, int startLine, int startPoint) {
    if (points.isEmpty) return [];

    // Agrupar por línea
    final lineGroups = <int, List<VirtualPoint>>{};
    for (var point in points) {
      lineGroups.putIfAbsent(point.lineNumber, () => []).add(point);
    }

    // Ordenar puntos dentro de cada línea
    lineGroups.forEach((line, linePoints) {
      linePoints.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    });

    final result = <VirtualPoint>[];
    final visited = <String>{}; // "lineNumber:pointNumber"
    final allLines = lineGroups.keys.toList()..sort();

    debugPrint('🕸️ Zigzag Espiral: Inicio en L${startLine}P${startPoint}');

    // Función auxiliar para marcar y agregar punto
    void addPoint(int line, int pointNum) {
      final key = '$line:$pointNum';
      if (visited.contains(key)) return;

      if (lineGroups.containsKey(line)) {
        final linePoints = lineGroups[line]!;
        final point = linePoints.firstWhere(
          (p) => p.pointNumber == pointNum,
          orElse: () => linePoints.first,
        );

        if (point.pointNumber == pointNum) {
          result.add(point);
          visited.add(key);
        }
      }
    }

    // Obtener rango de puntos por línea
    final pointRanges = <int, List<int>>{};
    lineGroups.forEach((line, linePoints) {
      pointRanges[line] = linePoints.map((p) => p.pointNumber).toList();
    });

    // Agregar punto inicial
    addPoint(startLine, startPoint);

    // Expandir en anillos concéntricos
    int maxRadius = 100;
    for (int radius = 1; radius <= maxRadius; radius++) {
      int addedInRadius = 0;

      // Líneas hacia arriba y abajo
      final linesToCheck = <int>[];

      if (allLines.contains(startLine + radius)) {
        linesToCheck.add(startLine + radius);
      }

      if (radius > 0 && allLines.contains(startLine - radius)) {
        linesToCheck.add(startLine - radius);
      }

      // Para cada línea en este radio, expandir puntos horizontalmente
      for (var line in linesToCheck) {
        if (!lineGroups.containsKey(line)) continue;
        final availablePoints = pointRanges[line]!;

        for (int pOffset = 0; pOffset <= radius; pOffset++) {
          final rightPoint = startPoint + pOffset;
          if (availablePoints.contains(rightPoint)) {
            final key = '$line:$rightPoint';
            if (!visited.contains(key)) {
              addPoint(line, rightPoint);
              addedInRadius++;
            }
          }

          if (pOffset > 0) {
            final leftPoint = startPoint - pOffset;
            if (availablePoints.contains(leftPoint)) {
              final key = '$line:$leftPoint';
              if (!visited.contains(key)) {
                addPoint(line, leftPoint);
                addedInRadius++;
              }
            }
          }
        }
      }

      // Cubrir puntos en la línea inicial que estén en este radio
      if (radius <= maxRadius && lineGroups.containsKey(startLine)) {
        final availablePoints = pointRanges[startLine]!;

        final rightPoint = startPoint + radius;
        if (availablePoints.contains(rightPoint)) {
          final key = '$startLine:$rightPoint';
          if (!visited.contains(key)) {
            addPoint(startLine, rightPoint);
            addedInRadius++;
          }
        }

        final leftPoint = startPoint - radius;
        if (availablePoints.contains(leftPoint)) {
          final key = '$startLine:$leftPoint';
          if (!visited.contains(key)) {
            addPoint(startLine, leftPoint);
            addedInRadius++;
          }
        }
      }

      if (addedInRadius == 0 && radius > 10) {
        debugPrint('   🛑 Radio $radius sin puntos, deteniendo');
        break;
      }
    }

    debugPrint('✅ Zigzag Espiral completado: ${result.length} puntos totales');

    return result;
  }
}
