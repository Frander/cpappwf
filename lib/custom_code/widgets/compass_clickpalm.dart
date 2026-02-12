// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart';
import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom widget code

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// ============================================================================
// CLASES DE DATOS
// ============================================================================

class CompassVirtualPoint {
  final int id;
  final int lineNumber;
  final int pointNumber;
  final double latitude;
  final double longitude;
  final String? description;

  CompassVirtualPoint({
    required this.id,
    required this.lineNumber,
    required this.pointNumber,
    required this.latitude,
    required this.longitude,
    this.description,
  });
}

class CardinalDirection {
  final String direction;
  final CompassVirtualPoint? point;
  final double distanceMeters;
  final double bearing; // Rumbo desde el usuario al punto

  CardinalDirection({
    required this.direction,
    this.point,
    this.distanceMeters = 0.0,
    this.bearing = 0.0,
  });

  String getDirectionLabel() {
    switch (direction) {
      case 'N':
        return 'NORTE';
      case 'S':
        return 'SUR';
      case 'E':
        return 'ESTE';
      case 'O':
        return 'OESTE';
      default:
        return 'N/A';
    }
  }
}

class CurrentLocationDisplay {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? battery;

  CurrentLocationDisplay({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.battery,
  });

  String get formattedLatitude => latitude.toStringAsFixed(5);
  String get formattedLongitude => longitude.toStringAsFixed(5);
  String get formattedCoordinates => '$formattedLatitude, $formattedLongitude';
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class CompassClickpalm extends StatefulWidget {
  const CompassClickpalm({
    super.key,
    this.width,
    this.height,
    this.idHeadquarter,
  });

  final double? width;
  final double? height;
  final int? idHeadquarter;

  @override
  State<CompassClickpalm> createState() => _CompassClickpalmState();
}

class _CompassClickpalmState extends State<CompassClickpalm>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Estado de ubicación actual
  CurrentLocationDisplay? _currentLocation;
  List<CompassVirtualPoint> _virtualPoints = [];
  Map<String, CardinalDirection> _cardinalDirections = {
    'N': CardinalDirection(direction: 'N'),
    'S': CardinalDirection(direction: 'S'),
    'E': CardinalDirection(direction: 'E'),
    'O': CardinalDirection(direction: 'O'),
  };

  // Timer de actualización
  Timer? _updateTimer;

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _directionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _directionAnimation;

