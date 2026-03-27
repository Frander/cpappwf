// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

// ============================================================================
// MODELO DE DATOS GPS
// ============================================================================

class GPSPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double horizontalError;
  final DateTime createdAt;
  final int battery;

  GPSPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.horizontalError,
    required this.createdAt,
    required this.battery,
  });

  factory GPSPoint.fromMap(Map<String, dynamic> map) {
    return GPSPoint(
      latitude: (map['Latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['Longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['Altitude'] as num?)?.toDouble() ?? 0.0,
      horizontalError: (map['HorizontalError'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
      battery: (map['Battery'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================================
// MENSAJES DINÁMICOS PARA LA ESPERA
// ============================================================================

class _DynamicMessages {
  static const List<String> waitingMessages = [
    'Conectando con satélites GPS...',
    'Triangulando tu posición...',
    'Optimizando precisión de coordenadas...',
    'Sincronizando señal GPS...',
    'Calibrando ubicación exacta...',
    'Procesando datos de geolocalización...',
    'Verificando precisión del GPS...',
    'Obteniendo coordenadas de alta precisión...',
  ];

  static const List<String> tips = [
    '💡 Mantén el dispositivo en un lugar abierto',
    '💡 Evita estar cerca de edificios altos',
    '💡 El cielo despejado mejora la señal',
    '💡 Mantén el GPS activado',
    '💡 La primera lectura puede tardar más',
    '💡 Mejor precisión en exteriores',
  ];

  static String getRandomMessage() {
    final random = math.Random();
    return waitingMessages[random.nextInt(waitingMessages.length)];
  }

  static String getRandomTip() {
    final random = math.Random();
    return tips[random.nextInt(tips.length)];
  }
}

// ============================================================================
// WIDGET PRINCIPAL - CARGA DE COORDENADAS PARA VISITA
// ============================================================================

class LoadCoordinatesVisit extends StatefulWidget {
  const LoadCoordinatesVisit({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<LoadCoordinatesVisit> createState() => _LoadCoordinatesVisitState();
}

class _LoadCoordinatesVisitState extends State<LoadCoordinatesVisit>
    with TickerProviderStateMixin {
  // Contador
  int _countdown = 5;
  Timer? _countdownTimer;
  Timer? _messageTimer;

  // Estado
  bool _isWaiting = false;
  bool _isProcessing = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _statusMessage = '';
  String _errorMessage = '';
  String _dynamicMessage = _DynamicMessages.getRandomMessage();
  String _currentTip = _DynamicMessages.getRandomTip();

  // GPS Points
  List<GPSPoint> _gpsPoints = [];
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;

  // Filtro de precisión GPS
  static const double _maxHorizontalError = 10.0;
  static const int _maxWaitTimeSeconds = 40;
  static const int _retryIntervalSeconds = 2;

  // Progreso visual
  int _elapsedSeconds = 0;
  int _validPoints = 0;
  double _finalHorizontalError = 0.0;
  double _currentBestError = 0.0;

  // Modo de entrada manual
  bool _showManualInput = false;
  String? _manualError;
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  // Modo de rendimiento - detectado automáticamente basado en refresh rate
  late bool _isLowPerformanceMode;

  // Animaciones esenciales (siempre activas)
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;
  late AnimationController _radarController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _radarAnimation;

  // Animaciones opcionales (solo en modo alto rendimiento)
  AnimationController? _particleController;
  AnimationController? _glowController;

  // Colores de la paleta verde oscuro
  static const Color _darkGreen1 = Color(0xFF003420);
  static const Color _darkGreen2 = Color(0xFF002415);
  static const Color _darkGreen3 = Color(0xFF00150A);
  static const Color _accentGreen = Color(0xFF00a86b);
  static const Color _brightGreen = Color(0xFF00ff9f);
  static const Color _successGreen = Color(0xFF00D9A5);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startCountdown();
    _startMessageRotation();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _messageTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    _radarController.dispose();
    _particleController?.dispose();
    _glowController?.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Detectar modo de rendimiento basado en la memoria del dispositivo
    // En dispositivos de gama baja, reducimos animaciones
    _isLowPerformanceMode = _detectLowPerformanceMode();

    // Animación de pulso - ESENCIAL (más lenta en modo bajo rendimiento)
    _pulseController = AnimationController(
      duration: Duration(milliseconds: _isLowPerformanceMode ? 2000 : 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación - ESENCIAL (más lenta en modo bajo rendimiento)
    _rotateController = AnimationController(
      duration: Duration(milliseconds: _isLowPerformanceMode ? 5000 : 3000),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Animación de escala - ESENCIAL
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Animación de radar - ESENCIAL (reducida en modo bajo rendimiento)
    _radarController = AnimationController(
      duration: Duration(milliseconds: _isLowPerformanceMode ? 3000 : 2000),
      vsync: this,
    )..repeat();

    _radarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );

    // Animaciones OPCIONALES - solo en modo alto rendimiento
    if (!_isLowPerformanceMode) {
      // Animación de partículas
      _particleController = AnimationController(
        duration: const Duration(milliseconds: 4000),
        vsync: this,
      )..repeat();

      // Animación de glow
      _glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat(reverse: true);
    }
  }

  /// Detecta si el dispositivo es de bajo rendimiento
  bool _detectLowPerformanceMode() {
    // Usar el tamaño de la pantalla como indicador aproximado
    // Dispositivos pequeños o con poca RAM típicamente tienen pantallas más pequeñas
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final devicePixelRatio = window.devicePixelRatio;
    final physicalSize = window.physicalSize;

    // Si el dispositivo tiene baja densidad de píxeles o pantalla pequeña,
    // probablemente es de gama media/baja
    final screenDiagonal = math.sqrt(
      math.pow(physicalSize.width / devicePixelRatio, 2) +
      math.pow(physicalSize.height / devicePixelRatio, 2)
    );

    // Dispositivos con pantalla < 5.5" o densidad < 2.5 se consideran de bajo rendimiento
    // También activamos modo bajo si la densidad es muy alta (> 3.5) ya que eso significa
    // más píxeles que renderizar
    return devicePixelRatio < 2.0 || devicePixelRatio > 3.5 || screenDiagonal < 600;
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && (_isWaiting || _countdown > 0)) {
        setState(() {
          _dynamicMessage = _DynamicMessages.getRandomMessage();
          _currentTip = _DynamicMessages.getRandomTip();
        });
      }
    });
  }

  void _startCountdown() {
    _scaleController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
          _checkGPSPoints();
        }
      });
    });
  }

  Future<void> _checkGPSPoints() async {
    debugPrint('🌐🌐🌐 ========================================');
    debugPrint('🌐🌐🌐 INICIO DE _checkGPSPoints()');
    debugPrint('🌐🌐🌐 ========================================');

    setState(() {
      _isWaiting = true;
      _statusMessage = 'Obteniendo coordenadas GPS precisas...';
      _elapsedSeconds = 0;
    });

    debugPrint('🔍 Estado cambiado: _isWaiting = true');

    try {
      final startTime = DateTime.now();
      int attemptNumber = 0;

      while (true) {
        attemptNumber++;
        final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        setState(() {
          _elapsedSeconds = elapsedSeconds;
        });

        if (elapsedSeconds >= _maxWaitTimeSeconds) {
          debugPrint('⏱️ Timeout de $_maxWaitTimeSeconds segundos alcanzado.');
          break;
        }

        final geoLocationsList = FFAppState().geoLocationsList;
        debugPrint('📍 [Intento $attemptNumber] Puntos GPS en AppState: ${geoLocationsList.length}');

        if (geoLocationsList.isNotEmpty) {
          final battery = Battery();
          int batteryLevel = 100;
          try {
            batteryLevel = await battery.batteryLevel;
          } catch (e) {
            debugPrint('⚠️ No se pudo obtener nivel de batería: $e');
          }

          final allPoints = geoLocationsList.map((geoStruct) {
            return GPSPoint(
              latitude: geoStruct.latitude,
              longitude: geoStruct.longitude,
              altitude: geoStruct.altitude,
              horizontalError: geoStruct.errorHorizontal,
              createdAt: geoStruct.dateHourRead ?? DateTime.now().toUtc(),
              battery: batteryLevel,
            );
          }).toList();

          _gpsPoints = allPoints
              .where((point) => point.horizontalError <= _maxHorizontalError)
              .toList();

          setState(() {
            _validPoints = _gpsPoints.length;
            if (_gpsPoints.isNotEmpty) {
              _currentBestError = _gpsPoints.map((p) => p.horizontalError).reduce((a, b) => a < b ? a : b);
            }
          });

          if (_gpsPoints.length >= 1) {
            debugPrint('✅ Suficientes puntos precisos obtenidos (${_gpsPoints.length} >= 1)');
            debugPrint('📍 RUTA 1: Llamando _createVisit() desde AppState geoLocationsList...');
            await _createVisit();
            return;
          }

          setState(() {
            _statusMessage = 'Esperando señal GPS precisa...';
          });

          await Future.delayed(const Duration(seconds: _retryIntervalSeconds));
          if (!mounted) return;
          continue;
        } else {
          setState(() {
            _statusMessage = 'Buscando señal GPS...';
          });

          await Future.delayed(const Duration(seconds: _retryIntervalSeconds));
          if (!mounted) return;
          continue;
        }
      }

      // Estrategia 2: SQLite
      debugPrint('⚠️ Timeout alcanzado, intentando SQLite...');

      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');

      final database = await openDatabase(dbPath);

      final List<Map<String, dynamic>> results = await database.rawQuery('''
        SELECT Latitude, Longitude, Altitude, HorizontalError, Battery, CreatedAt
        FROM Location_tracking
        WHERE HorizontalError <= ?
        ORDER BY CreatedAt DESC
        LIMIT 8
      ''', [_maxHorizontalError]);

      await database.close();

      final allPointsFromDB = results.map((row) => GPSPoint.fromMap(row)).toList();
      _gpsPoints = allPointsFromDB
          .where((point) => point.horizontalError <= _maxHorizontalError)
          .toList();

      setState(() {
        _validPoints = _gpsPoints.length;
        if (_gpsPoints.isNotEmpty) {
          _currentBestError = _gpsPoints.map((p) => p.horizontalError).reduce((a, b) => a < b ? a : b);
        }
      });

      if (_gpsPoints.length >= 2) {
        debugPrint('✅ Usando puntos de SQLite');
        debugPrint('📍 RUTA 2: Llamando _createVisit() desde SQLite Location_tracking...');
        await _createVisit();
      } else {
        _retryAttempts++;

        if (_retryAttempts >= _maxRetryAttempts) {
          debugPrint('⚠️ Usando fallback de geolocator...');
          setState(() {
            _statusMessage = 'Obteniendo GPS directo del dispositivo...';
          });
          await _getGPSFromGeolocator();
          return;
        }

        setState(() {
          _statusMessage = 'Reintentando obtener coordenadas...';
        });

        _countdown = 5;
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() {
            _isWaiting = false;
          });
          _startCountdown();
        }
      }
    } catch (e) {
      debugPrint('❌ Error verificando puntos GPS: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al obtener coordenadas GPS:\n$e';
        _isWaiting = false;
      });
    }
  }

  Future<void> _getGPSFromGeolocator() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('El servicio de ubicación está deshabilitado.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente.');
      }

      final battery = Battery();
      int batteryLevel = 100;
      try {
        batteryLevel = await battery.batteryLevel;
      } catch (e) {
        debugPrint('⚠️ No se pudo obtener nivel de batería: $e');
      }

      setState(() {
        _statusMessage = 'Obteniendo GPS de alta precisión...';
      });

      _gpsPoints.clear();
      List<GPSPoint> allAttempts = [];

      for (int i = 0; i < 5; i++) {
        try {
          debugPrint('📍 Obteniendo punto GPS ${i + 1}/5...');

          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

          final gpsPoint = GPSPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            altitude: position.altitude,
            horizontalError: position.accuracy,
            createdAt: DateTime.now().toUtc(),
            battery: batteryLevel,
          );

          allAttempts.add(gpsPoint);

          if (position.accuracy <= _maxHorizontalError) {
            _gpsPoints.add(gpsPoint);
            setState(() {
              _validPoints = _gpsPoints.length;
              _currentBestError = _gpsPoints.map((p) => p.horizontalError).reduce((a, b) => a < b ? a : b);
            });

            if (_gpsPoints.length >= 2) {
              break;
            }
          }

          if (i < 4 && _gpsPoints.length < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          debugPrint('⚠️ Error obteniendo punto GPS ${i + 1}: $e');
        }
      }

      if (_gpsPoints.isEmpty) {
        if (allAttempts.isNotEmpty) {
          throw Exception(
              'No se pudo obtener señal GPS con precisión requerida (≤${_maxHorizontalError}m)');
        } else {
          throw Exception('No se pudieron obtener coordenadas GPS del dispositivo.');
        }
      }

      if (_gpsPoints.length == 1) {
        final originalPoint = _gpsPoints.first;
        _gpsPoints.add(GPSPoint(
          latitude: originalPoint.latitude,
          longitude: originalPoint.longitude,
          altitude: originalPoint.altitude,
          horizontalError: originalPoint.horizontalError,
          createdAt: DateTime.now().toUtc(),
          battery: originalPoint.battery,
        ));
      }

      debugPrint('📍 RUTA 3: Llamando _createVisit() desde fallback Geolocator...');
      await _createVisit();
    } catch (e) {
      debugPrint('❌ Error en fallback de geolocator: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al obtener coordenadas GPS:\n\n$e';
        _isWaiting = false;
      });
    }
  }

  Future<void> _createVisit() async {
    debugPrint('🚀🚀🚀 ============================================');
    debugPrint('🚀🚀🚀 INICIO DE _createVisit() - FUNCIÓN LLAMADA');
    debugPrint('🚀🚀🚀 ============================================');

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Guardando visita...';
    });

    debugPrint('🔍 Estado cambiado: _isProcessing = true');

    try {
      debugPrint('🔍 Obteniendo datos de FFAppState...');
      final deviceDefault = FFAppState().deviceDefault;
      final userSelected = FFAppState().userSelected;
      final activitySelectedJSON = FFAppState().activitySelectedJSON;
      final visitDetails = FFAppState().visitDetails;
      debugPrint('✅ Datos de FFAppState obtenidos exitosamente');

      // PRIORIDAD 1: Usar activitySelected (struct que se persiste correctamente)
      final activitySelected = FFAppState().activitySelected;
      int idActivity = activitySelected.idActivity;

      debugPrint('🔍 activitySelected.idActivity: $idActivity');
      debugPrint('🔍 activitySelected.nameActivity: ${activitySelected.nameActivity}');

      // PRIORIDAD 2: Si activitySelected no tiene ID, intentar con activitySelectedJSON
      if (idActivity == 0 && activitySelectedJSON != null) {
        debugPrint('🔍 Intentando con activitySelectedJSON...');
        debugPrint('🔍 activitySelectedJSON tipo: ${activitySelectedJSON.runtimeType}');

        try {
          dynamic activityData;

          if (activitySelectedJSON is String && activitySelectedJSON.isNotEmpty) {
            activityData = jsonDecode(activitySelectedJSON);
          } else if (activitySelectedJSON is Map) {
            activityData = activitySelectedJSON;
          } else {
            activityData = activitySelectedJSON;
          }

          if (activityData != null && activityData is Map) {
            idActivity = (activityData['id_activity'] as num?)?.toInt() ?? 0;
          }

          // Intentar acceso dinámico si aún es 0
          if (idActivity == 0 && activityData != null) {
            try {
              final dynamic idValue = activityData['id_activity'];
              if (idValue is int) {
                idActivity = idValue;
              } else if (idValue is double) {
                idActivity = idValue.toInt();
              } else if (idValue is String) {
                idActivity = int.tryParse(idValue) ?? 0;
              }
            } catch (e) {
              debugPrint('⚠️ Error accediendo a id_activity desde JSON: $e');
            }
          }

          debugPrint('🔍 idActivity desde JSON: $idActivity');
        } catch (e) {
          debugPrint('⚠️ Error parseando activitySelectedJSON: $e');
        }
      }

      debugPrint('🔍 idActivity final: $idActivity');

      if (deviceDefault.idDevice == 0) {
        throw Exception('ID de dispositivo no encontrado');
      }
      if (userSelected.idUser == 0) {
        throw Exception('ID de usuario no encontrado');
      }
      if (idActivity == 0) {
        throw Exception('ID de actividad no encontrado');
      }

      final mainGPSPoint = _gpsPoints.first;

      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');

      final database = await openDatabase(dbPath);

      // Obtener el Id_headquarter del lote actual
      // Prioridad 1: Usar el primer lote de headquartersSelectedList
      int idHeadquarter = 0;
      final headquartersList = FFAppState().headquartersSelectedList;

      if (headquartersList.isNotEmpty) {
        idHeadquarter = headquartersList.first.idHeadquarter;
        debugPrint('✅ Usando lote: ${headquartersList.first.nameHeadquarter} (ID: $idHeadquarter)');
      } else {
        debugPrint('⚠️ No hay lotes seleccionados, Id_headquarter será 0');
      }

      int visitId = 0;
      await database.transaction((txn) async {
        visitId = await txn.rawInsert('''
          INSERT INTO Visits (
            Id_company, Id_activity, Id_headquarter, Id_product, Id_bulk,
            Id_user, Id_device, Id_status, Created_at, Battery,
            Latitude, Longitude, Altitude, Error_horizontal, Id_virtual_point, Status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          userSelected.idCompany, idActivity, idHeadquarter, 0, 0,
          userSelected.idUser, deviceDefault.idDevice, 0,
          DateTime.now().toIso8601String(), mainGPSPoint.battery,
          mainGPSPoint.latitude, mainGPSPoint.longitude, mainGPSPoint.altitude,
          mainGPSPoint.horizontalError, null, 0,
        ]);

        debugPrint('✅ Visita creada con ID: $visitId');

        final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();
        int insertedCount = 0;

        for (var detail in detailsToInsert) {
          final idActivityStatus = detail.idActivityStatus;

          final statusCheck = await txn.rawQuery('''
            SELECT Id_activity_status FROM Activities_status WHERE Id_activity_status = ?
          ''', [idActivityStatus]);

          if (statusCheck.isEmpty) continue;

          await txn.rawInsert('''
            INSERT INTO Visits_details (Id_visit, Id_activity_status, Status_option, Status_response)
            VALUES (?, ?, ?, ?)
          ''', [visitId, idActivityStatus, detail.statusOption, detail.statusResponse]);

          insertedCount++;
        }

        debugPrint('✅ $insertedCount detalles de visita insertados');

        final now = DateTime.now().toUtc();
        final sixSecondsAgo = now.subtract(const Duration(seconds: 6));
        final recentPoints = _gpsPoints
            .where((point) => point.createdAt.isAfter(sixSecondsAgo))
            .toList();
        recentPoints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final pointsToSave = recentPoints.take(10).toList();

        for (var gpsPoint in pointsToSave) {
          await txn.rawInsert('''
            INSERT INTO Visits_locations (Id_visit, Latitude, Longitude, Altitude, HorizontalError, CreatedAt)
            VALUES (?, ?, ?, ?, ?, ?)
          ''', [
            visitId, gpsPoint.latitude, gpsPoint.longitude, gpsPoint.altitude,
            gpsPoint.horizontalError, gpsPoint.createdAt.toIso8601String(),
          ]);
        }

        debugPrint('✅ ${pointsToSave.length} ubicaciones GPS insertadas');
      });

      await database.close();

      FFAppState().update(() {
        FFAppState().visitCount = FFAppState().visitCount + 1;
        FFAppState().visitDetails = removeVisits(FFAppState().visitDetails);
      });

      setState(() {
        _isProcessing = false;
        _isComplete = true;
        _finalHorizontalError = mainGPSPoint.horizontalError;
        _statusMessage = 'ID: $visitId\nCoordenadas: ${_gpsPoints.length} puntos';
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error creando visita: $e');
      setState(() {
        _isProcessing = false;
        _hasError = true;
        _errorMessage = 'Error al crear la visita:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: widget.width ?? screenWidth,
      height: widget.height ?? screenHeight * 0.92, // Ocupa 92% del alto
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkGreen1, _darkGreen2, _darkGreen3],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accentGreen.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          child: _hasError
              ? _buildErrorScreen()
              : _isComplete
                  ? _buildSuccessScreen()
                  : _isProcessing
                      ? _buildProcessingScreen()
                      : _showManualInput
                          ? _buildManualInputScreen()
                          : _isWaiting
                              ? _buildWaitingScreen()
                              : _buildCountdownScreen(),
        ),
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE CONTADOR - DISEÑO EXTREMO
  // ==========================================================================

  Widget _buildCountdownScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 600;
        final isVeryCompact = availableHeight < 500;

        return Stack(
          children: [
            // Partículas flotantes de fondo - SOLO en modo alto rendimiento
            if (!_isLowPerformanceMode)
              ...List.generate(8, (index) => _buildFloatingParticle(index)),

            // Contenido principal adaptativo
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isVeryCompact ? 8 : (isCompact ? 16 : 24),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableHeight - (isVeryCompact ? 16 : (isCompact ? 32 : 48)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Título con glassmorphism
                        _buildGlassTitle('Preparando Visita'),

                        SizedBox(height: isVeryCompact ? 8 : 16),

                        // Contador circular con radar y ondas - se adapta al espacio
                        _buildAnimatedCounter(isCompact: isCompact),

                        SizedBox(height: isVeryCompact ? 6 : 10),

                        // Botón VISITA MANUAL (siempre visible bajo el contador)
                        _buildManualButton(),

                        SizedBox(height: isVeryCompact ? 8 : 16),

                        // Mensaje dinámico
                        _buildDynamicMessageCard(),

                        SizedBox(height: isVeryCompact ? 6 : (isCompact ? 12 : 20)),

                        // Tip animado
                        if (!isVeryCompact) _buildAnimatedTip(),

                        SizedBox(height: isVeryCompact ? 8 : 16),

                        // PIN de ubicación animado
                        _buildAnimatedLocationPin(isCompact: isCompact),

                        SizedBox(height: isVeryCompact ? 4 : (isCompact ? 8 : 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // BOTÓN VISITA MANUAL
  // ==========================================================================

  Widget _buildManualButton() {
    return GestureDetector(
      onTap: () {
        _countdownTimer?.cancel();
        _messageTimer?.cancel();
        setState(() {
          _showManualInput = true;
          _manualError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_location_alt_outlined,
                color: Color(0xFF94A3B8), size: 14),
            SizedBox(width: 6),
            Text(
              'VISITA MANUAL',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE ENTRADA MANUAL DE COORDENADAS
  // ==========================================================================

  Widget _buildManualInputScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          Row(
            children: [
              const Icon(Icons.edit_location_alt_outlined,
                  color: Color(0xFF60A5FA), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ubicación manual',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showManualInput = false;
                    _manualError = null;
                    _latController.clear();
                    _lonController.clear();
                  });
                  _startCountdown();
                  _startMessageRotation();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      color: Color(0xFF94A3B8), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa las coordenadas para registrar la visita',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 28),

          // Campo Latitud
          TextField(
            controller: _latController,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Latitud',
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              hintText: 'Ej: 5.07285',
              hintStyle:
                  const TextStyle(color: Color(0xFF475569), fontSize: 13),
              prefixIcon: const Icon(Icons.north_outlined,
                  color: Color(0xFF60A5FA), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF60A5FA))),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Campo Longitud
          TextField(
            controller: _lonController,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Longitud',
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              hintText: 'Ej: -75.53112',
              hintStyle:
                  const TextStyle(color: Color(0xFF475569), fontSize: 13),
              prefixIcon: const Icon(Icons.east_outlined,
                  color: Color(0xFF60A5FA), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF60A5FA))),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            onSubmitted: (_) => _confirmManualCoords(),
          ),

          if (_manualError != null) ...[
            const SizedBox(height: 8),
            Text(
              _manualError!,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Botón confirmar
          ElevatedButton(
            onPressed: _confirmManualCoords,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00a86b),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Confirmar ubicación',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmManualCoords() {
    final lat = double.tryParse(
        _latController.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(
        _lonController.text.trim().replaceAll(',', '.'));

    if (lat == null || lon == null ||
        lat < -90 || lat > 90 ||
        lon < -180 || lon > 180) {
      setState(() {
        _manualError = 'Ingresa coordenadas válidas (lat ±90, lon ±180)';
      });
      return;
    }

    _gpsPoints = [
      GPSPoint(
        latitude: lat,
        longitude: lon,
        altitude: 0.0,
        horizontalError: 0.5,
        createdAt: DateTime.now().toUtc(),
        battery: 100,
      ),
    ];

    _createVisit();
  }

  Widget _buildFloatingParticle(int index) {
    // Solo construir si el controller existe (modo alto rendimiento)
    if (_particleController == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = 3.0 + random.nextDouble() * 4;
    final startX = random.nextDouble();

    return AnimatedBuilder(
      animation: _particleController!,
      builder: (context, child) {
        final progress = (_particleController!.value + index * 0.05) % 1.0;
        return Positioned(
          left: MediaQuery.of(context).size.width * startX,
          top: MediaQuery.of(context).size.height * (1 - progress),
          child: Opacity(
            opacity: (1 - progress) * 0.5,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brightGreen.withValues(alpha: 0.4),
                // Sin boxShadow para mejor rendimiento
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassTitle(String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        return ClipRRect(
          borderRadius: BorderRadius.circular(isNarrow ? 18 : 24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 20 : 40,
                vertical: isNarrow ? 12 : 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accentGreen.withValues(alpha: 0.25),
                    _brightGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(isNarrow ? 18 : 24),
                border: Border.all(
                  color: _brightGreen.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentGreen.withValues(alpha: 0.3),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.satellite_alt, color: _brightGreen, size: isNarrow ? 22 : 28),
                  SizedBox(width: isNarrow ? 10 : 14),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: isNarrow ? 18 : 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedCounter({bool isCompact = false}) {
    final size = isCompact ? 220.0 : 280.0;
    final innerSize = isCompact ? 140.0 : 180.0;
    final fontSize = isCompact ? 56.0 : 72.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ondas de radar expandiéndose
            ...List.generate(3, (index) {
              final radarBaseSize = isCompact ? 150.0 : 200.0;
              final radarExpand = isCompact ? 60.0 : 80.0;
              return AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  final delay = index * 0.33;
                  final progress = (_radarAnimation.value + delay) % 1.0;
                  return Container(
                    width: radarBaseSize + (progress * radarExpand),
                    height: radarBaseSize + (progress * radarExpand),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _brightGreen.withValues(alpha: (1 - progress) * 0.5),
                        width: 2,
                      ),
                    ),
                  );
                },
              );
            }),

            // Anillo giratorio exterior
            RotationTransition(
              turns: _rotateAnimation,
              child: Container(
                width: isCompact ? 190.0 : 240.0,
                height: isCompact ? 190.0 : 240.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      _accentGreen.withValues(alpha: 0.3),
                      _brightGreen.withValues(alpha: 0.6),
                      _accentGreen.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Círculo de fondo con glow - versión simplificada en modo bajo rendimiento
            if (_glowController != null)
              AnimatedBuilder(
                animation: _glowController!,
                builder: (context, child) {
                  final glowSize = isCompact ? 160.0 : 200.0;
                  final glowValue = _glowController!.value;
                  return Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _accentGreen.withValues(alpha: 0.2 * glowValue),
                          _darkGreen1.withValues(alpha: 0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _brightGreen.withValues(alpha: 0.2 * glowValue),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              // Versión estática para modo bajo rendimiento
              Container(
                width: isCompact ? 160.0 : 200.0,
                height: isCompact ? 160.0 : 200.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentGreen.withValues(alpha: 0.15),
                      _darkGreen1.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

            // Círculo principal con contador
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_accentGreen, Color(0xFF006644)],
                  ),
                  border: Border.all(
                    color: _brightGreen.withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentGreen.withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'segundos',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: isCompact ? 12.0 : 14.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Indicador de progreso circular
            SizedBox(
              width: 260,
              height: 260,
              child: CircularProgressIndicator(
                value: (5 - _countdown) / 5,
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _brightGreen.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicMessageCard() {
    return AnimatedSwitcher(
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
      child: ClipRRect(
        key: ValueKey(_dynamicMessage),
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _brightGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_brightGreen),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _dynamicMessage,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTip() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: Container(
        key: ValueKey(_currentTip),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: _accentGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _accentGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          _currentTip,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _buildAnimatedLocationPin({bool isCompact = false}) {
    final baseSize = isCompact ? 60.0 : 80.0;
    final expandSize = isCompact ? 30.0 : 40.0;
    final glowSize = isCompact ? 54.0 : 70.0;
    final pinSize = isCompact ? 44.0 : 56.0;
    final iconSize = isCompact ? 22.0 : 28.0;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Onda de expansión - usa radarController (reutilizado)
              if (!_isLowPerformanceMode)
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    final waveValue = _radarAnimation.value;
                    return Container(
                      width: baseSize + (waveValue * expandSize),
                      height: baseSize + (waveValue * expandSize),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: (1 - waveValue) * 0.4),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              // Glow - simplificado
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.redAccent.withValues(alpha: 0.3),
                      Colors.redAccent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Pin
              Container(
                width: pinSize,
                height: pinSize,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _isLowPerformanceMode ? null : [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: isCompact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              'Tu ubicación',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: isCompact ? 10 : 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE ESPERA - DISEÑO EXTREMO
  // ==========================================================================

  Widget _buildWaitingScreen() {
    final progress = _elapsedSeconds / _maxWaitTimeSeconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 600;

        return Stack(
          children: [
            // Partículas
            ...List.generate(15, (index) => _buildFloatingParticle(index)),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isCompact ? 16 : 24,
              ),
              child: Column(
                children: [
                  // Espacio flexible superior
                  const Spacer(flex: 1),

                  // Icono de satélite con radar
                  _buildSatelliteRadar(isCompact: isCompact),

                  SizedBox(height: isCompact ? 16 : 25),

                  // Barra de progreso circular grande
                  _buildCircularProgressWithInfo(progress, isCompact: isCompact),

                  SizedBox(height: isCompact ? 14 : 20),

                  // Card de estado con glassmorphism
                  _buildStatusCard(),

                  SizedBox(height: isCompact ? 10 : 16),

                  // Tip animado
                  _buildAnimatedTip(),

                  // Espacio flexible inferior
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSatelliteRadar({bool isCompact = false}) {
    final containerSize = isCompact ? 110.0 : 140.0;
    final radarBase = isCompact ? 45.0 : 60.0;
    final radarExpand = isCompact ? 60.0 : 80.0;
    final centerSize = isCompact ? 70.0 : 90.0;
    final iconSize = isCompact ? 35.0 : 45.0;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ondas de radar
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                final delay = index * 0.33;
                final progress = (_radarAnimation.value + delay) % 1.0;
                return Container(
                  width: radarBase + (progress * radarExpand),
                  height: radarBase + (progress * radarExpand),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _brightGreen.withValues(alpha:(1 - progress) * 0.6),
                      width: 2,
                    ),
                  ),
                );
              },
            );
          }),

          // Círculo central con icono
          RotationTransition(
            turns: _rotateAnimation,
            child: Container(
              width: centerSize,
              height: centerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accentGreen, Color(0xFF006644)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentGreen.withValues(alpha:0.5),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.satellite_alt,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgressWithInfo(double progress, {bool isCompact = false}) {
    final containerSize = isCompact ? 160.0 : 200.0;
    final innerSize = isCompact ? 145.0 : 180.0;
    final timerFontSize = isCompact ? 28.0 : 36.0;
    final subFontSize = isCompact ? 12.0 : 14.0;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha:0.3),
              border: Border.all(
                color: _accentGreen.withValues(alpha:0.2),
                width: 2,
              ),
            ),
          ),

          // Progreso circular
          SizedBox(
            width: innerSize,
            height: innerSize,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: isCompact ? 6 : 8,
              backgroundColor: Colors.white.withValues(alpha:0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_brightGreen),
            ),
          ),

          // Info central
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_elapsedSeconds}s',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: timerFontSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                'de ${_maxWaitTimeSeconds}s',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: subFontSize,
                  color: Colors.white.withValues(alpha:0.7),
                ),
              ),
              SizedBox(height: isCompact ? 6 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: _validPoints >= 2 ? _successGreen.withValues(alpha:0.3) : _accentGreen.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_validPoints/2 puntos',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: isCompact ? 10 : 12,
                    fontWeight: FontWeight.w700,
                    color: _validPoints >= 2 ? _successGreen : _brightGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _brightGreen.withValues(alpha:0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentGreen.withValues(alpha:0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_fixed, color: _brightGreen, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoChip(Icons.precision_manufacturing, '≤${_maxHorizontalError}m'),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.verified, '$_validPoints válidos'),
                    if (_currentBestError > 0) ...[
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.gps_fixed, '${_currentBestError.toStringAsFixed(2)}m'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 110),
      decoration: BoxDecoration(
        color: _accentGreen.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _accentGreen.withValues(alpha:0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _brightGreen, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha:0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE PROCESAMIENTO
  // ==========================================================================

  Widget _buildProcessingScreen() {
    return Stack(
      children: [
        ...List.generate(10, (index) => _buildFloatingParticle(index)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner con gradiente
              RotationTransition(
                turns: _rotateAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accentGreen, Color(0xFF006644)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentGreen.withValues(alpha:0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                _statusMessage,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha:0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(_brightGreen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PANTALLA DE ÉXITO
  // ==========================================================================

  Widget _buildSuccessScreen() {
    return Stack(
      children: [
        // Partículas solo en modo alto rendimiento (reducidas de 25 a 10)
        if (!_isLowPerformanceMode)
          ...List.generate(10, (index) => _buildFloatingParticle(index)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono de éxito con animación
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_successGreen, Color(0xFF00B88D)],
                      ),
                      // BoxShadow solo en modo alto rendimiento
                      boxShadow: _isLowPerformanceMode ? null : [
                        BoxShadow(
                          color: _successGreen.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  '¡Visita Registrada!',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 20),

                // BackdropFilter solo en modo alto rendimiento
                if (_isLowPerformanceMode)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _successGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _successGreen.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _successGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _successGreen.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Margen de error
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _accentGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentGreen.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: _brightGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Margen de error: ${_finalHorizontalError.toStringAsFixed(2)} m',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PANTALLA DE ERROR
  // ==========================================================================

  Widget _buildErrorScreen() {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                    ),
                    // BoxShadow solo en modo alto rendimiento
                    boxShadow: _isLowPerformanceMode ? null : [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                // BackdropFilter solo en modo alto rendimiento
                if (_isLowPerformanceMode)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      'Cerrar',
                      Icons.close,
                      Colors.redAccent,
                      () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'Reintentar',
                      Icons.refresh,
                      _accentGreen,
                      () {
                        setState(() {
                          _hasError = false;
                          _errorMessage = '';
                          _retryAttempts = 0;
                          _countdown = 5;
                          _gpsPoints.clear();
                          _validPoints = 0;
                          _elapsedSeconds = 0;
                        });
                        _startCountdown();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 8,
        shadowColor: color.withValues(alpha:0.5),
      ),
    );
  }
}
