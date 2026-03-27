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

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:pmtiles/pmtiles.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================================
// ENUMS Y CLASES DE DATOS
// ============================================================================

enum TimeFilter {
  minutes5('5 min', Duration(minutes: 5)),
  minutes10('10 min', Duration(minutes: 10)),
  minutes20('20 min', Duration(minutes: 20)),
  minutes30('30 min', Duration(minutes: 30)),
  hour1('1 hora', Duration(hours: 1)),
  day1('1 día', Duration(days: 1)),
  all('Todos', null);

  final String label;
  final Duration? duration;

  const TimeFilter(this.label, this.duration);
}

class GeoLocation {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  final double? speed;
  final double? heading;

  GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
    this.speed,
    this.heading,
  });
}

class TypePointData {
  final int id;
  final String? name;
  final String? colorHex;
  final int? order;
  final int? virtualPointsCount;

  TypePointData({
    required this.id,
    this.name,
    this.colorHex,
    this.order,
    this.virtualPointsCount,
  });

  Color getColor() {
    if (colorHex == null || colorHex!.isEmpty) {
      return const Color(0xFFA855F7); // Color por defecto morado
    }
    try {
      String hex = colorHex!.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Agregar alpha si no tiene
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFFA855F7); // Color por defecto si hay error
    }
  }
}

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
  final String? headquarterName;
  final String? pointDisplayName;
  final TypePointData? typePoint;

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
    this.headquarterName,
    this.pointDisplayName,
    this.typePoint,
  });
}

// ============================================================================
// CLASES PARA SIMULACIÓN DE RECORRIDO
// ============================================================================

enum RoutePattern {
  lineaRecta,
  zigzagSimple,
  zigzagSerpentina,
  zigzagEspiral,
  rutaOptimizada, // Ruta optimizada usando Google OR-Tools del API
}

class RouteSimulationConfig {
  final int startLine;
  final int startPoint;
  final int? maxLines;
  final int? maxPoints;
  final RoutePattern pattern;
  final double errorMarginMeters;

  RouteSimulationConfig({
    required this.startLine,
    required this.startPoint,
    this.maxLines,
    this.maxPoints,
    required this.pattern,
    this.errorMarginMeters = 5.0,
  });
}

/// Representa una ruta guardada en SQLite
class SavedRoute {
  final int id;
  final int idHeadquarter;
  final int startLine;
  final int startPoint;
  final int maxLines;
  final int maxPoints;
  final String routePattern;
  final double? totalDistanceKm;
  final String? estimatedDuration;
  final String createdAt;

  SavedRoute({
    required this.id,
    required this.idHeadquarter,
    required this.startLine,
    required this.startPoint,
    required this.maxLines,
    required this.maxPoints,
    required this.routePattern,
    this.totalDistanceKm,
    this.estimatedDuration,
    required this.createdAt,
  });

  /// Nombre descriptivo de la ruta
  String get displayName {
    final patternNames = {
      'lineaRecta': 'Línea Recta',
      'zigzagSimple': 'Zigzag Simple',
      'zigzagSerpentina': 'Zigzag Serpentina',
      'zigzagEspiral': 'Zigzag Espiral',
      'rutaOptimizada': 'Ruta Optimizada',
    };

    final patternName = patternNames[routePattern] ?? routePattern;
    final maxLinesText = maxLines > 0 ? ', Máx. $maxLines líneas' : '';
    final maxPointsText = maxPoints > 0 ? ', Máx. $maxPoints palmas' : '';

    return '$patternName - Inicio: L$startLine P$startPoint$maxLinesText$maxPointsText';
  }

  /// Crear desde mapa de SQLite
  factory SavedRoute.fromMap(Map<String, dynamic> map) {
    return SavedRoute(
      id: map['Id_optimized_route'] as int,
      idHeadquarter: map['Id_headquarter'] as int,
      startLine: map['Start_line'] as int,
      startPoint: map['Start_point'] as int,
      maxLines: map['Max_lines'] as int? ?? 0,
      maxPoints: map['Max_points'] as int? ?? 0,
      routePattern: map['Route_pattern'] as String,
      totalDistanceKm: map['Total_distance_km'] as double?,
      estimatedDuration: map['Estimated_duration'] as String?,
      createdAt: map['Created_at'] as String,
    );
  }
}

/// Marca una zona de exclusión cercana a un punto de la ruta
class ExclusionZoneMarker {
  final int idPolygonCoordinate; // ID del Headquarter_coordinate
  final String
      namePolygonCoordinate; // Nombre de la zona (ej: "Zona Rocosa", "Pantano")
  final String? typePointName; // Tipo de punto (de Types_points)
  final int? idTypePoint; // ID del tipo de punto
  final TypePointData? typePoint; // Datos completos del tipo
  final double distanceMeters; // Distancia desde el punto actual a la zona
  final double latitude; // Ubicación aproximada del centroide de la zona
  final double longitude;

  ExclusionZoneMarker({
    required this.idPolygonCoordinate,
    required this.namePolygonCoordinate,
    this.typePointName,
    this.idTypePoint,
    this.typePoint,
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
  });
}

class SimulatedLocationPoint {
  final VirtualPoint currentVirtualPoint; // Punto virtual de referencia actual
  final VirtualPoint?
      nextVirtualPoint; // Siguiente punto virtual a visitar (null si es el último)
  final double simulatedLatitude; // Coordenada ficticia (GPS simulado)
  final double simulatedLongitude; // Coordenada ficticia (GPS simulado)
  final DateTime timestamp; // Timestamp real de creación
  final int sequenceNumber;

  // NUEVOS CAMPOS PARA REPRODUCCIÓN
  final DateTime simulatedTimestamp; // Hora ficticia (empieza 8:00 AM)
  final double walkingSpeedMps; // Velocidad de caminata en m/s (0.8-1.5)
  final double distanceToNextMeters; // Distancia al siguiente punto
  final Duration timeToNextPoint; // Tiempo calculado para llegar al siguiente

  // ZONAS DE EXCLUSIÓN CERCANAS (para anuncios de voz contextuales)
  final List<ExclusionZoneMarker> nearbyExclusionZones;

  SimulatedLocationPoint({
    required this.currentVirtualPoint,
    this.nextVirtualPoint,
    required this.simulatedLatitude,
    required this.simulatedLongitude,
    required this.timestamp,
    required this.sequenceNumber,
    required this.simulatedTimestamp,
    required this.walkingSpeedMps,
    required this.distanceToNextMeters,
    required this.timeToNextPoint,
    this.nearbyExclusionZones = const [],
  });
}

class ProductData {
  final int id;
  final int? idHeadquarter;
  final int? idCompany;
  final int? idType;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final String? typeProduct;
  final String? nameProduct;
  final String? rfid;
  final String? descriptionProduct;
  final String? state;
  final String? locationRaw;
  final int? line;
  final int? palm;
  final List<latlong.LatLng> coordinates;
  final TypePointData? typePoint;

  ProductData({
    required this.id,
    this.idHeadquarter,
    this.idCompany,
    this.idType,
    this.createdAt,
    this.modifiedAt,
    this.typeProduct,
    this.nameProduct,
    this.rfid,
    this.descriptionProduct,
    this.state,
    this.locationRaw,
    this.line,
    this.palm,
    required this.coordinates,
    this.typePoint,
  });
}

class CoordinateData {
  final int id;
  final int idHeadquarter;
  final String? name;
  final String? coordinatesRaw;
  final String? pointType;
  final int? idTypePoint;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final bool isActive;
  final List<latlong.LatLng>
      polygonPoints; // CAMBIADO: Lista de puntos para polígono
  final TypePointData? typePoint;

  CoordinateData({
    required this.id,
    required this.idHeadquarter,
    this.name,
    this.coordinatesRaw,
    this.pointType,
    this.idTypePoint,
    this.createdAt,
    this.modifiedAt,
    this.isActive = true,
    required this.polygonPoints, // CAMBIADO: Ahora es lista de puntos
    this.typePoint,
  });
}

class HeadquarterData {
  final int id;
  final int? idZone;
  final DateTime? createdAt;
  final String? name;
  final double? density;
  final String? seedTime;
  final String? state;
  final double? area;
  final String? polygon;
  final String? centroidCoordinate;
  final double? azimuth;
  final double? slopeAzimuthDirection;
  final double? slopeAzimuthPerpendicular;
  final double? horizontalPalmDistance;
  final double? verticalPalmDistance;
  final double? magneticDeclination;
  final double? customOriginLatitude;
  final double? customOriginLongitude;
  final bool hasPlants;

  HeadquarterData({
    required this.id,
    this.idZone,
    this.createdAt,
    this.name,
    this.density,
    this.seedTime,
    this.state,
    this.area,
    this.polygon,
    this.centroidCoordinate,
    this.azimuth,
    this.slopeAzimuthDirection,
    this.slopeAzimuthPerpendicular,
    this.horizontalPalmDistance,
    this.verticalPalmDistance,
    this.magneticDeclination,
    this.customOriginLatitude,
    this.customOriginLongitude,
    this.hasPlants = false,
  });
}

// ============================================================================
// CLASES PARA SISTEMA DE NAVEGACIÓN POR VOZ
// ============================================================================

enum NavigationState {
  idle, // Sin datos o muy lejos
  noMovement, // Usuario quieto
  approaching, // Acercándose (5-20m)
  nearPoint, // Cerca del punto (<5m)
  atPoint, // En el punto (<2m)
}

class NavigationEvent {
  final NavigationState state;
  final VirtualPoint? targetPoint;
  final double? distance;
  final String message;
  final DateTime timestamp;

  NavigationEvent({
    required this.state,
    this.targetPoint,
    this.distance,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class LocationData {
  final double latitude;
  final double longitude;
  final double speed; // m/s
  final double battery;
  final DateTime createdAt;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.battery,
    required this.createdAt,
  });
}

enum SpeechPriority { low, normal, high, critical }

class SpeechMessage {
  final String text;
  final SpeechPriority priority;
  final DateTime timestamp;

  SpeechMessage({
    required this.text,
    required this.priority,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================================
// SERVICIOS DE NAVEGACIÓN
// ============================================================================

/// Optimizador de búsqueda de proximidad con radio adaptativo estilo Waze
class ProximityOptimizer {
  VirtualPoint? _lastClosestPoint;
  double _lastDistance = double.infinity;
  int _missedUpdates = 0;
  double _lastSpeed = 0;

  // Historial de ubicaciones para detección de movimiento estilo Waze
  final List<LocationData> _locationHistory = [];
  static const int _maxHistorySize = 10;
  double _lastBearing = 0;
  DateTime? _lastMovementTime;
  bool _isMoving = false;

  // Getters para estado de movimiento
  bool get isMoving => _isMoving;
  double get lastBearing => _lastBearing;
  VirtualPoint? get lastClosestPoint => _lastClosestPoint;
  double get lastDistance => _lastDistance;

  /// Encuentra el punto virtual más cercano con búsqueda optimizada
  VirtualPoint? findClosestPoint(
    LocationData location,
    List<VirtualPoint> allPoints,
  ) {
    if (allPoints.isEmpty) return null;

    List<VirtualPoint> candidates;

    // ESTRATEGIA 1: Búsqueda incremental (si hay punto previo)
    if (_lastClosestPoint != null) {
      final searchRadius = _calculateAdaptiveRadius(location.speed);

      candidates = allPoints.where((vp) {
        return _calculateDistance(
              _lastClosestPoint!.latitude,
              _lastClosestPoint!.longitude,
              vp.latitude,
              vp.longitude,
            ) <=
            searchRadius;
      }).toList();

      // debugPrint('📍 Radio adaptativo: ${searchRadius.toInt()}m (speed: ${location.speed.toStringAsFixed(1)} m/s) → ${candidates.length} candidatos');
    } else {
      // Primera iteración: búsqueda completa
      candidates = allPoints;
      debugPrint('📍 Búsqueda inicial completa: ${candidates.length} puntos');
    }

    // FALLBACK: Si no hay candidatos, buscar en toda la lista
    if (candidates.isEmpty) {
      _missedUpdates++;
      debugPrint(
          '⚠️ Sin candidatos en radio. Fallback a búsqueda completa (miss #$_missedUpdates)');
      candidates = allPoints;
    }

    // Buscar el más cercano
    final stopwatch = Stopwatch()..start();
    final result = _findClosest(location, candidates);
    stopwatch.stop();

    if (stopwatch.elapsedMilliseconds > 50) {
      debugPrint(
          '⚠️ Búsqueda de proximidad lenta: ${stopwatch.elapsedMilliseconds}ms');
    }

    // VALIDACIÓN: Si la distancia aumentó drásticamente, hacer búsqueda completa
    if (result != null) {
      final newDistance = _calculateDistance(
        location.latitude,
        location.longitude,
        result.latitude,
        result.longitude,
      );

      // Detectar salto de distancia (posible pérdida de tracking)
      if (_lastDistance < 50 && newDistance > _lastDistance + 50) {
        return _findClosest(location, allPoints); // Búsqueda completa
      }

      _lastDistance = newDistance;
      _lastClosestPoint = result;
      _missedUpdates = 0;
    }

    _lastSpeed = location.speed;
    return result;
  }

  /// Calcula radio de búsqueda adaptativo según velocidad
  /// SOLUCIÓN: Aumenta el radio cuando detecta aceleración
  double _calculateAdaptiveRadius(double currentSpeed) {
    // Detectar aceleración
    final speedDelta = currentSpeed - _lastSpeed;
    final isAccelerating = speedDelta > 1.0; // Aceleración > 1 m/s²

    double baseRadius;

    if (currentSpeed < 0.5) {
      baseRadius = 30; // Quieto: radio pequeño
    } else if (currentSpeed < 2.0) {
      baseRadius = 50; // Caminando (0.5-2 m/s = 1.8-7.2 km/h)
    } else if (currentSpeed < 5.0) {
      baseRadius = 100; // Corriendo (2-5 m/s = 7.2-18 km/h)
    } else if (currentSpeed < 10.0) {
      baseRadius = 150; // Bicicleta (5-10 m/s = 18-36 km/h)
    } else if (currentSpeed < 20.0) {
      baseRadius = 250; // Vehículo lento (10-20 m/s = 36-72 km/h)
    } else {
      baseRadius = 400; // Vehículo rápido (>20 m/s = >72 km/h)
    }

    // OPTIMIZACIÓN: Si está acelerando, duplicar el radio
    if (isAccelerating) {
      debugPrint(
          '🚀 Aceleración detectada: ${speedDelta.toStringAsFixed(1)} m/s². Radio aumentado: ${baseRadius}m → ${(baseRadius * 2).toInt()}m');
      return baseRadius * 2;
    }

    return baseRadius;
  }

  /// Encuentra el punto más cercano en una lista de candidatos
  VirtualPoint? _findClosest(
    LocationData location,
    List<VirtualPoint> candidates,
  ) {
    if (candidates.isEmpty) return null;

    VirtualPoint? closestPoint;
    double minDistance = double.infinity;

    for (var vp in candidates) {
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        vp.latitude,
        vp.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = vp;
      }
    }

    return closestPoint;
  }

  /// Calcula distancia en metros usando fórmula de Haversine
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Radio de la Tierra en metros
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Actualiza el historial de ubicaciones y detecta movimiento estilo Waze
  void updateMovementHistory(LocationData location) {
    // Agregar al historial
    _locationHistory.add(location);
    if (_locationHistory.length > _maxHistorySize) {
      _locationHistory.removeAt(0);
    }

    // Detectar si está en movimiento (velocidad > 0.5 m/s o desplazamiento significativo)
    if (_locationHistory.length >= 2) {
      final previous = _locationHistory[_locationHistory.length - 2];
      final current = location;

      // Calcular distancia recorrida
      final distanceMoved = _calculateDistance(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );

      // Calcular bearing (dirección de movimiento)
      _lastBearing = _calculateBearing(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );

      // Determinar si hay movimiento significativo
      // Waze considera movimiento: velocidad > 0.5 m/s O desplazamiento > 2m en últimos 5 segundos
      final timeDiff = current.createdAt.difference(previous.createdAt).inMilliseconds / 1000.0;
      final effectiveSpeed = timeDiff > 0 ? distanceMoved / timeDiff : 0;

      _isMoving = current.speed > 0.5 || effectiveSpeed > 0.5;

      if (_isMoving) {
        _lastMovementTime = current.createdAt;
      }
    }
  }

  /// Calcula el bearing (dirección) entre dos puntos en grados
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRadians(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_toRadians(lat2));
    final x = math.cos(_toRadians(lat1)) * math.sin(_toRadians(lat2)) -
        math.sin(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.cos(dLon);
    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360; // Normalizar a 0-360
  }

  /// Verifica si el usuario está quieto por un tiempo determinado
  bool isStationaryFor(Duration duration) {
    if (_lastMovementTime == null) return true;
    return DateTime.now().difference(_lastMovementTime!) > duration;
  }

  /// Obtiene la velocidad promedio de las últimas ubicaciones
  double getAverageSpeed() {
    if (_locationHistory.isEmpty) return 0;
    final speeds = _locationHistory.map((l) => l.speed).toList();
    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  void reset() {
    _lastClosestPoint = null;
    _lastDistance = double.infinity;
    _missedUpdates = 0;
    _lastSpeed = 0;
    _locationHistory.clear();
    _lastBearing = 0;
    _lastMovementTime = null;
    _isMoving = false;
  }
}

/// Gestor de cola de mensajes TTS con sistema de cooldown
class TTSQueueManager {
  final FlutterTts _tts = FlutterTts();
  final List<SpeechMessage> _queue = [];
  bool _isSpeaking = false;
  final Map<String, DateTime> _lastAnnouncementTime = {};

  // Getter para exponer el estado de habla
  bool get isSpeaking => _isSpeaking;

  TTSQueueManager() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("es-ES");
    await _tts.setSpeechRate(0.5); // Velocidad normal
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue();
    });

    _tts.setErrorHandler((msg) {
      debugPrint('❌ Error TTS: $msg');
      _isSpeaking = false;
      _processQueue();
    });
  }

  /// Encola un mensaje para ser reproducido
  void enqueueSpeech(
    String text,
    String messageKey,
    SpeechPriority priority,
    Duration cooldown,
  ) {
    // Verificar cooldown
    if (!_canAnnounce(messageKey, cooldown)) {
      // debugPrint('🔇 Mensaje bloqueado por cooldown: $messageKey');
      return;
    }

    _lastAnnouncementTime[messageKey] = DateTime.now();

    _queue.add(SpeechMessage(
      text: text,
      priority: priority,
    ));

    // Ordenar por prioridad
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    // debugPrint('🔊 Mensaje encolado: "$text" (prioridad: ${priority.name})');
    _processQueue();
  }

  bool _canAnnounce(String messageKey, Duration cooldown) {
    final lastTime = _lastAnnouncementTime[messageKey];
    if (lastTime == null) return true;

    return DateTime.now().difference(lastTime) > cooldown;
  }

  Future<void> _processQueue() async {
    if (_isSpeaking || _queue.isEmpty) return;

    final message = _queue.removeAt(0);
    _isSpeaking = true;

    try {
      await _tts.stop(); // Cancelar cualquier TTS previo
      await _tts.speak(message.text);
    } catch (e) {
      debugPrint('❌ Error al hablar: $e');
      _isSpeaking = false;
      _processQueue(); // Intentar con siguiente
    }
  }

  void clearQueue() {
    _queue.clear();
    _tts.stop();
    _isSpeaking = false;
  }

  /// Habla inmediatamente sin verificar cooldown (para botón "¿Dónde estoy?")
  Future<void> speakImmediately(String text) async {
    // Cancelar cualquier mensaje en curso
    await _tts.stop();
    _queue.clear();
    _isSpeaking = true;

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('❌ Error al hablar inmediatamente: $e');
      _isSpeaking = false;
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
    _queue.clear();
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class OfflineMapTrackerVisits extends StatefulWidget {
  const OfflineMapTrackerVisits({
    super.key,
    this.width,
    this.height,
    required this.mapFilePath,
    this.headquarters,
    this.isTestMode,
    this.authToken,
  });

  final double? width;
  final double? height;
  final String mapFilePath;
  final List<HeadquartersStruct>? headquarters;
  final bool? isTestMode;
  final String? authToken;

  @override
  State<OfflineMapTrackerVisits> createState() =>
      _OfflineMapTrackerVisitsState();
}

class _OfflineMapTrackerVisitsState extends State<OfflineMapTrackerVisits>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Mantener vivo el estado cuando se cambia de tab
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  bool _isFollowingUser = true;
  PmTilesArchive? _pmtilesArchive;
  bool _isLoading = true;
  String? _errorMessage;

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _filterPanelController;
  late Animation<double> _filterPanelAnimation;
  late AnimationController _speakingAnimationController;
  late Animation<double> _speakingAnimation;

  double _currentBearing = 0.0;

  // Filtros de capas
  bool _showVirtualPoints = true;
  bool _showPolygon = true;
  bool _showProducts = false;
  bool _showCoordinates = true; // Activada por defecto
  bool _showMyLocation = true;
  bool _showTrackingLine = true; // Nueva opción para la línea de trazo

  // Filtro de tiempo
  TimeFilter _selectedFilter = TimeFilter.all;
  List<GeoLocation> _allGeolocations = [];
  List<GeoLocation> _filteredGeolocations = [];

  // Datos de headquarters
  HeadquarterData? _headquarter; // Headquarter activo actual
  Map<int, HeadquarterData> _headquarters =
      {}; // Todos los headquarters cargados
  Map<int, TypePointData> _typePoints = {}; // Cache de Type_points por ID

  // Datos organizados por headquarter
  List<VirtualPoint> _virtualPoints = []; // Del headquarter activo
  Map<int, List<VirtualPoint>> _virtualPointsByHeadquarter = {};

  List<latlong.LatLng> _polygonPoints = []; // Del headquarter activo
  Map<int, List<latlong.LatLng>> _polygonsByHeadquarter = {};

  List<ProductData> _products = []; // Del headquarter activo
  Map<int, List<ProductData>> _productsByHeadquarter = {};

  List<CoordinateData> _coordinates = []; // Del headquarter activo
  Map<int, List<CoordinateData>> _coordinatesByHeadquarter = {};

  int? _activeHeadquarterId; // ID del lote activo en el selector de lotes

  // Simulación de recorrido
  List<SimulatedLocationPoint> _simulatedRoute = [];
  bool _showSimulatedRoute = false;
  RouteSimulationConfig? _routeConfig;
  VirtualPoint? _startingPoint; // Punto inicial del recorrido configurado

  // Estado del reproductor de ruta
  bool _isPlaybackActive = false; // Si el reproductor está visible
  bool _isPlaybackPlaying = false; // Si está reproduciendo
  int _currentPlaybackIndex = 0; // Índice del punto actual
  double _playbackSpeed = 1.0; // Velocidad de reproducción (1x, 2x, 5x, etc.)
  DateTime? _playbackStartTime; // Momento en que inició la reproducción
  Timer? _playbackTimer; // Timer para actualizar posición
  bool _autoFollowPlayback = true; // Auto-centrar en posición actual
  final List<double> _availablePlaybackSpeeds = [
    1.0,
    2.0,
    5.0,
    10.0,
    20.0,
    50.0
  ];

  // UI State
  bool _showFilterPanel = false;
  bool _fabMenuExpanded = false; // Estado del menú FAB Speed Dial
  bool _showLayerPanel = false; // Panel de capas visible/oculto

  VectorTileProvider? _vectorTileProvider;
  double _currentZoom = 18.0;

  // Sistema de navegación por voz
  late ProximityOptimizer _proximityOptimizer;
  late TTSQueueManager _ttsManager;
  Timer? _proximityTimer;
  NavigationEvent? _currentNavigationEvent;
  bool _showNavigationCard = false;
  bool _voiceEnabled = true; // Control de voz activado/desactivado
  bool _isTotalTimeCollapsed =
      false; // Estado de colapso de la tarjeta de tiempo total

  // Control de anuncios de línea (para no repetir constantemente)
  int? _currentAnnouncedLine; // Última línea anunciada
  int _pointsInCurrentLine = 0; // Contador de puntos en la línea actual

  // Control de zonas de exclusión cercanas y modificación de tipos
  List<ExclusionZoneMarker> _nearbyExclusionZones = [];
  bool _showExclusionButton = false;
  List<TypePointData> _availableTypesPoints = [];

  // Función para calcular el tamaño de los marcadores según el zoom
  double _getMarkerSize(double baseSize) {
    // Escala agresiva para pines pequeños
    // Basado en: zoom 18 = 40% del tamaño base (ejemplo: 40px → 16px)
    // Zoom 3-10:  5-15% del tamaño (muy pequeño)
    // Zoom 10-14: 15-25% del tamaño (pequeño)
    // Zoom 14-18: 25-40% del tamaño (medio)
    // Zoom 18-20: 40-55% del tamaño (grande)
    // Zoom 20+:   55-65% del tamaño (muy grande)

    final zoom = _currentZoom.clamp(3.0, 22.0);

    if (zoom <= 10) {
      // Interpolación lineal de 5% a 15%
      final t = (zoom - 3) / 7; // 0 a 1
      return baseSize * (0.05 + (0.10 * t));
    } else if (zoom <= 14) {
      // Interpolación lineal de 15% a 25%
      final t = (zoom - 10) / 4; // 0 a 1
      return baseSize * (0.15 + (0.10 * t));
    } else if (zoom <= 18) {
      // Interpolación lineal de 25% a 40%
      final t = (zoom - 14) / 4; // 0 a 1
      return baseSize * (0.25 + (0.15 * t));
    } else if (zoom <= 20) {
      // Interpolación lineal de 40% a 55%
      final t = (zoom - 18) / 2; // 0 a 1
      return baseSize * (0.40 + (0.15 * t));
    } else {
      // Interpolación lineal de 55% a 65%
      final t = (zoom - 20) / 2; // 0 a 1
      return baseSize * (0.55 + (0.10 * t));
    }
  }

  // Función para calcular el tamaño de texto según el zoom
  double _getTextSize(double baseSize) {
    final zoom = _currentZoom.clamp(3.0, 22.0);

    if (zoom < 14) {
      return 0; // No mostrar texto cuando está muy alejado
    } else if (zoom <= 18) {
      // Interpolación de 30% a 50%
      final t = (zoom - 14) / 4;
      return baseSize * (0.3 + (0.2 * t));
    } else if (zoom <= 20) {
      // Interpolación de 50% a 70%
      final t = (zoom - 18) / 2;
      return baseSize * (0.5 + (0.2 * t));
    } else {
      // Interpolación de 70% a 80%
      final t = (zoom - 20) / 2;
      return baseSize * (0.7 + (0.1 * t));
    }
  }

  // Determinar si mostrar texto en marcadores
  bool _shouldShowText() {
    return _currentZoom >= 14;
  }

  @override
  void initState() {
    super.initState();

    // Configurar animación de pulso
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Configurar animación del panel de filtros
    _filterPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _filterPanelAnimation = CurvedAnimation(
      parent: _filterPanelController,
      curve: Curves.easeInOut,
    );

    // Configurar animación de habla (sound wave)
    _speakingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _speakingAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _speakingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Inicializar PMTiles
    _initPMTiles();

    // CARGA DE DATOS Y MOSTRAR POPUP DE CONFIGURACIÓN
    // Cargar datos sin verificar sincronización automática
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cargar datos normalmente (sin validación previa)
      await _loadAllData();

      _centerOnCurrentLocation(animated: false);
      // Log de zoom inicial (solo una vez)
      debugPrint(
          '🔍 Zoom inicial: ${_currentZoom.toStringAsFixed(1)} | Marcador 40px → ${_getMarkerSize(40).toStringAsFixed(1)}px');

      // El popup de configuración de ruta ahora se abre manualmente por el usuario
      // if (mounted) {
      //   await _showSimulationConfigDialog();
      // }
    });

