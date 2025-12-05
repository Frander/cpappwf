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

  // Estado
  bool _isWaiting = false;
  bool _isProcessing = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _statusMessage = '';
  String _errorMessage = '';

  // GPS Points
  List<GPSPoint> _gpsPoints = [];
  int _retryAttempts = 0;
  static const int _maxRetryAttempts =
      3; // Después de 3 intentos, usar geolocator

  // Filtro de precisión GPS
  static const double _maxHorizontalError = 10.0; // metros
  static const int _maxWaitTimeSeconds = 40; // segundos máximo de espera
  static const int _retryIntervalSeconds = 2; // intervalo entre reintentos

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Animación de pulso
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Animación de escala
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
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
    setState(() {
      _isWaiting = true;
      _statusMessage = 'Obteniendo coordenadas GPS precisas...';
    });

    try {
      // ESTRATEGIA 1: Intentar obtener de AppState con filtro de precisión
      // Loop con timeout de 40 segundos
      final startTime = DateTime.now();
      int attemptNumber = 0;

      while (true) {
        attemptNumber++;
        final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        // Verificar timeout
        if (elapsedSeconds >= _maxWaitTimeSeconds) {
          debugPrint(
              '⏱️ Timeout de $_maxWaitTimeSeconds segundos alcanzado. Intentando estrategia alternativa...');
          break;
        }

        final geoLocationsList = FFAppState().geoLocationsList;
        debugPrint(
            '📍 [Intento $attemptNumber] Puntos GPS en AppState: ${geoLocationsList.length}');

        if (geoLocationsList.isNotEmpty) {
          // Obtener nivel de batería
          final battery = Battery();
          int batteryLevel = 100;
          try {
            batteryLevel = await battery.batteryLevel;
          } catch (e) {
            debugPrint('⚠️ No se pudo obtener nivel de batería: $e');
          }

          // Convertir y FILTRAR puntos con error <= 10 metros
          final allPoints = geoLocationsList.map((geoStruct) {
            return GPSPoint(
              latitude: geoStruct.latitude ?? 0.0,
              longitude: geoStruct.longitude ?? 0.0,
              altitude: geoStruct.altitude ?? 0.0,
              horizontalError: geoStruct.errorHorizontal ?? 0.0,
              createdAt: geoStruct.dateHourRead ?? DateTime.now().toUtc(),
              battery: batteryLevel,
            );
          }).toList();

          // FILTRAR: Solo puntos con error <= 10 metros
          _gpsPoints = allPoints
              .where((point) => point.horizontalError <= _maxHorizontalError)
              .toList();

          final rejectedCount = allPoints.length - _gpsPoints.length;

          debugPrint(
              '🎯 Filtro de precisión aplicado (error <= ${_maxHorizontalError}m):');
          debugPrint('   Total puntos: ${allPoints.length}');
          debugPrint('   Puntos precisos: ${_gpsPoints.length}');
          debugPrint('   Puntos rechazados: $rejectedCount');

          if (rejectedCount > 0) {
            debugPrint('   ⚠️ Errores rechazados:');
            for (var point in allPoints) {
              if (point.horizontalError > _maxHorizontalError) {
                debugPrint(
                    '      - ${point.horizontalError.toStringAsFixed(1)}m (RECHAZADO)');
              }
            }
          }

          // Si tenemos suficientes puntos precisos, crear visita
          if (_gpsPoints.length >= 2) {
            debugPrint(
                '✅ Suficientes puntos precisos obtenidos (${_gpsPoints.length} >= 2)');
            await _createVisit();
            return;
          }

          // Actualizar mensaje para el usuario
          setState(() {
            _statusMessage = 'Esperando señal GPS precisa...\n\n'
                '📡 Precisión requerida: ≤ ${_maxHorizontalError}m\n'
                '📍 Puntos válidos: ${_gpsPoints.length}/2\n'
                '⏱️ Tiempo: ${elapsedSeconds}s / ${_maxWaitTimeSeconds}s\n'
                '🔄 Reintentando en $_retryIntervalSeconds segundos...';
          });

          debugPrint(
              '⏳ Esperando $_retryIntervalSeconds segundos antes de reintentar...');
          await Future.delayed(Duration(seconds: _retryIntervalSeconds));

          // Verificar si el widget sigue montado
          if (!mounted) return;

          continue; // Reintentar
        } else {
          // AppState vacío
          debugPrint('⚠️ AppState vacío en intento $attemptNumber');

          setState(() {
            _statusMessage = 'Esperando señal GPS del sistema...\n\n'
                '⏱️ Tiempo: ${elapsedSeconds}s / ${_maxWaitTimeSeconds}s\n'
                '🔄 Reintentando...';
          });

          await Future.delayed(Duration(seconds: _retryIntervalSeconds));

          if (!mounted) return;
          continue;
        }
      }

      // ESTRATEGIA 2: Si AppState está vacío, intentar SQLite con filtro de precisión
      debugPrint(
          '⚠️ Timeout alcanzado o AppState insuficiente, intentando SQLite...');

      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');

      final database = await openDatabase(dbPath);

      // Consultar Location_tracking con filtro de precisión
      final List<Map<String, dynamic>> results = await database.rawQuery('''
        SELECT
          Latitude,
          Longitude,
          Altitude,
          HorizontalError,
          Battery,
          CreatedAt
        FROM Location_tracking
        WHERE HorizontalError <= ?
        ORDER BY CreatedAt DESC
        LIMIT 8
      ''', [_maxHorizontalError]);

      await database.close();

      final allPointsFromDB =
          results.map((row) => GPSPoint.fromMap(row)).toList();

      // Aplicar el mismo filtro por consistencia
      _gpsPoints = allPointsFromDB
          .where((point) => point.horizontalError <= _maxHorizontalError)
          .toList();

      debugPrint(
          '📍 Puntos GPS precisos encontrados en SQLite: ${_gpsPoints.length} (error <= ${_maxHorizontalError}m)');

      if (_gpsPoints.length >= 2) {
        // Suficientes puntos GPS precisos
        debugPrint('✅ Usando puntos de SQLite (precisión adecuada)');
        await _createVisit();
      } else {
        // ESTRATEGIA 3: Fallback a geolocator directo
        _retryAttempts++;

        if (_retryAttempts >= _maxRetryAttempts) {
          // Fallback: Usar geolocator para obtener coordenadas directamente del GPS
          debugPrint(
              '⚠️ No hay suficientes datos en AppState ni SQLite. Usando fallback de geolocator...');
          setState(() {
            _statusMessage =
                'Obteniendo coordenadas directamente del GPS del dispositivo...';
          });

          await _getGPSFromGeolocator();
          return;
        }

        setState(() {
          _statusMessage =
              'Se está tardando más de lo normal...\n\nPuntos GPS obtenidos: ${_gpsPoints.length}/2\nIntento ${_retryAttempts}/$_maxRetryAttempts\n\nEsperando más coordenadas...';
        });

        // Reiniciar contador para esperar 5 segundos más
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

  // ==========================================================================
  // FALLBACK: Obtener GPS directamente usando Geolocator
  // ==========================================================================

  Future<void> _getGPSFromGeolocator() async {
    try {
      // 1. Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
            'El servicio de ubicación está deshabilitado.\n\nPor favor, habilita el GPS en tu dispositivo.');
      }

      // 2. Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
              'Permisos de ubicación denegados.\n\nPor favor, habilita los permisos de ubicación en la configuración.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Permisos de ubicación denegados permanentemente.\n\nPor favor, habilita los permisos en la configuración del dispositivo.');
      }

      // 3. Obtener nivel de batería
      final battery = Battery();
      int batteryLevel = 0;
      try {
        batteryLevel = await battery.batteryLevel;
      } catch (e) {
        debugPrint('⚠️ No se pudo obtener nivel de batería: $e');
        batteryLevel = 100; // Valor por defecto
      }

      setState(() {
        _statusMessage =
            'Obteniendo coordenadas GPS precisas del dispositivo...\n\n'
            '📡 Precisión requerida: ≤ ${_maxHorizontalError}m\n'
            'Esto puede tardar unos segundos.';
      });

      // 4. Obtener múltiples lecturas GPS con validación de precisión
      _gpsPoints.clear();
      List<GPSPoint> allAttempts = [];

      for (int i = 0; i < 5; i++) {
        // Aumentado a 5 intentos
        try {
          debugPrint('📍 Obteniendo punto GPS preciso ${i + 1}/5...');

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );

          final gpsPoint = GPSPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            altitude: position.altitude ?? 0.0,
            horizontalError: position.accuracy,
            createdAt: DateTime.now().toUtc(),
            battery: batteryLevel,
          );

          allAttempts.add(gpsPoint);

          debugPrint(
              '📍 Punto GPS ${i + 1}/5: ${position.latitude}, ${position.longitude} (error: ±${position.accuracy.toStringAsFixed(1)}m)');

          // Validar precisión
          if (position.accuracy <= _maxHorizontalError) {
            _gpsPoints.add(gpsPoint);
            debugPrint('   ✅ ACEPTADO (error <= ${_maxHorizontalError}m)');

            // Si ya tenemos 2 puntos precisos, podemos parar
            if (_gpsPoints.length >= 2) {
              debugPrint(
                  '✅ Suficientes puntos precisos obtenidos (${_gpsPoints.length} >= 2)');
              break;
            }
          } else {
            debugPrint(
                '   ❌ RECHAZADO (error ${position.accuracy.toStringAsFixed(1)}m > ${_maxHorizontalError}m)');
          }

          // Actualizar UI
          setState(() {
            _statusMessage = 'Obteniendo coordenadas GPS precisas...\n\n'
                '📡 Precisión requerida: ≤ ${_maxHorizontalError}m\n'
                '📍 Puntos válidos: ${_gpsPoints.length}/2\n'
                '🔄 Intento: ${i + 1}/5';
          });

          // Pequeña espera entre lecturas
          if (i < 4 && _gpsPoints.length < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          debugPrint('⚠️ Error obteniendo punto GPS ${i + 1}: $e');
          // Continuar con los siguientes intentos
        }
      }

      // 5. Verificar que se obtuvieron al menos 2 puntos PRECISOS
      debugPrint('');
      debugPrint('📊 Resumen de intentos de geolocator:');
      debugPrint('   Total intentos: ${allAttempts.length}');
      debugPrint(
          '   Puntos precisos (≤${_maxHorizontalError}m): ${_gpsPoints.length}');
      debugPrint(
          '   Puntos rechazados: ${allAttempts.length - _gpsPoints.length}');

      if (_gpsPoints.isEmpty) {
        // Mostrar los errores de los puntos rechazados
        if (allAttempts.isNotEmpty) {
          debugPrint(
              '   ⚠️ Todos los puntos fueron rechazados por baja precisión:');
          for (var point in allAttempts) {
            debugPrint(
                '      - Error: ${point.horizontalError.toStringAsFixed(1)}m (> ${_maxHorizontalError}m)');
          }
          throw Exception(
              'No se pudo obtener señal GPS con la precisión requerida.\n\n'
              '📡 Precisión requerida: ≤ ${_maxHorizontalError}m\n'
              '📍 Mejor precisión obtenida: ±${allAttempts.map((p) => p.horizontalError).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}m\n\n'
              'Intenta moverte a un lugar con mejor señal GPS (cielo despejado, lejos de edificios).');
        } else {
          throw Exception(
              'No se pudieron obtener coordenadas GPS del dispositivo.\n\n'
              'Verifica que el GPS esté habilitado y que tengas buena señal.');
        }
      }

      // Si solo se obtuvo 1 punto preciso, duplicarlo con timestamp diferente
      if (_gpsPoints.length == 1) {
        debugPrint(
            '⚠️ Solo se obtuvo 1 punto GPS preciso. Duplicando para cumplir requisito mínimo...');
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

      debugPrint(
          '✅ Total de puntos GPS PRECISOS obtenidos desde geolocator: ${_gpsPoints.length}');

      // 6. Continuar con la creación de la visita
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
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Creando visita...';
    });

    try {
      // Obtener datos del AppState
      final deviceDefault = FFAppState().deviceDefault;
      final userSelected = FFAppState().userSelected;
      final activitySelectedJSON = FFAppState().activitySelectedJSON;
      final visitDetails = FFAppState().visitDetails;

      // Extraer id_activity del JSON
      int idActivity = 0;
      if (activitySelectedJSON != null && activitySelectedJSON.isNotEmpty) {
        try {
          // Verificar si activitySelectedJSON ya es un Map o es String
          dynamic activityData;
          if (activitySelectedJSON is String) {
            activityData = jsonDecode(activitySelectedJSON);
          } else if (activitySelectedJSON is Map) {
            activityData = activitySelectedJSON;
          } else {
            debugPrint(
                '⚠️ activitySelectedJSON tiene tipo inesperado: ${activitySelectedJSON.runtimeType}');
            activityData = null;
          }

          if (activityData != null && activityData is Map) {
            idActivity = (activityData['id_activity'] as num?)?.toInt() ?? 0;
          }
        } catch (e) {
          debugPrint('⚠️ Error parseando activitySelectedJSON: $e');
        }
      }

      // Validar datos necesarios
      if (deviceDefault.idDevice == 0) {
        throw Exception('ID de dispositivo no encontrado');
      }
      if (userSelected.idUser == 0) {
        throw Exception('ID de usuario no encontrado');
      }
      if (idActivity == 0) {
        throw Exception('ID de actividad no encontrado');
      }

      // Usar el primer punto GPS como coordenadas principales de la visita
      final mainGPSPoint = _gpsPoints.first;

      // Abrir base de datos (misma ruta que sync_visits_form.dart)
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento externo');
      }
      final String pathStr = '${externalDir.path}/ClickPalmData';
      final dbPath = path.join(pathStr, 'clickpalm_database.db');

      final database = await openDatabase(dbPath);

      // Insertar en transacción
      int visitId = 0;
      await database.transaction((txn) async {
        // 1. Insertar Visits
        visitId = await txn.rawInsert('''
          INSERT INTO Visits (
            Id_company,
            Id_activity,
            Id_headquarter,
            Id_product,
            Id_bulk,
            Id_user,
            Id_device,
            Id_status,
            Created_at,
            Battery,
            Latitude,
            Longitude,
            Altitude,
            Error_horizontal,
            Id_virtual_point,
            Status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          userSelected.idCompany,
          idActivity,
          0, // Id_headquarter (puedes ajustarlo si lo tienes)
          0, // Id_product (puedes ajustarlo si lo tienes)
          0, // Id_bulk (puedes ajustarlo si lo tienes)
          userSelected.idUser,
          deviceDefault.idDevice,
          0, // Id_status siempre 0 según especificación
          DateTime.now().toUtc().toIso8601String(),
          mainGPSPoint.battery,
          mainGPSPoint.latitude,
          mainGPSPoint.longitude,
          mainGPSPoint.altitude,
          mainGPSPoint.horizontalError,
          null, // Id_virtual_point
          0, // Status (false por defecto)
        ]);

        debugPrint('✅ Visita creada con ID: $visitId');

        // 2. Insertar Visits_details (filtrar registros de tipo STEP)
        final detailsToInsert = visitDetails.where((detail) => detail.typeStatus != 'STEP').toList();

        debugPrint('📝 Insertando ${detailsToInsert.length} detalles de visita:');

        int insertedCount = 0;
        int skippedCount = 0;

        for (var detail in detailsToInsert) {
          final idActivityStatus = detail.idActivityStatus;

          // Verificar si el Id_activity_status existe en Activities_status
          final statusCheck = await txn.rawQuery('''
            SELECT Id_activity_status, Status_name, Factor
            FROM Activities_status
            WHERE Id_activity_status = ?
          ''', [idActivityStatus]);

          if (statusCheck.isEmpty) {
            debugPrint('  ❌ SALTADO: Id_activity_status=$idActivityStatus NO existe en Activities_status');
            debugPrint('     Tipo: ${detail.typeStatus}, Respuesta: ${detail.statusResponse}');
            skippedCount++;
            continue; // NO insertar este detalle huérfano
          }

          final statusInfo = statusCheck.first;
          debugPrint('  ✅ Insertando: Id_activity_status=$idActivityStatus "${statusInfo['Status_name']}" Factor=${statusInfo['Factor']}');

          await txn.rawInsert('''
            INSERT INTO Visits_details (
              Id_visit,
              Id_activity_status,
              Status_option,
              Status_response
            ) VALUES (?, ?, ?, ?)
          ''', [
            visitId,
            idActivityStatus,
            detail.statusOption,
            detail.statusResponse,
          ]);

          insertedCount++;
        }

        if (skippedCount > 0) {
          debugPrint('⚠️ ${skippedCount} detalles SALTADOS por tener Id_activity_status huérfano');
        }

        debugPrint('✅ $insertedCount detalles de visita insertados (${visitDetails.length - detailsToInsert.length} registros STEP excluidos)');

        // 3. Insertar Visits_locations (últimos 10 puntos máximo de los últimos 6 segundos)
        final now = DateTime.now().toUtc();
        final sixSecondsAgo = now.subtract(const Duration(seconds: 6));

        // Filtrar puntos: solo los de los últimos 6 segundos
        final recentPoints = _gpsPoints
            .where((point) => point.createdAt.isAfter(sixSecondsAgo))
            .toList();

        // Ordenar por fecha descendente (más reciente primero)
        recentPoints.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Tomar máximo 10 puntos
        final pointsToSave = recentPoints.take(10).toList();

        debugPrint('');
        debugPrint('📍 Filtro de Visits_locations aplicado:');
        debugPrint('   Total puntos disponibles: ${_gpsPoints.length}');
        debugPrint('   Puntos de últimos 6 segundos: ${recentPoints.length}');
        debugPrint('   Puntos a guardar (máx 10): ${pointsToSave.length}');

        // Insertar solo los puntos filtrados
        for (var gpsPoint in pointsToSave) {
          await txn.rawInsert('''
            INSERT INTO Visits_locations (
              Id_visit,
              Latitude,
              Longitude,
              Altitude,
              HorizontalError,
              CreatedAt
            ) VALUES (?, ?, ?, ?, ?, ?)
          ''', [
            visitId,
            gpsPoint.latitude,
            gpsPoint.longitude,
            gpsPoint.altitude,
            gpsPoint.horizontalError,
            gpsPoint.createdAt.toIso8601String(),
          ]);
        }

        debugPrint(
            '✅ ${pointsToSave.length} ubicaciones GPS insertadas (últimos 10 puntos de los últimos 6 segundos)');
      });

      await database.close();

      // Actualizar AppState
      FFAppState().update(() {
        FFAppState().visitCount = (FFAppState().visitCount ?? 0) + 1;

        // Filtrar visitDetails usando removeVisits (mantiene solo los que tienen rememberStatus == true)
        final int previousCount = FFAppState().visitDetails.length;
        FFAppState().visitDetails = removeVisits(FFAppState().visitDetails);
        final int newCount = FFAppState().visitDetails.length;

        debugPrint('🔄 visitDetails filtrado después de agregar visita:');
        debugPrint('   Antes: $previousCount elementos');
        debugPrint('   Después: $newCount elementos');
        debugPrint(
            '   Eliminados: ${previousCount - newCount} elementos sin rememberStatus');
      });

      setState(() {
        _isProcessing = false;
        _isComplete = true;
        _statusMessage =
            'Visita registrada exitosamente\n\nID: $visitId\nCoordenadas GPS: ${_gpsPoints.length}';
      });

      // Cerrar automáticamente después de 2 segundos
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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primaryBackground,
            FlutterFlowTheme.of(context).secondaryBackground,
          ],
        ),
      ),
      child: SafeArea(
        child: _hasError
            ? _buildErrorScreen()
            : _isComplete
                ? _buildSuccessScreen()
                : _isProcessing
                    ? _buildProcessingScreen()
                    : _isWaiting
                        ? _buildWaitingScreen()
                        : _buildCountdownScreen(),
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE CONTADOR
  // ==========================================================================

  Widget _buildCountdownScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            FlutterFlowTheme.of(context).primaryBackground,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título con efecto glass
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary.withValues(alpha: 0.2),
                    FlutterFlowTheme.of(context)
                        .secondary
                        .withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                'Preparando Visita',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Contador circular animado con fondo mejorado
            ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anillo giratorio de fondo
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.3),
                            FlutterFlowTheme.of(context)
                                .secondary
                                .withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Círculo de progreso con gradiente moderno
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
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
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$_countdown',
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Indicador de progreso circular
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: (5 - _countdown) / 5,
                      strokeWidth: 6,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Mensaje con contenedor glass
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Obteniendo coordenadas GPS...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),

            // PIN animado en la parte inferior
            ScaleTransition(
              scale: _pulseAnimation,
              child: Column(
                children: [
                  // PIN con efecto de sombra y gradiente
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sombra pulsante del PIN
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              FlutterFlowTheme.of(context)
                                  .error
                                  .withValues(alpha: 0.4),
                              FlutterFlowTheme.of(context)
                                  .error
                                  .withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      // Contenedor del PIN
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              FlutterFlowTheme.of(context).error,
                              FlutterFlowTheme.of(context).error,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: FlutterFlowTheme.of(context)
                                  .error
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Texto debajo del PIN
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.2),
                          FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context)
                            .error
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Ubicación actual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
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

  // ==========================================================================
  // PANTALLA DE ESPERA
  // ==========================================================================

  Widget _buildWaitingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono animado
            RotationTransition(
              turns: _rotateAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).warning,
                      FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.7),
                    ],
                  ),
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
                child: const Icon(
                  Icons.gps_fixed,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Mensaje
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    FlutterFlowTheme.of(context).warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: FlutterFlowTheme.of(context).warning,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Indicador de progreso
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE PROCESAMIENTO
  // ==========================================================================

  Widget _buildProcessingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Spinner animado
          RotationTransition(
            turns: _rotateAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor:
                  FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE ÉXITO
  // ==========================================================================

  Widget _buildSuccessScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono de éxito
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).success,
                    FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 80,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              '¡Visita Registrada!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    FlutterFlowTheme.of(context).success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PANTALLA DE ERROR
  // ==========================================================================

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono de error
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).error,
                    FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .error
                        .withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
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

            Text(
              'Error',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    FlutterFlowTheme.of(context).error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      FlutterFlowTheme.of(context).error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('Cerrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                      _retryAttempts = 0;
                      _countdown = 5;
                      _gpsPoints.clear();
                    });
                    _startCountdown();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