  // Control de carga
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _directionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _directionAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _directionController, curve: Curves.easeInOut),
    );

    // Cargar datos iniciales
    _initializeCompass();

    // Listener para actualizaciones de AppState cada 1.5s
    FFAppState().addListener(_onLocationUpdate);

    // Timer de actualización de brújula
    _updateTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
        _updateCompassData();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    _directionController.dispose();
    FFAppState().removeListener(_onLocationUpdate);
    super.dispose();
  }

  /// Inicializa los datos del compass
  Future<void> _initializeCompass() async {
    try {
      // Cargar puntos virtuales desde SQLite
      await _loadVirtualPoints();

      // Actualizar posición actual
      await _updateCompassData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error inicializando compass: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inicializando brújula: $e';
      });
    }
  }

  /// Carga los puntos virtuales desde SQLite
  Future<void> _loadVirtualPoints() async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }

      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');

      final database = await openDatabase(dbPath);

      String query = '''
        SELECT DISTINCT
          vp.Id_virtual_point,
          vp.Line_number,
          vp.Point_number,
          vp.Latitude,
          vp.Longitude,
          vp.Description
        FROM Virtual_points vp
      ''';

      // Si se especifica un headquarter, filtrar por ese
      if (widget.idHeadquarter != null) {
        query += ' WHERE vp.Id_headquarter = ${widget.idHeadquarter}';
      }

      query += ' ORDER BY vp.Line_number, vp.Point_number';

      final List<Map<String, dynamic>> results = await database.rawQuery(query);
      await database.close();

      setState(() {
        _virtualPoints = results.map((row) {
          return CompassVirtualPoint(
            id: row['Id_virtual_point'] as int,
            lineNumber: row['Line_number'] as int? ?? 0,
            pointNumber: row['Point_number'] as int? ?? 0,
            latitude: (row['Latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (row['Longitude'] as num?)?.toDouble() ?? 0.0,
            description: row['Description'] as String?,
          );
        }).toList();
      });

      debugPrint('✅ Cargados ${_virtualPoints.length} puntos virtuales');
    } catch (e) {
      debugPrint('❌ Error cargando puntos virtuales: $e');
    }
  }

  /// Listener para cambios en AppState
  void _onLocationUpdate() {
    if (mounted) {
      _updateCompassData();
    }
  }

  /// Actualiza los datos del compass con la ubicación actual
  Future<void> _updateCompassData() async {
    try {
      // Obtener ubicación actual desde AppState
      final geoLocations = FFAppState().geoLocationsList;

      if (geoLocations.isEmpty) {
        // Intenta SQLite como fallback
        await _loadFromSQLite();
        return;
      }

      final lastGeo = geoLocations.last;

      setState(() {
        _currentLocation = CurrentLocationDisplay(
          latitude: lastGeo.latitude,
          longitude: lastGeo.longitude,
          timestamp: DateTime.now(),
          battery: null, // ReadGeoStruct no tiene campo battery
        );
      });

      // Calcular puntos cardinales
      await _calculateCardinalDirections();
    } catch (e) {
      debugPrint('❌ Error actualizando compass: $e');
    }
  }

  /// Fallback a SQLite si AppState no tiene datos
  Future<void> _loadFromSQLite() async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;

      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');
      final database = await openDatabase(dbPath);

      final List<Map<String, dynamic>> results = await database.rawQuery('''
        SELECT Latitude, Longitude, Battery
        FROM Location_tracking
        ORDER BY CreatedAt DESC
        LIMIT 1
      ''');

      await database.close();

      if (results.isNotEmpty) {
        setState(() {
          _currentLocation = CurrentLocationDisplay(
            latitude: (results[0]['Latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (results[0]['Longitude'] as num?)?.toDouble() ?? 0.0,
            timestamp: DateTime.now(),
            battery: (results[0]['Battery'] as num?)?.toDouble(),
          );
        });

        await _calculateCardinalDirections();
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando desde SQLite: $e');
    }
  }

  /// Calcula los puntos más cercanos en cada dirección cardinal
  Future<void> _calculateCardinalDirections() async {
    if (_currentLocation == null || _virtualPoints.isEmpty) return;

    try {
      final current = _currentLocation!;

      // Para cada punto virtual, calcular su bearing y distancia
      final pointsWithInfo = _virtualPoints.map((vp) {
        final distance = _calculateHaversineDistance(
          current.latitude,
          current.longitude,
          vp.latitude,
          vp.longitude,
        );

        final bearing = _calculateBearing(
          current.latitude,
          current.longitude,
          vp.latitude,
          vp.longitude,
        );

        return {
          'point': vp,
          'distance': distance,
          'bearing': bearing,
        };
      }).toList();

      // Agrupar por dirección cardinal más cercana
      final Map<String, CardinalDirection> newDirections = {
        'N': CardinalDirection(direction: 'N'),
        'S': CardinalDirection(direction: 'S'),
        'E': CardinalDirection(direction: 'E'),
        'O': CardinalDirection(direction: 'O'),
      };

      // Asignar puntos a cada dirección cardinal (rango de ±45°)
      for (var item in pointsWithInfo) {
        final bearing = item['bearing'] as double;
        final distance = item['distance'] as double;
        final point = item['point'] as CompassVirtualPoint;

        String closestDirection = _getNormalizeBearing(bearing);

        final current = newDirections[closestDirection]!;

        // Si no hay punto o este está más cerca, actualizar
        if (current.point == null ||
            distance < current.distanceMeters) {
          newDirections[closestDirection] = CardinalDirection(
            direction: closestDirection,
            point: point,
            distanceMeters: distance,
            bearing: bearing,
          );
        }
      }

      setState(() {
        _cardinalDirections = newDirections;
      });

      debugPrint(
          '🧭 Brújula actualizada: N(${newDirections['N']!.distanceMeters.toStringAsFixed(0)}m) S(${newDirections['S']!.distanceMeters.toStringAsFixed(0)}m) E(${newDirections['E']!.distanceMeters.toStringAsFixed(0)}m) O(${newDirections['O']!.distanceMeters.toStringAsFixed(0)}m)');
    } catch (e) {
      debugPrint('❌ Error calculando direcciones cardinales: $e');
    }
  }

  /// Normaliza el bearing a dirección cardinal (N, S, E, O)
  /// N: 337.5° - 22.5° | E: 67.5° - 112.5° | S: 157.5° - 202.5° | O: 247.5° - 292.5°
  String _getNormalizeBearing(double bearing) {
    // Normalizar bearing a 0-360
    final normalized = ((bearing % 360) + 360) % 360;

    if (normalized >= 337.5 || normalized < 22.5) {
      return 'N';
    } else if (normalized >= 67.5 && normalized < 112.5) {
      return 'E';
    } else if (normalized >= 157.5 && normalized < 202.5) {
      return 'S';
    } else if (normalized >= 247.5 && normalized < 292.5) {
      return 'O';
    }

    // Si no está en rango cardinal exacto, encontrar el más cercano
    final distances = {
      'N': _bearingDistance(normalized, 0),
      'E': _bearingDistance(normalized, 90),
      'S': _bearingDistance(normalized, 180),
      'O': _bearingDistance(normalized, 270),
    };

    // Retornar la dirección con menor distancia
    return distances.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  /// Calcula la distancia angular entre dos bearings
  double _bearingDistance(double b1, double b2) {
    double diff = ((b2 - b1) % 360 + 360) % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  /// Calcula la distancia Haversine entre dos puntos en metros
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0; // Radio de la Tierra en metros
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Calcula el bearing (rumbo) entre dos puntos
  /// Retorna un ángulo de 0° a 360° donde 0° es Norte
  double _calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return ((bearing % 360) + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage ?? 'Error desconocido',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: FlutterFlowTheme.of(context).primaryBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Título simple
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Text(
                'BRÚJULA',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 2,
                ),
              ),
            ),

            // Brújula circular
            Expanded(
              child: Center(
                child: _buildCompassCircle(),
              ),
            ),

            // Información de ubicación al pie
            if (_currentLocation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildLocationInfoSilent(),
              ),
          ],
        ),
      ),
    );
  }

  /// Brújula circular estilo brújula real
  Widget _buildCompassCircle() {
    const double compassSize = 340;

    return SizedBox(
      width: compassSize,
      height: compassSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // CustomPaint para dibujar líneas indicadoras hacia cada punto
          CustomPaint(
            size: const Size(compassSize, compassSize),
            painter: _CompassPainter(
              directions: _cardinalDirections,
            ),
          ),

          // Fondo del compass (círculo exterior)
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: compassSize,
              height: compassSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),

          // Círculo interior más oscuro
          Container(
            width: compassSize * 0.95,
            height: compassSize * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[900]?.withOpacity(0.3),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),

          // Líneas de cruz suave (N-S, E-O)
          Container(
            width: compassSize * 0.6,
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
          Container(
            width: 1,
            height: compassSize * 0.6,
            color: Colors.white.withOpacity(0.08),
          ),

          // 4 direcciones cardinales (N, S, E, O) en los bordes
          _buildCompassDirection('N', _cardinalDirections['N']!, 0),
          _buildCompassDirection('S', _cardinalDirections['S']!, 180),
          _buildCompassDirection('E', _cardinalDirections['E']!, 90),
          _buildCompassDirection('O', _cardinalDirections['O']!, 270),

          // Centro: ubicación actual con detalles
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800]?.withOpacity(0.5),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.my_location,
                  color: Colors.white.withOpacity(0.6),
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'TÚ',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                if (_currentLocation != null) ...[
                  Text(
                    _currentLocation!.formattedLatitude,
                    style: TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  Text(
                    _currentLocation!.formattedLongitude,
                    style: TextStyle(
                      fontFamily: 'Roboto Mono',
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renderiza una dirección cardinal con su punto más cercano
  Widget _buildCompassDirection(
    String direction,
    CardinalDirection cardinal,
    double angleInDegrees,
  ) {
    final angleInRadians = (angleInDegrees * math.pi) / 180;
    const double radius = 145; // Distancia del centro

    final dx = radius * math.sin(angleInRadians);
    final dy = -radius * math.cos(angleInRadians);

    final hasPoint = cardinal.point != null;

    // Formatear distancia (km si >= 1000m, sino en m)
    String distanceLabel = '';
    if (hasPoint) {
      if (cardinal.distanceMeters >= 1000) {
        distanceLabel = '${(cardinal.distanceMeters / 1000).toStringAsFixed(1)}km';
      } else {
        distanceLabel = '${cardinal.distanceMeters.toStringAsFixed(0)}m';
      }
    }

    return Positioned(
      left: 170 + dx - 35,
      top: 170 + dy - 45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Letra cardinal
          Text(
            direction,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.3),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),

          // Información del punto
          if (hasPoint) ...[
            Text(
              'L${cardinal.point!.lineNumber}P${cardinal.point!.pointNumber}',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              distanceLabel,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ] else ...[
            Text(
              '—',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Información de ubicación sutil
  Widget _buildLocationInfoSilent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentLocation!.formattedCoordinates,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_currentLocation!.battery != null)
            Text(
              'Batería: ${_currentLocation!.battery!.toStringAsFixed(0)}%',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER PARA INDICADORES DE DIRECCIÓN
// ============================================================================

class _CompassPainter extends CustomPainter {
  final Map<String, CardinalDirection> directions;

  _CompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final centerRadius = 50.0;
    const outerRadius = 135.0;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintArrow = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Ángulos para cada dirección cardinal
    final angles = {
      'N': 0,
      'E': 90,
      'S': 180,
      'O': 270,
    };

    // Dibujar líneas desde el centro hacia cada dirección cardinal
    angles.forEach((direction, angle) {
      final cardinal = directions[direction];
      if (cardinal == null || cardinal.point == null) return;

      final angleRad = (angle * math.pi) / 180;

      // Puntos inicio (exterior del círculo central) y fin (interior)
      final start = Offset(
        center.dx + centerRadius * math.sin(angleRad),
        center.dy - centerRadius * math.cos(angleRad),
      );

      final end = Offset(
        center.dx + outerRadius * math.sin(angleRad),
        center.dy - outerRadius * math.cos(angleRad),
      );

      // Dibujar línea
      canvas.drawLine(start, end, paint);

      // Dibujar pequeña flecha en la punta
      final arrowSize = 8.0;
      final arrowAngle1 =
          angleRad - (30 * math.pi / 180); // 30 grados a la izquierda
      final arrowAngle2 =
          angleRad + (30 * math.pi / 180); // 30 grados a la derecha

      final arrowPoint1 = Offset(
        end.dx + arrowSize * math.sin(arrowAngle1),
        end.dy - arrowSize * math.cos(arrowAngle1),
      );

      final arrowPoint2 = Offset(
        end.dx + arrowSize * math.sin(arrowAngle2),
        end.dy - arrowSize * math.cos(arrowAngle2),
      );

      // Dibujar triángulo de flecha
      canvas.drawLine(end, arrowPoint1, paintArrow);
      canvas.drawLine(end, arrowPoint2, paintArrow);
    });
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.directions != directions;
}