    // Listener para cambios en AppState
    FFAppState().addListener(_onLocationUpdate);

    // Inicializar sistema de navegación por voz
    _proximityOptimizer = ProximityOptimizer();
    _ttsManager = TTSQueueManager();

    // Timer de detección de proximidad (cada 1 segundo)
    _proximityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkProximityToVirtualPoints();
    });
  }

  /// Valida que existan datos de los lotes en SQLite antes de cargar
  /// Si no existen, muestra diálogo y llama a syncInstallModule
  Future<void> _validateAndLoadData() async {
    try {
      debugPrint(
          '🔍 Verificando datos de ${widget.headquarters!.length} lotes en SQLite...');

      // Verificar cada headquarter
      final List<int> missingHeadquarters = [];
      for (var hq in widget.headquarters!) {
        final hasData = await _checkHeadquarterData(hq.idHeadquarter);
        if (!hasData) {
          missingHeadquarters.add(hq.idHeadquarter);
        }
      }

      if (missingHeadquarters.isNotEmpty) {
        debugPrint(
            '⚠️ Faltan datos de ${missingHeadquarters.length} lotes: $missingHeadquarters');

        // Mostrar diálogo pidiendo sincronizar
        if (!mounted) return;

        final bool shouldSync = await _showSyncRequiredDialog();

        if (shouldSync && mounted) {
          // Mostrar pantalla de carga elegante y sincronizar
          await _syncHeadquarterDataWithLoading();
        } else {
          // Usuario canceló, cerrar la ventana
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      } else {
        debugPrint('✅ Datos de todos los lotes encontrados en SQLite');
      }

      // Cargar datos normalmente
      await _loadAllData();
    } catch (e) {
      debugPrint('❌ Error en validación de datos: $e');
      // Intentar cargar de todos modos
      await _loadAllData();
    }
  }

  /// Verifica si existen datos del headquarter en SQLite
  Future<bool> _checkHeadquarterData(int idHeadquarter) async {
    try {
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Verificar si existe el headquarter
      final List<Map<String, dynamic>> hqResult = await db.query(
        'Headquarters',
        where: 'Id_headquarter = ?',
        whereArgs: [idHeadquarter],
        limit: 1,
      );

      if (hqResult.isEmpty) {
        await db.close();
        return false;
      }

      // Verificar si tiene Virtual_points
      final List<Map<String, dynamic>> vpResult = await db.query(
        'Virtual_points',
        where: 'Id_headquarter = ?',
        whereArgs: [idHeadquarter],
        limit: 1,
      );

      await db.close();

      // Tiene datos si existe el headquarter Y tiene virtual points
      return vpResult.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error verificando datos: $e');
      return false;
    }
  }

  /// Muestra diálogo pidiendo sincronizar datos del lote
  Future<bool> _showSyncRequiredDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).warning,
                      FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono animado
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_download_outlined,
                        color: FlutterFlowTheme.of(context).info,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Sincronización Requerida',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Es necesario sincronizar la información del lote seleccionado antes de continuar.',
                      style: TextStyle(
                        fontSize: 15,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: FlutterFlowTheme.of(context).info,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Se descargarán puntos virtuales, polígonos y productos del lote.',
                              style: TextStyle(
                                fontSize: 12,
                                color: FlutterFlowTheme.of(context)
                                    .info
                                    .withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              foregroundColor:
                                  FlutterFlowTheme.of(context).info,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  FlutterFlowTheme.of(context).info,
                              foregroundColor:
                                  FlutterFlowTheme.of(context).warning,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sincronizar Ahora',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
        ) ??
        false;
  }

  /// Sincroniza datos del headquarter mostrando pantalla de carga elegante
  Future<void> _syncHeadquarterDataWithLoading() async {
    // Mostrar diálogo de carga
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _buildElegantLoadingDialog();
      },
    );

    try {
      debugPrint('🔄 Iniciando sincronización del lote ${_headquarter?.id}...');

      // Llamar a sync_install_module
      final bool success = await syncInstallModule(
        context,
        _headquarter!.id,
        widget.authToken ?? '',
      );

      // Cerrar diálogo de carga
      if (mounted) {
        Navigator.pop(context);
      }

      if (success) {
        debugPrint('✅ Sincronización completada exitosamente');

        // Mostrar mensaje de éxito
        if (mounted) {
          await _showSyncSuccessDialog();
        }
      } else {
        debugPrint('❌ Error en la sincronización');

        // Mostrar mensaje de error
        if (mounted) {
          await _showSyncErrorDialog();
          // Cerrar la ventana del mapa
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Excepción durante sincronización: $e');

      // Cerrar diálogo de carga
      if (mounted) {
        Navigator.pop(context);
        await _showSyncErrorDialog();
        Navigator.pop(context);
      }
    }
  }

  /// Diálogo de carga elegante y moderno
  Widget _buildElegantLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlutterFlowTheme.of(context).primary,
              FlutterFlowTheme.of(context).secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color:
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación de carga
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.cloud_sync,
                        color: FlutterFlowTheme.of(context).info,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Sincronizando Información',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).info,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              'Descargando datos del lote...',
              style: TextStyle(
                fontSize: 15,
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Indicador de progreso
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de éxito en la sincronización
  Future<void> _showSyncSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                Icon(
                  Icons.check_circle_outline,
                  color: FlutterFlowTheme.of(context).info,
                  size: 72,
                ),
                const SizedBox(height: 20),
                Text(
                  'Sincronización Exitosa',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).info,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Los datos del lote se han descargado correctamente.',
                  style: TextStyle(
                    fontSize: 14,
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).info,
                    foregroundColor: FlutterFlowTheme.of(context).success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
        );
      },
    );
  }

  /// Diálogo de error en la sincronización
  Future<void> _showSyncErrorDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).error,
                  FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: FlutterFlowTheme.of(context).info,
                  size: 72,
                ),
                const SizedBox(height: 20),
                Text(
                  'Error en Sincronización',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).info,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'No se pudieron descargar los datos del lote. Verifica tu conexión e intenta nuevamente.',
                  style: TextStyle(
                    fontSize: 14,
                    color: FlutterFlowTheme.of(context)
                        .info
                        .withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).info,
                    foregroundColor: FlutterFlowTheme.of(context).error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Future<void> _initPMTiles() async {
    try {
      debugPrint('🗺️ Inicializando PMTiles desde: ${widget.mapFilePath}');

      final file = File(widget.mapFilePath);
      if (!await file.exists()) {
        throw Exception('Archivo PMTiles no encontrado: ${widget.mapFilePath}');
      }

      // Verificar tamaño mínimo del archivo (header PMTiles mínimo)
      final fileSize = await file.length();
      if (fileSize < 127) { // Header PMTiles v3 es de al menos 127 bytes
        debugPrint('⚠️ Archivo PMTiles demasiado pequeño: $fileSize bytes');
        await _handleCorruptPMTiles(file, 'El archivo está incompleto o corrupto');
        return;
      }

      // Verificar header PMTiles antes de cargar
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(7);
        final signature = String.fromCharCodes(header);
        if (!signature.startsWith('PMTiles')) {
          debugPrint('⚠️ Header PMTiles inválido: $signature');
          await raf.close();
          await _handleCorruptPMTiles(file, 'El archivo no es un PMTiles válido');
          return;
        }
      } finally {
        await raf.close();
      }

      _pmtilesArchive = await PmTilesArchive.from(widget.mapFilePath);

      debugPrint('✅ PMTiles cargado correctamente');

      _vectorTileProvider = _PMTilesVectorTileProvider(_pmtilesArchive!);
      debugPrint('✅ VectorTileProvider creado');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar PMTiles: $e');

      // Verificar si es un error de corrupción
      final errorStr = e.toString().toLowerCase();
      final isCorruptError = errorStr.contains('corrupt') ||
          errorStr.contains('header') ||
          errorStr.contains('too short') ||
          errorStr.contains('invalid');

      if (isCorruptError) {
        final file = File(widget.mapFilePath);
        await _handleCorruptPMTiles(file, 'El archivo PMTiles está corrupto o incompleto');
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar el mapa: $e';
        });
      }
    }
  }

  /// Maneja archivos PMTiles corruptos eliminándolos y mostrando mensaje
  Future<void> _handleCorruptPMTiles(File file, String reason) async {
    try {
      // Eliminar archivo corrupto
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Archivo corrupto eliminado: ${file.path}');
      }

      // También eliminar archivo parcial si existe
      final partialFile = File('${file.path}.partial');
      if (await partialFile.exists()) {
        await partialFile.delete();
        debugPrint('🗑️ Archivo parcial eliminado');
      }

      // Limpiar ruta en AppState
      FFAppState().update(() {
        FFAppState().pathPmtiles = '';
      });
    } catch (deleteError) {
      debugPrint('⚠️ Error eliminando archivo corrupto: $deleteError');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '$reason\n\nEl archivo ha sido eliminado.\nPor favor, vuelva a descargar el mapa desde Configuración.';
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      final String dbPath = await _getDatabasePath();

      // Abrir base de datos sin cerrarla (sqflite maneja el pool automáticamente)
      final database = await openDatabase(dbPath);

      // Cargar geolocalizaciones primero (sin cerrar la base de datos)
      await _loadGeolocationsWithConnection(database);

      // Cargar datos de múltiples headquarters si existen
      if (widget.headquarters != null && widget.headquarters!.isNotEmpty) {
        debugPrint(
            '🏢 Cargando datos de ${widget.headquarters!.length} lotes...');

        // Cargar Type_points PRIMERO (necesarios para colores, compartidos por todos)
        await _loadTypePoints(database);

        // Iterar por cada headquarter y cargar sus datos
        for (var i = 0; i < widget.headquarters!.length; i++) {
          final hq = widget.headquarters![i];
          final headquarterId = hq.idHeadquarter;

          debugPrint(
              '📦 Cargando lote ${i + 1}/${widget.headquarters!.length}: ID=$headquarterId, Nombre="${hq.nameHeadquarter}"');

          // Cargar datos completos del headquarter
          await _loadHeadquarter(headquarterId, database);

          // Ejecutar todas las cargas secuencialmente para este headquarter
          await _loadVirtualPoints(headquarterId, database);
          await _loadPolygon(headquarterId, database);
          await _loadProducts(headquarterId, database);
          await _loadCoordinates(headquarterId, database);
        }

        // Establecer el primer headquarter como activo
        if (_headquarters.isNotEmpty) {
          final firstHqId = widget.headquarters!.first.idHeadquarter;
          _activeHeadquarterId = firstHqId;
          _headquarter = _headquarters[firstHqId];
          _virtualPoints = _virtualPointsByHeadquarter[firstHqId] ?? [];
          _polygonPoints = _polygonsByHeadquarter[firstHqId] ?? [];
          _products = _productsByHeadquarter[firstHqId] ?? [];
          _coordinates = _coordinatesByHeadquarter[firstHqId] ?? [];

          debugPrint(
              '✅ Lote activo establecido: ID=$firstHqId, Nombre="${_headquarter?.name}"');
        }

        // Mostrar diálogo de simulación si está en modo de prueba
        if (widget.isTestMode == true && _virtualPoints.isNotEmpty) {
          // Usar WidgetsBinding para mostrar el diálogo después del build
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              await _showSimulationConfigDialog();
            }
          });
        }

        // Anunciar el nombre del lote al finalizar la carga
        if (_headquarter?.name != null && _voiceEnabled) {
          // Esperar un momento para que se estabilice todo
          await Future.delayed(const Duration(milliseconds: 500));
          _ttsManager.enqueueSpeech(
            'Lote ${_headquarter!.name}',
            'headquarter_loaded',
            SpeechPriority.high,
            const Duration(seconds: 60), // Cooldown largo para no repetir
          );
        }

        debugPrint(
            '✅ Carga completa de ${widget.headquarters!.length} lotes finalizada');
      }

      // NO cerrar la base de datos - sqflite maneja el pool automáticamente
      // Cerrar causaba DatabaseException cuando otras funciones intentaban usarla
    } catch (e) {
      debugPrint('❌ Error cargando datos del mapa: $e');
    }
  }

  Future<void> _loadTypePoints(Database database) async {
    try {
      debugPrint('🎨 Cargando Type_points...');

      final List<Map<String, dynamic>> results = await database.query(
        'Types_points',
        orderBy: 'Order_type ASC',
      );

      debugPrint('📊 Total de registros en Types_points: ${results.length}');

      _typePoints.clear();
      _availableTypesPoints.clear();

      for (var row in results) {
        debugPrint('   📝 Procesando row: $row');
        final typePoint = TypePointData(
          id: row['Id_type_point'] as int,
          name: row['Name_type'] as String?,
          colorHex: row['Color_type'] as String?,
          order: row['Order_type'] as int?,
          virtualPointsCount: row['Virtual_points_count'] as int?,
        );
        _typePoints[typePoint.id] = typePoint;
        _availableTypesPoints
            .add(typePoint); // También agregar a la lista ordenada
        debugPrint(
            '   🎨 Type_point cargado: ID=${typePoint.id}, Nombre="${typePoint.name}", Color=${typePoint.colorHex}');
      }

      debugPrint('✅ Type_points cargados: ${_typePoints.length}');
      debugPrint('✅ _availableTypesPoints: ${_availableTypesPoints.length}');
      debugPrint('   📋 IDs disponibles: ${_typePoints.keys.toList()..sort()}');
      debugPrint(
          '   📋 Tipos en _availableTypesPoints: ${_availableTypesPoints.map((t) => '${t.id}:${t.name}').toList()}');
    } catch (e) {
      debugPrint('❌ Error cargando Type_points: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadHeadquarter(int headquarterId, Database database) async {
    try {
      debugPrint('🏢 Cargando datos del headquarter ID=$headquarterId...');

      final List<Map<String, dynamic>> results = await database.query(
        'Headquarters',
        where: 'Id_headquarter = ?',
        whereArgs: [headquarterId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final headquarterData = HeadquarterData(
          id: row['Id_headquarter'] as int,
          idZone: row['Id_zone'] as int?,
          createdAt: row['Created_at'] != null
              ? DateTime.tryParse(row['Created_at'] as String)
              : null,
          name: row['Name_headquarter'] as String?,
          density: row['Density_headquarter'] as double?,
          seedTime: row['Seed_time'] as String?,
          state: row['State_headquarter'] as String?,
          area: row['Area_headquarter'] as double?,
          polygon: row['Polygon'] as String?,
          centroidCoordinate: row['Centroid_coordinate'] as String?,
          azimuth: row['Azimuth'] as double?,
          slopeAzimuthDirection: row['Slope_azimuth_direction'] as double?,
          slopeAzimuthPerpendicular:
              row['Slope_azimuth_perpendicular'] as double?,
          horizontalPalmDistance: row['Horizontal_palm_distance'] as double?,
          verticalPalmDistance: row['Vertical_palm_distance'] as double?,
          magneticDeclination: row['Magnetic_declination'] as double?,
          customOriginLatitude: row['CustomOriginLatitude'] as double?,
          customOriginLongitude: row['CustomOriginLongitude'] as double?,
          hasPlants: (row['Has_plants'] as int?) == 1,
        );

        // Guardar en el mapa de headquarters
        _headquarters[headquarterId] = headquarterData;

        debugPrint(
            '✅ Headquarter cargado: ID=$headquarterId, Nombre="${headquarterData.name}"');
      } else {
        debugPrint('⚠️ No se encontró el headquarter con ID: $headquarterId');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error cargando headquarter: $e');
    }
  }

  Future<void> _loadGeolocationsWithConnection(Database database) async {
    try {
      debugPrint('📍 Cargando geolocalizaciones desde la base de datos...');

      final List<Map<String, dynamic>> results = await database.query(
        'Location_tracking',
        orderBy: 'CreatedAt DESC',
      );

      debugPrint('📊 Geolocalizaciones encontradas: ${results.length}');

      _allGeolocations = results.map((row) {
        return GeoLocation(
          latitude: row['Latitude'] as double,
          longitude: row['Longitude'] as double,
          altitude: (row['Altitude'] as num?)?.toDouble() ?? 0.0,
          timestamp: DateTime.parse(row['CreatedAt'] as String),
          speed: null,
          heading: null,
        );
      }).toList();

      _applyFilter();

      debugPrint('✅ Geolocalizaciones cargadas: ${_allGeolocations.length}');
    } catch (e) {
      debugPrint('❌ Error cargando geolocalizaciones: $e');
    }
  }

  Future<void> _loadGeolocationsFromDatabase() async {
    try {
      debugPrint('📍 Cargando geolocalizaciones desde la base de datos...');

      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      final List<Map<String, dynamic>> results = await database.query(
        'Location_tracking',
        orderBy: 'CreatedAt DESC',
      );

      debugPrint('📊 Geolocalizaciones encontradas: ${results.length}');

      _allGeolocations = results.map((row) {
        return GeoLocation(
          latitude: row['Latitude'] as double,
          longitude: row['Longitude'] as double,
          altitude: (row['Altitude'] as num?)?.toDouble() ?? 0.0,
          timestamp: DateTime.parse(row['CreatedAt'] as String),
          speed: null,
          heading: null,
        );
      }).toList();

      // NO cerrar - sqflite maneja el pool automáticamente

      _applyFilter();

      debugPrint('✅ Geolocalizaciones cargadas: ${_allGeolocations.length}');
    } catch (e) {
      debugPrint('❌ Error cargando geolocalizaciones: $e');
    }
  }

  Future<void> _loadVirtualPoints(int headquarterId, Database database) async {
    try {
      debugPrint('🟣 Cargando Virtual Points para lote ID=$headquarterId...');

      final List<Map<String, dynamic>> results = await database.query(
        'Virtual_points',
        where: 'Id_headquarter = ? AND Is_active = 1',
        whereArgs: [headquarterId],
      );

      final virtualPoints = results.map((row) {
        final int? idTypePoint = row['Id_type_point'] as int?;
        return VirtualPoint(
          id: row['Id_virtual_point'] as int,
          lineNumber: row['Line_number'] as int,
          pointNumber: row['Point_number'] as int,
          latitude: row['Latitude'] as double,
          longitude: row['Longitude'] as double,
          description: row['Description_virtual_point'] as String?,
          typeName: row['Type_point_name'] as String?,
          idTypePoint: idTypePoint,
          generationMethod: row['Generation_method'] as String?,
          createdDate: row['Created_date'] != null
              ? DateTime.tryParse(row['Created_date'] as String)
              : null,
          isActive: (row['Is_active'] as int?) == 1,
          headquarterName: row['Headquarter_name'] as String?,
          pointDisplayName: row['Point_display_name'] as String?,
          typePoint: idTypePoint != null ? _typePoints[idTypePoint] : null,
        );
      }).toList();

      // Guardar en el mapa de virtual points por headquarter
      _virtualPointsByHeadquarter[headquarterId] = virtualPoints;

      debugPrint(
          '✅ Virtual Points cargados para lote ID=$headquarterId: ${virtualPoints.length} puntos');

      if (mounted) {
        setState(() {});

        // Centrar automáticamente en los puntos virtuales después de cargarlos (solo si es el primer lote)
        if (virtualPoints.isNotEmpty &&
            _virtualPointsByHeadquarter.length == 1) {
          // Usar addPostFrameCallback con un pequeño delay para asegurar que el mapa esté listo
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            // Esperar un frame adicional para asegurar que el mapa esté renderizado
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              _centerOnVirtualPoints(animated: true);
              debugPrint('📍 Auto-centrado en puntos virtuales completado');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando Virtual Points: $e');
    }
  }

  Future<void> _loadPolygon(int headquarterId, Database database) async {
    try {
      debugPrint('🟡 Cargando Polígono para lote ID=$headquarterId...');

      final List<Map<String, dynamic>> results = await database.query(
        'Headquarters_polygons',
        where: 'Id_headquarter = ?',
        whereArgs: [headquarterId],
        orderBy: 'Id_headquarter_polygon ASC',
      );

      final polygonPoints = results.map((row) {
        return latlong.LatLng(
          row['Latitude'] as double,
          row['Longitude'] as double,
        );
      }).toList();

      // Guardar en el mapa de polígonos por headquarter
      _polygonsByHeadquarter[headquarterId] = polygonPoints;

      debugPrint(
          '✅ Polígono cargado para lote ID=$headquarterId: ${polygonPoints.length} puntos');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error cargando Polígono: $e');
    }
  }

  Future<void> _loadProducts(int headquarterId, Database database) async {
    try {
      debugPrint('🟢 Cargando Productos para lote ID=$headquarterId...');

      // Obtener productos
      final List<Map<String, dynamic>> productResults = await database.query(
        'Products',
        where: 'Id_headquarter = ?',
        whereArgs: [headquarterId],
      );

      // Cargar coordenadas de cada producto
      final products = <ProductData>[];
      int productsWithCoordinates = 0;
      for (var productRow in productResults) {
        final int productId = productRow['Id_product'] as int;

        final List<Map<String, dynamic>> coordResults = await database.query(
          'Products_coordinates',
          where: 'Id_product = ?',
          whereArgs: [productId],
        );

        List<latlong.LatLng> coordinates = coordResults.map((coord) {
          return latlong.LatLng(
            coord['Latitude'] as double,
            coord['Longitude'] as double,
          );
        }).toList();

        // Solo agregar productos que tengan al menos una coordenada
        if (coordinates.isNotEmpty) {
          final int? idType = productRow['Id_type'] as int?;
          products.add(ProductData(
            id: productId,
            idHeadquarter: productRow['Id_headquarter'] as int?,
            idCompany: productRow['Id_company'] as int?,
            idType: idType,
            createdAt: productRow['Created_at'] != null
                ? DateTime.tryParse(productRow['Created_at'] as String)
                : null,
            modifiedAt: productRow['Modified_at'] != null
                ? DateTime.tryParse(productRow['Modified_at'] as String)
                : null,
            typeProduct: productRow['Type_product'] as String?,
            nameProduct: productRow['Name_product'] as String?,
            rfid: productRow['Rfid'] as String?,
            descriptionProduct: productRow['Description_product'] as String?,
            state: productRow['State_product'] as String?,
            locationRaw: productRow['Location_raw'] as String?,
            line: productRow['Line'] as int?,
            palm: productRow['Palm'] as int?,
            coordinates: coordinates,
            typePoint: idType != null ? _typePoints[idType] : null,
          ));
          productsWithCoordinates++;
        }
      }

      // Guardar en el mapa de productos por headquarter
      _productsByHeadquarter[headquarterId] = products;

      debugPrint(
          '✅ Productos cargados para lote ID=$headquarterId: ${products.length} (${productResults.length} en total, $productsWithCoordinates con coordenadas)');

      // Log detallado de los primeros productos para debugging
      if (products.isNotEmpty && products.length <= 5) {
        for (var product in products) {
          debugPrint(
              '   📦 Producto ${product.id}: ${product.coordinates.length} coordenadas - Línea ${product.line}, Palma ${product.palm}');
        }
      } else if (products.isNotEmpty) {
        debugPrint('   📦 Mostrando primeros 3 productos:');
        for (var i = 0; i < 3 && i < products.length; i++) {
          final product = products[i];
          debugPrint(
              '   📦 Producto ${product.id}: ${product.coordinates.length} coordenadas - Línea ${product.line}, Palma ${product.palm}');
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error cargando Productos: $e');
    }
  }

  Future<void> _loadCoordinates(int headquarterId, Database database) async {
    try {
      debugPrint(
          '🔵 Cargando Coordenadas (Polígonos de Exclusión) para lote ID=$headquarterId...');

      final List<Map<String, dynamic>> results = await database.query(
        'Headquarters_coordinates',
        where: 'Id_headquarter = ? AND Is_active = 1',
        whereArgs: [headquarterId],
      );

      final coordinates = <CoordinateData>[];
      int totalPolygons = 0;
      int totalPoints = 0;

      for (var row in results) {
        final String? coordinatesRaw = row['Coordinates_raw'] as String?;
        if (coordinatesRaw != null && coordinatesRaw.isNotEmpty) {
          try {
            // Parse JSON array de coordenadas
            // Formato: [{"latitude":1.45,"longitude":-78.69},...]
            final dynamic jsonData = jsonDecode(coordinatesRaw);

            if (jsonData is List) {
              List<latlong.LatLng> polygonPoints = [];

              for (var point in jsonData) {
                if (point is Map<String, dynamic>) {
                  final lat = (point['latitude'] as num?)?.toDouble();
                  final lon = (point['longitude'] as num?)?.toDouble();

                  if (lat != null && lon != null) {
                    polygonPoints.add(latlong.LatLng(lat, lon));
                  }
                }
              }

              // Solo agregar si tiene al menos 3 puntos (mínimo para un polígono)
              if (polygonPoints.length >= 3) {
                final int? idTypePoint = row['Id_type_point'] as int?;
                final typePointData =
                    idTypePoint != null ? _typePoints[idTypePoint] : null;

                coordinates.add(CoordinateData(
                  id: row['Id_polygon_coordinate'] as int,
                  idHeadquarter: headquarterId,
                  name: row['Name_polygon_coordinate'] as String?,
                  coordinatesRaw: coordinatesRaw,
                  pointType: row['Point_type'] as String?,
                  idTypePoint: idTypePoint,
                  createdAt: row['Created_at'] != null
                      ? DateTime.tryParse(row['Created_at'] as String)
                      : null,
                  modifiedAt: row['Modified_at'] != null
                      ? DateTime.tryParse(row['Modified_at'] as String)
                      : null,
                  isActive: (row['Is_active'] as int?) == 1,
                  polygonPoints: polygonPoints,
                  typePoint: typePointData,
                ));

                totalPolygons++;
                totalPoints += polygonPoints.length;

                debugPrint(
                    '   📐 Polígono "${row['Name_polygon_coordinate']}": ${polygonPoints.length} puntos, Type: "${typePointData?.name ?? "SIN TIPO"}" (ID: ${idTypePoint ?? "NULL"}), Color: ${typePointData?.colorHex ?? "default"}');
              } else {
                debugPrint(
                    '⚠️ Polígono con menos de 3 puntos, ignorado: ${polygonPoints.length}');
              }
            }
          } catch (e) {
            debugPrint(
                '⚠️ Error parseando JSON de coordenada ${row['Name_polygon_coordinate']}: $e');
            debugPrint('   JSON raw: $coordinatesRaw');
          }
        }
      }

      // Guardar en el mapa de coordenadas por headquarter
      _coordinatesByHeadquarter[headquarterId] = coordinates;

      debugPrint(
          '✅ Coordenadas cargadas para lote ID=$headquarterId: $totalPolygons polígonos con $totalPoints puntos totales');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error cargando Coordenadas: $e');
    }
  }

  // ============================================================================
  // FUNCIONES DE SIMULACIÓN DE RECORRIDO
  // ============================================================================

  /// Calcula la distancia entre dos puntos en metros (Haversine)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros

    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Encuentra el punto más cercano de una línea específica a un punto de referencia
  VirtualPoint? _findClosestPointInLine(
    int lineNumber,
    VirtualPoint referencePoint,
    List<VirtualPoint> allPoints,
  ) {
    final pointsInLine =
        allPoints.where((p) => p.lineNumber == lineNumber).toList();
    if (pointsInLine.isEmpty) return null;

    VirtualPoint? closest;
    double minDistance = double.infinity;

    for (final point in pointsInLine) {
      final distance = _calculateDistance(
        referencePoint.latitude,
        referencePoint.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closest = point;
      }
    }

    return closest;
  }

  /// Encuentra la línea más cercana que tiene puntos
  int? _findClosestLine(
    int currentLine,
    List<int> availableLines,
    VirtualPoint lastPoint,
    List<VirtualPoint> allPoints,
    Set<int> visitedLines,
  ) {
    // Excluir la línea actual Y las líneas ya visitadas
    final otherLines = availableLines
        .where((l) => l != currentLine && !visitedLines.contains(l))
        .toList();
    debugPrint(
        '      🔎 _findClosestLine: línea actual=$currentLine, otras líneas disponibles=$otherLines');
    debugPrint('      🚫 Líneas excluidas (ya visitadas): $visitedLines');

    if (otherLines.isEmpty) {
      debugPrint('      ⚠️ No hay otras líneas disponibles');
      return null;
    }

    int? closestLine;
    double minDistance = double.infinity;

    for (final line in otherLines) {
      final closestPointInLine =
          _findClosestPointInLine(line, lastPoint, allPoints);
      if (closestPointInLine != null) {
        final distance = _calculateDistance(
          lastPoint.latitude,
          lastPoint.longitude,
          closestPointInLine.latitude,
          closestPointInLine.longitude,
        );
        debugPrint(
            '         - Línea $line: distancia=${distance.toStringAsFixed(2)}m');
        if (distance < minDistance) {
          minDistance = distance;
          closestLine = line;
        }
      } else {
        debugPrint('         - Línea $line: sin puntos encontrados');
      }
    }

    debugPrint(
        '      ✅ Línea más cercana: $closestLine (${minDistance.toStringAsFixed(2)}m)');
    return closestLine;
  }

  /// Verifica si un punto está dentro de un polígono usando Ray Casting Algorithm
  bool _isPointInPolygon(double lat, double lon, List<latlong.LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > lon) != (yj > lon)) &&
          (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Verifica si un punto está dentro de algún polígono de exclusión
  bool _isPointInExclusionZone(double lat, double lon) {
    for (final coordinate in _coordinates) {
      if (coordinate.polygonPoints.isNotEmpty) {
        if (_isPointInPolygon(lat, lon, coordinate.polygonPoints)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Verifica si un punto virtual está dentro de algún polígono de exclusión
  bool _isVirtualPointInExclusionZone(VirtualPoint vp) {
    return _isPointInExclusionZone(vp.latitude, vp.longitude);
  }

  /// Genera una velocidad de caminata aleatoria realista
  /// Rango: 0.8 - 1.5 m/s (2.88 - 5.4 km/h)
  double _generateWalkingSpeed() {
    final random = math.Random();
    // Velocidad humana típica al caminar:
    // - Lento: 0.8 m/s (2.88 km/h)
    // - Normal: 1.2 m/s (4.32 km/h)
    // - Rápido: 1.5 m/s (5.4 km/h)
    return 0.8 + (random.nextDouble() * 0.7); // 0.8 - 1.5 m/s
  }

  /// Encuentra zonas de exclusión cercanas a un punto (dentro de 50m)
  /// Retorna lista de ExclusionZoneMarker con info para anuncios de voz
  List<ExclusionZoneMarker> _findNearbyExclusionZones(
    double lat,
    double lon,
  ) {
    const double proximityThreshold = 50.0; // metros
    List<ExclusionZoneMarker> nearbyZones = [];

    for (var coord in _coordinates) {
      if (!coord.isActive || coord.polygonPoints.isEmpty) continue;

      // Calcular centroide del polígono
      double sumLat = 0.0;
      double sumLon = 0.0;
      for (var point in coord.polygonPoints) {
        sumLat += point.latitude;
        sumLon += point.longitude;
      }
      final centroidLat = sumLat / coord.polygonPoints.length;
      final centroidLon = sumLon / coord.polygonPoints.length;

      // Calcular distancia al centroide
      final distance = _calculateDistance(lat, lon, centroidLat, centroidLon);

      // Si está cerca (dentro del umbral), agregar a la lista
      if (distance <= proximityThreshold) {
        nearbyZones.add(ExclusionZoneMarker(
          idPolygonCoordinate: coord.id,
          namePolygonCoordinate: coord.name ?? 'Zona sin nombre',
          typePointName: coord.typePoint?.name,
          idTypePoint: coord.idTypePoint, // AGREGADO: Incluir ID del tipo
          typePoint:
              coord.typePoint, // AGREGADO: Incluir datos completos del tipo
          distanceMeters: distance,
          latitude: centroidLat,
          longitude: centroidLon,
        ));
      }
    }

    // Ordenar por distancia (más cercana primero)
    nearbyZones.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return nearbyZones;
  }

  /// Genera una coordenada desplazada aleatoriamente dentro del radio
  /// Valida que la coordenada NO esté dentro de polígonos de exclusión
  /// Calcula distancia al siguiente punto y tiempo estimado
  SimulatedLocationPoint _generateSimulatedPoint(
    VirtualPoint currentPoint,
    VirtualPoint? nextPoint,
    double radiusMeters,
    int sequenceNumber,
    DateTime currentSimulatedTime,
  ) {
    final random = math.Random();
    const int maxAttempts = 50; // Límite de intentos para evitar loop infinito
    int attempts = 0;

    double newLat = currentPoint.latitude;
    double newLon = currentPoint.longitude;
    bool validCoordinate = false;

    // Intentar generar una coordenada válida (fuera de zonas de exclusión)
    while (!validCoordinate && attempts < maxAttempts) {
      attempts++;

      // Generar ángulo aleatorio (0 a 360 grados)
      final angle = random.nextDouble() * 2 * math.pi;

      // Generar distancia aleatoria dentro del radio
      // Usar sqrt para distribución uniforme en área circular
      final distance = math.sqrt(random.nextDouble()) * radiusMeters;

      // Calcular desplazamiento en metros
      final deltaLat = distance * math.cos(angle);
      final deltaLon = distance * math.sin(angle);

      // Convertir metros a grados
      // 1 grado de latitud ≈ 111,320 metros
      // 1 grado de longitud ≈ 111,320 * cos(latitud) metros
      final latInRadians = currentPoint.latitude * math.pi / 180;
      const metersPerDegreeLat = 111320.0;
      final metersPerDegreeLon = 111320.0 * math.cos(latInRadians);

      newLat = currentPoint.latitude + (deltaLat / metersPerDegreeLat);
      newLon = currentPoint.longitude + (deltaLon / metersPerDegreeLon);

      // Verificar si la coordenada está dentro de una zona de exclusión
      if (!_isPointInExclusionZone(newLat, newLon)) {
        validCoordinate = true;
      }
    }

    // Si después de todos los intentos no se encontró coordenada válida
    if (!validCoordinate) {
      debugPrint(
          '⚠️ No se pudo generar coordenada válida para VP L${currentPoint.lineNumber} P${currentPoint.pointNumber} después de $maxAttempts intentos');
      debugPrint('   Usando coordenada del punto virtual original');
      // Usar la coordenada del punto virtual original como fallback
      newLat = currentPoint.latitude;
      newLon = currentPoint.longitude;
    }

    // Generar velocidad de caminata aleatoria
    final walkingSpeed = _generateWalkingSpeed();

    // Calcular distancia y tiempo al siguiente punto
    double distanceToNext = 0.0;
    Duration timeToNext = Duration.zero;

    if (nextPoint != null) {
      // Calcular distancia desde la coordenada simulada actual al siguiente punto virtual
      distanceToNext = _calculateDistance(
        newLat,
        newLon,
        nextPoint.latitude,
        nextPoint.longitude,
      );

      // Calcular tiempo basado en velocidad
      // tiempo (s) = distancia (m) / velocidad (m/s)
      final timeInSeconds = distanceToNext / walkingSpeed;
      timeToNext = Duration(milliseconds: (timeInSeconds * 1000).round());
    }

    // Detectar zonas de exclusión cercanas para anuncios de voz
    final nearbyZones = _findNearbyExclusionZones(newLat, newLon);

    if (nearbyZones.isNotEmpty) {
      debugPrint(
          '   🚧 ${nearbyZones.length} zona(s) de exclusión cercana(s):');
      for (var zone in nearbyZones.take(3)) {
        // Mostrar solo las 3 más cercanas
        debugPrint(
            '      - ${zone.namePolygonCoordinate} | Tipo: "${zone.typePointName ?? 'SIN TIPO'}" | Distancia: ${zone.distanceMeters.toStringAsFixed(1)}m');
      }
    }

    return SimulatedLocationPoint(
      currentVirtualPoint: currentPoint,
      nextVirtualPoint: nextPoint,
      simulatedLatitude: newLat,
      simulatedLongitude: newLon,
      timestamp: DateTime.now(),
      sequenceNumber: sequenceNumber,
      simulatedTimestamp: currentSimulatedTime,
      walkingSpeedMps: walkingSpeed,
      distanceToNextMeters: distanceToNext,
      timeToNextPoint: timeToNext,
      nearbyExclusionZones: nearbyZones,
    );
  }

  /// Ordenamiento: Línea Recta
  /// Recorre LÍNEA 1 completa, luego LÍNEA 2 completa, luego LÍNEA 3, etc.
  /// Al terminar cada línea, se conecta al punto más cercano de la línea siguiente
  /// Ejemplo: L1P1→L1P2→L1P3 → L2P3→L2P2→L2P1 → L3P1→L3P2→L3P3 (alternando dirección)
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
    debugPrint('   Puntos por línea:');
    lineGroups.forEach((line, pts) {
      debugPrint('   - Línea $line: ${pts.length} puntos');
    });

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
            '   ✅ Primera línea (L$lineNumber): agregados ${validPoints.length} puntos (desde P$startPoint hasta P${validPoints.last.pointNumber})');
      } else if (result.isNotEmpty || lineNumber > startLine) {
        // Determinar dirección basándonos en el último punto agregado y la línea actual
        final lastAddedPoint = result.last;
        final lastPointNumber = lastAddedPoint.pointNumber;

        // Calcular distancia al primer y último punto de la línea actual
        final firstPointOfLine = linePoints.first.pointNumber;
        final lastPointOfLine = linePoints.last.pointNumber;

        final distToFirst = (lastPointNumber - firstPointOfLine).abs();
        final distToLast = (lastPointNumber - lastPointOfLine).abs();

        debugPrint(
            '   📏 Último punto agregado: L${lastAddedPoint.lineNumber}P$lastPointNumber');
        debugPrint(
            '   📏 Línea $lineNumber: P$firstPointOfLine a P$lastPointOfLine');
        debugPrint(
            '   📏 Distancia a primer punto: $distToFirst, a último punto: $distToLast');

        // Agregar línea en la dirección que minimiza distancia
        if (distToFirst <= distToLast) {
          // Más cerca del primer punto, ir hacia adelante
          result.addAll(linePoints);
          debugPrint(
              '   ✅ Agregados ${linePoints.length} puntos de L$lineNumber (→ forward: P$firstPointOfLine→P$lastPointOfLine)');
        } else {
          // Más cerca del último punto, ir hacia atrás
          result.addAll(linePoints.reversed);
          debugPrint(
              '   ✅ Agregados ${linePoints.length} puntos de L$lineNumber (← reverse: P$lastPointOfLine→P$firstPointOfLine)');
        }
      }
    }

    debugPrint(
        '✅ _orderStraightLine completado: ${result.length} puntos totales');

    return result;
  }

  /// Ordenamiento: Zigzag Simple
  /// Alterna entre 2 líneas, punto por punto
  /// Al terminar cada par, se conecta al punto más cercano del siguiente par
  /// Ejemplo: L1P1→L2P1→L1P2→L2P2→L1P3→L2P3 → L4P3→L3P3→L4P2→L3P2→L4P1→L3P1
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
    debugPrint('   Puntos por línea:');
    lineGroups.forEach((line, pts) {
      debugPrint('   - Línea $line: ${pts.length} puntos');
    });

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

      debugPrint(
          '   📍 Alternando entre línea $line1 y ${line2Index < availableLines.length ? availableLines[line2Index] : "N/A"} (reverso: $reverseNextPair)');

      // Si debemos invertir el par (para conectar con el punto más cercano)
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
        // Si es la primera iteración y es la línea inicial, aplicar startPoint
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

      debugPrint('   ✅ Zigzag completado para este par de líneas');

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
  /// Recorre cada línea completa alternando dirección (forward/backward)
  /// Ejemplo: L1 (P1→P2→P3) → L2 (P3→P2→P1) → L3 (P1→P2→P3)
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

    return result;
  }

  /// Ordenamiento: Zigzag Espiral (Patrón Telaraña)
  /// Empieza en un punto específico y se expande en todas direcciones en zigzag
  /// Cubre puntos cercanos progresivamente, como una telaraña desde el centro
  /// Ejemplo desde L5P10: L5P10→L5P11→L6P11→L6P10→L4P10→L4P11→L5P12→L6P12...
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

    debugPrint(
        '🕸️ Zigzag Espiral (Telaraña): Inicio en L${startLine}P${startPoint}');

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
          debugPrint('   ✓ Agregado: L${line}P${pointNum}');
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

    // Expandir en anillos concéntricos (radio)
    int maxRadius = 100; // Límite de seguridad
    for (int radius = 1; radius <= maxRadius; radius++) {
      int addedInRadius = 0;

      // Para cada radio, recorrer en forma de zigzag
      // 1. Líneas hacia arriba y abajo
      final linesToCheck = <int>[];

      // Agregar línea superior
      if (allLines.contains(startLine + radius)) {
        linesToCheck.add(startLine + radius);
      }

      // Agregar línea inferior
      if (radius > 0 && allLines.contains(startLine - radius)) {
        linesToCheck.add(startLine - radius);
      }

      // 2. Para cada línea en este radio, expandir puntos horizontalmente
      for (var line in linesToCheck) {
        if (!lineGroups.containsKey(line)) continue;
        final availablePoints = pointRanges[line]!;

        // Expandir desde startPoint hacia ambos lados
        for (int pOffset = 0; pOffset <= radius; pOffset++) {
          // Punto a la derecha
          final rightPoint = startPoint + pOffset;
          if (availablePoints.contains(rightPoint)) {
            final key = '$line:$rightPoint';
            if (!visited.contains(key)) {
              addPoint(line, rightPoint);
              addedInRadius++;
            }
          }

          // Punto a la izquierda (si pOffset > 0 para no duplicar el centro)
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

      // 3. También cubrir puntos en la línea inicial que estén en este radio
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

      // Si no agregamos nada en este radio, intentamos algunos radios más
      // pero si llegamos muy lejos sin agregar nada, terminamos
      if (addedInRadius == 0 && radius > 10) {
        debugPrint('   🛑 Radio $radius sin puntos, deteniendo expansión');
        break;
      }

      debugPrint('   📊 Radio $radius: agregados $addedInRadius puntos');
    }

    debugPrint('✅ Zigzag Espiral completado: ${result.length} puntos totales');

    return result;
  }

  /// Ordenar puntos virtuales según configuración
  /// Filtra puntos en zonas de exclusión antes de ordenar
  List<VirtualPoint> _orderVirtualPoints(
    List<VirtualPoint> allPoints,
    RouteSimulationConfig config,
  ) {
    // 1. PRIMERO: Filtrar puntos que están dentro de polígonos de exclusión
    final initialCount = allPoints.length;

    // Obtener líneas únicas ANTES del filtro de exclusión
    final linesBeforeExclusion =
        allPoints.map((p) => p.lineNumber).toSet().toList()..sort();
    debugPrint(
        '📊 Líneas ANTES de filtrar zonas de exclusión: ${linesBeforeExclusion.length} líneas');
    debugPrint('   Líneas: $linesBeforeExclusion');

    var filteredPoints =
        allPoints.where((vp) => !_isVirtualPointInExclusionZone(vp)).toList();
    final excludedCount = initialCount - filteredPoints.length;

    if (excludedCount > 0) {
      debugPrint(
          '🚫 Excluidos $excludedCount puntos virtuales por estar en zonas de exclusión');

      // Mostrar qué líneas quedaron después de filtrar zonas de exclusión
      final linesAfterExclusion =
          filteredPoints.map((p) => p.lineNumber).toSet().toList()..sort();
      debugPrint(
          '📊 Líneas DESPUÉS de filtrar zonas de exclusión: ${linesAfterExclusion.length} líneas');
      debugPrint('   Líneas: $linesAfterExclusion');

      // Mostrar qué líneas se perdieron completamente
      final lostLines = linesBeforeExclusion
          .where((line) => !linesAfterExclusion.contains(line))
          .toList();
      if (lostLines.isNotEmpty) {
        debugPrint(
            '⚠️ Líneas COMPLETAMENTE EXCLUIDAS por zonas de exclusión: $lostLines');
      }
    }

    // 2. Filtrar puntos si hay límite de líneas
    if (config.maxLines != null) {
      debugPrint('🔍 Filtrando por límite de líneas:');
      debugPrint('   - startLine: ${config.startLine}');
      debugPrint('   - maxLines: ${config.maxLines}');
      debugPrint(
          '   - Rango: línea ${config.startLine} a ${config.startLine + config.maxLines! - 1}');

      filteredPoints = filteredPoints.where((point) {
        return point.lineNumber >= config.startLine &&
            point.lineNumber < config.startLine + config.maxLines!;
      }).toList();

      // Contar líneas únicas después del filtro
      final uniqueLines = filteredPoints.map((p) => p.lineNumber).toSet();
      debugPrint('   - Puntos después del filtro: ${filteredPoints.length}');
      debugPrint(
          '   - Líneas únicas después del filtro: ${uniqueLines.length}');
      debugPrint('   - Líneas: ${uniqueLines.toList()..sort()}');
    }

    debugPrint(
        '✅ Puntos virtuales válidos para simulación: ${filteredPoints.length}');

    // 3. Ordenar según patrón (ahora los algoritmos manejan startLine y startPoint internamente)
    switch (config.pattern) {
      case RoutePattern.lineaRecta:
        return _orderStraightLine(
            filteredPoints, config.startLine, config.startPoint);
      case RoutePattern.zigzagSimple:
        return _orderZigzagSimple(
            filteredPoints, config.startLine, config.startPoint);
      case RoutePattern.zigzagSerpentina:
        return _orderZigzagSerpentina(
            filteredPoints, config.startLine, config.startPoint);
      case RoutePattern.zigzagEspiral:
        return _orderZigzagEspiral(
            filteredPoints, config.startLine, config.startPoint);
      case RoutePattern.rutaOptimizada:
        // La ruta optimizada se maneja en _generateSimulatedRoute directamente
        // Este caso no debería llegar aquí, pero lo incluimos por completitud
        return filteredPoints;
    }
  }

  /// Calcular velocidad promedio en km/h basada en velocidades aleatorias generadas
  /// Rango típico: 2.88 - 5.4 km/h (0.8 - 1.5 m/s)
  double _calculateAverageSpeedKmh() {
    // Promedio del rango 0.8 - 1.5 m/s = 1.15 m/s
    // 1.15 m/s * 3.6 = 4.14 km/h
    const double avgSpeedMps = 1.15; // Promedio del rango
    return avgSpeedMps * 3.6; // Convertir a km/h
  }

  /// Obtener ruta optimizada desde SQLite (guardada por sync_install_module)
  Future<List<VirtualPoint>?> _getOptimizedRouteFromSQLite(
    RouteSimulationConfig config,
  ) async {
    try {
      debugPrint('💾 Buscando ruta optimizada en SQLite...');

      if (_headquarter == null) {
        debugPrint('❌ No hay ID de headquarter disponible');
        return null;
      }

      // Obtener base de datos
      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      // Buscar ruta optimizada que coincida con la configuración
      final List<Map<String, dynamic>> routes = await db.query(
        'Optimized_routes',
        where:
            'Id_headquarter = ? AND Start_line = ? AND Start_point = ? AND Max_lines = ? AND Max_points = ?',
        whereArgs: [
          _headquarter!.id,
          config.startLine,
          config.startPoint,
          config.maxLines ?? 0,
          config.maxPoints ?? 0,
        ],
        orderBy: 'Created_at DESC',
        limit: 1,
      );

      if (routes.isEmpty) {
        debugPrint(
            '   ⚠️ No se encontró ruta optimizada para esta configuración');
        debugPrint('   Configuración buscada:');
        debugPrint('      - Headquarter: ${_headquarter!.id}');
        debugPrint('      - Start Line: ${config.startLine}');
        debugPrint('      - Start Point: ${config.startPoint}');
        debugPrint('      - Max Lines: ${config.maxLines ?? 0}');
        debugPrint('      - Max Points: ${config.maxPoints ?? 0}');
        await db.close();
        return null;
      }

      final routeData = routes.first;
      final int routeId = routeData['Id_optimized_route'] as int;

      debugPrint('   ✅ Ruta encontrada: ID=$routeId');
      debugPrint('      Distancia total: ${routeData['Total_distance_km']} km');
      debugPrint('      Duración estimada: ${routeData['Estimated_duration']}');
      debugPrint('      Algoritmo: ${routeData['Algorithm']}');
      debugPrint('      Estrategia: ${routeData['Strategy_used']}');

      // Obtener puntos ordenados de la ruta
      final List<Map<String, dynamic>> pointsData = await db.query(
        'Optimized_route_points',
        where: 'Id_optimized_route = ?',
        whereArgs: [routeId],
        orderBy: 'Route_position ASC',
      );

      await db.close();

      if (pointsData.isEmpty) {
        debugPrint('   ⚠️ La ruta no tiene puntos asociados');
        return null;
      }

      debugPrint('   📍 ${pointsData.length} puntos cargados desde SQLite');

      // Convertir a VirtualPoint
      final List<VirtualPoint> orderedPoints = [];
      for (var pointData in pointsData) {
        final vpId = pointData['Id_virtual_point'] as int;

        // Buscar el punto virtual en la lista ya cargada
        final vp = _virtualPoints.firstWhere(
          (p) => p.id == vpId,
          orElse: () {
            // Si no está en la lista, crear uno nuevo con los datos de SQLite
            final idTypePoint = pointData['Id_type_point'] as int?;
            return VirtualPoint(
              id: vpId,
              lineNumber: pointData['Line_number'] as int,
              pointNumber: pointData['Point_number'] as int,
              latitude: pointData['Latitude'] as double,
              longitude: pointData['Longitude'] as double,
              description: null,
              isActive: true,
              idTypePoint: idTypePoint,
              typeName: null,
              headquarterName: null,
              pointDisplayName: null,
              typePoint: idTypePoint != null ? _typePoints[idTypePoint] : null,
            );
          },
        );
        orderedPoints.add(vp);
      }

      debugPrint(
          '   ✅ ${orderedPoints.length} puntos convertidos correctamente');
      return orderedPoints;
    } catch (e, stackTrace) {
      debugPrint('❌ Error obteniendo ruta optimizada desde SQLite: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Obtener el punto virtual inicial basado en la configuración
  VirtualPoint? _getStartingPoint(RouteSimulationConfig config) {
    try {
      // Buscar el punto que coincida con startLine y startPoint
      final startPoint = _virtualPoints.firstWhere(
        (vp) =>
            vp.lineNumber == config.startLine &&
            vp.pointNumber == config.startPoint,
        orElse: () => throw Exception('Punto inicial no encontrado'),
      );

      debugPrint(
          '📍 Punto inicial encontrado: L${config.startLine}P${config.startPoint}');
      return startPoint;
    } catch (e) {
      debugPrint(
          '⚠️ No se encontró el punto inicial L${config.startLine}P${config.startPoint}: $e');
      return null;
    }
  }

  /// Widget helper para mostrar información de ruta en el diálogo
  Widget _buildRouteInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right,
            size: 16,
            color: FlutterFlowTheme.of(context).primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generar ruta simulada completa
  Future<void> _generateSimulatedRoute(
    RouteSimulationConfig config, {
    bool skipExistingCheck = false,
  }) async {
    debugPrint('🧪 Generando ruta simulada...');
    debugPrint('   Patrón seleccionado: ${config.pattern}');
    debugPrint('   Verificando polígonos de exclusión: ${_coordinates.length}');

    // VERIFICAR SI YA EXISTE UNA RUTA CON ESTOS PARÁMETROS (solo si no se saltó la verificación)
    if (!skipExistingCheck && _headquarter != null) {
      final exists = await _routeExists(_headquarter!.id, config);
      if (exists) {
        debugPrint('⚠️ Ya existe una ruta con estos parámetros');

        // Mostrar diálogo de confirmación
        final bool? shouldReplace = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: FlutterFlowTheme.of(context).warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ruta Ya Existente',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ya generaste una ruta con estos parámetros:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRouteInfoItem(
                      'Patrón', config.pattern.toString().split('.').last),
                  _buildRouteInfoItem('Inicio',
                      'Línea ${config.startLine}, Punto ${config.startPoint}'),
                  if (config.maxLines != null)
                    _buildRouteInfoItem('Máx. Líneas', '${config.maxLines}'),
                  if (config.maxPoints != null)
                    _buildRouteInfoItem('Máx. Palmas', '${config.maxPoints}'),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Deseas reemplazar la ruta existente?',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).warning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Reemplazar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        // Si el usuario canceló, salir
        if (shouldReplace != true) {
          debugPrint('❌ Usuario canceló la generación de ruta');
          return;
        }

        debugPrint('✅ Usuario confirmó reemplazo de ruta');
      }
    }

    // 0. LIMPIAR RUTA ANTERIOR
    _simulatedRoute.clear();
    _currentPlaybackIndex = 0;
    _isPlaybackPlaying = false;
    _isPlaybackActive = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackStartTime = null;
    _startingPoint = null; // Limpiar punto inicial anterior

    // Actualizar UI inmediatamente para limpiar líneas del mapa
    if (mounted) {
      setState(() {});
    }

    debugPrint('   🧹 Ruta anterior limpiada');

    // 1. Ordenar puntos virtuales según configuración
    List<VirtualPoint> orderedPoints;

    if (config.pattern == RoutePattern.rutaOptimizada) {
      // Obtener ruta optimizada desde SQLite
      debugPrint('   💾 Cargando ruta optimizada desde SQLite...');
      final sqliteOrderedPoints = await _getOptimizedRouteFromSQLite(config);

      if (sqliteOrderedPoints == null || sqliteOrderedPoints.isEmpty) {
        debugPrint(
            '❌ No se pudo obtener ruta optimizada desde SQLite, cancelando generación');
        debugPrint('   💡 Asegúrate de sincronizar el módulo primero');
        _showMarkerInfo(
          'Ruta No Disponible',
          'Sin datos offline',
          'No hay ruta optimizada guardada localmente. Sincroniza el módulo primero.',
        );
        return;
      }

      orderedPoints = sqliteOrderedPoints;
      debugPrint(
          '   ✅ Usando ruta optimizada desde SQLite (${orderedPoints.length} puntos)');
    } else {
      // Ordenar puntos localmente según patrón seleccionado (filtra zonas de exclusión)
      orderedPoints = _orderVirtualPoints(_virtualPoints, config);
      debugPrint(
          '   ✅ Usando ordenamiento local: ${config.pattern} (${orderedPoints.length} puntos)');
    }

    if (orderedPoints.isEmpty) {
      debugPrint('❌ No hay puntos virtuales válidos para simular');
      _showMarkerInfo(
        'Error de Simulación',
        'No hay puntos válidos',
        'Todos los puntos virtuales están en zonas de exclusión o fuera del rango especificado.',
      );
      return;
    }

    // 2. Aplicar límite de puntos totales si existe
    final pointsToSimulate = config.maxPoints != null
        ? orderedPoints.take(config.maxPoints!).toList()
        : orderedPoints;

    debugPrint('   Puntos a simular: ${pointsToSimulate.length}');

    // 3. Generar puntos simulados con margen de error y timestamps
    _simulatedRoute.clear();
    int coordinatesWithFallback = 0;

    // Hora de inicio: 8:00 AM del día actual
    final today = DateTime.now();
    DateTime currentSimulatedTime = DateTime(
      today.year,
      today.month,
      today.day,
      8, // 8 AM
      0,
      0,
    );

    for (int i = 0; i < pointsToSimulate.length; i++) {
      final currentPoint = pointsToSimulate[i];
      final nextPoint =
          i < pointsToSimulate.length - 1 ? pointsToSimulate[i + 1] : null;

      final simulatedPoint = _generateSimulatedPoint(
        currentPoint,
        nextPoint,
        config.errorMarginMeters,
        i + 1,
        currentSimulatedTime,
      );

      // Contar si se usó fallback (coordenada = punto virtual)
      if (simulatedPoint.simulatedLatitude == currentPoint.latitude &&
          simulatedPoint.simulatedLongitude == currentPoint.longitude) {
        coordinatesWithFallback++;
      }

      _simulatedRoute.add(simulatedPoint);

      // Actualizar tiempo para el siguiente punto
      currentSimulatedTime =
          currentSimulatedTime.add(simulatedPoint.timeToNextPoint);
    }

    // Calcular tiempo total del recorrido
    final totalTime = _simulatedRoute.isEmpty
        ? Duration.zero
        : _simulatedRoute.last.simulatedTimestamp
            .difference(_simulatedRoute.first.simulatedTimestamp);

    final totalDistance = _simulatedRoute.fold<double>(
        0.0, (sum, point) => sum + point.distanceToNextMeters);

    debugPrint('✅ Ruta simulada generada: ${_simulatedRoute.length} puntos');
    debugPrint('   Patrón: ${config.pattern}');
    debugPrint('   Margen de error: ${config.errorMarginMeters}m');
    debugPrint(
        '   Distancia total: ${(totalDistance / 1000).toStringAsFixed(2)} km');
    debugPrint(
        '   Tiempo estimado: ${totalTime.inHours}h ${totalTime.inMinutes % 60}m ${totalTime.inSeconds % 60}s');
    debugPrint(
        '   Hora inicio: ${_simulatedRoute.first.simulatedTimestamp.toString().substring(11, 19)}');
    debugPrint(
        '   Hora fin estimada: ${_simulatedRoute.last.simulatedTimestamp.toString().substring(11, 19)}');

    if (coordinatesWithFallback > 0) {
      debugPrint(
          '⚠️ Advertencia: $coordinatesWithFallback coordenadas no pudieron desplazarse (zona de exclusión muy cercana)');
    }

    setState(() {
      _routeConfig = config;
      _startingPoint = _getStartingPoint(config);
      _showSimulatedRoute = true;
    });

    // Guardar ruta en SQLite (TODAS las rutas, no solo optimizadas)
    if (_headquarter != null && config.pattern != RoutePattern.rutaOptimizada) {
      try {
        await _saveRouteToDatabase(
          _headquarter!.id,
          config,
          pointsToSimulate,
          totalDistance / 1000, // Convertir metros a km
          '${totalTime.inHours}h ${totalTime.inMinutes % 60}m',
          totalTime.inSeconds,
        );
        debugPrint('✅ Ruta guardada automáticamente en SQLite');
      } catch (e) {
        debugPrint('⚠️ No se pudo guardar la ruta en SQLite: $e');
        // No mostrar error al usuario, solo log
      }
    }

    // Mostrar mensaje si hay coordenadas con fallback
    if (coordinatesWithFallback > 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showMarkerInfo(
            'Simulación Generada',
            'Ruta creada con advertencias',
            '$coordinatesWithFallback de ${_simulatedRoute.length} coordenadas están muy cerca de zonas de exclusión y no pudieron desplazarse.\n\nEstas coordenadas coinciden exactamente con sus puntos virtuales de referencia.',
          );
        }
      });
    }
  }

  /// Generar ruta simulada desde lista de VirtualPoints cargados de la BD
  Future<void> _generateSimulatedRouteFromVirtualPoints(
      List<VirtualPoint> points) async {
    debugPrint('🧪 Generando ruta simulada desde puntos cargados...');

    _simulatedRoute.clear();

    // Hora de inicio: 8:00 AM del día actual
    final today = DateTime.now();
    DateTime currentTime = DateTime(
      today.year,
      today.month,
      today.day,
      8,
      0,
      0,
    );

    for (int i = 0; i < points.length; i++) {
      final currentPoint = points[i];
      final nextPoint = i < points.length - 1 ? points[i + 1] : null;

      // Generar velocidad de caminata aleatoria
      final walkingSpeed = _generateWalkingSpeed();

      // Calcular distancia y tiempo al siguiente punto
      double distanceToNext = 0.0;
      Duration timeToNext = Duration.zero;

      if (nextPoint != null) {
        distanceToNext = _calculateDistance(
          currentPoint.latitude,
          currentPoint.longitude,
          nextPoint.latitude,
          nextPoint.longitude,
        );

        final timeInSeconds = (distanceToNext / walkingSpeed).ceil();
        timeToNext = Duration(seconds: timeInSeconds);
      }

      // Crear punto simulado
      final simPoint = SimulatedLocationPoint(
        currentVirtualPoint: currentPoint,
        nextVirtualPoint: nextPoint,
        sequenceNumber: i,
        simulatedLatitude: currentPoint.latitude,
        simulatedLongitude: currentPoint.longitude,
        timestamp: DateTime.now(),
        simulatedTimestamp: currentTime,
        walkingSpeedMps: walkingSpeed,
        distanceToNextMeters: distanceToNext,
        timeToNextPoint: timeToNext,
        nearbyExclusionZones: _findNearbyExclusionZones(
          currentPoint.latitude,
          currentPoint.longitude,
        ),
      );

      _simulatedRoute.add(simPoint);

      // Avanzar el tiempo
      currentTime = currentTime.add(timeToNext);
    }

    debugPrint('   ✅ ${_simulatedRoute.length} puntos simulados generados');

    setState(() {
      _showSimulatedRoute = true;
    });
  }

  void _applyFilter() {
    if (_selectedFilter.duration == null) {
      _filteredGeolocations = List.from(_allGeolocations);
    } else {
      final now = DateTime.now();
      final cutoffTime = now.subtract(_selectedFilter.duration!);

      _filteredGeolocations = _allGeolocations
          .where((geo) => geo.timestamp.isAfter(cutoffTime))
          .toList();
    }

    debugPrint(
        '🔍 Filtro aplicado: ${_selectedFilter.label} - ${_filteredGeolocations.length} puntos');

    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getDatabasePath() async {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }

    final String pathStr = '${externalDir.path}/ClickPalmData';
    return path.join(pathStr, 'clickpalm_database.db');
  }

  vtr.Theme _createVectorTheme() {
    return vtr.ThemeReader().read({
      "version": 8,
      "sources": {
        "pmtiles": {"type": "vector"}
      },
      "layers": [
        {
          "id": "background",
          "type": "background",
          "paint": {"background-color": "#F8F4F0"}
        },
        {
          "id": "water",
          "type": "fill",
          "source": "pmtiles",
          "source-layer": "water",
          "paint": {"fill-color": "#AAD3DF"}
        },
        {
          "id": "park",
          "type": "fill",
          "source": "pmtiles",
          "source-layer": "park",
          "paint": {"fill-color": "#D8E8C8"}
        },
        {
          "id": "building",
          "type": "fill",
          "source": "pmtiles",
          "source-layer": "building",
          "paint": {"fill-color": "#E0E0E0", "fill-opacity": 0.7}
        },
        {
          "id": "road",
          "type": "line",
          "source": "pmtiles",
          "source-layer": "transportation",
          "paint": {"line-color": "#FFFFFF", "line-width": 2}
        },
        {
          "id": "place_label",
          "type": "symbol",
          "source": "pmtiles",
          "source-layer": "place",
          "layout": {
            "text-field": ["get", "name"],
            "text-size": 12
          },
          "paint": {
            "text-color": "#333333",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 2
          }
        }
      ]
    });
  }

  @override
  void dispose() {
    FFAppState().removeListener(_onLocationUpdate);
    _proximityTimer?.cancel();
    _playbackTimer?.cancel(); // Cancelar timer del reproductor
    _pulseController.dispose();
    _filterPanelController.dispose();
    _speakingAnimationController.dispose();
    _mapController.dispose();
    _ttsManager.dispose();
    super.dispose();
  }

  void _onLocationUpdate() {
    if (mounted) {
      setState(() {});

      if (_isFollowingUser) {
        _centerOnCurrentLocation(animated: true);
      }
    }
  }

  // ============================================================================
  // FUNCIONES DEL REPRODUCTOR DE RUTA
  // ============================================================================

  void _togglePlaybackPanel() {
    setState(() {
      _isPlaybackActive = !_isPlaybackActive;
      if (!_isPlaybackActive) {
        _stopPlayback();
      }
    });
  }

  void _startPlayback() {
    if (_simulatedRoute.isEmpty) return;

    setState(() {
      _isPlaybackPlaying = true;
      _playbackStartTime = DateTime.now();
      if (_currentPlaybackIndex == 0 ||
          _currentPlaybackIndex >= _simulatedRoute.length) {
        _currentPlaybackIndex = 0;
        // Reiniciar contador de anuncios de línea cuando se inicia desde el principio
        _currentAnnouncedLine = null;
        _pointsInCurrentLine = 0;
      }
    });

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updatePlaybackPosition();
    });
  }

  void _pausePlayback() {
    setState(() {
      _isPlaybackPlaying = false;
    });
    _playbackTimer?.cancel();
  }

  void _stopPlayback() {
    setState(() {
      _isPlaybackPlaying = false;
      _currentPlaybackIndex = 0;
      _playbackStartTime = null;
      // Reiniciar contador de anuncios de línea
      _currentAnnouncedLine = null;
      _pointsInCurrentLine = 0;
    });
    _playbackTimer?.cancel();
  }

  void _updatePlaybackPosition() {
    if (!_isPlaybackPlaying || _simulatedRoute.isEmpty) return;

    final elapsed = DateTime.now().difference(_playbackStartTime!);
    final adjustedElapsed = Duration(
      milliseconds: (elapsed.inMilliseconds * _playbackSpeed).round(),
    );

    int targetIndex = 0;
    Duration accumulatedTime = Duration.zero;

    for (int i = 0; i < _simulatedRoute.length; i++) {
      if (i > 0) {
        accumulatedTime += _simulatedRoute[i - 1].timeToNextPoint;
      }

      if (accumulatedTime <= adjustedElapsed) {
        targetIndex = i;
      } else {
        break;
      }
    }

    if (targetIndex >= _simulatedRoute.length - 1) {
      _stopPlayback();
      return;
    }

    setState(() {
      _currentPlaybackIndex = targetIndex;
    });

    if (_autoFollowPlayback) {
      final current = _simulatedRoute[_currentPlaybackIndex];
      try {
        _mapController.move(
          latlong.LatLng(current.simulatedLatitude, current.simulatedLongitude),
          _mapController.camera.zoom,
        );
      } catch (e) {
        debugPrint('⚠️ MapController no listo: $e');
      }
    }
  }

  void _jumpToPoint(int index) {
    if (index < 0 || index >= _simulatedRoute.length) return;

    final wasPlaying = _isPlaybackPlaying;
    if (wasPlaying) _pausePlayback();

    setState(() {
      _currentPlaybackIndex = index;
    });

    if (wasPlaying) {
      Duration timeToCurrentPoint = Duration.zero;
      for (int i = 0; i < _currentPlaybackIndex; i++) {
        timeToCurrentPoint += _simulatedRoute[i].timeToNextPoint;
      }

      _playbackStartTime = DateTime.now().subtract(
        Duration(
          milliseconds:
              (timeToCurrentPoint.inMilliseconds / _playbackSpeed).round(),
        ),
      );

      _startPlayback();
    }

    final current = _simulatedRoute[_currentPlaybackIndex];
    try {
      _mapController.move(
        latlong.LatLng(current.simulatedLatitude, current.simulatedLongitude),
        _mapController.camera.zoom,
      );
    } catch (e) {
      debugPrint('⚠️ MapController no listo: $e');
    }
  }

  void _nextPlaybackSpeed() {
    final currentIndex = _availablePlaybackSpeeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _availablePlaybackSpeeds.length;

    setState(() {
      _playbackSpeed = _availablePlaybackSpeeds[nextIndex];
    });

    debugPrint('🎬 Velocidad de reproducción: ${_playbackSpeed}x');
  }

  Duration _getTotalRouteTime() {
    if (_simulatedRoute.isEmpty) return Duration.zero;
    return _simulatedRoute.last.simulatedTimestamp
        .difference(_simulatedRoute.first.simulatedTimestamp);
  }

  Duration _getCurrentPlaybackTime() {
    if (_simulatedRoute.isEmpty || _currentPlaybackIndex == 0) {
      return Duration.zero;
    }
    return _simulatedRoute[_currentPlaybackIndex]
        .simulatedTimestamp
        .difference(_simulatedRoute.first.simulatedTimestamp);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatea la duración con unidades apropiadas (seg o min)
  String _formatDurationWithUnits(Duration duration) {
    final totalSeconds = duration.inSeconds;

    if (totalSeconds < 60) {
      // Menos de 1 minuto: mostrar en segundos con decimales
      final seconds = duration.inMilliseconds / 1000.0;
      return '${seconds.toStringAsFixed(1)} seg';
    } else if (totalSeconds < 3600) {
      // Menos de 1 hora: mostrar en minutos con decimales
      final minutes = totalSeconds / 60.0;
      return '${minutes.toStringAsFixed(1)} min';
    } else {
      // 1 hora o más: mostrar en formato hora:minuto
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}min';
    }
  }

  void _centerOnCurrentLocation({bool animated = true}) {
    // Verificar que el widget esté montado
    if (!mounted) return;

    final locations = FFAppState().geoLocationsList;

    if (locations.isEmpty) return;

    final currentLocation = locations.last;
    final center =
        latlong.LatLng(currentLocation.latitude, currentLocation.longitude);

    if (locations.length >= 2) {
      final prevLocation = locations[locations.length - 2];
      _currentBearing = _calculateBearing(
        prevLocation.latitude,
        prevLocation.longitude,
        currentLocation.latitude,
        currentLocation.longitude,
      );
    }

    if (animated) {
      try {
        _mapController.move(center, _currentZoom);
      } catch (e) {
        debugPrint('⚠️ MapController no listo para mover: $e');
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(center, _currentZoom);
          } catch (e) {
            debugPrint('⚠️ MapController no listo para mover (postFrame): $e');
          }
        }
      });
    }
  }

  void _centerOnVirtualPoints({bool animated = true}) {
    if (_virtualPoints.isEmpty) {
      debugPrint('⚠️ No hay puntos virtuales para centrar');
      return;
    }

    // Verificar que el widget esté montado antes de usar el controlador del mapa
    if (!mounted) {
      debugPrint('⚠️ Widget no montado, cancelando centrado en Virtual Points');
      return;
    }

    // Calcular el centroide (centro geométrico) de todos los puntos virtuales
    double sumLat = 0;
    double sumLng = 0;

    for (var point in _virtualPoints) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    final centerLat = sumLat / _virtualPoints.length;
    final centerLng = sumLng / _virtualPoints.length;

    final center = latlong.LatLng(centerLat, centerLng);

    debugPrint('📍 Centrando en Virtual Points: $centerLat, $centerLng');

    if (animated) {
      try {
        _mapController.move(center, 18.0);
      } catch (e) {
        debugPrint('⚠️ MapController no listo: $e');
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(center, 18.0);
          } catch (e) {
            debugPrint('⚠️ MapController no listo (postFrame): $e');
          }
        }
      });
    }

    // Desactivar el seguimiento automático de ubicación
    if (mounted) {
      setState(() {
        _isFollowingUser = false;
      });
    }
  }

  void _fitAllBounds() {
    List<latlong.LatLng> allPoints = [];

    // Agregar ubicación actual
    final currentLocation = _getCurrentLocation();
    if (currentLocation != null) {
      allPoints.add(currentLocation);
    }

    // Agregar puntos filtrados
    if (_showMyLocation) {
      allPoints.addAll(_getRoutePoints());
    }

    // Agregar virtual points
    if (_showVirtualPoints) {
      allPoints.addAll(_virtualPoints
          .map((vp) => latlong.LatLng(vp.latitude, vp.longitude)));
    }

    // Agregar polígono
    if (_showPolygon) {
      allPoints.addAll(_polygonPoints);
    }

    // Agregar productos
    if (_showProducts) {
      for (var product in _products) {
        allPoints.addAll(product.coordinates);
      }
    }

    // Agregar coordenadas (polígonos)
    if (_showCoordinates) {
      for (var coord in _coordinates) {
        allPoints.addAll(coord.polygonPoints);
      }
    }

    if (allPoints.isEmpty) return;

    // Calcular los límites manualmente
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (var point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      latlong.LatLng(minLat, minLng),
      latlong.LatLng(maxLat, maxLng),
    );

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ MapController no listo para fitCamera: $e');
    }
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Genera marcadores de flecha direccionales a lo largo de la ruta optimizada
  /// para indicar el sentido de recorrido
  List<Marker> _generateRouteArrows(List<latlong.LatLng> routePoints) {
    if (routePoints.length < 2) return [];

    final List<Marker> arrows = [];

    // Agregar flecha en CADA segmento (entre cada par de puntos virtuales)
    for (int i = 0; i < routePoints.length - 1; i++) {
      final start = routePoints[i];
      final end = routePoints[i + 1];

      // Calcular el punto medio del segmento
      final midLat = (start.latitude + end.latitude) / 2;
      final midLng = (start.longitude + end.longitude) / 2;

      // Calcular el ángulo de dirección (de start a end)
      final double bearing = _calculateBearing(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      // Crear marcador de flecha
      arrows.add(
        Marker(
          point: latlong.LatLng(midLat, midLng),
          width: 24, // Un poco más grande (antes 20)
          height: 24, // Un poco más grande (antes 20)
          child: Transform.rotate(
            angle: bearing * math.pi / 180, // Convertir a radianes
            child: const Icon(
              Icons.arrow_upward,
              size: 20, // Un poco más grande (antes 16)
              color: Color(0xFF2563EB), // Azul brillante (mismo que la línea)
              shadows: [
                Shadow(
                  color: Colors.white,
                  blurRadius: 4, // Sombra un poco más pronunciada
                ),
              ],
            ),
          ),
        ),
      );
    }

    return arrows;
  }

  List<latlong.LatLng> _getRoutePoints() {
    final List<latlong.LatLng> points = [];

    for (var geo in _filteredGeolocations) {
      points.add(latlong.LatLng(geo.latitude, geo.longitude));
    }

    return points;
  }

  latlong.LatLng? _getCurrentLocation() {
    final locations = FFAppState().geoLocationsList;
    if (locations.isEmpty) return null;

    final current = locations.last;
    return latlong.LatLng(current.latitude, current.longitude);
  }

  // ========================================================================
  // SISTEMA DE NAVEGACIÓN POR VOZ
  // ========================================================================

  /// Verifica proximidad a puntos virtuales y maneja anuncios de voz
  Future<void> _checkProximityToVirtualPoints() async {
    try {
      // Obtener ubicación actual (del reproductor si está activo, sino GPS real)
      final locationData = await _getCurrentLocationForVoice();
      if (locationData == null) {
        _updateNavigationState(
            NavigationState.idle, null, null, 'Esperando GPS...');
        return;
      }

      // Actualizar historial de movimiento estilo Waze
      _proximityOptimizer.updateMovementHistory(locationData);

      // Si no hay puntos virtuales cargados, no hacer nada
      if (_virtualPoints.isEmpty) {
        return;
      }

      // NUEVO: Verificar zonas de exclusión cercanas si estamos en modo reproductor
      if (_isPlaybackActive &&
          _isPlaybackPlaying &&
          _simulatedRoute.isNotEmpty &&
          _currentPlaybackIndex < _simulatedRoute.length) {
        final currentSimPoint = _simulatedRoute[_currentPlaybackIndex];

        // Anunciar zonas de exclusión cercanas
        if (currentSimPoint.nearbyExclusionZones.isNotEmpty && _voiceEnabled) {
          _announceExclusionZones(currentSimPoint);
        }
      }

      // Buscar punto virtual más cercano con algoritmo optimizado
      final closestPoint = _proximityOptimizer.findClosestPoint(
        locationData,
        _virtualPoints,
      );

      if (closestPoint == null) {
        _updateNavigationState(
            NavigationState.idle, null, null, 'Sin puntos cercanos');
        return;
      }

      // Calcular distancia al punto más cercano
      final distance = _calculateHaversineDistance(
        locationData.latitude,
        locationData.longitude,
        closestPoint.latitude,
        closestPoint.longitude,
      );

      // Determinar estado de navegación
      _processNavigationState(locationData, closestPoint, distance);
    } catch (e) {
      debugPrint('❌ Error en detección de proximidad: $e');
    }
  }

  /// Anuncia zonas de exclusión cercanas según el contexto
  void _announceExclusionZones(SimulatedLocationPoint currentPoint) {
    // Actualizar lista de zonas cercanas (≤25m para mostrar botón)
    final zonesWithin25m = currentPoint.nearbyExclusionZones
        .where((zone) => zone.distanceMeters <= 25.0)
        .toList();

    // Actualizar estado para mostrar/ocultar botón
    final shouldShowButton = zonesWithin25m.isNotEmpty;
    if (_showExclusionButton != shouldShowButton) {
      setState(() {
        _showExclusionButton = shouldShowButton;
        _nearbyExclusionZones = zonesWithin25m;
      });
      // debugPrint(
      //     '🚫 Botón de exclusión: ${shouldShowButton ? 'VISIBLE' : 'OCULTO'} | Zonas cercanas: ${zonesWithin25m.length}');
    } else if (shouldShowButton) {
      // Actualizar lista de zonas sin rebuild completo
      _nearbyExclusionZones = zonesWithin25m;
    }

    // Solo anunciar la zona más cercana para evitar saturación
    if (currentPoint.nearbyExclusionZones.isEmpty) return;

    final zone = currentPoint.nearbyExclusionZones.first;

    // debugPrint(
    //     '🔊 Evaluando anuncio de zona: "${zone.namePolygonCoordinate}" | Tipo: "${zone.typePointName ?? 'SIN TIPO'}" | Distancia: ${zone.distanceMeters.toStringAsFixed(1)}m');

    // Determinar qué anunciar según la distancia
    String? voiceMessage;
    String? messageId;
    SpeechPriority? priority;
    Duration? cooldown;

    if (zone.distanceMeters <= 10.0) {
      // Muy cerca (< 10m) - Prioridad ALTA
      // Usar un messageId genérico para evitar repetir el mismo tipo de zona
      final typeName = zone.typePointName ?? 'zona';
      voiceMessage = 'Precaución, $typeName muy cerca';
      messageId = 'exclusion_very_close_${zone.typePointName ?? "unknown"}';
      priority = SpeechPriority.high;
      cooldown = const Duration(seconds: 30); // Aumentado de 5 a 30 segundos
    } else if (zone.distanceMeters <= 25.0) {
      // Cerca (10-25m) - Prioridad NORMAL
      // Solo anunciar si hay suficiente tiempo hasta el siguiente punto
      if (currentPoint.timeToNextPoint.inSeconds > 20) {
        final typeName = zone.typePointName ?? 'zona';
        voiceMessage = '$typeName cercana';
        messageId = 'exclusion_close_${zone.typePointName ?? "unknown"}';
        priority = SpeechPriority.normal;
        cooldown = const Duration(seconds: 45); // Aumentado de 10 a 45 segundos
      }
    } else if (zone.distanceMeters <= 50.0) {
      // Lejos (25-50m) - Prioridad BAJA, solo si hay mucho tiempo al siguiente punto
      // Verificar si el tiempo al siguiente punto es > 40 segundos
      if (currentPoint.timeToNextPoint.inSeconds > 40) {
        final typeName = zone.typePointName ?? 'zona de exclusión';
        voiceMessage = '$typeName adelante';
        messageId = 'exclusion_far_${zone.typePointName ?? "unknown"}';
        priority = SpeechPriority.low;
        cooldown =
            const Duration(minutes: 1); // Aumentado de 15 segundos a 1 minuto
      }
    }

    // Encolar mensaje si se generó
    if (voiceMessage != null &&
        messageId != null &&
        priority != null &&
        cooldown != null) {
      // debugPrint(
      //     '   ✅ Anunciando: "$voiceMessage" (prioridad: ${priority.toString().split('.').last})');
      _ttsManager.enqueueSpeech(
        voiceMessage,
        messageId,
        priority,
        cooldown,
      );
    } else {
      // debugPrint(
      //     '   ⏭️ Anuncio omitido (condiciones de tiempo no cumplidas o fuera de rango)');
    }
  }

  /// Obtiene la ubicación actual para el sistema de voz según el contexto:
  /// - Si el reproductor está activo Y reproduciendo: usa coordenadas ficticias
  /// - En cualquier otro caso: usa ubicación GPS real desde SQLite
  Future<LocationData?> _getCurrentLocationForVoice() async {
    // Si el reproductor está activo y reproduciendo, usar coordenadas ficticias
    if (_isPlaybackActive &&
        _isPlaybackPlaying &&
        _simulatedRoute.isNotEmpty &&
        _currentPlaybackIndex < _simulatedRoute.length) {
      final currentSimulatedPoint = _simulatedRoute[_currentPlaybackIndex];

      // debugPrint(
      //     '🎤 Usando ubicación FICTICIA del reproductor para sistema de voz');
      // debugPrint(
      //     '   Punto: L${currentSimulatedPoint.currentVirtualPoint.lineNumber} P${currentSimulatedPoint.currentVirtualPoint.pointNumber}');

      return LocationData(
        latitude: currentSimulatedPoint.simulatedLatitude,
        longitude: currentSimulatedPoint.simulatedLongitude,
        speed: currentSimulatedPoint
            .walkingSpeedMps, // Velocidad de caminata simulada
        battery: 100.0, // Batería ficticia al 100%
        createdAt: currentSimulatedPoint.simulatedTimestamp,
      );
    }

    // En cualquier otro caso, usar ubicación GPS real
    // debugPrint('🎤 Usando ubicación GPS REAL para sistema de voz'); // SILENCIADO - logging excesivo
    return await _getLastLocationFromDB();
  }

  /// Obtiene la última ubicación desde SQLite
  Future<LocationData?> _getLastLocationFromDB() async {
    try {
      final String dbPath = await _getDatabasePath();
      final database = await openDatabase(dbPath);

      final List<Map<String, dynamic>> results = await database.query(
        'Location_tracking',
        orderBy: 'CreatedAt DESC',
        limit: 1,
      );

      // NO cerrar - sqflite maneja el pool automáticamente

      if (results.isEmpty) return null;

      final row = results.first;
      return LocationData(
        latitude: row['Latitude'] as double,
        longitude: row['Longitude'] as double,
        speed: (row['Speed'] as num?)?.toDouble() ?? 0.0,
        battery: (row['Battery'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(row['CreatedAt'] as String),
      );
    } catch (e) {
      debugPrint('❌ Error obteniendo última ubicación: $e');
      return null;
    }
  }

  /// Procesa el estado de navegación y genera eventos/anuncios
  void _processNavigationState(
    LocationData location,
    VirtualPoint point,
    double distance,
  ) {
    NavigationState newState;
    String message;
    String voiceMessage;

    // Determinar estado según distancia y velocidad
    if (location.speed < 0.5) {
      // Usuario sin movimiento
      newState = NavigationState.noMovement;
      message = 'Sin movimiento';
      voiceMessage = 'Sin movimiento';

      if (_voiceEnabled) {
        _ttsManager.enqueueSpeech(
          voiceMessage,
          'no_movement',
          SpeechPriority.low,
          const Duration(
              minutes: 1), // Cooldown muy largo para "sin movimiento"
        );
      }
    } else if (distance <= 2.0) {
      // En el punto (< 2m)
      newState = NavigationState.atPoint;
      message = 'En Línea ${point.lineNumber} - Punto ${point.pointNumber}';

      // Lógica inteligente de anuncios de línea
      bool shouldAnnounceLine = false;
      String lineAnnouncement = '';

      // Verificar si cambió de línea
      if (_currentAnnouncedLine != point.lineNumber) {
        // Cambio de línea: SIEMPRE anunciar
        shouldAnnounceLine = true;
        lineAnnouncement = 'Línea ${point.lineNumber}';
        _currentAnnouncedLine = point.lineNumber;
        _pointsInCurrentLine = 1; // Reiniciar contador
        // debugPrint(
        //     '📍 Cambio de línea detectado: ${_currentAnnouncedLine} → ${point.lineNumber}');
      } else {
        // Misma línea: incrementar contador
        _pointsInCurrentLine++;

        // Anunciar cada 6 puntos en la misma línea
        if (_pointsInCurrentLine >= 6) {
          shouldAnnounceLine = true;
          lineAnnouncement =
              'Línea ${point.lineNumber}'; // Recordatorio de línea
          _pointsInCurrentLine =
              0; // Reiniciar contador para próximo recordatorio
          // debugPrint(
          //     '📍 Recordatorio de línea ${point.lineNumber} (6 puntos visitados)');
        }
      }

      // Construir mensaje de voz
      if (shouldAnnounceLine) {
        voiceMessage = '$lineAnnouncement, Punto ${point.pointNumber}';
      } else {
        voiceMessage = 'Punto ${point.pointNumber}'; // Solo el punto, sin línea
      }

      if (_voiceEnabled) {
        _ttsManager.enqueueSpeech(
          voiceMessage,
          'at_point_${point.id}',
          SpeechPriority.high,
          const Duration(seconds: 10), // Aumentado de 5 a 10 segundos
        );
      }
    } else if (distance <= 5.0) {
      // Cerca del punto (2-5m)
      newState = NavigationState.nearPoint;
      message =
          'Llegando a Línea ${point.lineNumber} - Punto ${point.pointNumber}';

      // Usar la misma lógica de anuncios que en "atPoint" pero con "Llegando a"
      bool shouldAnnounceLine = false;

      if (_currentAnnouncedLine != point.lineNumber) {
        shouldAnnounceLine = true;
      } else if (_pointsInCurrentLine >= 6) {
        shouldAnnounceLine = true;
      }

      if (shouldAnnounceLine) {
        voiceMessage =
            'Llegando a Línea ${point.lineNumber}, Punto ${point.pointNumber}';
      } else {
        voiceMessage = 'Llegando a Punto ${point.pointNumber}';
      }

      if (_voiceEnabled) {
        _ttsManager.enqueueSpeech(
          voiceMessage,
          'near_point_${point.id}',
          SpeechPriority.normal,
          const Duration(seconds: 15), // Aumentado de 8 a 15 segundos
        );
      }
    } else if (distance <= 20.0) {
      // Acercándose (5-20m)
      newState = NavigationState.approaching;
      message =
          'Acercándose a Línea ${point.lineNumber} - Punto ${point.pointNumber} (${distance.toStringAsFixed(1)}m)';

      // Usar la misma lógica de anuncios que en "atPoint" pero con "Acercándose a"
      bool shouldAnnounceLine = false;

      if (_currentAnnouncedLine != point.lineNumber) {
        shouldAnnounceLine = true;
      } else if (_pointsInCurrentLine >= 6) {
        shouldAnnounceLine = true;
      }

      if (shouldAnnounceLine) {
        voiceMessage =
            'Acercándose a Línea ${point.lineNumber}, Punto ${point.pointNumber}';
      } else {
        voiceMessage = 'Acercándose a Punto ${point.pointNumber}';
      }

      if (_voiceEnabled) {
        _ttsManager.enqueueSpeech(
          voiceMessage,
          'approaching_${point.id}',
          SpeechPriority.normal,
          const Duration(seconds: 20), // Aumentado de 10 a 20 segundos
        );
      }
    } else if (distance <= 20000.0) {
      // Lejos pero dentro de 20km
      newState = NavigationState.idle;
      message =
          'Punto más cercano: Línea ${point.lineNumber} - Punto ${point.pointNumber} (${distance.toStringAsFixed(0)}m)';
      voiceMessage = '';
    } else {
      // Muy lejos (>20km)
      newState = NavigationState.idle;
      final distanceKm = distance / 1000.0;
      message =
          'Estás muy lejos de cualquier palma del lote (${distanceKm.toStringAsFixed(1)} km)';
      voiceMessage = '';
    }

    _updateNavigationState(newState, point, distance, message);
  }

  /// Actualiza el estado de navegación y la UI
  void _updateNavigationState(
    NavigationState state,
    VirtualPoint? point,
    double? distance,
    String message,
  ) {
    if (!mounted) return;

    final newEvent = NavigationEvent(
      state: state,
      targetPoint: point,
      distance: distance,
      message: message,
    );

    setState(() {
      _currentNavigationEvent = newEvent;
      // Mostrar tarjeta siempre que haya un evento válido (excepto idle sin punto)
      _showNavigationCard = state != NavigationState.idle || point != null;
    });
  }

  /// Anuncia la ubicación actual por voz (botón "¿Dónde estoy?")
  Future<void> _speakCurrentLocation() async {
    // Obtener el punto más cercano del optimizer
    final closestPoint = _proximityOptimizer.lastClosestPoint;
    final distance = _proximityOptimizer.lastDistance;

    if (closestPoint == null) {
      // No hay puntos virtuales cargados
      await _ttsManager.speakImmediately(
        'No hay puntos virtuales cargados. Configura una ruta primero.',
      );
      return;
    }

    // Construir mensaje de ubicación
    String message;
    final distanceText = distance < 1000
        ? '${distance.toStringAsFixed(0)} metros'
        : '${(distance / 1000).toStringAsFixed(1)} kilómetros';

    if (distance <= 5) {
      // Muy cerca o en el punto
      message = 'Estás en Línea ${closestPoint.lineNumber}, Punto ${closestPoint.pointNumber}';
    } else if (distance <= 20) {
      // Cerca del punto
      message = 'Estás a $distanceText de Línea ${closestPoint.lineNumber}, Punto ${closestPoint.pointNumber}';
    } else if (distance <= 100) {
      // A distancia moderada
      message = 'El punto más cercano es Línea ${closestPoint.lineNumber}, Punto ${closestPoint.pointNumber}, a $distanceText';
    } else {
      // Lejos
      message = 'Línea ${closestPoint.lineNumber}, Punto ${closestPoint.pointNumber} está a $distanceText de distancia';
    }

    // Agregar información de movimiento si está disponible
    if (_proximityOptimizer.isMoving) {
      final speed = _proximityOptimizer.getAverageSpeed();
      if (speed > 1) {
        final speedKmh = (speed * 3.6).toStringAsFixed(0);
        message += '. Velocidad: $speedKmh kilómetros por hora';
      }
    }

    await _ttsManager.speakImmediately(message);
  }

  /// Calcula distancia en metros usando fórmula de Haversine
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Radio de la Tierra en metros
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Obtener puntos virtuales que están dentro de una zona de exclusión
  List<VirtualPoint> _getVirtualPointsInExclusionZone(int idPolygonCoordinate) {
    final List<VirtualPoint> pointsInside = [];

    // Buscar el polígono correspondiente en _coordinates
    final polygonCoord = _coordinates.firstWhere(
      (coord) => coord.id == idPolygonCoordinate,
      orElse: () => _coordinates.first, // Fallback
    );

    if (polygonCoord.polygonPoints.isEmpty) {
      return pointsInside;
    }

    // Verificar cada punto virtual
    for (var virtualPoint in _virtualPoints) {
      if (_isPointInPolygon(
        virtualPoint.latitude,
        virtualPoint.longitude,
        polygonCoord.polygonPoints,
      )) {
        pointsInside.add(virtualPoint);
      }
    }

    // Ordenar por línea y punto
    pointsInside.sort((a, b) {
      final lineCompare = a.lineNumber.compareTo(b.lineNumber);
      if (lineCompare != 0) return lineCompare;
      return a.pointNumber.compareTo(b.pointNumber);
    });

    return pointsInside;
  }

  /// Mostrar dialog de configuración de simulación
  Future<void> _showSimulationConfigDialog() async {
    final config = await showDialog<RouteSimulationConfig>(
      context: context,
      builder: (context) => _SimulationConfigDialog(
        virtualPoints: _virtualPoints,
        headquarterId: _headquarter?.id,
        authToken: widget.authToken,
      ),
    );

    if (config != null) {
      // Establecer el punto inicial basado en la configuración
      setState(() {
        _routeConfig = config;
        _startingPoint = _getStartingPoint(config);
      });

      // Para rutas optimizadas, la verificación ya se hizo en el diálogo
      // Para otros patrones, verificar normalmente
      final skipCheck = config.pattern == RoutePattern.rutaOptimizada;
      await _generateSimulatedRoute(config, skipExistingCheck: skipCheck);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Requerido por AutomaticKeepAliveClientMixin
    super.build(context);

    // Pantalla de carga
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: FlutterFlowTheme.of(context).alternate,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Cargando mapa offline...',
                style: TextStyle(
                  fontSize: 16,
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pantalla de error
    if (_errorMessage != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: FlutterFlowTheme.of(context).alternate,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: FlutterFlowTheme.of(context).error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar el mapa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initPMTiles();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final routePoints = _getRoutePoints();
    final currentLocation = _getCurrentLocation();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // Mapa principal
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  currentLocation ?? const latlong.LatLng(4.5709, -74.2973),
              initialZoom: 18.0,
              minZoom: 3.0,
              maxZoom: 22.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isFollowingUser) {
                  setState(() {
                    _isFollowingUser = false;
                  });
                }
                setState(() {
                  _currentZoom = position.zoom ?? 18.0;
                });
              },
            ),
            children: [
              // Capa de tiles vectoriales offline
              if (_vectorTileProvider != null)
                VectorTileLayer(
                  tileProviders: TileProviders({
                    'pmtiles': _vectorTileProvider!,
                  }),
                  theme: _createVectorTheme(),
                  maximumZoom: 22,
                ),

              // Polígono del lote
              if (_showPolygon && _polygonPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.2),
                      borderColor: FlutterFlowTheme.of(context).warning,
                      borderStrokeWidth: 3.0,
                      isFilled: true,
                    ),
                  ],
                ),

              // Polyline - Ruta de mi ubicación
              if (_showMyLocation &&
                  _showTrackingLine &&
                  routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: FlutterFlowTheme.of(context).error,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // RUTA SIMULADA: Líneas discontinuas rojas (GPS ficticio → Punto Virtual)
              if (_showSimulatedRoute && _simulatedRoute.isNotEmpty)
                PolylineLayer(
                  polylines: _simulatedRoute.map((point) {
                    return Polyline(
                      points: [
                        latlong.LatLng(
                          point.simulatedLatitude,
                          point.simulatedLongitude,
                        ),
                        latlong.LatLng(
                          point.currentVirtualPoint.latitude,
                          point.currentVirtualPoint.longitude,
                        ),
                      ],
                      strokeWidth: 2.0,
                      color: const Color(0xFFFF6B6B),
                      borderStrokeWidth: 1.0,
                      borderColor: Colors.white.withValues(alpha: 0.5),
                      isDotted: true,
                    );
                  }).toList(),
                ),

              // RUTA SIMULADA: Líneas continuas azules (Punto Virtual actual → Siguiente)
              if (_showSimulatedRoute && _simulatedRoute.isNotEmpty)
                PolylineLayer(
                  polylines: _simulatedRoute
                      .where((point) => point.nextVirtualPoint != null)
                      .map((point) {
                    return Polyline(
                      points: [
                        latlong.LatLng(
                          point.currentVirtualPoint.latitude,
                          point.currentVirtualPoint.longitude,
                        ),
                        latlong.LatLng(
                          point.nextVirtualPoint!.latitude,
                          point.nextVirtualPoint!.longitude,
                        ),
                      ],
                      strokeWidth: 3.0,
                      color: FlutterFlowTheme.of(context).info,
                      borderStrokeWidth: 1.0,
                      borderColor: Colors.white,
                    );
                  }).toList(),
                ),

              // RUTA SIMULADA: Flechas direccionales en medio de cada línea
              if (_showSimulatedRoute && _simulatedRoute.isNotEmpty)
                MarkerLayer(
                  markers: _generateRouteArrows(
                    _simulatedRoute.map((point) {
                      return latlong.LatLng(
                        point.currentVirtualPoint.latitude,
                        point.currentVirtualPoint.longitude,
                      );
                    }).toList(),
                  ),
                ),

              // Marcadores - GPS Simulado (rojo)
              if (_showSimulatedRoute && _simulatedRoute.isNotEmpty)
                MarkerLayer(
                  markers: _simulatedRoute.map((point) {
                    final markerSize = _getMarkerSize(30);
                    return Marker(
                      point: latlong.LatLng(
                        point.simulatedLatitude,
                        point.simulatedLongitude,
                      ),
                      width: markerSize,
                      height: markerSize,
                      child: GestureDetector(
                        onTap: () {
                          _showMarkerInfo(
                            'GPS Simulado',
                            'Secuencia: ${point.sequenceNumber}',
                            'Referencia: L${point.currentVirtualPoint.lineNumber} P${point.currentVirtualPoint.pointNumber}\n'
                                '${point.nextVirtualPoint != null ? "Siguiente: L${point.nextVirtualPoint!.lineNumber} P${point.nextVirtualPoint!.pointNumber}" : "Último punto"}',
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _shouldShowText()
                              ? Center(
                                  child: Text(
                                    '${point.sequenceNumber}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _getTextSize(10),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // MARCADOR DE POSICIÓN ACTUAL DEL REPRODUCTOR (verde pulsante)
              if (_isPlaybackActive &&
                  _simulatedRoute.isNotEmpty &&
                  _currentPlaybackIndex < _simulatedRoute.length)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latlong.LatLng(
                        _simulatedRoute[_currentPlaybackIndex]
                            .simulatedLatitude,
                        _simulatedRoute[_currentPlaybackIndex]
                            .simulatedLongitude,
                      ),
                      width: _getMarkerSize(50),
                      height: _getMarkerSize(50),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Halo pulsante exterior
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FlutterFlowTheme.of(context)
                                  .success
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          // Círculo principal
                          Container(
                            width: _getMarkerSize(35),
                            height: _getMarkerSize(35),
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: FlutterFlowTheme.of(context)
                                      .success
                                      .withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_pin,
                              color: Colors.white,
                              size: _getMarkerSize(20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Marcadores de Virtual Points
              if (_showVirtualPoints && _virtualPoints.isNotEmpty)
                MarkerLayer(
                  markers: _virtualPoints.map((vp) {
                    final markerSize = _getMarkerSize(40);
                    final Color color =
                        vp.typePoint?.getColor() ?? const Color(0xFFA855F7);
                    return Marker(
                      point: latlong.LatLng(vp.latitude, vp.longitude),
                      width: markerSize,
                      height: markerSize,
                      child: GestureDetector(
                        onTap: () {
                          _showMarkerInfo(
                            'Virtual Point',
                            'Línea ${vp.lineNumber} - Punto ${vp.pointNumber}',
                            vp.description ??
                                (vp.typeName != null
                                    ? 'Tipo: ${vp.typeName}'
                                    : null),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _shouldShowText()
                              ? Center(
                                  child: Text(
                                    '${vp.pointNumber}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _getTextSize(12),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Marcador del PUNTO INICIAL (cuando hay una ruta configurada)
              if (_startingPoint != null && _showVirtualPoints)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latlong.LatLng(
                        _startingPoint!.latitude,
                        _startingPoint!.longitude,
                      ),
                      width: _getMarkerSize(60),
                      height: _getMarkerSize(60),
                      child: GestureDetector(
                        onTap: () {
                          _showMarkerInfo(
                            'Punto Inicial',
                            'Línea ${_startingPoint!.lineNumber} - Punto ${_startingPoint!.pointNumber}',
                            'Este es el punto de inicio del recorrido configurado',
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Anillo pulsante externo (animado)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: _getMarkerSize(60),
                                  height: _getMarkerSize(60),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .success
                                          .withValues(
                                            alpha: 0.6 *
                                                (1 - _pulseAnimation.value),
                                          ),
                                      width: 3,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Círculo interior con el icono
                            Container(
                              width: _getMarkerSize(40),
                              height: _getMarkerSize(40),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .success, // Verde
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: FlutterFlowTheme.of(context)
                                        .success
                                        .withValues(alpha: 0.6),
                                    blurRadius: 12,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: _getMarkerSize(20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Marcadores de Productos
              if (_showProducts && _products.isNotEmpty)
                MarkerLayer(
                  markers: _products.expand((product) {
                    // Color verde oscuro fijo para productos/palmas
                    const Color color = Color(0xFF064E3B); // Verde oscuro
                    return product.coordinates.map((coord) {
                      final markerSize = _getMarkerSize(36);
                      final iconSize = _getMarkerSize(18);
                      return Marker(
                        point: coord,
                        width: markerSize,
                        height: markerSize,
                        child: GestureDetector(
                          onTap: () {
                            _showMarkerInfo(
                              'Producto',
                              product.nameProduct ??
                                  product.rfid ??
                                  'Sin nombre',
                              'Línea ${product.line ?? "?"} - Palma ${product.palm ?? "?"}${product.state != null ? "\nEstado: ${product.state}" : ""}',
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.eco,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                      );
                    });
                  }).toList(),
                ),

              // Polígonos de Coordenadas (Polígonos de Exclusión)
              if (_showCoordinates && _coordinates.isNotEmpty)
                PolygonLayer(
                  polygons: _coordinates.map((coord) {
                    final Color color = coord.typePoint?.getColor() ??
                        FlutterFlowTheme.of(context).info;
                    return Polygon(
                      points: coord.polygonPoints,
                      color: color.withValues(
                          alpha: 0.3), // Fondo con transparencia
                      borderColor: color, // Borde con color sólido
                      borderStrokeWidth: 2.5,
                      isFilled: true,
                    );
                  }).toList(),
                ),

              // Marcador de posición actual
              if (_showMyLocation && currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation,
                      width: _getMarkerSize(60),
                      height: _getMarkerSize(60),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final haloSize = _getMarkerSize(40);
                          final dotSize = _getMarkerSize(24);
                          final innerDotSize = _getMarkerSize(8);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo pulsante
                              Container(
                                width: haloSize * _pulseAnimation.value,
                                height: haloSize * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: FlutterFlowTheme.of(context)
                                      .error
                                      .withValues(
                                        alpha: 0.3 / _pulseAnimation.value,
                                      ),
                                ),
                              ),

                              // Punto principal
                              Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: FlutterFlowTheme.of(context).error,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: innerDotSize,
                                    height: innerDotSize,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              // Flecha de dirección
                              if (routePoints.length >= 2)
                                Transform.rotate(
                                  angle: _currentBearing * math.pi / 180,
                                  child: Transform.translate(
                                    offset: const Offset(0, -15),
                                    child: CustomPaint(
                                      size: const Size(12, 12),
                                      painter: _ArrowPainter(
                                          FlutterFlowTheme.of(context).error),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Leyendas de capas con controles (superior izquierda) - Solo si está visible
          if (_showLayerPanel) _buildLayerLegends(),

          // Panel de control superior derecho compacto
          _buildCompactTopControls(),

          // Menú FAB Speed Dial moderno (inferior derecha)
          _buildModernFABMenu(),

          // Botón "¿Dónde estoy?" (al lado del FAB)
          _buildWhereAmIButton(),

          // Panel de controles del reproductor (encima del panel de navegación)
          if (_isPlaybackActive && _simulatedRoute.isNotEmpty)
            _buildPlaybackControlPanel(),

          // Label de tiempo total del recorrido (superior centro)
          if (_simulatedRoute.isNotEmpty) _buildTotalTimeLabel(),

          // Selector de lote activo (superior centro, solo con múltiples lotes)
          if ((widget.headquarters?.length ?? 0) > 1) _buildHeadquarterSelector(),

          // Tarjeta de navegación estilo Waze (bottom-center)
          if (_showNavigationCard && _currentNavigationEvent != null)
            _buildBottomNavigationCard(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Botón de filtros
            InkWell(
              onTap: () {
                setState(() {
                  _showFilterPanel = !_showFilterPanel;
                  if (_showFilterPanel) {
                    _filterPanelController.forward();
                  } else {
                    _filterPanelController.reverse();
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _showFilterPanel
                      ? FlutterFlowTheme.of(context).primary
                      : FlutterFlowTheme.of(context).alternate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.layers,
                      color: _showFilterPanel
                          ? Colors.white
                          : FlutterFlowTheme.of(context).primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Capas',
                      style: TextStyle(
                        color: _showFilterPanel
                            ? Colors.white
                            : FlutterFlowTheme.of(context).primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Botón línea de trazo
            InkWell(
              onTap: () {
                setState(() {
                  _showTrackingLine = !_showTrackingLine;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showTrackingLine
                      ? FlutterFlowTheme.of(context)
                          .error
                          .withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _showTrackingLine ? Icons.timeline : Icons.timeline_outlined,
                  color: _showTrackingLine
                      ? FlutterFlowTheme.of(context).error
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Botón ver todo
            InkWell(
              onTap: _fitAllBounds,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.fit_screen,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Leyendas verticales con controles en la esquina superior izquierda
  Widget _buildLayerLegends() {
    // Posicionar justo debajo del control de tiempo/distancia
    // Control de tiempo está en top: 16, con altura aproximada de 50-60px cuando expandido
    double topPosition = _isTotalTimeCollapsed ? 54.0 : 78.0;
    // Si hay múltiples lotes, desplazar hacia abajo para dejar espacio al selector (top:70 + 42px + 8px margen)
    if ((widget.headquarters?.length ?? 0) > 1) topPosition += 54.0;

    return Positioned(
      top: topPosition,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título (sin botón de colapsar - el toggle está en el botón principal)
            Text(
              'CAPAS',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // Contenido siempre visible cuando el panel está abierto
            // Coordenadas
            if (_virtualPoints.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🟣',
                'Coordenadas',
                _virtualPoints.length,
                const Color(0xFFA855F7),
                _showVirtualPoints,
                (value) {
                  setState(() {
                    _showVirtualPoints = value;
                  });
                },
              ),
            if (_virtualPoints.isNotEmpty) const SizedBox(height: 8),
            // Polígono
            if (_polygonPoints.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🟡',
                'Polígono',
                1,
                FlutterFlowTheme.of(context).warning,
                _showPolygon,
                (value) {
                  setState(() {
                    _showPolygon = value;
                  });
                },
              ),
            if (_polygonPoints.isNotEmpty) const SizedBox(height: 8),
            // Tags
            if (_products.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🟢',
                'Tags',
                _products.length,
                FlutterFlowTheme.of(context).success,
                _showProducts,
                (value) {
                  setState(() {
                    _showProducts = value;
                  });
                },
              ),
            if (_products.isNotEmpty) const SizedBox(height: 8),
            // Exclusiones
            if (_coordinates.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🔵',
                'Exclusiones',
                _coordinates.length,
                FlutterFlowTheme.of(context)
                    .primary, // Cambio a primary para color azul
                _showCoordinates,
                (value) {
                  setState(() {
                    _showCoordinates = value;
                  });
                },
              ),
            if (_coordinates.isNotEmpty) const SizedBox(height: 8),
            // Mis ubicaciones
            if (_filteredGeolocations.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🔴',
                'Mis ubicaciones',
                _filteredGeolocations.length,
                FlutterFlowTheme.of(context).error,
                _showMyLocation,
                (value) {
                  setState(() {
                    _showMyLocation = value;
                  });
                },
              ),
            if (_simulatedRoute.isNotEmpty) const SizedBox(height: 8),
            // Ruta de Prueba
            if (_simulatedRoute.isNotEmpty)
              _buildLegendItemWithSwitch(
                '🧪',
                'Ruta de Prueba',
                _simulatedRoute.length,
                const Color(0xFFFF6B6B),
                _showSimulatedRoute,
                (value) {
                  setState(() {
                    _showSimulatedRoute = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItemWithSwitch(
    String emoji,
    String label,
    int count,
    Color color,
    bool isVisible,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji y contenido
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count elementos',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 8),
        // Switch
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isVisible,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String emoji, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(_filterPanelAnimation),
        child: FadeTransition(
          opacity: _filterPanelAnimation,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FlutterFlowTheme.of(context).primary,
                          FlutterFlowTheme.of(context).secondary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.layers, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Capas del Mapa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showFilterPanel = false;
                              _filterPanelController.reverse();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Opciones de capas
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLayerToggle(
                          '🟣',
                          'Coordenadas',
                          _virtualPoints.length,
                          _showVirtualPoints,
                          (value) => setState(() => _showVirtualPoints = value),
                          const Color(0xFFA855F7),
                        ),
                        const SizedBox(height: 12),
                        _buildLayerToggle(
                          '🟡',
                          'Polígono del Lote',
                          _polygonPoints.isNotEmpty ? 1 : 0,
                          _showPolygon,
                          (value) => setState(() => _showPolygon = value),
                          FlutterFlowTheme.of(context).warning,
                        ),
                        const SizedBox(height: 12),
                        _buildLayerToggle(
                          '🟢',
                          'Tags',
                          _products.length,
                          _showProducts,
                          (value) => setState(() => _showProducts = value),
                          FlutterFlowTheme.of(context).success,
                        ),
                        const SizedBox(height: 12),
                        _buildLayerToggle(
                          '🔵',
                          'Exclusiones',
                          _coordinates.length,
                          _showCoordinates,
                          (value) => setState(() => _showCoordinates = value),
                          FlutterFlowTheme.of(context).info,
                        ),
                        const SizedBox(height: 12),
                        _buildLayerToggle(
                          '🔴',
                          'Mi Ubicación',
                          _filteredGeolocations.length,
                          _showMyLocation,
                          (value) => setState(() => _showMyLocation = value),
                          FlutterFlowTheme.of(context).error,
                        ),
                      ],
                    ),
                  ),

                  // Divisor
                  Container(
                    height: 1,
                    color: FlutterFlowTheme.of(context).alternate,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                  // Filtro de tiempo
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: FlutterFlowTheme.of(context).primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Filtro de Tiempo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TimeFilter.values.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = filter;
                                  _applyFilter();
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context).alternate,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  filter.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : FlutterFlowTheme.of(context)
                                            .secondaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerToggle(
    String emoji,
    String title,
    int count,
    bool value,
    Function(bool) onChanged,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? color.withValues(alpha: 0.1)
            : FlutterFlowTheme.of(context).alternate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color : FlutterFlowTheme.of(context).alternate,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                Text(
                  '$count elemento${count != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  /// Botones flotantes en la parte superior derecha
  Widget _buildTopFloatingButtons() {
    return Positioned(
      top: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón mostrar/ocultar recorrido
          _buildFloatingButton(
            icon: _showTrackingLine ? Icons.timeline : Icons.timeline_outlined,
            color: FlutterFlowTheme.of(context).error,
            isActive: _showTrackingLine,
            onTap: () {
              setState(() {
                _showTrackingLine = !_showTrackingLine;
              });
            },
          ),
          const SizedBox(width: 8),
          // Botón centrar todo
          _buildFloatingButton(
            icon: Icons.fit_screen,
            color: FlutterFlowTheme.of(context).primary,
            onTap: _fitAllBounds,
          ),
          const SizedBox(width: 8),
          // Botón actualizar datos
          _buildFloatingButton(
            icon: Icons.refresh,
            color: FlutterFlowTheme.of(context).warning,
            onTap: () async {
              // Mostrar indicador de carga
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }

              // Recargar todos los datos
              await _loadAllData();

              // Ocultar indicador de carga
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }

              // Mostrar mensaje de confirmación
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Datos actualizados: ${_virtualPoints.length} puntos virtuales, ${_products.length} productos',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: FlutterFlowTheme.of(context).success,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          // Botón activar/desactivar voz
          _buildFloatingButton(
            icon: _voiceEnabled ? Icons.volume_up : Icons.volume_off,
            color: FlutterFlowTheme.of(context).success,
            isActive: _voiceEnabled,
            onTap: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                if (!_voiceEnabled) {
                  _ttsManager.clearQueue(); // Limpiar cola si se desactiva
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : color,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSideControls() {
    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          // Botón centrar en mi ubicación
          _buildControlButton(
            icon: Icons.my_location,
            isActive: _isFollowingUser,
            color: FlutterFlowTheme.of(context).error,
            onTap: () {
              setState(() {
                _isFollowingUser = true;
              });
              _centerOnCurrentLocation(animated: true);
            },
          ),
          const SizedBox(height: 12),
          // Botón centrar en Virtual Points
          if (_virtualPoints.isNotEmpty)
            _buildControlButton(
              icon: Icons.scatter_plot_rounded,
              color: const Color(0xFFA855F7),
              onTap: () {
                _centerOnVirtualPoints(animated: true);
              },
            ),
          if (_virtualPoints.isNotEmpty) const SizedBox(height: 12),
          // Botón simular ruta (solo si hay puntos virtuales)
          if (_virtualPoints.isNotEmpty)
            _buildControlButton(
              icon: Icons.route,
              color: FlutterFlowTheme.of(context).success,
              onTap: () {
                _showSimulationConfigDialog();
              },
            ),
          if (_virtualPoints.isNotEmpty) const SizedBox(height: 12),
          // Botón zoom in
          _buildControlButton(
            icon: Icons.add,
            onTap: () {
              try {
                _mapController.move(
                  _mapController.camera.center,
                  _currentZoom + 1,
                );
              } catch (e) {
                debugPrint('⚠️ MapController no listo: $e');
              }
            },
          ),
          const SizedBox(height: 12),
          // Botón zoom out
          _buildControlButton(
            icon: Icons.remove,
            onTap: () {
              try {
                _mapController.move(
                  _mapController.camera.center,
                  _currentZoom - 1,
                );
              } catch (e) {
                debugPrint('⚠️ MapController no listo: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    bool isActive = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    final buttonColor = color ?? FlutterFlowTheme.of(context).primary;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? buttonColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : buttonColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Widget de icono animado para indicar que está hablando
  Widget _buildAnimatedSpeakingIcon(IconData iconData, Color iconColor) {
    final isSpeaking = _ttsManager.isSpeaking;

    // Iniciar/detener animación según el estado
    if (isSpeaking && !_speakingAnimationController.isAnimating) {
      _speakingAnimationController.repeat(reverse: true);
    } else if (!isSpeaking && _speakingAnimationController.isAnimating) {
      _speakingAnimationController.stop();
      _speakingAnimationController.reset();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ondas de sonido (solo cuando está hablando) - compactas
        if (isSpeaking) ...[
          // Onda exterior
          AnimatedBuilder(
            animation: _speakingAnimation,
            builder: (context, child) {
              return Container(
                width: 36 + (10 * _speakingAnimation.value),
                height: 36 + (10 * _speakingAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.3 * (1 - _speakingAnimation.value),
                    ),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
        // Icono principal con animación de escala - compacto
        AnimatedBuilder(
          animation: _speakingAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale:
                  isSpeaking ? (0.9 + (0.1 * _speakingAnimation.value)) : 1.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 20,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Panel de controles del reproductor
  /// Se muestra minimizado cuando está reproduciendo, maximizado cuando está pausado
  Widget _buildPlaybackControlPanel() {
    final currentPoint = _currentPlaybackIndex < _simulatedRoute.length
        ? _simulatedRoute[_currentPlaybackIndex]
        : _simulatedRoute.last;

    final currentTime = _getCurrentPlaybackTime();
    final totalTime = _getTotalRouteTime();
    final progress = totalTime.inSeconds > 0
        ? currentTime.inSeconds / totalTime.inSeconds
        : 0.0;

    // Calcular posición: encima del panel de navegación si está visible
    final bottomPosition = _showNavigationCard &&
            _currentNavigationEvent != null
        ? 70.0 // Justo encima del panel de navegación compacto
        : 20.0; // Margen normal desde el bottom

    return Positioned(
      bottom: bottomPosition,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isPlaybackPlaying
                ? _buildMinimizedPanel()
                : _buildMaximizedPanel(
                    currentPoint, currentTime, totalTime, progress),
          ),
        ),
      ),
    );
  }

  /// Panel minimizado (solo controles esenciales cuando está reproduciendo)
  Widget _buildMinimizedPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón disminuir velocidad
          IconButton(
            onPressed: () {
              final currentIndex =
                  _availablePlaybackSpeeds.indexOf(_playbackSpeed);
              if (currentIndex > 0) {
                setState(() {
                  _playbackSpeed = _availablePlaybackSpeeds[currentIndex - 1];
                });
                debugPrint('🎬 Velocidad: ${_playbackSpeed}x');
              }
            },
            icon: const Icon(Icons.remove_circle_outline),
            color: FlutterFlowTheme.of(context).secondaryText,
            iconSize: 24,
            tooltip: 'Reducir velocidad',
          ),
          const SizedBox(width: 6),
          // Indicador de velocidad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).alternate,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_playbackSpeed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Botón aumentar velocidad
          IconButton(
            onPressed: () {
              final currentIndex =
                  _availablePlaybackSpeeds.indexOf(_playbackSpeed);
              if (currentIndex < _availablePlaybackSpeeds.length - 1) {
                setState(() {
                  _playbackSpeed = _availablePlaybackSpeeds[currentIndex + 1];
                });
                debugPrint('🎬 Velocidad: ${_playbackSpeed}x');
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            color: FlutterFlowTheme.of(context).secondaryText,
            iconSize: 24,
            tooltip: 'Aumentar velocidad',
          ),
          const SizedBox(width: 12),
          // Botón PAUSE/RESUME (grande y destacado)
          Container(
            decoration: BoxDecoration(
              color: _isPlaybackPlaying
                  ? FlutterFlowTheme.of(context).warning
                  : FlutterFlowTheme.of(context).success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isPlaybackPlaying
                          ? FlutterFlowTheme.of(context).warning
                          : FlutterFlowTheme.of(context).success)
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isPlaybackPlaying ? _pausePlayback : _startPlayback,
              icon: Icon(_isPlaybackPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              iconSize: 28,
              tooltip: _isPlaybackPlaying ? 'Pausar' : 'Reanudar',
            ),
          ),
          const SizedBox(width: 12),
          // Botón STOP
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      FlutterFlowTheme.of(context).error.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _stopPlayback();
                  _isPlaybackActive = false;
                });
              },
              icon: const Icon(Icons.stop),
              color: Colors.white,
              iconSize: 28,
              tooltip: 'Detener',
            ),
          ),
        ],
      ),
    );
  }

  /// Panel maximizado (todos los controles cuando está pausado)
  Widget _buildMaximizedPanel(
    SimulatedLocationPoint currentPoint,
    Duration currentTime,
    Duration totalTime,
    double progress,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Row(
            children: [
              Icon(Icons.route,
                  color: FlutterFlowTheme.of(context).success, size: 24),
              const SizedBox(width: 8),
              Text(
                'Reproductor de Ruta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const Spacer(),
              Text(
                '${_playbackSpeed.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Información del punto actual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Punto ${_currentPlaybackIndex + 1} de ${_simulatedRoute.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'L${currentPoint.currentVirtualPoint.lineNumber} P${currentPoint.currentVirtualPoint.pointNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Velocidad: ${currentPoint.walkingSpeedMps.toStringAsFixed(1)} m/s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDuration(currentTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '/ ${_formatDuration(totalTime)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barra de progreso
          Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: FlutterFlowTheme.of(context).alternate,
                valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).success),
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón inicio
              IconButton(
                onPressed: () => _jumpToPoint(0),
                icon: const Icon(Icons.skip_previous),
                color: FlutterFlowTheme.of(context).secondaryText,
                iconSize: 28,
              ),
              // Botón anterior
              IconButton(
                onPressed: _currentPlaybackIndex > 0
                    ? () => _jumpToPoint(_currentPlaybackIndex - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios),
                color: FlutterFlowTheme.of(context).secondaryText,
                iconSize: 24,
              ),
              // Botón play/pause
              Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .success
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed:
                      _isPlaybackPlaying ? _pausePlayback : _startPlayback,
                  icon: Icon(
                    _isPlaybackPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  color: Colors.white,
                  iconSize: 32,
                ),
              ),
              // Botón siguiente
              IconButton(
                onPressed: _currentPlaybackIndex < _simulatedRoute.length - 1
                    ? () => _jumpToPoint(_currentPlaybackIndex + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios),
                color: FlutterFlowTheme.of(context).secondaryText,
                iconSize: 24,
              ),
              // Botón final
              IconButton(
                onPressed: () => _jumpToPoint(_simulatedRoute.length - 1),
                icon: const Icon(Icons.skip_next),
                color: FlutterFlowTheme.of(context).secondaryText,
                iconSize: 28,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Botones adicionales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón velocidad
              OutlinedButton.icon(
                onPressed: _nextPlaybackSpeed,
                icon: const Icon(Icons.speed, size: 18),
                label: Text('${_playbackSpeed}x'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlutterFlowTheme.of(context).primary,
                  side: BorderSide(color: FlutterFlowTheme.of(context).primary),
                ),
              ),
              // Botón detener
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _stopPlayback();
                    _isPlaybackActive = false;
                  });
                },
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Detener'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlutterFlowTheme.of(context).error,
                  side: BorderSide(color: FlutterFlowTheme.of(context).error),
                ),
              ),
              // Toggle auto-follow
              IconButton(
                onPressed: () {
                  setState(() {
                    _autoFollowPlayback = !_autoFollowPlayback;
                  });
                },
                icon: Icon(
                  _autoFollowPlayback
                      ? Icons.my_location
                      : Icons.location_disabled,
                ),
                color: _autoFollowPlayback
                    ? FlutterFlowTheme.of(context).success
                    : FlutterFlowTheme.of(context).secondaryText,
                tooltip: _autoFollowPlayback
                    ? 'Seguimiento automático activado'
                    : 'Seguimiento automático desactivado',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de navegación estilo Waze en la parte inferior
  Widget _buildBottomNavigationCard() {
    final event = _currentNavigationEvent!;

    // SIEMPRE usar Primary (verde) como color de fondo
    final cardColor = FlutterFlowTheme.of(context).primary;
    const iconColor = Colors.white;

    // Iconos según estado (pero mantener el mismo color de fondo)
    IconData iconData;
    String emoji;

    switch (event.state) {
      case NavigationState.atPoint:
        iconData = Icons.check_circle;
        emoji = '✅';
        break;
      case NavigationState.nearPoint:
        iconData = Icons.near_me;
        emoji = '🎯';
        break;
      case NavigationState.approaching:
        iconData = Icons.navigation;
        emoji = '🎯';
        break;
      case NavigationState.noMovement:
        iconData = Icons.pause_circle;
        emoji = '⏸️';
        break;
      default:
        iconData = Icons.explore;
        emoji = '🔍';
    }

    // Calcular progreso si hay distancia
    double? progress;
    if (event.distance != null && event.distance! <= 20) {
      progress = 1 - (event.distance! / 20).clamp(0.0, 1.0);
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _showNavigationCard ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Material(
          elevation: 16,
          color: Colors
              .transparent, // Transparente para que se vea el gradiente del Container
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Container(
              decoration: BoxDecoration(
                // SIEMPRE fondo Primary (verde) con gradiente sutil
                gradient: LinearGradient(
                  colors: [cardColor, cardColor.withValues(alpha: 0.95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icono compacto
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _buildAnimatedSpeakingIcon(iconData, iconColor),
                    ),
                    const SizedBox(width: 10),
                    // Información compacta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Línea superior: Estado + Línea/Punto
                          Row(
                            children: [
                              // Estado compacto
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.state == NavigationState.atPoint
                                      ? 'EN PUNTO'
                                      : event.state == NavigationState.nearPoint
                                          ? 'LLEGANDO'
                                          : event.state == NavigationState.approaching
                                              ? 'CERCA'
                                              : event.state == NavigationState.noMovement
                                                  ? 'QUIETO'
                                                  : 'NAV',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Línea y Punto
                              if (event.targetPoint != null)
                                Expanded(
                                  child: Text(
                                    'L${event.targetPoint!.lineNumber} - P${event.targetPoint!.pointNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (event.targetPoint == null)
                                Expanded(
                                  child: Text(
                                    event.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          // Línea inferior: Distancia, tiempo y velocidad (compacto)
                          if (event.distance != null && event.distance! <= 20) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // En modo reproductor
                                if (_isPlaybackActive &&
                                    _simulatedRoute.isNotEmpty &&
                                    _currentPlaybackIndex < _simulatedRoute.length) ...[
                                  Text(
                                    '${_simulatedRoute[_currentPlaybackIndex].distanceToNextMeters.toStringAsFixed(0)}m',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDurationCompact(_simulatedRoute[_currentPlaybackIndex].timeToNextPoint),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(_simulatedRoute[_currentPlaybackIndex].walkingSpeedMps * 3.6).toStringAsFixed(1)}km/h',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '${event.distance!.toStringAsFixed(0)}m',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                // Barra de progreso compacta
                                if (progress != null) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 3,
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          // Indicador de zonas de exclusión (compacto)
                          if (_showExclusionButton && _nearbyExclusionZones.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 11),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_nearbyExclusionZones.first.typePointName ?? 'Zona'} ${_nearbyExclusionZones.first.distanceMeters.toStringAsFixed(0)}m',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Botón de zonas de exclusión con badge
                    if (_showExclusionButton &&
                        _nearbyExclusionZones.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showExclusionZonesBottomSheet(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            // Badge con contador
                            if (_nearbyExclusionZones.length > 1)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_nearbyExclusionZones.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }

  /// Formatea duración de forma compacta (ej: "2m", "1h5m")
  String _formatDurationCompact(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Label que muestra el tiempo total del recorrido (colapsable)
  Widget _buildTotalTimeLabel() {
    final totalTime = _getTotalRouteTime();
    final totalTimeFormatted = _formatDuration(totalTime);
    final totalDistance = _simulatedRoute.fold<double>(
      0.0,
      (sum, point) => sum + point.distanceToNextMeters,
    );

    return Positioned(
      top: 16,
      left: 16, // Alineado a la izquierda
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isTotalTimeCollapsed = !_isTotalTimeCollapsed;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: _isTotalTimeCollapsed ? 12 : 16,
            vertical: _isTotalTimeCollapsed ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius:
                BorderRadius.circular(_isTotalTimeCollapsed ? 16 : 20),
            border: Border.all(
              color:
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isTotalTimeCollapsed ? Icons.expand_more : Icons.route,
                color: FlutterFlowTheme.of(context).primary,
                size: _isTotalTimeCollapsed ? 18 : 18,
              ),
              if (!_isTotalTimeCollapsed) ...[
                const SizedBox(width: 8),
                Text(
                  totalTimeFormatted,
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 14,
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                const SizedBox(width: 8),
                Text(
                  '${(totalDistance / 1000).toStringAsFixed(2)} km',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkerInfo(String title, String subtitle, String? description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_on,
                color: FlutterFlowTheme.of(context).primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: FlutterFlowTheme.of(context).primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra BottomSheet con lista de zonas de exclusión cercanas
  void _showExclusionZonesBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: FlutterFlowTheme.of(context).error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Zonas de Exclusión Cercanas (${_nearbyExclusionZones.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista de zonas
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _nearbyExclusionZones.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final zone = _nearbyExclusionZones[index];
                    final typeColor = zone.typePoint?.getColor() ??
                        FlutterFlowTheme.of(context).secondaryText;

                    // Obtener puntos virtuales dentro de esta zona de exclusión
                    final pointsInside = _getVirtualPointsInExclusionZone(
                        zone.idPolygonCoordinate);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: typeColor,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        zone.namePolygonCoordinate ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tipo: ${zone.typePointName ?? 'Sin tipo'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Distancia: ${zone.distanceMeters.toStringAsFixed(1)}m',
                            style: TextStyle(
                              fontSize: 13,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // NUEVO: Mostrar puntos virtuales dentro de la zona
                          if (pointsInside.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .error
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context)
                                      .error
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${pointsInside.length} punto${pointsInside.length > 1 ? 's' : ''} dentro:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children:
                                        pointsInside.take(10).map((point) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .error
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'L${point.lineNumber}P${point.pointNumber}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (pointsInside.length > 10)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '... y ${pointsInside.length - 10} más',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Cerrar BottomSheet
                          // Si hay puntos virtuales dentro de la zona, mostrar diálogo de selección
                          if (pointsInside.isNotEmpty) {
                            _showVirtualPointsSelectionDialog(
                                zone, pointsInside);
                          } else {
                            // Si no hay puntos virtuales, usar flujo anterior
                            _showTypeSelectionDialog(zone);
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Cambiar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlutterFlowTheme.of(context).primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra diálogo de selección de puntos virtuales con checkboxes
  void _showVirtualPointsSelectionDialog(
      ExclusionZoneMarker zone, List<VirtualPoint> pointsInside) {
    // Estado local para los checkboxes
    Map<int, bool> selectedPoints = {};
    for (var point in pointsInside) {
      selectedPoints[point.id] = false;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedCount =
              selectedPoints.values.where((selected) => selected).length;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            elevation: 8,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primary,
                            FlutterFlowTheme.of(context).secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_location_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar Puntos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            zone.namePolygonCoordinate ?? 'Sin nombre',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selecciona los puntos que deseas modificar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Contador de selección con diseño mejorado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: selectedCount > 0
                          ? LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context)
                                    .primary
                                    .withValues(alpha: 0.15),
                                FlutterFlowTheme.of(context)
                                    .secondary
                                    .withValues(alpha: 0.15),
                              ],
                            )
                          : null,
                      color: selectedCount == 0
                          ? FlutterFlowTheme.of(context).alternate
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedCount > 0
                            ? FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.4)
                            : FlutterFlowTheme.of(context).alternate,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: selectedCount > 0
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$selectedCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'de ${pointsInside.length} seleccionados',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selectedCount > 0
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                              ),
                            ),
                          ],
                        ),
                        if (selectedCount > 0)
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                selectedPoints.updateAll((key, value) => false);
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              Icons.clear_all,
                              size: 16,
                              color: FlutterFlowTheme.of(context).error,
                            ),
                            label: Text(
                              'Limpiar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Lista de puntos virtuales con diseño mejorado
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pointsInside.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final point = pointsInside[index];
                        final isSelected = selectedPoints[point.id] ?? false;
                        final typePointName = point.typeName ?? 'Sin tipo';

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedPoints[point.id] = !isSelected;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FlutterFlowTheme.of(context)
                                      .primary
                                      .withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? FlutterFlowTheme.of(context).primary
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: FlutterFlowTheme.of(context)
                                            .primary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Checkbox personalizado
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? FlutterFlowTheme.of(context).primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? FlutterFlowTheme.of(context).primary
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Información del punto
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Línea y Punto
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'L${point.lineNumber} • P${point.pointNumber}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .success
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .success
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                typePointName,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .success,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Coordenadas
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.my_location,
                                            size: 14,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // ID
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.tag,
                                            size: 14,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ID: ${point.id}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: selectedCount > 0
                    ? () {
                        // Obtener puntos seleccionados
                        final selected = pointsInside
                            .where((point) => selectedPoints[point.id] == true)
                            .toList();

                        Navigator.pop(context); // Cerrar diálogo actual
                        // Mostrar diálogo de selección de tipo
                        _showTypeSelectionDialogForMultiplePoints(
                            zone, selected);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      FlutterFlowTheme.of(context).alternate,
                  disabledForegroundColor:
                      FlutterFlowTheme.of(context).secondaryText,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: selectedCount > 0 ? 4 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Muestra diálogo de selección de tipo de punto para múltiples puntos virtuales
  void _showTypeSelectionDialogForMultiplePoints(
      ExclusionZoneMarker zone, List<VirtualPoint> selectedPoints) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar Nuevo Tipo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              zone.namePolygonCoordinate ?? 'Sin nombre',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${selectedPoints.length} punto${selectedPoints.length > 1 ? 's' : ''} seleccionado${selectedPoints.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).info,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _availableTypesPoints.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No hay tipos de puntos disponibles',
                      style: TextStyle(
                        fontSize: 14,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _availableTypesPoints.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final typePoint = _availableTypesPoints[index];
                    final color = typePoint.getColor();
                    final isCurrentType = typePoint.id == zone.idTypePoint;

                    return ListTile(
                      onTap: isCurrentType
                          ? null
                          : () async {
                              Navigator.pop(context); // Cerrar diálogo
                              await _saveExclusionZoneModificationForMultiplePoints(
                                zone: zone,
                                selectedPoints: selectedPoints,
                                newTypeId: typePoint.id,
                                newTypeName: typePoint.name,
                              );
                            },
                      enabled: !isCurrentType,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: isCurrentType
                              ? Border.all(
                                  color: color,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        typePoint.name ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isCurrentType ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentType
                              ? FlutterFlowTheme.of(context).primaryText
                              : FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      trailing: isCurrentType
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Actual',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: FlutterFlowTheme.of(context).success,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Muestra diálogo de selección de tipo de punto
  void _showTypeSelectionDialog(ExclusionZoneMarker zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar Nuevo Tipo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              zone.namePolygonCoordinate ?? 'Sin nombre',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _availableTypesPoints.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No hay tipos de puntos disponibles',
                      style: TextStyle(
                        fontSize: 14,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _availableTypesPoints.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final typePoint = _availableTypesPoints[index];
                    final color = typePoint.getColor();
                    final isCurrentType = typePoint.id == zone.idTypePoint;

                    return ListTile(
                      onTap: isCurrentType
                          ? null
                          : () async {
                              Navigator.pop(context); // Cerrar diálogo
                              await _saveExclusionZoneModification(
                                zone: zone,
                                newTypeId: typePoint.id,
                                newTypeName: typePoint.name,
                              );
                            },
                      enabled: !isCurrentType,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: isCurrentType
                              ? Border.all(
                                  color: color,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        typePoint.name ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isCurrentType ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentType
                              ? FlutterFlowTheme.of(context).primaryText
                              : FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      trailing: isCurrentType
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Actual',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: FlutterFlowTheme.of(context).success,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Guarda la modificación del tipo para múltiples puntos virtuales
  Future<void> _saveExclusionZoneModificationForMultiplePoints({
    required ExclusionZoneMarker zone,
    required List<VirtualPoint> selectedPoints,
    required int newTypeId,
    required String? newTypeName,
  }) async {
    try {
      debugPrint(
          '💾 Guardando modificación de ${selectedPoints.length} puntos virtuales');
      debugPrint('   Zona: ${zone.namePolygonCoordinate}');
      debugPrint(
          '   Tipo anterior: ${zone.typePointName} (ID: ${zone.idTypePoint})');
      debugPrint('   Tipo nuevo: $newTypeName (ID: $newTypeId)');

      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      final now = DateTime.now().toIso8601String();

      // Procesar cada punto virtual seleccionado
      for (var point in selectedPoints) {
        // 1. Insertar en historial para cada punto virtual
        await db.insert(
          'Exclusion_zones_history',
          {
            'Id_polygon_coordinate': zone.idPolygonCoordinate,
            'Id_virtual_point': point.id,
            'Line_number': point.lineNumber,
            'Point_number': point.pointNumber,
            'Previous_type_id': zone.idTypePoint,
            'Previous_type_name': zone.typePointName,
            'New_type_id': newTypeId,
            'New_type_name': newTypeName,
            'Modified_at': now,
            'User_id': null, // Puede implementarse después
          },
        );

        debugPrint(
            '✅ Historial guardado para punto virtual L${point.lineNumber}P${point.pointNumber} (ID: ${point.id})');
      }

      debugPrint(
          '✅ ${selectedPoints.length} registros insertados en Exclusion_zones_history');

      // 2. Recargar datos para reflejar el cambio
      if (_headquarter != null) {
        await _loadTypePoints(db);
        await _loadCoordinates(_headquarter!.id, db);

        if (mounted) {
          setState(() {});

          // Mostrar confirmación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${selectedPoints.length} punto${selectedPoints.length > 1 ? 's' : ''} virtual${selectedPoints.length > 1 ? 'es' : ''} modificado${selectedPoints.length > 1 ? 's' : ''} en ${zone.namePolygonCoordinate}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: FlutterFlowTheme.of(context).success,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      debugPrint('✅ Modificación de múltiples puntos completada exitosamente');
    } catch (e) {
      debugPrint('❌ Error guardando modificación de múltiples puntos: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Error al actualizar los puntos virtuales: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Guarda la modificación del tipo de zona de exclusión en el historial
  Future<void> _saveExclusionZoneModification({
    required ExclusionZoneMarker zone,
    required int newTypeId,
    required String? newTypeName,
  }) async {
    try {
      debugPrint(
          '💾 Guardando modificación de zona: ${zone.namePolygonCoordinate}');
      debugPrint(
          '   Tipo anterior: ${zone.typePointName} (ID: ${zone.idTypePoint})');
      debugPrint('   Tipo nuevo: $newTypeName (ID: $newTypeId)');

      final String dbPath = await _getDatabasePath();
      final Database db = await openDatabase(dbPath);

      final now = DateTime.now().toIso8601String();

      // 1. Insertar en historial
      await db.insert(
        'Exclusion_zones_history',
        {
          'Id_polygon_coordinate': zone.idPolygonCoordinate,
          'Id_virtual_point': null, // Puede ser null si no aplica
          'Line_number': null,
          'Point_number': null,
          'Previous_type_id': zone.idTypePoint,
          'Previous_type_name': zone.typePointName,
          'New_type_id': newTypeId,
          'New_type_name': newTypeName,
          'Modified_at': now,
          'User_id': null, // Puede implementarse después
        },
      );

      debugPrint('✅ Historial guardado en Exclusion_zones_history');

      // 2. Actualizar tipo en Headquarters_coordinates
      await db.update(
        'Headquarters_coordinates',
        {
          'Id_type_point': newTypeId,
          'Modified_at': now,
        },
        where: 'Id_polygon_coordinate = ?',
        whereArgs: [zone.idPolygonCoordinate],
      );

      debugPrint('✅ Tipo actualizado en Headquarters_coordinates');

      // 3. Recargar datos para reflejar el cambio
      if (_headquarter != null) {
        await _loadTypePoints(db);
        await _loadCoordinates(_headquarter!.id, db);

        if (mounted) {
          setState(() {});

          // Mostrar confirmación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Tipo de zona actualizado: ${zone.namePolygonCoordinate}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: FlutterFlowTheme.of(context).success,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      debugPrint('✅ Modificación completada exitosamente');
    } catch (e) {
      debugPrint('❌ Error guardando modificación: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Error al actualizar el tipo de zona: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Panel de controles superior derecho compacto
  Widget _buildCompactTopControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de reproductor (solo si hay puntos virtuales o ruta simulada)
          if (_virtualPoints.isNotEmpty || _simulatedRoute.isNotEmpty) ...[
            _buildGlassButton(
              icon: _isPlaybackActive ? Icons.close : Icons.play_circle_filled,
              color: _isPlaybackActive
                  ? FlutterFlowTheme.of(context).success
                  : FlutterFlowTheme.of(context).primary,
              isActive: _isPlaybackActive,
              onTap: _togglePlaybackPanel,
            ),
            const SizedBox(width: 12),
          ],
          // Botón de capas
          _buildGlassButton(
            icon: _showLayerPanel ? Icons.layers : Icons.layers_outlined,
            color: FlutterFlowTheme.of(context).primary,
            isActive: _showLayerPanel,
            onTap: () {
              setState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
          ),
          const SizedBox(width: 12),
          // Botón de volumen
          _buildGlassButton(
            icon: _voiceEnabled ? Icons.volume_up : Icons.volume_off,
            color: FlutterFlowTheme.of(context).success,
            isActive: _voiceEnabled,
            onTap: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                if (!_voiceEnabled) {
                  _ttsManager.clearQueue();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  /// Menú FAB Speed Dial moderno
  Widget _buildModernFABMenu() {
    // Calcular posición dinámica basada en si la barra de navegación está visible
    final double bottomOffset = (_showNavigationCard && _currentNavigationEvent != null)
        ? 100  // Altura aproximada de la barra de navegación + margen
        : 24;  // Margen normal cuando no hay barra

    return Positioned(
      bottom: bottomOffset,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabMenuExpanded) ...[
            _buildFABOption(
              icon: Icons.my_location,
              label: 'Mi Ubicación',
              color: FlutterFlowTheme.of(context).error,
              onTap: () {
                setState(() {
                  _isFollowingUser = true;
                  _fabMenuExpanded = false;
                });
                _centerOnCurrentLocation(animated: true);
              },
            ),
            const SizedBox(height: 12),
            if (_virtualPoints.isNotEmpty)
              _buildFABOption(
                icon: Icons.scatter_plot_rounded,
                label: 'Centrar Puntos',
                color: const Color(0xFFA855F7),
                onTap: () {
                  setState(() {
                    _fabMenuExpanded = false;
                  });
                  _centerOnVirtualPoints(animated: true);
                },
              ),
            if (_virtualPoints.isNotEmpty) const SizedBox(height: 12),
            if (_virtualPoints.isNotEmpty)
              _buildFABOption(
                icon: Icons.route,
                label: 'Configurar Ruta',
                color: FlutterFlowTheme.of(context).success,
                onTap: () {
                  setState(() {
                    _fabMenuExpanded = false;
                  });
                  _showSimulationConfigDialog();
                },
              ),
            const SizedBox(height: 12),
            _buildFABOption(
              icon: Icons.fit_screen,
              label: 'Ajustar Todo',
              color: FlutterFlowTheme.of(context).primary,
              onTap: () {
                setState(() {
                  _fabMenuExpanded = false;
                });
                _fitAllBounds();
              },
            ),
            const SizedBox(height: 12),
            _buildFABOption(
              icon:
                  _showTrackingLine ? Icons.timeline : Icons.timeline_outlined,
              label: 'Línea de Trazo',
              color: FlutterFlowTheme.of(context).warning,
              onTap: () {
                setState(() {
                  _showTrackingLine = !_showTrackingLine;
                  _fabMenuExpanded = false;
                });
              },
            ),
            const SizedBox(height: 20),
          ],
          GestureDetector(
            onTap: () {
              setState(() {
                _fabMenuExpanded = !_fabMenuExpanded;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _fabMenuExpanded
                      ? [
                          FlutterFlowTheme.of(context).error,
                          FlutterFlowTheme.of(context).error
                        ]
                      : [
                          FlutterFlowTheme.of(context).primary,
                          FlutterFlowTheme.of(context).secondary
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_fabMenuExpanded
                            ? FlutterFlowTheme.of(context).error
                            : FlutterFlowTheme.of(context).primary)
                        .withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: _fabMenuExpanded ? 0.125 : 0,
                child: Icon(
                  _fabMenuExpanded ? Icons.close : Icons.menu,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón flotante "¿Dónde estoy?" - anuncia ubicación actual por voz
  Widget _buildWhereAmIButton() {
    // Calcular posición dinámica basada en si la barra de navegación está visible
    final double bottomOffset = (_showNavigationCard && _currentNavigationEvent != null)
        ? 108  // Altura aproximada de la barra de navegación + margen (alineado con FAB)
        : 32;  // Margen normal cuando no hay barra

    // Color azul vibrante para el botón
    const Color buttonColor = Color(0xFF2196F3);  // Material Blue 500

    return Positioned(
      bottom: bottomOffset,
      right: 88,  // Al lado izquierdo del FAB (16 + 64 + 8)
      child: GestureDetector(
        onTap: () {
          _speakCurrentLocation();
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3),  // Material Blue 500
                Color(0xFF1976D2),  // Material Blue 700
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: buttonColor.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.record_voice_over,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFABOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
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

  /// Cambia el lote activo en el mapa y actualiza todas las capas
  void _switchToHeadquarter(int hqId) {
    setState(() {
      _activeHeadquarterId = hqId;
      _headquarter = _headquarters[hqId];
      _virtualPoints = _virtualPointsByHeadquarter[hqId] ?? [];
      _polygonPoints = _polygonsByHeadquarter[hqId] ?? [];
      _products = _productsByHeadquarter[hqId] ?? [];
      _coordinates = _coordinatesByHeadquarter[hqId] ?? [];
    });
    debugPrint('🗺️ Lote activo cambiado a ID=$hqId: "${_headquarter?.name}"');
    Future.microtask(() => _fitAllBounds());
  }

  /// Selector de lote activo — aparece solo cuando hay múltiples lotes cargados
  Widget _buildHeadquarterSelector() {
    final hqList = widget.headquarters ?? [];
    if (hqList.length <= 1) return const SizedBox.shrink();

    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: hqList.map((hq) {
                final isActive = hq.idHeadquarter == _activeHeadquarterId;
                final primaryColor = FlutterFlowTheme.of(context).primary;
                return GestureDetector(
                  onTap: () => _switchToHeadquarter(hq.idHeadquarter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(
                              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive) ...[
                          Icon(
                            Icons.layers_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          hq.nameHeadquarter,
                          style: TextStyle(
                            color: isActive ? Colors.white : primaryColor,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                            letterSpacing: 0.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required Color color,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? color : Colors.black)
                  .withValues(alpha: isActive ? 0.3 : 0.1),
              blurRadius: 12,
              spreadRadius: isActive ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : color,
          size: 24,
        ),
      ),
    );
  }
}

// ============================================================================
// CLASES AUXILIARES
// ============================================================================

class _PMTilesVectorTileProvider extends VectorTileProvider {
  final PmTilesArchive archive;

  // Contador de errores para evitar spam en consola
  static int _tileErrorCount = 0;
  static DateTime? _lastErrorReport;
  static const int _errorReportThreshold = 50; // Reportar cada 50 errores
  static const Duration _errorReportInterval = Duration(seconds: 30); // O cada 30 segundos

  _PMTilesVectorTileProvider(this.archive);

  @override
  int get maximumZoom => 22;

  @override
  int get minimumZoom => 0;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      int actualZoom = tile.z;
      int actualX = tile.x;
      int actualY = tile.y;

      if (tile.z > 14) {
        final zoomDiff = tile.z - 14;
        final divisor = math.pow(2, zoomDiff).toInt();
        actualZoom = 14;
        actualX = tile.x ~/ divisor;
        actualY = tile.y ~/ divisor;
      }

      final tileId = ZXY(actualZoom, actualX, actualY).toTileId();
      final pmTile = await archive.tile(tileId);

      final tileData = pmTile.bytes();
      return Uint8List.fromList(tileData);
    } catch (e) {
      // Incrementar contador de errores
      _tileErrorCount++;

      // Solo reportar si:
      // 1. Es el primer error
      // 2. Se alcanzó el threshold de errores
      // 3. Han pasado más de 30 segundos desde el último reporte
      final now = DateTime.now();
      final shouldReport = _tileErrorCount == 1 ||
          _tileErrorCount % _errorReportThreshold == 0 ||
          (_lastErrorReport == null || now.difference(_lastErrorReport!) > _errorReportInterval);

      if (shouldReport) {
        if (_tileErrorCount == 1) {
          debugPrint('⚠️ Error cargando tile del mapa (z=${tile.z} x=${tile.x} y=${tile.y}): $e');
          debugPrint('   Los siguientes errores se agruparán para evitar spam...');
        } else {
          debugPrint('⚠️ Resumen de errores de tiles: $_tileErrorCount tiles fallidos');
          debugPrint('   Último error: z=${tile.z} x=${tile.x} y=${tile.y}');
          debugPrint('   Tipo de error: $e');
        }
        _lastErrorReport = now;
      }

      return Uint8List(0);
    }
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width / 2, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Verificar si ya existe una ruta con los mismos parámetros
Future<bool> _routeExists(
  int headquarterId,
  RouteSimulationConfig config,
) async {
  try {
    // Obtener path de la base de datos
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      return false;
    }
    final String basePath = '${externalDir.path}/ClickPalmData';
    final String dbPath = path.join(basePath, 'clickpalm_database.db');

    // Abrir base de datos
    final Database db = await openDatabase(dbPath);

    // Preparar nombre del patrón
    String routePatternName;
    switch (config.pattern) {
      case RoutePattern.lineaRecta:
        routePatternName = 'lineaRecta';
        break;
      case RoutePattern.zigzagSimple:
        routePatternName = 'zigzagSimple';
        break;
      case RoutePattern.zigzagSerpentina:
        routePatternName = 'zigzagSerpentina';
        break;
      case RoutePattern.zigzagEspiral:
        routePatternName = 'zigzagEspiral';
        break;
      case RoutePattern.rutaOptimizada:
        routePatternName = 'rutaOptimizada';
        break;
    }

    // Buscar ruta con la configuración exacta
    final List<Map<String, dynamic>> results = await db.query(
      'Optimized_routes',
      where:
          'Id_headquarter = ? AND Start_line = ? AND Start_point = ? AND Max_lines = ? AND Max_points = ? AND Route_pattern = ?',
      whereArgs: [
        headquarterId,
        config.startLine,
        config.startPoint,
        config.maxLines ?? 0,
        config.maxPoints ?? 0,
        routePatternName,
      ],
      limit: 1,
    );

    await db.close();

    return results.isNotEmpty;
  } catch (e) {
    debugPrint('⚠️ Error verificando ruta existente: $e');
    return false;
  }
}

/// Guardar CUALQUIER ruta en SQLite (genérico para todos los patrones)
Future<void> _saveRouteToDatabase(
  int headquarterId,
  RouteSimulationConfig config,
  List<VirtualPoint> orderedPoints,
  double totalDistanceKm,
  String estimatedDuration,
  int estimatedDurationSeconds,
) async {
  try {
    debugPrint('💾 Guardando ruta en SQLite...');
    debugPrint('   Patrón: ${config.pattern}');
    debugPrint('   Puntos: ${orderedPoints.length}');

    // Obtener path de la base de datos
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }
    final String basePath = '${externalDir.path}/ClickPalmData';
    final String dbPath = path.join(basePath, 'clickpalm_database.db');

    // Abrir base de datos
    final Database db = await openDatabase(dbPath);

    await db.transaction((txn) async {
      // Preparar nombre del patrón para SQLite
      String routePatternName;
      switch (config.pattern) {
        case RoutePattern.lineaRecta:
          routePatternName = 'lineaRecta';
          break;
        case RoutePattern.zigzagSimple:
          routePatternName = 'zigzagSimple';
          break;
        case RoutePattern.zigzagSerpentina:
          routePatternName = 'zigzagSerpentina';
          break;
        case RoutePattern.zigzagEspiral:
          routePatternName = 'zigzagEspiral';
          break;
        case RoutePattern.rutaOptimizada:
          routePatternName = 'rutaOptimizada';
          break;
      }

      // Insertar ruta
      final routeId = await txn.insert(
        'Optimized_routes',
        {
          'Id_headquarter': headquarterId,
          'Start_line': config.startLine,
          'Start_point': config.startPoint,
          'Max_lines': config.maxLines ?? 0,
          'Max_points': config.maxPoints ?? 0,
          'Route_pattern': routePatternName,
          'Average_speed_kmh': 4.14, // Velocidad promedio de caminata
          'Time_limit_seconds': 0, // No aplica para rutas locales
          'Optimization_strategy': null,
          'Apply_exclusion_zones': 1,
          'Total_distance_km': totalDistanceKm,
          'Estimated_duration': estimatedDuration,
          'Estimated_duration_seconds': estimatedDurationSeconds,
          'Excluded_points_count': 0,
          'Algorithm': routePatternName, // El patrón es el algoritmo
          'Strategy_used': routePatternName,
          'Optimization_time_seconds': 0,
          'Total_lines': null,
          'Lines_in_range': null,
          'Start_location':
              '${orderedPoints.first.lineNumber}-${orderedPoints.first.pointNumber}',
          'End_location':
              '${orderedPoints.last.lineNumber}-${orderedPoints.last.pointNumber}',
          'Improvement_percentage': null,
          'Solution_quality': null,
          'Warnings': null,
          'Total_segments': null,
          'Valid_segments': null,
          'Minor_violations': null,
          'Major_violations': null,
          'Violation_percentage': null,
          'Is_geometrically_valid': null,
          'Geometry_quality': null,
          'Geometry_warnings': null,
          'Disconnected_components': null,
          'Components_were_connected': null,
          'Created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('   ✅ Ruta insertada con ID: $routeId');

      // Insertar puntos ordenados
      for (int i = 0; i < orderedPoints.length; i++) {
        final point = orderedPoints[i];
        await txn.insert(
          'Optimized_route_points',
          {
            'Id_optimized_route': routeId,
            'Id_virtual_point': point.id,
            'Line_number': point.lineNumber,
            'Point_number': point.pointNumber,
            'Latitude': point.latitude,
            'Longitude': point.longitude,
            'Id_type_point': point.idTypePoint,
            'Route_position': i + 1,
            'Distance_to_next_meters':
                null, // Se puede calcular si es necesario
            'Time_to_next': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      debugPrint('   ✅ ${orderedPoints.length} puntos guardados en SQLite');
    });

    await db.close();
    debugPrint('✅ Ruta guardada exitosamente en SQLite');
  } catch (e, stackTrace) {
    debugPrint('❌ Error guardando ruta en SQLite: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

// ============================================================================
// DIALOG DE CONFIGURACIÓN DE SIMULACIÓN
// ============================================================================

class _SimulationConfigDialog extends StatefulWidget {
  final List<VirtualPoint> virtualPoints;
  final int? headquarterId;
  final String? authToken;

  const _SimulationConfigDialog({
    required this.virtualPoints,
    this.headquarterId,
    this.authToken,
  });

  @override
  State<_SimulationConfigDialog> createState() =>
      _SimulationConfigDialogState();
}

class _SimulationConfigDialogState extends State<_SimulationConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _startLineController = TextEditingController(text: '1');
  final _startPointController = TextEditingController(text: '1');
  final _maxLinesController = TextEditingController();
  final _maxPointsController = TextEditingController();
  final _errorMarginController = TextEditingController(text: '5.0');

  RoutePattern _selectedPattern = RoutePattern.lineaRecta;
  bool _isLoadingCache = true;

  // Lista de rutas guardadas
  List<SavedRoute> _savedRoutes = [];
  bool _isLoadingRoutes = true;
  bool _showSavedRoutes = false; // Toggle para mostrar/ocultar lista

  @override
  void initState() {
    super.initState();
    _loadCachedConfig();
    _loadSavedRoutes();
  }

  /// Cargar configuración guardada desde FFAppState
  Future<void> _loadCachedConfig() async {
    try {
      final appState = FFAppState();

      // Cargar valores guardados
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
      if (appState.routeConfigErrorMargin > 0) {
        _errorMarginController.text =
            appState.routeConfigErrorMargin.toString();
      }

      // Cargar patrón guardado
      final patternIndex = appState.routeConfigPattern;
      if (patternIndex >= 0 && patternIndex < RoutePattern.values.length) {
        _selectedPattern = RoutePattern.values[patternIndex];
      }

      debugPrint('✅ Configuración de recorrido cargada desde caché');
    } catch (e) {
      debugPrint('⚠️ Error cargando configuración de caché: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCache = false;
        });
      }
    }
  }

  /// Guardar configuración en FFAppState
  void _saveConfigToCache(RouteSimulationConfig config) {
    try {
      final appState = FFAppState();

      appState.routeConfigStartLine = config.startLine;
      appState.routeConfigStartPoint = config.startPoint;
      appState.routeConfigMaxLines = config.maxLines ?? 0;
      appState.routeConfigMaxPoints = config.maxPoints ?? 0;
      appState.routeConfigErrorMargin = config.errorMarginMeters;
      appState.routeConfigPattern = config.pattern.index;

      debugPrint('💾 Configuración de recorrido guardada en caché');
    } catch (e) {
      debugPrint('⚠️ Error guardando configuración en caché: $e');
    }
  }

  /// Cargar rutas guardadas desde SQLite
  Future<void> _loadSavedRoutes() async {
    if (widget.headquarterId == null) {
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
      return;
    }

    try {
      debugPrint('📂 Cargando rutas guardadas desde SQLite...');

      // Obtener path de la base de datos
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String basePath = '${externalDir.path}/ClickPalmData';
      final String dbPath = path.join(basePath, 'clickpalm_database.db');

      // Abrir base de datos (sqflite reutiliza la conexión si ya está abierta)
      final Database db = await openDatabase(dbPath);

      // Cargar rutas del headquarter actual
      final List<Map<String, dynamic>> results = await db.query(
        'Optimized_routes',
        where: 'Id_headquarter = ?',
        whereArgs: [widget.headquarterId],
        orderBy: 'Created_at DESC',
      );

      // NO cerrar la base de datos - sqflite maneja el pool automáticamente
      // Cerrar aquí causaría DatabaseException en otras operaciones concurrentes

      final routes = results.map((map) => SavedRoute.fromMap(map)).toList();

      debugPrint('✅ ${routes.length} rutas guardadas encontradas');

      if (mounted) {
        setState(() {
          _savedRoutes = routes;
          _isLoadingRoutes = false;
          _showSavedRoutes = routes.isNotEmpty; // Mostrar si hay rutas
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando rutas guardadas: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
    }
  }

  /// Verificar conexión a internet (duplicado de sync_install_module)
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('❌ Sin conexión a internet');
        return false;
      }

      // Verificar conectividad real con ping
      try {
        final result = await http
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 5));
        return result.statusCode == 200;
      } catch (e) {
        debugPrint('❌ No se pudo conectar a internet: $e');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// Verificar si existe una ruta optimizada en la base de datos
  Future<Map<String, dynamic>?> _checkExistingRoute(
    int headquarterId,
    int startLine,
    int startPoint,
    int maxLines,
    int maxPoints,
  ) async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return null;

      final String basePath = '${externalDir.path}/ClickPalmData';
      final String dbPath = path.join(basePath, 'clickpalm_database.db');

      final Database db = await openDatabase(dbPath);

      // Buscar ruta con la configuración exacta
      final List<Map<String, dynamic>> results = await db.query(
        'Optimized_routes',
        where:
            'Id_headquarter = ? AND Start_line = ? AND Start_point = ? AND Max_lines = ? AND Max_points = ?',
        whereArgs: [headquarterId, startLine, startPoint, maxLines, maxPoints],
        orderBy: 'Created_at DESC',
        limit: 1,
      );

      await db.close();

      if (results.isNotEmpty) {
        return results.first;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error verificando ruta existente: $e');
      return null;
    }
  }

  /// Cargar ruta optimizada existente desde SQLite
  Future<void> _loadExistingOptimizedRoute(int routeId) async {
    try {
      debugPrint('📂 Cargando ruta optimizada existente desde SQLite...');
      debugPrint('   ID de ruta: $routeId');

      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        debugPrint('❌ No se pudo acceder al almacenamiento externo');
        return;
      }

      final String basePath = '${externalDir.path}/ClickPalmData';
      final String dbPath = path.join(basePath, 'clickpalm_database.db');
      final Database db = await openDatabase(dbPath);

      // Obtener información de la ruta
      final List<Map<String, dynamic>> routeData = await db.query(
        'Optimized_routes',
        where: 'Id_optimized_route = ?',
        whereArgs: [routeId],
        limit: 1,
      );

      if (routeData.isEmpty) {
        debugPrint('❌ No se encontró la ruta con ID: $routeId');
        await db.close();
        return;
      }

      final route = routeData.first;
      debugPrint('   ✅ Ruta encontrada');
      debugPrint('      Distancia total: ${route['Total_distance_km']} km');
      debugPrint('      Duración estimada: ${route['Estimated_duration']}');
      debugPrint('      Algoritmo: ${route['Algorithm']}');
      debugPrint('      Estrategia: ${route['Strategy_used']}');

      // Obtener puntos ordenados de la ruta
      final List<Map<String, dynamic>> pointsData = await db.query(
        'Optimized_route_points',
        where: 'Id_optimized_route = ?',
        whereArgs: [routeId],
        orderBy: 'Route_position ASC',
      );

      await db.close();

      if (pointsData.isEmpty) {
        debugPrint('❌ La ruta no tiene puntos asociados');
        return;
      }

      debugPrint('   📍 ${pointsData.length} puntos cargados desde SQLite');

      // Convertir a VirtualPoint
      final List<VirtualPoint> orderedPoints = [];
      for (var pointData in pointsData) {
        final vpId = pointData['Id_virtual_point'] as int;

        // Buscar el punto virtual en la lista ya cargada del widget
        VirtualPoint? vp;
        try {
          vp = widget.virtualPoints.firstWhere((p) => p.id == vpId);
        } catch (e) {
          // Si no está en la lista, crear uno nuevo con los datos de SQLite
          final idTypePoint = pointData['Id_type_point'] as int?;
          vp = VirtualPoint(
            id: vpId,
            lineNumber: pointData['Line_number'] as int,
            pointNumber: pointData['Point_number'] as int,
            latitude: pointData['Latitude'] as double,
            longitude: pointData['Longitude'] as double,
            description: null,
            isActive: true,
            idTypePoint: idTypePoint,
            typeName: null,
            headquarterName: null,
            pointDisplayName: null,
            typePoint: null,
          );
        }
        orderedPoints.add(vp);
      }

      debugPrint(
          '   ✅ ${orderedPoints.length} puntos convertidos correctamente');
      debugPrint('   🎯 Ruta optimizada cargada exitosamente');
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando ruta existente: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Generar y guardar ruta optimizada llamando al API
  /// Diálogo elegante mostrando ruta existente encontrada
  Future<bool?> _showExistingRouteDialog(
    BuildContext context,
    Map<String, dynamic> existingRoute,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).success,
                  FlutterFlowTheme.of(context).success,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono con animación
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),

                // Título
                const Text(
                  'Ruta Optimizada Encontrada',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Información de la ruta
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRouteInfoRow(
                        Icons.straighten,
                        'Distancia',
                        '${existingRoute['Total_distance_km']?.toStringAsFixed(2) ?? 'N/A'} km',
                      ),
                      const SizedBox(height: 12),
                      _buildRouteInfoRow(
                        Icons.access_time,
                        'Duración',
                        '${existingRoute['Estimated_duration'] ?? 'N/A'}',
                      ),
                      const SizedBox(height: 12),
                      _buildRouteInfoRow(
                        Icons.star,
                        'Calidad',
                        '${existingRoute['Solution_quality'] ?? 'N/A'}',
                      ),
                      if (existingRoute['Improvement_percentage'] != null) ...[
                        const SizedBox(height: 12),
                        _buildRouteInfoRow(
                          Icons.trending_up,
                          'Mejora',
                          '${existingRoute['Improvement_percentage']?.toStringAsFixed(1)}%',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Mensaje
                Text(
                  '¿Deseas usar esta ruta o generar una nueva?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Nueva Ruta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FlutterFlowTheme.of(context).success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 8,
                          shadowColor: Colors.white.withValues(alpha: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Usar Esta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
  }

  /// Widget helper para fila de información de ruta
  Widget _buildRouteInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Diálogo elegante de carga para optimización de ruta
  Widget _buildOptimizationLoadingDialog(ValueNotifier<String> statusNotifier) {
    return _OptimizationLoadingDialog(statusNotifier: statusNotifier);
  }

  Future<bool> _generateAndSaveOptimizedRoute(
    RouteSimulationConfig config,
    BuildContext dialogContext, {
    bool skipExistingCheck = false,
    ValueNotifier<String>? statusNotifier,
  }) async {
    try {
      debugPrint('🌐 Iniciando generación de ruta optimizada...');

      // 0. Obtener headquarterId primero para verificar ruta existente
      final headquarterId = widget.headquarterId;

      if (headquarterId == null) {
        statusNotifier?.value = 'Error: No hay ID de headquarter disponible';
        if (dialogContext.mounted) {
          await showDialog(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('No hay ID de headquarter disponible.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      // 0.1. Verificar si ya existe una ruta con esta configuración en la BD
      // (Solo si no se saltó esta verificación previamente)
      if (!skipExistingCheck) {
        statusNotifier?.value =
            'Verificando ruta existente en base de datos...';
        debugPrint(
            '   🔍 Verificando si ya existe ruta en la base de datos...');
        final existingRoute = await _checkExistingRoute(
          headquarterId,
          config.startLine,
          config.startPoint,
          config.maxLines ?? 0,
          config.maxPoints ?? 0,
        );

        if (existingRoute != null) {
          debugPrint(
              '   ✅ Se encontró ruta existente (ID: ${existingRoute['Id_optimized_route']})');

          // Preguntar al usuario si desea usar la ruta existente o generar una nueva
          if (dialogContext.mounted) {
            final useExisting = await _showExistingRouteDialog(
              dialogContext,
              existingRoute,
            );

            if (useExisting == true) {
              // Cargar ruta existente
              statusNotifier?.value = 'Cargando ruta existente...';
              await _loadExistingOptimizedRoute(
                  existingRoute['Id_optimized_route']);
              return true;
            } else if (useExisting == null) {
              // Usuario canceló
              return false;
            }
            // Si useExisting == false, continuar generando nueva ruta
          }
        } else {
          debugPrint(
              '   ℹ️ No se encontró ruta existente, se generará una nueva');
        }
      } else {
        debugPrint(
            '   ⏭️ Verificación de ruta existente omitida (ya se verificó)');
      }

      // 1. Verificar conexión a internet
      statusNotifier?.value = 'Verificando conexión a internet...';
      debugPrint('   📡 Verificando conexión a internet...');
      final hasConnection = await _checkInternetConnection();

      if (!hasConnection) {
        statusNotifier?.value = 'Sin conexión a internet';
        if (dialogContext.mounted) {
          await showDialog(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Sin Conexión'),
              content: const Text(
                'Se requiere conexión a internet para generar rutas optimizadas. '
                'Por favor, verifica tu conexión e intenta nuevamente.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      debugPrint('   ✅ Conexión verificada');

      // 2. Obtener datos necesarios desde el widget
      final authToken = widget.authToken;

      if (headquarterId == null) {
        statusNotifier?.value = 'Error: No hay ID de headquarter disponible';
        if (dialogContext.mounted) {
          await showDialog(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('No hay ID de headquarter disponible.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      if (authToken == null || authToken.isEmpty) {
        statusNotifier?.value = 'Error: No hay token de autenticación';
        if (dialogContext.mounted) {
          await showDialog(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Error de Autenticación'),
              content: const Text('No hay token de autenticación disponible.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      // 3. Llamar al API con callback de actualización de estado
      debugPrint('   📞 Llamando al API de optimización...');
      final success = await _callOptimizationAPIAndSave(
        headquarterId,
        config,
        authToken,
        onStatusUpdate: (String status) {
          statusNotifier?.value = status;
        },
      );

      if (!success) {
        if (dialogContext.mounted) {
          await showDialog(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: const Text('Error de Optimización'),
              content: const Text(
                'No se pudo generar la ruta optimizada. '
                'Por favor, intenta nuevamente más tarde.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }

      debugPrint('   ✅ Ruta optimizada generada y guardada exitosamente');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando ruta optimizada: $e');
      debugPrint('Stack trace: $stackTrace');
      statusNotifier?.value = 'Error inesperado: ${e.toString()}';
      return false;
    }
  }

  /// Llamar al API y guardar en SQLite con sistema de reintentos robusto
  Future<bool> _callOptimizationAPIAndSave(
    int headquarterId,
    RouteSimulationConfig config,
    String authToken, {
    Function(String)? onStatusUpdate,
  }) async {
    const int maxRetries = 3;
    const Duration initialRetryDelay = Duration(seconds: 2);
    const Duration apiTimeout = Duration(seconds: 300); // 5 minutos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const double avgSpeedKmh = 4.14;
        const String baseUrl = 'https://api.clickpalm.com';

        // Construir request body
        final requestBody = {
          'id_headquarter': headquarterId,
          'start_line': config.startLine,
          'start_point': config.startPoint,
          'max_lines': config.maxLines ?? 0,
          'max_points': config.maxPoints ?? 0,
          'average_speed_kmh': avgSpeedKmh,
          'time_limit_seconds': 30,
          'optimization_strategy': 'GuidedLocalSearch',
          'apply_exclusion_zones': true,
        };

        debugPrint('   📤 Intento $attempt/$maxRetries');
        debugPrint('   Request: ${jsonEncode(requestBody)}');

        if (attempt == 1) {
          onStatusUpdate?.call('Solicitando ruta al servidor...');
        } else {
          onStatusUpdate
              ?.call('Reintentando (intento $attempt/$maxRetries)...');
        }

        // Llamar al endpoint con timeout de 5 minutos
        final response = await http
            .post(
          Uri.parse('$baseUrl/RouteOptimization/optimize'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
            .timeout(
          apiTimeout,
          onTimeout: () {
            throw TimeoutException(
              'El servidor tardó más de ${apiTimeout.inMinutes} minutos en responder',
              apiTimeout,
            );
          },
        );

        debugPrint('   Status code: ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint('   ❌ Error del API: ${response.body}');

          // Si es el último intento, fallar
          if (attempt >= maxRetries) {
            onStatusUpdate
                ?.call('Error del servidor (código ${response.statusCode})');
            return false;
          }

          // Reintentar en errores 5xx (servidor)
          if (response.statusCode >= 500) {
            final delay = initialRetryDelay * attempt;
            debugPrint(
                '   🔄 Error del servidor, reintentando en ${delay.inSeconds}s...');
            onStatusUpdate?.call(
                'Error del servidor. Reintentando en ${delay.inSeconds}s...');
            await Future.delayed(delay);
            continue;
          }

          // Para errores 4xx (cliente), no reintentar
          onStatusUpdate?.call('Error: ${response.body}');
          return false;
        }

        // Parsear respuesta
        onStatusUpdate?.call('Procesando respuesta del servidor...');
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        debugPrint('   ✅ Respuesta recibida del API');
        debugPrint('      Distancia: ${responseData['total_distance_km']} km');
        debugPrint('      Duración: ${responseData['estimated_duration']}');
        debugPrint(
            '      Puntos: ${(responseData['ordered_points'] as List?)?.length ?? 0}');

        // Guardar en SQLite
        onStatusUpdate?.call('Guardando ruta en base de datos...');
        await _saveOptimizedRouteToDatabase(
          headquarterId,
          requestBody,
          responseData,
        );

        onStatusUpdate?.call('¡Ruta optimizada guardada exitosamente!');
        return true;
      } on TimeoutException catch (e) {
        debugPrint('   ⏱️ Timeout en intento $attempt: $e');

        if (attempt >= maxRetries) {
          onStatusUpdate?.call(
              'El servidor no respondió en ${apiTimeout.inMinutes} minutos');
          return false;
        }

        final delay = initialRetryDelay * attempt;
        debugPrint('   🔄 Timeout, reintentando en ${delay.inSeconds}s...');
        onStatusUpdate?.call('Timeout. Reintentando en ${delay.inSeconds}s...');
        await Future.delayed(delay);
        continue;
      } on SocketException catch (e) {
        debugPrint('   🌐 Error de conexión en intento $attempt: $e');

        if (attempt >= maxRetries) {
          onStatusUpdate?.call('Sin conexión a internet. Verifica tu red.');
          return false;
        }

        final delay = initialRetryDelay * attempt;
        debugPrint(
            '   🔄 Error de conexión, reintentando en ${delay.inSeconds}s...');
        onStatusUpdate
            ?.call('Sin conexión. Reintentando en ${delay.inSeconds}s...');
        await Future.delayed(delay);
        continue;
      } on HttpException catch (e) {
        debugPrint('   🌐 Error HTTP en intento $attempt: $e');

        if (attempt >= maxRetries) {
          onStatusUpdate?.call('Error de red. Intenta más tarde.');
          return false;
        }

        final delay = initialRetryDelay * attempt;
        debugPrint('   🔄 Error HTTP, reintentando en ${delay.inSeconds}s...');
        onStatusUpdate
            ?.call('Error de red. Reintentando en ${delay.inSeconds}s...');
        await Future.delayed(delay);
        continue;
      } catch (e) {
        debugPrint('   ❌ Error inesperado en intento $attempt: $e');

        if (attempt >= maxRetries) {
          onStatusUpdate?.call('Error inesperado: ${e.toString()}');
          return false;
        }

        final delay = initialRetryDelay * attempt;
        debugPrint('   🔄 Reintentando en ${delay.inSeconds}s...');
        onStatusUpdate?.call('Error. Reintentando en ${delay.inSeconds}s...');
        await Future.delayed(delay);
        continue;
      }
    }

    // Si llegamos aquí después de todos los reintentos
    onStatusUpdate?.call(
        'No se pudo completar la optimización después de $maxRetries intentos');
    return false;
  }

  /// Guardar ruta en SQLite (duplicado de sync_install_module)
  Future<void> _saveOptimizedRouteToDatabase(
    int headquarterId,
    Map<String, dynamic> requestConfig,
    Map<String, dynamic> responseData,
  ) async {
    try {
      // Obtener path de la base de datos
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String basePath = '${externalDir.path}/ClickPalmData';
      final String dbPath = path.join(basePath, 'clickpalm_database.db');

      // Abrir base de datos
      final Database db = await openDatabase(dbPath);

      await db.transaction((txn) async {
        // Preparar datos
        final routeMetadata = responseData['route_metadata'] ?? {};
        final warnings = responseData['warnings'];
        final warningsJson = warnings != null ? jsonEncode(warnings) : null;
        final linesInRange = routeMetadata['lines_in_range'];
        final linesInRangeJson =
            linesInRange != null ? jsonEncode(linesInRange) : null;

        // Preparar datos de geometría
        final geometryWarnings = routeMetadata['geometry_warnings'];
        final geometryWarningsJson =
            geometryWarnings != null ? jsonEncode(geometryWarnings) : null;

        // Insertar ruta
        final routeId = await txn.insert(
          'Optimized_routes',
          {
            'Id_headquarter': headquarterId,
            'Start_line': requestConfig['start_line'],
            'Start_point': requestConfig['start_point'],
            'Max_lines': requestConfig['max_lines'],
            'Max_points': requestConfig['max_points'],
            'Route_pattern':
                'rutaOptimizada', // Siempre rutaOptimizada para esta función
            'Average_speed_kmh': requestConfig['average_speed_kmh'],
            'Time_limit_seconds': requestConfig['time_limit_seconds'],
            'Optimization_strategy': requestConfig['optimization_strategy'],
            'Apply_exclusion_zones':
                (requestConfig['apply_exclusion_zones'] == true) ? 1 : 0,
            'Total_distance_km': responseData['total_distance_km'],
            'Estimated_duration': responseData['estimated_duration'],
            'Estimated_duration_seconds':
                responseData['estimated_duration_seconds'],
            'Excluded_points_count': responseData['excluded_points_count'] ?? 0,
            'Algorithm': responseData['algorithm'],
            'Strategy_used': responseData['strategy_used'],
            'Optimization_time_seconds':
                responseData['optimization_time_seconds'],
            'Total_lines': routeMetadata['total_lines'],
            'Lines_in_range': linesInRangeJson,
            'Start_location': routeMetadata['start_location'],
            'End_location': routeMetadata['end_location'],
            'Improvement_percentage': routeMetadata['improvement_percentage'],
            'Solution_quality': routeMetadata['solution_quality'],
            'Warnings': warningsJson,
            // Nuevos campos geométricos
            'Total_segments': routeMetadata['total_segments'],
            'Valid_segments': routeMetadata['valid_segments'],
            'Minor_violations': routeMetadata['minor_violations'],
            'Major_violations': routeMetadata['major_violations'],
            'Violation_percentage': routeMetadata['violation_percentage'],
            'Is_geometrically_valid':
                (routeMetadata['is_geometrically_valid'] == true) ? 1 : 0,
            'Geometry_quality': routeMetadata['geometry_quality'],
            'Geometry_warnings': geometryWarningsJson,
            'Disconnected_components': routeMetadata['disconnected_components'],
            'Components_were_connected':
                (routeMetadata['components_were_connected'] == true) ? 1 : 0,
            'Created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Insertar puntos
        final List<dynamic>? orderedPoints = responseData['ordered_points'];
        if (orderedPoints != null && orderedPoints.isNotEmpty) {
          for (var point in orderedPoints) {
            await txn.insert(
              'Optimized_route_points',
              {
                'Id_optimized_route': routeId,
                'Id_virtual_point': point['id'],
                'Line_number': point['line_number'],
                'Point_number': point['point_number'],
                'Latitude': point['latitude'],
                'Longitude': point['longitude'],
                'Id_type_point': point['id_type_point'],
                'Route_position': point['route_position'],
                'Distance_to_next_meters': point['distance_to_next_meters'],
                'Time_to_next': point['time_to_next'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          debugPrint(
              '      💾 ${orderedPoints.length} puntos guardados en SQLite');
        }
      });

      await db.close();
      debugPrint('   ✅ Ruta guardada en SQLite');
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error guardando en SQLite: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  void dispose() {
    _startLineController.dispose();
    _startPointController.dispose();
    _maxLinesController.dispose();
    _maxPointsController.dispose();
    _errorMarginController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.3),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con gradiente
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).secondary
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.route,
                      color: Colors.white,
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Personaliza tu ruta',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RUTAS GUARDADAS
                      if (_savedRoutes.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.1),
                                FlutterFlowTheme.of(context)
                                    .success
                                    .withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context)
                                  .success
                                  .withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header de rutas guardadas (siempre visible)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showSavedRoutes = !_showSavedRoutes;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .success
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.history,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Rutas Guardadas',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${_savedRoutes.length} ${_savedRoutes.length == 1 ? 'ruta' : 'rutas'} disponible${_savedRoutes.length == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _showSavedRoutes
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Lista de rutas (collapsible)
                              if (_showSavedRoutes) ...[
                                Divider(
                                  height: 1,
                                  color: FlutterFlowTheme.of(context).success,
                                  thickness: 0.5,
                                ),
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 250),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _savedRoutes.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final route = _savedRoutes[index];
                                      return _buildSavedRouteCard(route);
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Divider entre rutas guardadas y nueva configuración
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white24)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'O CREA UNA NUEVA RUTA',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white24)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Punto de Inicio
                      _buildSectionHeader(Icons.location_on, 'Punto de Inicio'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTextField(
                              controller: _startLineController,
                              label: 'Línea',
                              icon: Icons.horizontal_rule,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernTextField(
                              controller: _startPointController,
                              label: 'Punto',
                              icon: Icons.location_searching,
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Límites
                      _buildSectionHeader(Icons.tune, 'Límites (Opcional)'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTextField(
                              controller: _maxLinesController,
                              label: 'Max Líneas',
                              icon: Icons.view_headline,
                              isNumber: true,
                              isOptional: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernTextField(
                              controller: _maxPointsController,
                              label: 'Max Puntos',
                              icon: Icons.grid_on,
                              isNumber: true,
                              isOptional: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Patrón de Recorrido
                      _buildSectionHeader(
                          Icons.route_outlined, 'Patrón de Recorrido'),
                      const SizedBox(height: 12),
                      _buildPatternCard(
                        RoutePattern.lineaRecta,
                        'Línea Recta',
                        'Secuencial: L1→L2→L3',
                        Icons.trending_flat,
                      ),
                      _buildPatternCard(
                        RoutePattern.zigzagSimple,
                        'Zigzag Simple',
                        'Alterna: L1→, L2←, L3→',
                        Icons.swap_horiz,
                      ),
                      _buildPatternCard(
                        RoutePattern.zigzagSerpentina,
                        'Zigzag Serpentina',
                        'Optimiza distancia entre líneas',
                        Icons.show_chart,
                      ),
                      _buildPatternCard(
                        RoutePattern.zigzagEspiral,
                        'Zigzag Espiral',
                        'Desde el centro hacia afuera',
                        Icons.tornado,
                      ),
                      _buildPatternCard(
                        RoutePattern.rutaOptimizada,
                        'Ruta Optimizada',
                        'Google OR-Tools (requiere internet)',
                        Icons.psychology,
                        isPremium: true,
                      ),

                      const SizedBox(height: 24),

                      // Margen de Error
                      _buildSectionHeader(Icons.straighten, 'Margen de Error'),
                      const SizedBox(height: 12),
                      _buildModernTextField(
                        controller: _errorMarginController,
                        label: 'Distancia en metros',
                        icon: Icons.straighten,
                        suffix: 'm',
                        isDecimal: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final config = RouteSimulationConfig(
                            startLine: int.parse(_startLineController.text),
                            startPoint: int.parse(_startPointController.text),
                            maxLines: _maxLinesController.text.isNotEmpty
                                ? int.parse(_maxLinesController.text)
                                : null,
                            maxPoints: _maxPointsController.text.isNotEmpty
                                ? int.parse(_maxPointsController.text)
                                : null,
                            pattern: _selectedPattern,
                            errorMarginMeters:
                                double.parse(_errorMarginController.text),
                          );

                          // Guardar configuración en caché
                          _saveConfigToCache(config);

                          // Si es ruta optimizada, verificar primero en SQLite
                          if (_selectedPattern == RoutePattern.rutaOptimizada) {
                            // PASO 1: Verificar si ya existe en SQLite ANTES de hacer nada
                            debugPrint(
                                '🔍 Verificando ruta optimizada en SQLite primero...');

                            final headquarterId = widget.headquarterId;
                            if (headquarterId != null) {
                              final existingRoute = await _checkExistingRoute(
                                headquarterId,
                                config.startLine,
                                config.startPoint,
                                config.maxLines ?? 0,
                                config.maxPoints ?? 0,
                              );

                              // Si existe, preguntar si desea usarla
                              if (existingRoute != null && context.mounted) {
                                debugPrint(
                                    '✅ Ruta optimizada encontrada en SQLite');

                                final useExisting =
                                    await _showExistingRouteDialog(
                                        context, existingRoute);

                                if (useExisting == true) {
                                  // Cargar ruta existente directamente
                                  Navigator.pop(context, config);
                                  return;
                                } else if (useExisting == false) {
                                  // Usuario eligió generar nueva, continuar con API
                                  debugPrint(
                                      '🔄 Usuario eligió generar nueva ruta');
                                } else {
                                  // Usuario canceló
                                  return;
                                }
                              }
                            }

                            // PASO 2: Si no existe o usuario eligió generar nueva, mostrar diálogo elegante y llamar API
                            if (context.mounted) {
                              // Crear notificador de estado para actualizar el diálogo
                              final statusNotifier = ValueNotifier<String>(
                                  'Preparando solicitud al servidor...');

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (loadingContext) =>
                                    _buildOptimizationLoadingDialog(
                                        statusNotifier),
                              );

                              final success =
                                  await _generateAndSaveOptimizedRoute(
                                config,
                                context,
                                skipExistingCheck:
                                    true, // Ya verificamos arriba
                                statusNotifier:
                                    statusNotifier, // Pasar notificador
                              );

                              if (context.mounted) {
                                Navigator.pop(
                                    context); // Cerrar diálogo de carga
                              }

                              // Limpiar notificador
                              statusNotifier.dispose();

                              if (!success) {
                                return;
                              }
                            }
                          }

                          Navigator.pop(context, config);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: FlutterFlowTheme.of(context)
                            .primary
                            .withValues(alpha: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Generar Recorrido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  // Widget para construir tarjeta de ruta guardada
  Widget _buildSavedRouteCard(SavedRoute route) {
    final patternIcons = {
      'lineaRecta': Icons.straight,
      'zigzagSimple': Icons.swap_vert,
      'zigzagSerpentina': Icons.waves,
      'zigzagEspiral': Icons.tornado,
      'rutaOptimizada': Icons.auto_awesome,
    };

    final patternNames = {
      'lineaRecta': 'Línea Recta',
      'zigzagSimple': 'Zigzag Simple',
      'zigzagSerpentina': 'Zigzag Serpentina',
      'zigzagEspiral': 'Zigzag Espiral',
      'rutaOptimizada': 'Optimizada por IA',
    };

    final icon = patternIcons[route.routePattern] ?? Icons.route;
    final patternName = patternNames[route.routePattern] ?? route.routePattern;
    final isOptimized = route.routePattern == 'rutaOptimizada';

    return InkWell(
      onTap: () {
        // Cargar la ruta seleccionada
        _loadRouteConfig(route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FlutterFlowTheme.of(context).success.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icono del patrón
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isOptimized
                        ? LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                          )
                        : null,
                    color: isOptimized
                        ? null
                        : FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isOptimized
                        ? Colors.white
                        : FlutterFlowTheme.of(context).success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre y patrón
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOptimized
                              ? FlutterFlowTheme.of(context)
                                  .primary
                                  .withValues(alpha: 0.2)
                              : FlutterFlowTheme.of(context)
                                  .warning
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOptimized
                                ? FlutterFlowTheme.of(context)
                                    .primary
                                    .withValues(alpha: 0.4)
                                : FlutterFlowTheme.of(context)
                                    .warning
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          patternName,
                          style: TextStyle(
                            color: isOptimized
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Información detallada
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRouteInfoChip(
                  icon: Icons.play_arrow,
                  label: 'Inicio',
                  value: 'L${route.startLine} P${route.startPoint}',
                  color: FlutterFlowTheme.of(context).success,
                ),
                _buildRouteInfoChip(
                  icon: Icons.format_list_numbered,
                  label: 'Máx Líneas',
                  value: route.maxLines.toString(),
                  color: FlutterFlowTheme.of(context).info,
                ),
                _buildRouteInfoChip(
                  icon: Icons.scatter_plot,
                  label: 'Máx Puntos',
                  value: route.maxPoints.toString(),
                  color: FlutterFlowTheme.of(context).tertiary,
                ),
                if (route.totalDistanceKm != null)
                  _buildRouteInfoChip(
                    icon: Icons.straighten,
                    label: 'Distancia',
                    value: '${route.totalDistanceKm!.toStringAsFixed(2)} km',
                    color: FlutterFlowTheme.of(context).warning,
                  ),
                if (route.estimatedDuration != null)
                  _buildRouteInfoChip(
                    icon: Icons.schedule,
                    label: 'Tiempo',
                    value: route.estimatedDuration!,
                    color: FlutterFlowTheme.of(context).error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cargar configuración desde una ruta guardada
  void _loadRouteConfig(SavedRoute route) {
    // Mapear string de patrón a enum
    RoutePattern? pattern;
    switch (route.routePattern) {
      case 'lineaRecta':
        pattern = RoutePattern.lineaRecta;
        break;
      case 'zigzagSimple':
        pattern = RoutePattern.zigzagSimple;
        break;
      case 'zigzagSerpentina':
        pattern = RoutePattern.zigzagSerpentina;
        break;
      case 'zigzagEspiral':
        pattern = RoutePattern.zigzagEspiral;
        break;
      case 'rutaOptimizada':
        pattern = RoutePattern.rutaOptimizada;
        break;
    }

    if (pattern == null) {
      debugPrint('⚠️ Patrón desconocido: ${route.routePattern}');
      return;
    }

    // Actualizar controladores de texto y estado
    setState(() {
      _startLineController.text = route.startLine.toString();
      _startPointController.text = route.startPoint.toString();
      _maxLinesController.text =
          route.maxLines > 0 ? route.maxLines.toString() : '';
      _maxPointsController.text =
          route.maxPoints > 0 ? route.maxPoints.toString() : '';
      _selectedPattern = pattern!;
      _showSavedRoutes = false; // Colapsar la lista al seleccionar
    });

    debugPrint('✅ Configuración cargada desde ruta guardada');
  }

  // Widgets auxiliares para el diseño moderno
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                FlutterFlowTheme.of(context).primary,
                FlutterFlowTheme.of(context).secondary
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
    bool isNumber = false,
    bool isDecimal = false,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isNumber ? TextInputType.number : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon,
            color: FlutterFlowTheme.of(context).secondaryBackground, size: 20),
        suffixText: suffix,
        suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: FlutterFlowTheme.of(context).error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: isOptional
          ? (value) {
              if (value != null && value.isNotEmpty) {
                final num =
                    isDecimal ? double.tryParse(value) : int.tryParse(value);
                if (num == null || num < (isDecimal ? 0.1 : 1)) {
                  return 'Inválido';
                }
              }
              return null;
            }
          : (value) {
              if (value == null || value.isEmpty) {
                return 'Requerido';
              }
              final num =
                  isDecimal ? double.tryParse(value) : int.tryParse(value);
              if (num == null || num < (isDecimal ? 0.1 : 1)) {
                return 'Inválido';
              }
              if (isDecimal && num > 100) {
                return 'Máx 100';
              }
              return null;
            },
    );
  }

  Widget _buildPatternCard(
    RoutePattern pattern,
    String title,
    String description,
    IconData icon, {
    bool isPremium = false,
  }) {
    final isSelected = _selectedPattern == pattern;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPattern = pattern;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).secondary
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : FlutterFlowTheme.of(context).secondaryBackground,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context).warning,
                                FlutterFlowTheme.of(context).warning
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET ESTATEFUL PARA DIÁLOGO DE CARGA DE OPTIMIZACIÓN
// ============================================================================

/// Widget independiente con su propia animación para el diálogo de carga
class _OptimizationLoadingDialog extends StatefulWidget {
  final ValueNotifier<String> statusNotifier;

  const _OptimizationLoadingDialog({required this.statusNotifier});

  @override
  State<_OptimizationLoadingDialog> createState() =>
      _OptimizationLoadingDialogState();
}

class _OptimizationLoadingDialogState extends State<_OptimizationLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animación de pulso independiente
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlutterFlowTheme.of(context).primary,
              FlutterFlowTheme.of(context).secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color:
                  FlutterFlowTheme.of(context).primary.withValues(alpha: 0.6),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación de carga con múltiples círculos
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Círculo exterior pulsante
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  // Círculo medio
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.route,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Indicador de progreso circular
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Título con efecto
            const Text(
              'Optimizando Ruta',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Estado dinámico actualizable
            ValueListenableBuilder<String>(
              valueListenable: widget.statusNotifier,
              builder: (context, status, child) {
                return Text(
                  status,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 16),

            // Mensaje informativo
            Text(
              'Esto puede tardar hasta 5 minutos',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Barra de progreso con estilo
            Container(
              width: 220,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Información adicional
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Usando algoritmos avanzados',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
}
