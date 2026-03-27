// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
// Begin custom widget code

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'tts_queue_manager.dart';

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
  final double bearing;

  CardinalDirection({
    required this.direction,
    this.point,
    this.distanceMeters = 0.0,
    this.bearing = 0.0,
  });

  String getDirectionLabel() {
    switch (direction) {
      case 'N': return 'NORTE';
      case 'S': return 'SUR';
      case 'E': return 'ESTE';
      case 'O': return 'OESTE';
      default:  return 'N/A';
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

  String get formattedLatitude  => latitude.toStringAsFixed(5);
  String get formattedLongitude => longitude.toStringAsFixed(5);
  String get formattedCoordinates => '$formattedLatitude, $formattedLongitude';
}

// ============================================================================
// CONTROLADOR DE VOZ LLM ON-DEVICE
// ============================================================================

const String _kVoiceModelReadyKey = 'voice_model_ready';
const String _kVoiceModelFileName = 'gemma3-1b-it-int4.task';

const String _kSystemPrompt =
    'Eres un asistente de campo para operarios de palma africana en Colombia. '
    'Convierte datos de brújula GPS en UNA frase corta, amable y en español colombiano. '
    'Máximo 2 oraciones. Sin símbolos especiales. Solo texto para lectura en voz alta.';

class CompassVoiceController {
  final TTSQueueManager _tts = TTSQueueManager();
  InferenceModel? _model;

  bool isModelReady    = false;
  bool isInferring     = false;
  bool voiceEnabled    = false;

  String? _lastKey;
  double? _lastDist;
  DateTime? _lastAt;

  final VoidCallback onStateChanged;

  CompassVoiceController({required this.onStateChanged});

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ready = prefs.getBool(_kVoiceModelReadyKey) ?? false;
      if (!ready) return;

      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/$_kVoiceModelFileName';
      if (!await File(modelPath).exists()) return;

      await FlutterGemmaPlugin.instance.init(
        maxTokens: 256,
        temperature: 0.7,
        topK: 40,
        randomSeed: 42,
      );

      _model = await InferenceModel.create(modelPath);
      isModelReady = true;
      onStateChanged();
    } catch (e) {
      debugPrint('⚠️ [CompassVoice] Error cargando modelo: $e');
    }
  }

  Future<void> announceState(
    Map<String, CardinalDirection> directions,
    CurrentLocationDisplay location,
  ) async {
    if (!voiceEnabled) return;
    if (isInferring) return;

    // Buscar la palma más cercana con punto
    CardinalDirection? nearest;
    for (final cd in directions.values) {
      if (cd.point == null) continue;
      if (nearest == null || cd.distanceMeters < nearest.distanceMeters) {
        nearest = cd;
      }
    }
    if (nearest == null) return;

    final newKey = 'L${nearest.point!.lineNumber}P${nearest.point!.pointNumber}';
    final newDist = nearest.distanceMeters;
    final now = DateTime.now();

    // Anti-spam: clave igual, distancia no cambió ±15m, cooldown 30s
    final keyChanged  = newKey != _lastKey;
    final distChanged = _lastDist == null || (newDist - _lastDist!).abs() > 15;
    final cooldownOk  = _lastAt == null || now.difference(_lastAt!).inSeconds >= 30;

    if (!keyChanged && !distChanged) return;
    if (!cooldownOk) return;

    _lastKey  = newKey;
    _lastDist = newDist;
    _lastAt   = now;

    if (isModelReady && _model != null) {
      await _announceWithLLM(directions, nearest);
    } else {
      _announceFallback(nearest);
    }
  }

  Future<void> _announceWithLLM(
    Map<String, CardinalDirection> directions,
    CardinalDirection nearest,
  ) async {
    isInferring = true;
    onStateChanged();
    try {
      final lines = <String>[];
      final dirLabels = {'N': 'Norte', 'S': 'Sur', 'E': 'Este', 'O': 'Oeste'};
      for (final entry in directions.entries) {
        final cd = entry.value;
        if (cd.point != null) {
          lines.add(
            '${dirLabels[entry.key]}: L${cd.point!.lineNumber}P${cd.point!.pointNumber} '
            'a ${cd.distanceMeters.toStringAsFixed(0)}m',
          );
        } else {
          lines.add('${dirLabels[entry.key]}: sin palma');
        }
      }
      final fieldData = lines.join('\n');

      final session = await _model!.createSession();
      final prompt = '$_kSystemPrompt\n\nDatos del campo:\n$fieldData';
      final response = StringBuffer();

      await for (final token in session.getResponseAsync(prompt)) {
        response.write(token);
      }
      await session.close();

      final text = response.toString().trim();
      if (text.isNotEmpty) {
        _tts.enqueueSpeech(text, 'compass_llm', SpeechPriority.normal,
            const Duration(seconds: 25));
      }
    } catch (e) {
      debugPrint('⚠️ [CompassVoice] Error LLM: $e');
      _announceFallback(nearest);
    } finally {
      isInferring = false;
      onStateChanged();
    }
  }

  void _announceFallback(CardinalDirection nearest) {
    final dirLabel = nearest.getDirectionLabel();
    final p = nearest.point!;
    final dist = nearest.distanceMeters.toStringAsFixed(0);
    final text =
        'Palma al $dirLabel: línea ${p.lineNumber}, punto ${p.pointNumber}, a $dist metros.';
    _tts.enqueueSpeech(text, 'compass_fallback', SpeechPriority.normal,
        const Duration(seconds: 25));
  }

  Future<void> dispose() async {
    await _model?.close();
    await _tts.dispose();
  }
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

  CurrentLocationDisplay? _currentLocation;
  List<CompassVirtualPoint> _virtualPoints = [];
  Map<String, CardinalDirection> _cardinalDirections = {
    'N': CardinalDirection(direction: 'N'),
    'S': CardinalDirection(direction: 'S'),
    'E': CardinalDirection(direction: 'E'),
    'O': CardinalDirection(direction: 'O'),
  };


  // Heading del dispositivo (magnetómetro + acelerómetro)
  double _deviceHeading = 0.0; // 0=Norte, 90=Este, 180=Sur, 270=Oeste
  StreamSubscription? _magnetometerSub;
  StreamSubscription? _accelerometerSub;
  double _ax = 0, _ay = 0, _az = -9.8; // últimos valores acelerómetro
  double _mx = 0, _my = 1, _mz = 0;    // últimos valores magnetómetro

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = true;
  String? _errorMessage;

  late CompassVoiceController _voiceController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _voiceController = CompassVoiceController(
      onStateChanged: () { if (mounted) setState(() {}); },
    );

    _initializeCompass();
    _initSensors();
    _voiceController.initialize();
    FFAppState().addListener(_onLocationUpdate);
  }

  @override
  void dispose() {
    _magnetometerSub?.cancel();
    _accelerometerSub?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _voiceController.dispose();
    FFAppState().removeListener(_onLocationUpdate);
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO (sin cambios)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _initializeCompass() async {
    try {
      await _loadVirtualPoints();
      await _updateCompassData();
      setState(() { _isLoading = false; });
    } catch (e) {
      debugPrint('❌ Error inicializando compass: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inicializando brújula: $e';
      });
    }
  }

  Future<void> _loadVirtualPoints() async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');

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
          vp.Description_virtual_point AS Description
        FROM Virtual_points vp
      ''';

      if (widget.idHeadquarter != null) {
        query += ' WHERE vp.Id_headquarter = ${widget.idHeadquarter}';
      }
      query += ' ORDER BY vp.Line_number, vp.Point_number';

      final List<Map<String, dynamic>> results = await database.rawQuery(query);
      await database.close();

      setState(() {
        _virtualPoints = results.map((row) => CompassVirtualPoint(
          id:          row['Id_virtual_point'] as int,
          lineNumber:  row['Line_number']  as int? ?? 0,
          pointNumber: row['Point_number'] as int? ?? 0,
          latitude:    (row['Latitude']  as num?)?.toDouble() ?? 0.0,
          longitude:   (row['Longitude'] as num?)?.toDouble() ?? 0.0,
          description: row['Description'] as String?,
        )).toList();
      });

      debugPrint('✅ Cargados ${_virtualPoints.length} puntos virtuales');
    } catch (e) {
      debugPrint('❌ Error cargando puntos virtuales: $e');
    }
  }

  void _onLocationUpdate() {
    if (mounted) _updateCompassData();
  }

  void _initSensors() {
    // Acelerómetro — guarda la última lectura de gravedad
    _accelerometerSub = accelerometerEventStream().listen((event) {
      _ax = event.x;
      _ay = event.y;
      _az = event.z;
    });

    // Magnetómetro — calcula heading tilt-compensado con cada nueva lectura
    _magnetometerSub = magnetometerEventStream().listen((event) {
      _mx = event.x;
      _my = event.y;
      _mz = event.z;
      _computeHeading();
    });
  }

  void _computeHeading() {
    // Normalizar vector de gravedad del acelerómetro
    final norm = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (norm == 0) return;
    final gx = _ax / norm;
    final gy = _ay / norm;

    // Pitch y roll a partir de la gravedad
    final pitch = math.asin(-gx);
    final cosPitch = math.cos(pitch);
    if (cosPitch.abs() < 1e-6) return; // teléfono perfectamente vertical — singularidad
    final roll = math.asin(gy / cosPitch);

    // Campo magnético compensado por inclinación
    final mx2 = _mx * math.cos(pitch) + _mz * math.sin(pitch);
    final my2 = _mx * math.sin(roll) * math.sin(pitch)
              + _my * math.cos(roll)
              - _mz * math.sin(roll) * math.cos(pitch);

    // Azimuth (0=Norte, sentido horario)
    double raw = math.atan2(-my2, mx2) * 180 / math.pi;
    if (raw < 0) raw += 360;

    // Filtro low-pass — suaviza sin perder respuesta (α = 0.18)
    double diff = raw - _deviceHeading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final smoothed = (_deviceHeading + 0.18 * diff + 360) % 360;

    // Solo repintar si el cambio supera 0.5°
    if ((smoothed - _deviceHeading).abs() > 0.5 && mounted) {
      setState(() => _deviceHeading = smoothed);
    }
  }

  String _headingLabel(double h) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    return dirs[((h + 22.5) ~/ 45) % 8];
  }

  Future<void> _updateCompassData() async {
    try {
      final geoLocations = FFAppState().geoLocationsList;

      if (geoLocations.isEmpty) {
        await _loadFromSQLite();
        return;
      }

      final lastGeo = geoLocations.last;
      setState(() {
        _currentLocation = CurrentLocationDisplay(
          latitude:  lastGeo.latitude,
          longitude: lastGeo.longitude,
          timestamp: DateTime.now(),
          battery:   null,
        );
      });

      await _calculateCardinalDirections();
    } catch (e) {
      debugPrint('❌ Error actualizando compass: $e');
    }
  }

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
            latitude:  (results[0]['Latitude']  as num?)?.toDouble() ?? 0.0,
            longitude: (results[0]['Longitude'] as num?)?.toDouble() ?? 0.0,
            timestamp: DateTime.now(),
            battery:   (results[0]['Battery']   as num?)?.toDouble(),
          );
        });
        await _calculateCardinalDirections();
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando desde SQLite: $e');
    }
  }

  Future<void> _calculateCardinalDirections() async {
    if (_currentLocation == null || _virtualPoints.isEmpty) return;

    try {
      final current = _currentLocation!;

      final pointsWithInfo = _virtualPoints.map((vp) {
        final distance = _calculateHaversineDistance(
          current.latitude, current.longitude,
          vp.latitude,      vp.longitude,
        );
        final bearing = _calculateBearing(
          current.latitude, current.longitude,
          vp.latitude,      vp.longitude,
        );
        return {'point': vp, 'distance': distance, 'bearing': bearing};
      }).toList();

      final Map<String, CardinalDirection> newDirections = {
        'N': CardinalDirection(direction: 'N'),
        'S': CardinalDirection(direction: 'S'),
        'E': CardinalDirection(direction: 'E'),
        'O': CardinalDirection(direction: 'O'),
      };

      for (var item in pointsWithInfo) {
        final bearing  = item['bearing']  as double;
        final distance = item['distance'] as double;
        final point    = item['point']    as CompassVirtualPoint;
        final dir      = _getNormalizeBearing(bearing);
        final cur      = newDirections[dir]!;

        if (cur.point == null || distance < cur.distanceMeters) {
          newDirections[dir] = CardinalDirection(
            direction:      dir,
            point:          point,
            distanceMeters: distance,
            bearing:        bearing,
          );
        }
      }

      setState(() { _cardinalDirections = newDirections; });

      // Disparar anuncio de voz si está habilitado
      if (_currentLocation != null) {
        _voiceController.announceState(newDirections, _currentLocation!);
      }

      debugPrint('🧭 Brújula actualizada: '
        'N(${newDirections['N']!.distanceMeters.toStringAsFixed(0)}m) '
        'S(${newDirections['S']!.distanceMeters.toStringAsFixed(0)}m) '
        'E(${newDirections['E']!.distanceMeters.toStringAsFixed(0)}m) '
        'O(${newDirections['O']!.distanceMeters.toStringAsFixed(0)}m)');
    } catch (e) {
      debugPrint('❌ Error calculando direcciones cardinales: $e');
    }
  }

  String _getNormalizeBearing(double bearing) {
    final normalized = ((bearing % 360) + 360) % 360;

    if (normalized >= 337.5 || normalized < 22.5)   return 'N';
    if (normalized >= 67.5  && normalized < 112.5)  return 'E';
    if (normalized >= 157.5 && normalized < 202.5)  return 'S';
    if (normalized >= 247.5 && normalized < 292.5)  return 'O';

    final distances = {
      'N': _bearingDistance(normalized, 0),
      'E': _bearingDistance(normalized, 90),
      'S': _bearingDistance(normalized, 180),
      'O': _bearingDistance(normalized, 270),
    };
    return distances.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  double _bearingDistance(double b1, double b2) {
    double diff = ((b2 - b1) % 360 + 360) % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  double _calculateHaversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371000.0;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1Rad) * math.cos(lat2Rad) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _calculateBearing(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLon    = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
              math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    return ((math.atan2(y, x) * 180 / math.pi) % 360 + 360) % 360;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI — DARK TACTICAL HUD
  // ──────────────────────────────────────────────────────────────────────────

  static const Color _kCyan   = Color(0xFF00E676); // verde brillante (accent)
  static const Color _kRed    = Color(0xFFFF3333); // rojo Norte (sin cambio)
  static const Color _kBg1    = Color(0xFF0B1F08); // verde oscuro fondo
  static const Color _kBg2    = Color(0xFF050F03); // verde muy oscuro fondo
  static const Color _kCard   = Color(0xFF0A1A07); // verde oscuro tarjeta

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    return Container(
      width:  widget.width  ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [_kBg1, _kBg2],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(child: _buildCompassCircle()),
            ),
            _buildLocationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasLocation = _currentLocation != null;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12, left: 16, right: 16),
      child: Column(
        children: [
          // Fila principal: GPS + controles de voz
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GPS status dot + label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasLocation
                            ? Color.lerp(const Color(0xFF00CC66), const Color(0xFF00FF88), _pulseAnimation.value)
                            : Colors.grey.withOpacity(0.4),
                        boxShadow: hasLocation
                            ? [BoxShadow(
                                color: const Color(0xFF00FF88).withOpacity(0.6),
                                blurRadius: 5,
                                spreadRadius: 1,
                              )]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    hasLocation ? 'GPS ACTIVO' : 'SIN SEÑAL',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: hasLocation
                          ? const Color(0xFF00FF88).withOpacity(0.8)
                          : Colors.grey.withOpacity(0.5),
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),

              // Controles de voz
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge IA o botón "DESCARGAR IA"
                  if (_voiceController.isModelReady)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_voiceController.isInferring)
                            const SizedBox(
                              width: 8, height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF10B981),
                              ),
                            )
                          else
                            Container(
                              width: 5, height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 5),
                          const Text('IA',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => context.pushNamed('ConfigVoicePage'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.5),
                          ),
                        ),
                        child: const Text('DESCARGAR IA',
                            style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Toggle VOZ ON/OFF
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _voiceController.voiceEnabled = !_voiceController.voiceEnabled;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _voiceController.voiceEnabled
                            ? const Color(0xFF00E676).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _voiceController.voiceEnabled
                              ? const Color(0xFF00E676).withOpacity(0.6)
                              : Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _voiceController.voiceEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: _voiceController.voiceEnabled
                                ? const Color(0xFF00E676)
                                : Colors.white38,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _voiceController.voiceEnabled ? 'VOZ' : 'VOZ',
                            style: TextStyle(
                              color: _voiceController.voiceEnabled
                                  ? const Color(0xFF00E676)
                                  : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
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
        ],
      ),
    );
  }

  Widget _buildCompassCircle() {
    const double compassSize = 340;

    return SizedBox(
      width:  compassSize,
      height: compassSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Todos los elementos pintados (anillos, ticks, sweep, bearing lines)
          AnimatedBuilder(
            animation: Listenable.merge([_scanController, _pulseController]),
            builder: (_, __) => CustomPaint(
              size: const Size(compassSize, compassSize),
              painter: _CompassPainter(
                directions: _cardinalDirections,
                scanAngle:  _scanController.value * 2 * math.pi,
                pulseValue: _pulseAnimation.value,
              ),
            ),
          ),

          // Tarjetas de dirección cardinal
          _buildDirectionCard('N', _cardinalDirections['N']!, 0),
          _buildDirectionCard('S', _cardinalDirections['S']!, 180),
          _buildDirectionCard('E', _cardinalDirections['E']!, 90),
          _buildDirectionCard('O', _cardinalDirections['O']!, 270),

          // Indicador de orientación del dispositivo
          _buildDeviceHeadingIndicator(),

          // Centro HUD
          _buildCenterHUD(),
        ],
      ),
    );
  }

  Widget _buildDirectionCard(
    String direction,
    CardinalDirection cardinal,
    double angleInDegrees,
  ) {
    final angleRad = angleInDegrees * math.pi / 180;
    const double radius = 135.0;

    final dx = radius * math.sin(angleRad);
    final dy = -radius * math.cos(angleRad);

    final hasPoint = cardinal.point != null;

    final Color cardColor;
    if (direction == 'N') {
      cardColor = _kRed;
    } else if (hasPoint) {
      cardColor = _kCyan;
    } else {
      cardColor = Colors.white.withOpacity(0.18);
    }

    String distanceLabel = '';
    if (hasPoint) {
      distanceLabel = cardinal.distanceMeters >= 1000
          ? '${(cardinal.distanceMeters / 1000).toStringAsFixed(1)}km'
          : '${cardinal.distanceMeters.toStringAsFixed(0)}m';
    }

    const double cardW = 80;
    const double cardH = 86;

    return Positioned(
      left: 170 + dx - cardW / 2,
      top:  170 + dy - cardH / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width:  cardW,
            height: cardH,
            decoration: BoxDecoration(
                color:        _kCard.withOpacity(0.82),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: cardColor, width: 1.2),
                boxShadow:    hasPoint
                    ? [BoxShadow(
                        color:      cardColor.withOpacity(0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    direction,
                    style: TextStyle(
                      fontFamily:  'Roboto',
                      fontSize:    20,
                      fontWeight:  FontWeight.w700,
                      color:       cardColor,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    width:  34,
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color:  cardColor.withOpacity(0.4),
                  ),
                  if (hasPoint) ...[
                    Text(
                      'L${cardinal.point!.lineNumber}P${cardinal.point!.pointNumber}',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color:      Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distanceLabel,
                      style: TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      cardColor,
                      ),
                    ),
                  ] else
                    Icon(
                      Icons.remove,
                      color: Colors.white.withOpacity(0.18),
                      size:  14,
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  /// Indicador que orbita el círculo central mostrando hacia dónde apunta el teléfono.
  /// heading=0 → arriba (Norte), heading=90 → derecha (Este), etc.
  Widget _buildDeviceHeadingIndicator() {
    const double orbitRadius = 68.0; // justo fuera del círculo central (r=48)
    const double compassCenter = 170.0; // compassSize/2
    final double rad = _deviceHeading * math.pi / 180;
    final double dx = orbitRadius * math.sin(rad);
    final double dy = -orbitRadius * math.cos(rad);

    return Positioned(
      left: compassCenter + dx - 14,
      top:  compassCenter + dy - 14,
      child: Transform.rotate(
        angle: rad, // la punta del triángulo apunta hacia el centro
        child: CustomPaint(
          size: const Size(28, 28),
          painter: _HeadingArrowPainter(),
        ),
      ),
    );
  }

  Widget _buildCenterHUD() {
    final headingDeg = _deviceHeading.toStringAsFixed(0);
    final headingCard = _headingLabel(_deviceHeading);

    return Container(
      width:  96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF183215), _kCard],
        ),
        border: Border.all(
          color: _kCyan.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:       _kCyan.withOpacity(0.12),
            blurRadius:  14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Heading del dispositivo
          Text(
            headingCard,
            style: const TextStyle(
              fontFamily:  'Roboto',
              fontSize:    14,
              fontWeight:  FontWeight.w700,
              color:       _kCyan,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            '$headingDeg°',
            style: TextStyle(
              fontFamily: 'Roboto Mono',
              fontSize:   10,
              fontWeight: FontWeight.w500,
              color:      Colors.white.withOpacity(0.55),
            ),
          ),
          Container(
            width: 28, height: 1,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: _kCyan.withOpacity(0.25),
          ),
          if (_currentLocation != null) ...[
            Text(
              _currentLocation!.formattedLatitude,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize:   7,
                color:      Colors.white.withOpacity(0.35),
              ),
            ),
            Text(
              _currentLocation!.formattedLongitude,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize:   7,
                color:      Colors.white.withOpacity(0.35),
              ),
            ),
          ] else
            Icon(Icons.my_location_rounded, color: _kCyan.withOpacity(0.5), size: 16),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    if (_currentLocation == null) return const SizedBox(height: 24);

    return Container(
      margin:   const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:        _kCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: const Color(0xFF1A3015), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded, color: _kCyan, size: 13),
          const SizedBox(width: 8),
          Text(
            _currentLocation!.formattedCoordinates,
            style: TextStyle(
              fontFamily:    'Roboto Mono',
              fontSize:      11,
              color:         Colors.white.withOpacity(0.6),
              letterSpacing: 0.4,
            ),
          ),
          if (_currentLocation!.battery != null) ...[
            Container(
              width:  1,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color:  Colors.white.withOpacity(0.15),
            ),
            Icon(
              Icons.battery_charging_full_rounded,
              color: Colors.white.withOpacity(0.4),
              size:  13,
            ),
            const SizedBox(width: 4),
            Text(
              '${_currentLocation!.battery!.toStringAsFixed(0)}%',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize:   11,
                color:      Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(colors: [_kBg1, _kBg2]),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_kCyan),
          strokeWidth: 1.5,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(colors: [_kBg1, _kBg2]),
      ),
      child: Center(
        child: Text(
          _errorMessage ?? 'Error desconocido',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER — DARK TACTICAL HUD
// ============================================================================

class _CompassPainter extends CustomPainter {
  final Map<String, CardinalDirection> directions;
  final double scanAngle;   // 0 .. 2π (desde North, sentido horario)
  final double pulseValue;  // 0 .. 1

  static const Color _cyan = Color(0xFF00E676);
  static const Color _red  = Color(0xFFFF3333);

  _CompassPainter({
    required this.directions,
    required this.scanAngle,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawConcentricRings(canvas, center);
    _drawBezelTicks(canvas, center);
    _drawScanSweep(canvas, center);
    _drawBearingLines(canvas, center);
    _drawCenterGlow(canvas, center);
  }

  // ── Anillos concéntricos ──────────────────────────────────────────────────
  void _drawConcentricRings(Canvas canvas, Offset center) {
    final p = Paint()..style = PaintingStyle.stroke;

    // Outer bezel
    canvas.drawCircle(center, 163,
      p..color = const Color(0xFF1B3519)..strokeWidth = 2.5);

    // Second ring
    canvas.drawCircle(center, 148,
      p..color = const Color(0xFF122B0E).withOpacity(0.7)..strokeWidth = 1.0);

    // Inner ring
    canvas.drawCircle(center, 110,
      p..color = const Color(0xFF183215).withOpacity(0.5)..strokeWidth = 1.0);

    // Innermost decorative ring
    canvas.drawCircle(center, 75,
      p..color = const Color(0xFF183215).withOpacity(0.35)..strokeWidth = 0.8);
  }

  // ── Marcas de grado en bezel ──────────────────────────────────────────────
  void _drawBezelTicks(Canvas canvas, Offset center) {
    const outerR = 162.0;
    final p = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    for (int i = 0; i < 72; i++) {
      // canvasAngle: 0 = right (+x). North-up: North = -π/2
      final canvasAngle = -math.pi / 2 + i * 5 * math.pi / 180;

      final bool isCardinal      = i % 18 == 0;
      final bool isIntercardinal = !isCardinal && (i % 9 == 0);

      double tickLen;
      Color  tickColor;
      double strokeW;

      if (isCardinal) {
        tickLen    = 16.0;
        strokeW    = 2.0;
        tickColor  = (i == 0) ? _red.withOpacity(0.9) : _cyan.withOpacity(0.7);
      } else if (isIntercardinal) {
        tickLen    = 10.0;
        strokeW    = 1.2;
        tickColor  = Colors.white.withOpacity(0.45);
      } else {
        tickLen    = 5.0;
        strokeW    = 0.8;
        tickColor  = Colors.white.withOpacity(0.18);
      }

      p..color = tickColor..strokeWidth = strokeW;

      final outerPt = Offset(
        center.dx + outerR * math.cos(canvasAngle),
        center.dy + outerR * math.sin(canvasAngle),
      );
      final innerPt = Offset(
        center.dx + (outerR - tickLen) * math.cos(canvasAngle),
        center.dy + (outerR - tickLen) * math.sin(canvasAngle),
      );

      canvas.drawLine(innerPt, outerPt, p);
    }
  }

  // ── Sweep de escaneo tipo radar ───────────────────────────────────────────
  void _drawScanSweep(Canvas canvas, Offset center) {
    const innerR   = 50.0;
    const outerR   = 148.0;
    const sweepRad = 50.0 * math.pi / 180; // 50°

    // North-up convention: North = -π/2 in canvas
    final startAngle = -math.pi / 2 + scanAngle;
    final endAngle   = startAngle + sweepRad;

    // Annular sector path
    final sweepPath = Path()
      ..moveTo(
        center.dx + innerR * math.cos(startAngle),
        center.dy + innerR * math.sin(startAngle),
      )
      ..lineTo(
        center.dx + outerR * math.cos(startAngle),
        center.dy + outerR * math.sin(startAngle),
      )
      ..arcTo(Rect.fromCircle(center: center, radius: outerR),
              startAngle, sweepRad, false)
      ..lineTo(
        center.dx + innerR * math.cos(endAngle),
        center.dy + innerR * math.sin(endAngle),
      )
      ..arcTo(Rect.fromCircle(center: center, radius: innerR),
              endAngle, -sweepRad, false)
      ..close();

    // Sweep fill — gradient transparent → cyan
    canvas.drawPath(sweepPath, Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [Colors.transparent, _cyan.withOpacity(0.11)],
        [0.0, 1.0],
        TileMode.clamp,
        startAngle,
        endAngle,
      )
      ..style = PaintingStyle.fill);

    // Leading edge bright line
    canvas.drawLine(
      Offset(center.dx + innerR * math.cos(endAngle), center.dy + innerR * math.sin(endAngle)),
      Offset(center.dx + outerR * math.cos(endAngle), center.dy + outerR * math.sin(endAngle)),
      Paint()
        ..color = _cyan.withOpacity(0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Líneas bearing con glow ───────────────────────────────────────────────
  void _drawBearingLines(Canvas canvas, Offset center) {
    const innerR         = 55.0;
    const outerR         = 142.0;
    const arrowSize      = 9.0;
    const arrowHalfAngle = 0.42;

    const cardinalAngles = {
      'N':   0.0,
      'E':  90.0,
      'S': 180.0,
      'O': 270.0,
    };

    cardinalAngles.forEach((dir, angleDeg) {
      final cardinal = directions[dir];
      if (cardinal == null || cardinal.point == null) return;

      final lineColor  = (dir == 'N') ? _red : _cyan;
      final canvasAngle = -math.pi / 2 + angleDeg * math.pi / 180;

      final startPt = Offset(
        center.dx + innerR * math.cos(canvasAngle),
        center.dy + innerR * math.sin(canvasAngle),
      );
      final endPt = Offset(
        center.dx + outerR * math.cos(canvasAngle),
        center.dy + outerR * math.sin(canvasAngle),
      );

      // Glow halo
      canvas.drawLine(startPt, endPt, Paint()
        ..color       = lineColor.withOpacity(0.10 + pulseValue * 0.08)
        ..strokeWidth = 7
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round);

      // Gradient line (transparent at center → color at tip)
      canvas.drawLine(startPt, endPt, Paint()
        ..shader = ui.Gradient.linear(startPt, endPt, [Colors.transparent, lineColor])
        ..strokeWidth = 2.0
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round);

      // Filled arrowhead at endPt (pointing outward)
      final wing1 = Offset(
        endPt.dx + arrowSize * math.cos(canvasAngle + math.pi - arrowHalfAngle),
        endPt.dy + arrowSize * math.sin(canvasAngle + math.pi - arrowHalfAngle),
      );
      final wing2 = Offset(
        endPt.dx + arrowSize * math.cos(canvasAngle + math.pi + arrowHalfAngle),
        endPt.dy + arrowSize * math.sin(canvasAngle + math.pi + arrowHalfAngle),
      );

      canvas.drawPath(
        Path()
          ..moveTo(endPt.dx, endPt.dy)
          ..lineTo(wing1.dx, wing1.dy)
          ..lineTo(wing2.dx, wing2.dy)
          ..close(),
        Paint()..color = lineColor..style = PaintingStyle.fill,
      );
    });
  }

  // ── Glow radial en el centro ──────────────────────────────────────────────
  void _drawCenterGlow(Canvas canvas, Offset center) {
    const glowR = 52.0;
    canvas.drawCircle(center, glowR, Paint()
      ..shader = ui.Gradient.radial(
        center,
        glowR,
        [_cyan.withOpacity(0.09), Colors.transparent],
      )
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.directions  != directions  ||
      old.scanAngle   != scanAngle   ||
      old.pulseValue  != pulseValue;
}

// ============================================================================
// PAINTER DEL INDICADOR DE ORIENTACIÓN DEL DISPOSITIVO
// Dibuja una flecha/diamante luminoso que apunta hacia el centro del compass.
// El widget padre lo rota según el heading → la punta siempre apunta al centro.
// ============================================================================

class _HeadingArrowPainter extends CustomPainter {
  static const Color _cyan = Color(0xFF00E676);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Triángulo: vértice superior (punta hacia centro cuando angle=0) + base inferior
    final tip    = Offset(cx, cy - 11);   // punta que apunta al centro
    final baseL  = Offset(cx - 6, cy + 5);
    final baseR  = Offset(cx + 6, cy + 5);
    final baseM  = Offset(cx, cy + 9);    // muesca en la base (efecto chevron)

    final arrowPath = Path()
      ..moveTo(tip.dx,   tip.dy)
      ..lineTo(baseL.dx, baseL.dy)
      ..lineTo(baseM.dx, baseM.dy)
      ..lineTo(baseR.dx, baseR.dy)
      ..close();

    // Halo glow exterior
    canvas.drawPath(arrowPath, Paint()
      ..color = _cyan.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.fill);

    // Relleno sólido
    canvas.drawPath(arrowPath, Paint()
      ..color = _cyan
      ..style = PaintingStyle.fill);

    // Borde fino más brillante
    canvas.drawPath(arrowPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_HeadingArrowPainter old) => false;
}
