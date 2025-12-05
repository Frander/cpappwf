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
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ============================================================================
// CLASE PARA GESTIÓN DE PROGRESO DE DESCARGA
// ============================================================================

class DownloadProgressManager {
  static const String _keyDownloadedBytes = 'map_download_bytes';
  static const String _keyTotalBytes = 'map_download_total';
  static const String _keyFilePath = 'map_download_path';
  static const String _keyLastUpdate = 'map_download_time';

  final int downloadedBytes;
  final int totalBytes;
  final String filePath;
  final DateTime lastUpdate;

  DownloadProgressManager({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.filePath,
    required this.lastUpdate,
  });

  // Guardar progreso
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDownloadedBytes, downloadedBytes);
      await prefs.setInt(_keyTotalBytes, totalBytes);
      await prefs.setString(_keyFilePath, filePath);
      await prefs.setString(_keyLastUpdate, lastUpdate.toIso8601String());
      debugPrint(
          '💾 Progreso guardado: ${downloadedBytes}/${totalBytes} bytes');
    } catch (e) {
      debugPrint('⚠️ Error guardando progreso: $e');
    }
  }

  // Cargar progreso guardado
  static Future<DownloadProgressManager?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bytes = prefs.getInt(_keyDownloadedBytes);

      if (bytes == null || bytes == 0) return null;

      return DownloadProgressManager(
        downloadedBytes: bytes,
        totalBytes: prefs.getInt(_keyTotalBytes) ?? 0,
        filePath: prefs.getString(_keyFilePath) ?? '',
        lastUpdate: DateTime.parse(prefs.getString(_keyLastUpdate) ??
            DateTime.now().toIso8601String()),
      );
    } catch (e) {
      debugPrint('⚠️ Error cargando progreso: $e');
      return null;
    }
  }

  // Limpiar progreso guardado
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDownloadedBytes);
      await prefs.remove(_keyTotalBytes);
      await prefs.remove(_keyFilePath);
      await prefs.remove(_keyLastUpdate);
      debugPrint('🗑️ Progreso limpiado');
    } catch (e) {
      debugPrint('⚠️ Error limpiando progreso: $e');
    }
  }
}

// ============================================================================
// CONFIGURACIÓN DE DESCARGA
// ============================================================================

class DownloadConfig {
  static const int maxRetries = 10;
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 0); // Sin timeout en receive (streaming)
  static const Duration sendTimeout = Duration(seconds: 30);
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const int progressSaveIntervalSeconds = 10; // Reducido a cada 10s
  static const int progressSaveBytes = 1024 * 1024 * 50; // Guardar cada 50 MB

  // Configuración para chunks paralelos optimizada
  static const int maxConcurrentChunks = 8; // Aumentado para aprovechar fibra óptica
  static const int chunkSize = 1024 * 1024 * 20; // 20 MB por chunk (más eficiente)

  // Umbrales para estrategia híbrida (SIMPLIFICADO - siempre paralelo en WiFi)
  static const int minFileSizeForParallel = 1024 * 1024 * 10; // 10 MB mínimo

  static const String pmtilesUrl =
      'https://clickpalmv2.s3.us-west-2.amazonaws.com/Resources/colombia.pmtiles';
}

// ============================================================================
// ENUM PARA ESTRATEGIA DE DESCARGA
// ============================================================================

enum DownloadStrategy {
  sequential, // Descarga tradicional en un solo stream
  parallel, // Descarga en chunks paralelos
  adaptive, // Comienza paralelo, degrada a secuencial si falla
}

// ============================================================================
// ESTADO DE CHUNK INDIVIDUAL
// ============================================================================

class ChunkInfo {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  bool isComplete;
  bool isDownloading;
  int retries;

  ChunkInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.isComplete = false,
    this.isDownloading = false,
    this.retries = 0,
  });

  int get totalBytes => endByte - startByte + 1;
  double get progress => downloadedBytes / totalBytes;
}

// ============================================================================
// WIDGET PRINCIPAL - DESCARGA DE MAPAS CON PROGRESO
// ============================================================================

class LoadResourcesMapTiles extends StatefulWidget {
  const LoadResourcesMapTiles({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<LoadResourcesMapTiles> createState() => _LoadResourcesMapTilesState();
}

class _LoadResourcesMapTilesState extends State<LoadResourcesMapTiles>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Estado de descarga
  bool _isDownloading = false;
  bool _downloadComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isAppInBackground = false;

  // Progreso
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _downloadSpeed = '';
  String _timeRemaining = '';

  // Información del archivo
  String _fileName = 'colombia.pmtiles';
  String _filePath = '';

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Timer para actualizar velocidad
  Timer? _speedTimer;
  int _lastDownloadedBytes = 0;
  DateTime? _downloadStartTime;

  // Nuevas variables para reintentos y conectividad
  int _retryCount = 0;
  bool _isPaused = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _connectionStatus = 'Verificando...';
  Timer? _progressSaveTimer;
  DateTime? _lastChunkTime;
  Dio? _dio;
  CancelToken? _cancelToken;
  int _lastSavedBytes = 0;

  // Variables para descarga paralela
  DownloadStrategy _currentStrategy = DownloadStrategy.parallel;
  List<ChunkInfo> _chunks = [];
  int _activeChunks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _setupConnectivityMonitoring();
    _checkExistingFile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // La app está en segundo plano o cerrándose
        debugPrint('📱 App en segundo plano - Pausando descarga');
        _isAppInBackground = true;
        if (_isDownloading && !_downloadComplete) {
          _pauseDownload();
        }
        break;
      case AppLifecycleState.resumed:
        // La app volvió a primer plano
        debugPrint('📱 App en primer plano');
        _isAppInBackground = false;
        if (_isPaused && !_hasError && !_downloadComplete) {
          debugPrint('📱 Reanudando descarga automáticamente');
          _resumeDownload();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _speedTimer?.cancel();
    _progressSaveTimer?.cancel();
    _connectivitySubscription?.cancel();
    _cancelToken?.cancel();

    // Liberar WakeLock si está activo
    WakelockPlus.disable();

    // Cerrar Dio al destruir el widget completamente
    _dio?.close(force: true);
    _dio = null;

    super.dispose();
  }

  // ==========================================================================
  // MÉTODOS DE VERIFICACIÓN Y DESCARGA
  // ==========================================================================

  void _setupConnectivityMonitoring() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((resultList) {
      if (!mounted) return;

      final result = resultList.firstOrNull ?? ConnectivityResult.none;

      setState(() {
        switch (result) {
          case ConnectivityResult.wifi:
            _connectionStatus = 'WiFi';
            break;
          case ConnectivityResult.mobile:
            _connectionStatus = 'Móvil';
            break;
          case ConnectivityResult.none:
            _connectionStatus = 'Sin conexión';
            if (_isDownloading && !_isPaused) {
              debugPrint('❌ Conexión perdida durante descarga');
              _pauseDownload();
            }
            break;
          default:
            _connectionStatus = 'Conectado';
        }
      });

      // Si recupera la conexión y estaba descargando, reintentar
      if (result != ConnectivityResult.none && _isPaused && _isDownloading) {
        debugPrint('✅ Conexión restaurada - Reintentando...');
        _resumeDownload();
      }
    });

    // Verificar estado inicial
    Connectivity().checkConnectivity().then((resultList) {
      if (!mounted) return;
      final result = resultList.firstOrNull ?? ConnectivityResult.none;
      setState(() {
        switch (result) {
          case ConnectivityResult.wifi:
            _connectionStatus = 'WiFi';
            break;
          case ConnectivityResult.mobile:
            _connectionStatus = 'Móvil';
            break;
          case ConnectivityResult.none:
            _connectionStatus = 'Sin conexión';
            break;
          default:
            _connectionStatus = 'Conectado';
        }
      });
    });
  }

  void _pauseDownload() {
    if (!mounted) return;

    setState(() {
      _isPaused = true;
    });

    // Cancelar todas las operaciones en curso
    _cancelToken?.cancel('App pausada o en segundo plano');
    _speedTimer?.cancel();
    _progressSaveTimer?.cancel();

    // Guardar progreso antes de pausar
    _saveProgress();

    debugPrint('⏸️ Descarga pausada - Estado guardado');
  }

  void _resumeDownload() async {
    if (!_isPaused) return;

    setState(() {
      _isPaused = false;
      _retryCount = 0; // Resetear contador de reintentos
    });

    debugPrint('▶️ Reanudando descarga...');
    await _startDownloadWithRetry();
  }

  Future<void> _checkExistingFile() async {
    try {
      final String docsPath = await _getBestDocumentsPath();
      final String filePath = '$docsPath/$_fileName';
      final File file = File(filePath);

      if (await file.exists()) {
        final int fileSize = await file.length();

        if (fileSize > 1024 * 1024) {
          // Archivo existe y es válido
          setState(() {
            _filePath = filePath;
            _totalBytes = fileSize;
            _downloadedBytes = fileSize;
            _downloadProgress = 1.0;
            _downloadComplete = true;
          });

          // Actualizar AppState
          FFAppState().update(() {
            FFAppState().pathPmtiles = filePath;
          });

          // Limpiar progreso guardado si existe
          await DownloadProgressManager.clear();

          debugPrint(
              '✅ Mapa ya descargado: $filePath (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
        }
      } else {
        // Verificar si hay descarga parcial guardada
        final partialFile = File('$filePath.partial');
        if (await partialFile.exists()) {
          final savedProgress = await DownloadProgressManager.load();
          if (savedProgress != null) {
            final partialSize = await partialFile.length();
            setState(() {
              _downloadedBytes = partialSize;
              _totalBytes = savedProgress.totalBytes;
              _downloadProgress =
                  _totalBytes > 0 ? _downloadedBytes / _totalBytes : 0.0;
            });
            debugPrint(
                '📦 Descarga parcial encontrada: ${(partialSize / (1024 * 1024)).toStringAsFixed(2)} MB / ${(savedProgress.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando archivo existente: $e');
    }
  }

  // Método público para iniciar descarga con reintentos
  Future<void> _startDownloadWithRetry() async {
    _retryCount = 0;
    await _attemptDownload();
  }

  Future<void> _attemptDownload() async {
    try {
      await _startDownload();
    } on DioException catch (e) {
      debugPrint('❌ Error Dio: ${e.type} - ${e.message}');

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        await _handleRetry('Tiempo de espera agotado');
      } else if (e.type == DioExceptionType.connectionError) {
        await _handleRetry('Error de conexión a internet');
      } else if (e.type == DioExceptionType.badResponse) {
        await _handleRetry('Error del servidor (${e.response?.statusCode})');
      } else if (e.type == DioExceptionType.cancel) {
        debugPrint('⏸️ Descarga cancelada por el usuario');
        setState(() {
          _isDownloading = false;
          _isPaused = true;
        });
      } else {
        await _handleRetry('Error de red: ${e.message}');
      }
    } on SocketException catch (e) {
      debugPrint('❌ Error de socket: $e');
      await _handleRetry('Error de conexión a internet');
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout: $e');
      await _handleRetry('Tiempo de espera agotado');
    } catch (e) {
      debugPrint('❌ Error en descarga: $e');

      // Error no recuperable
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isDownloading = false;
        _isPaused = false;
      });

      _cleanupDownload();
    }
  }

  Future<void> _handleRetry(String errorReason) async {
    // No reintentar si la app está en segundo plano
    if (_isAppInBackground) {
      debugPrint('⏸️ App en segundo plano - No se reintentará automáticamente');
      setState(() {
        _isPaused = true;
      });
      return;
    }

    if (_retryCount >= DownloadConfig.maxRetries) {
      setState(() {
        _hasError = true;
        _errorMessage =
            '$errorReason. Máximo de reintentos alcanzado (${DownloadConfig.maxRetries})';
        _isDownloading = false;
        _isPaused = false;
      });

      _cleanupDownload();
      return;
    }

    _retryCount++;

    // Usar backoff exponencial con jitter
    final delay = _calculateBackoffDelay(_retryCount);

    setState(() {
      _isPaused = true;
    });

    debugPrint(
        '🔄 Reintento $_retryCount/${DownloadConfig.maxRetries} en ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s...');
    debugPrint('   Razón: $errorReason');

    await Future.delayed(delay);

    // Verificar nuevamente si la app sigue en primer plano después del delay
    if (mounted && !_hasError && !_isAppInBackground) {
      setState(() {
        _isPaused = false;
      });
      await _attemptDownload();
    } else if (_isAppInBackground) {
      debugPrint('⏸️ App en segundo plano después del delay - Reintento cancelado');
    }
  }

  void _cleanupDownload() {
    _speedTimer?.cancel();
    _progressSaveTimer?.cancel();
    _cancelToken?.cancel();
    // NO cerrar Dio aquí, se reutiliza entre descargas
    _cancelToken = null;
  }

  // Inicializar Dio con configuración optimizada para máxima velocidad
  Dio _getDioInstance() {
    if (_dio != null) return _dio!;

    _dio = Dio(BaseOptions(
      connectTimeout: DownloadConfig.connectTimeout,
      receiveTimeout: DownloadConfig.receiveTimeout,
      sendTimeout: DownloadConfig.sendTimeout,
      receiveDataWhenStatusError: false,
      validateStatus: (status) => status != null && status >= 200 && status < 300,
      headers: {
        'Connection': 'keep-alive',
        'Accept-Encoding': 'identity', // Sin compresión para máxima velocidad
      },
      // Configuraciones de red optimizadas
      persistentConnection: true,
    ));

    // Sin interceptores para máxima velocidad (los errores se manejan en _attemptDownload)

    return _dio!;
  }

  // Determinar si un error es retryable
  bool _shouldRetryRequest(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.badResponse &&
            error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
  }

  // Calcular delay con backoff exponencial + jitter
  Duration _calculateBackoffDelay(int retryCount) {
    // Backoff exponencial: 1s, 2s, 4s, 8s, 16s, 32s...
    final exponentialDelay =
        DownloadConfig.initialRetryDelay * (1 << retryCount.clamp(0, 5));

    // Agregar jitter aleatorio (±30%) para evitar thundering herd
    final jitterFactor = 0.7 + (0.6 * (DateTime.now().millisecond / 1000));
    final delayWithJitter =
        Duration(milliseconds: (exponentialDelay.inMilliseconds * jitterFactor).toInt());

    return delayWithJitter;
  }

  // Verificar espacio disponible en disco
  Future<bool> _checkAvailableSpace(int requiredBytes) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return false;

      // Agregar 10% de margen de seguridad
      final requiredWithMargin = (requiredBytes * 1.1).toInt();

      // En Android, no hay API directa para espacio disponible en Dart
      // Asumimos que hay espacio suficiente si podemos crear el directorio
      // En producción, usarías un plugin como disk_space
      debugPrint(
          '💾 Espacio requerido: ${(requiredWithMargin / (1024 * 1024)).toStringAsFixed(2)} MB');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error verificando espacio: $e');
      return true; // Continuar de todos modos
    }
  }

  // ==========================================================================
  // MÉTODO SIMPLIFICADO PARA DETERMINAR ESTRATEGIA
  // ==========================================================================

  // Obtener tamaño del archivo de forma rápida con HEAD request
  Future<void> _getFileSize() async {
    try {
      final dio = _getDioInstance();
      final response = await dio.head(
        DownloadConfig.pmtilesUrl,
        options: Options(
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        setState(() {
          _totalBytes = int.tryParse(contentLength) ?? 0;
        });
        debugPrint('📊 Tamaño del archivo: ${(_totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener el tamaño del archivo: $e');
      // No es crítico, continuamos con la descarga
    }
  }

  // Decidir estrategia de descarga de forma simple y rápida
  Future<DownloadStrategy> _determineDownloadStrategy() async {
    // S3 siempre soporta Range requests, no necesitamos verificar
    // Simplemente verificamos el tipo de conexión

    final connectivity = await Connectivity().checkConnectivity();
    final hasWifi = connectivity.contains(ConnectivityResult.wifi);

    if (hasWifi) {
      debugPrint('🚀 WiFi detectado - Usando descarga PARALELA con ${DownloadConfig.maxConcurrentChunks} chunks');
      return DownloadStrategy.parallel;
    } else {
      debugPrint('📱 Conexión móvil - Usando descarga SECUENCIAL');
      return DownloadStrategy.sequential;
    }
  }

  // Crear chunks para descarga paralela
  List<ChunkInfo> _createChunks(int totalBytes, int startByte) {
    final chunks = <ChunkInfo>[];
    final chunkSize = DownloadConfig.chunkSize;

    int currentByte = startByte;
    int chunkIndex = 0;

    while (currentByte < totalBytes) {
      final endByte = (currentByte + chunkSize - 1).clamp(startByte, totalBytes - 1);

      chunks.add(ChunkInfo(
        index: chunkIndex,
        startByte: currentByte,
        endByte: endByte,
      ));

      currentByte = endByte + 1;
      chunkIndex++;
    }

    debugPrint('📦 Creados ${chunks.length} chunks de descarga');
    return chunks;
  }

  // ==========================================================================
  // MÉTODO DE DESCARGA SECUENCIAL (TRADICIONAL)
  // ==========================================================================

  Future<void> _downloadSequential(String partialFilePath, int startByte) async {
    final dio = _getDioInstance();
    _cancelToken = CancelToken();

    // ASEGURAR que WakeLock esté activo
    if (!await WakelockPlus.enabled) {
      await WakelockPlus.enable();
      debugPrint('🔋 WakeLock activado para descarga');
    }

    // Configurar Range header si es una reanudación
    Map<String, dynamic> headers = {};
    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
      debugPrint('📡 Range Request: bytes=$startByte-');
    }

    debugPrint('🚀 Iniciando descarga SECUENCIAL desde: ${DownloadConfig.pmtilesUrl}');
    debugPrint('💾 Guardando en: $partialFilePath');

    // Iniciar timers
    _startSpeedTimer();
    _startProgressSaveTimer();

    // Descargar con Dio optimizado
    await dio.download(
      DownloadConfig.pmtilesUrl,
      partialFilePath,
      cancelToken: _cancelToken,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        receiveDataWhenStatusError: true,
        followRedirects: true,
        maxRedirects: 5,
        persistentConnection: true,
      ),
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        if (_isPaused || _hasError) return;

        setState(() {
          if (startByte > 0) {
            _downloadedBytes = startByte + received;
            if (_totalBytes == 0 && total != -1) {
              _totalBytes = startByte + total;
            }
          } else {
            _downloadedBytes = received;
            if (total != -1) {
              _totalBytes = total;
            }
          }

          if (_totalBytes > 0) {
            _downloadProgress = _downloadedBytes / _totalBytes;
          }
        });

        _saveProgressIfNeeded();
      },
    );
  }

  // ==========================================================================
  // MÉTODO DE DESCARGA EN CHUNKS PARALELOS
  // ==========================================================================

  Future<void> _downloadWithChunks(String partialFilePath, int startByte) async {
    debugPrint('🚀 Iniciando descarga PARALELA con ${DownloadConfig.maxConcurrentChunks} chunks');

    // ASEGURAR que WakeLock esté activo
    if (!await WakelockPlus.enabled) {
      await WakelockPlus.enable();
      debugPrint('🔋 WakeLock activado - WiFi a máxima potencia');
    }

    // Crear chunks
    _chunks = _createChunks(_totalBytes, startByte);

    // Iniciar timers
    _startSpeedTimer();
    _startProgressSaveTimer();

    try {
      // Descargar chunks pendientes directamente en memoria y luego escribir
      final pendingChunks =
          _chunks.where((c) => !c.isComplete && !c.isDownloading).toList();

      debugPrint('📦 Total de chunks a descargar: ${pendingChunks.length}');

      // Descargar todos los chunks en paralelo
      await _downloadChunksInParallelOptimized(pendingChunks, partialFilePath);

      debugPrint('✅ Todos los chunks descargados exitosamente');
    } catch (e) {
      debugPrint('❌ Error en descarga paralela: $e');
      rethrow;
    }
  }

  // Método OPTIMIZADO de descarga paralela sin archivos temporales
  Future<void> _downloadChunksInParallelOptimized(
      List<ChunkInfo> chunks, String filePath) async {
    final dio = _getDioInstance();
    final file = File(filePath);

    // Crear o abrir archivo para escritura
    final raf = await file.open(mode: FileMode.writeOnlyAppend);

    try {
      // Crear un pool de descargas con límite de concurrencia
      final futures = <Future>[];
      int completedChunks = 0;

      for (final chunk in chunks) {
        // Esperar si hay demasiados chunks activos
        while (_activeChunks >= DownloadConfig.maxConcurrentChunks) {
          await Future.delayed(Duration(milliseconds: 50));
          if (_isPaused || _hasError || _isAppInBackground) break;
        }

        if (_isPaused || _hasError || _isAppInBackground) break;

        _activeChunks++;
        chunk.isDownloading = true;

        // Descargar chunk directamente
        final future = _downloadSingleChunkOptimized(dio, chunk, raf).then((_) {
          _activeChunks--;
          chunk.isDownloading = false;
          chunk.isComplete = true;
          completedChunks++;

          if (completedChunks % 5 == 0) {
            debugPrint('📊 Progreso: $completedChunks/${chunks.length} chunks completados');
          }
        }).catchError((e) {
          _activeChunks--;
          chunk.isDownloading = false;
          debugPrint('❌ Error en chunk ${chunk.index}: $e');
          throw e;
        });

        futures.add(future);
      }

      // Esperar a que todos terminen
      await Future.wait(futures);
      await raf.close();
    } catch (e) {
      await raf.close();
      rethrow;
    }
  }

  // Descargar un chunk directamente a memoria y escribir al archivo
  Future<void> _downloadSingleChunkOptimized(
      Dio dio, ChunkInfo chunk, RandomAccessFile file) async {
    final cancelToken = CancelToken();

    try {
      // Descargar chunk directamente a memoria
      final response = await dio.get<List<int>>(
        DownloadConfig.pmtilesUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Range': 'bytes=${chunk.startByte}-${chunk.endByte}',
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (_isPaused || _hasError || _isAppInBackground) {
            cancelToken.cancel('Descarga pausada');
            return;
          }

          chunk.downloadedBytes = received;
          _updateTotalProgress();
        },
      );

      // Escribir directamente al archivo en la posición correcta
      if (response.data != null) {
        await file.setPosition(chunk.startByte);
        await file.writeFrom(response.data!);
        await file.flush(); // Asegurar que se escriba al disco
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // Cancelación normal, no es un error
        return;
      }
      rethrow;
    }
  }

  void _updateTotalProgress() {
    int totalDownloaded = 0;

    for (final chunk in _chunks) {
      if (chunk.isComplete) {
        totalDownloaded += chunk.totalBytes;
      } else {
        totalDownloaded += chunk.downloadedBytes;
      }
    }

    setState(() {
      _downloadedBytes = totalDownloaded;
      if (_totalBytes > 0) {
        _downloadProgress = _downloadedBytes / _totalBytes;
      }
    });

    _saveProgressIfNeeded();
  }

  Future<void> _startDownload() async {
    try {
      // Verificar y solicitar permisos
      final hasPermissions = await _checkAndRequestStoragePermissions();
      if (!hasPermissions) {
        throw Exception('Permisos de almacenamiento no otorgados');
      }

      // Obtener ruta
      final String docsPath = await _getBestDocumentsPath();
      final String filePath = '$docsPath/$_fileName';
      final String partialFilePath = '$filePath.partial';
      final File finalFile = File(filePath);
      final File partialFile = File(partialFilePath);

      // Verificar si hay archivo parcial
      int startByte = 0;
      if (await partialFile.exists()) {
        startByte = await partialFile.length();
        debugPrint(
            '📦 Reanudando descarga desde: ${(startByte / (1024 * 1024)).toStringAsFixed(2)} MB');
      }

      setState(() {
        _isDownloading = true;
        _isPaused = false;
        _hasError = false;
        if (_downloadStartTime == null || _retryCount == 0) {
          _downloadStartTime = DateTime.now();
        }
        if (startByte == 0) {
          _downloadedBytes = 0;
          _downloadProgress = 0.0;
        } else {
          _downloadedBytes = startByte;
        }
        _filePath = filePath;
      });

      // DETERMINAR ESTRATEGIA DE DESCARGA (solo al inicio)
      if (startByte == 0) {
        _currentStrategy = await _determineDownloadStrategy();

        // Obtener el tamaño del archivo si no lo tenemos
        if (_totalBytes == 0) {
          await _getFileSize();
        }

        debugPrint('═══════════════════════════════════════════════');
        debugPrint('📊 CONFIGURACIÓN DE DESCARGA:');
        debugPrint('   Conexión: $_connectionStatus');
        debugPrint('   Estrategia: $_currentStrategy');
        debugPrint('   Tamaño archivo: ${(_totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
        debugPrint('   Chunks paralelos: ${_currentStrategy == DownloadStrategy.parallel ? DownloadConfig.maxConcurrentChunks : 1}');
        debugPrint('   Tamaño por chunk: ${(DownloadConfig.chunkSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        debugPrint('═══════════════════════════════════════════════');
      }

      // Verificar espacio disponible
      if (_totalBytes > 0) {
        final hasSpace = await _checkAvailableSpace(_totalBytes);
        if (!hasSpace) {
          throw Exception('Espacio insuficiente en el dispositivo');
        }
      }

      // EJECUTAR DESCARGA SEGÚN ESTRATEGIA
      if (_currentStrategy == DownloadStrategy.parallel ||
          _currentStrategy == DownloadStrategy.adaptive) {
        await _downloadWithChunks(partialFilePath, startByte);
      } else {
        await _downloadSequential(partialFilePath, startByte);
      }

      debugPrint(
          '📊 Descarga completada: ${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Verificar si la descarga está completa
      if (_downloadedBytes >= _totalBytes && _totalBytes > 0) {
        // Mover archivo temporal al final
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await partialFile.rename(filePath);

        debugPrint(
            '✅ Descarga completada: $filePath (${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB)');

        // Actualizar AppState
        FFAppState().update(() {
          FFAppState().pathPmtiles = filePath;
        });

        // Limpiar progreso guardado
        await DownloadProgressManager.clear();

        setState(() {
          _filePath = filePath;
          _downloadComplete = true;
          _isDownloading = false;
          _isPaused = false;
        });

        // Liberar WakeLock al completar
        await WakelockPlus.disable();
        debugPrint('🔋 WakeLock liberado');

        _cleanupDownload();

        // Mostrar diálogo de éxito
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showSuccessDialog();
        }
      } else if (!_isPaused && !_hasError) {
        // Descarga incompleta pero sin errores - reintentar
        throw Exception('Descarga incompleta');
      }
    } catch (e) {
      rethrow; // Propagar error para manejo en _attemptDownload
    }
  }

  // Guardar progreso solo si ha cambiado significativamente
  void _saveProgressIfNeeded() {
    final bytesDifference = (_downloadedBytes - _lastSavedBytes).abs();

    if (bytesDifference >= DownloadConfig.progressSaveBytes) {
      _saveProgress();
    }
  }

  // Guardar progreso inmediatamente
  Future<void> _saveProgress() async {
    _lastSavedBytes = _downloadedBytes;

    final progress = DownloadProgressManager(
      downloadedBytes: _downloadedBytes,
      totalBytes: _totalBytes,
      filePath: _filePath,
      lastUpdate: DateTime.now(),
    );
    await progress.save();
  }

  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(
      Duration(seconds: DownloadConfig.progressSaveIntervalSeconds),
      (timer) async {
        if (!_isDownloading || _downloadComplete || _hasError) {
          timer.cancel();
          return;
        }

        // Guardar progreso periódicamente como respaldo
        await _saveProgress();
      },
    );
  }

  void _startSpeedTimer() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDownloading || _downloadStartTime == null) {
        timer.cancel();
        return;
      }

      final bytesDownloadedSinceLastCheck =
          _downloadedBytes - _lastDownloadedBytes;
      _lastDownloadedBytes = _downloadedBytes;

      // Calcular velocidad (bytes/segundo)
      final speedBytesPerSecond = bytesDownloadedSinceLastCheck;
      final speedMBPerSecond = speedBytesPerSecond / (1024 * 1024);

      // Calcular tiempo restante
      final bytesRemaining = _totalBytes - _downloadedBytes;
      final secondsRemaining =
          speedBytesPerSecond > 0 ? bytesRemaining / speedBytesPerSecond : 0;

      setState(() {
        _downloadSpeed = '${speedMBPerSecond.toStringAsFixed(2)} MB/s';

        if (secondsRemaining > 0 && secondsRemaining.isFinite) {
          final minutes = (secondsRemaining / 60).floor();
          final seconds = (secondsRemaining % 60).floor();

          if (minutes > 0) {
            _timeRemaining = '${minutes}m ${seconds}s restantes';
          } else {
            _timeRemaining = '${seconds}s restantes';
          }
        } else {
          _timeRemaining = 'Calculando...';
        }
      });
    });
  }

  Future<String> _getBestDocumentsPath() async {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('No se pudo acceder al almacenamiento externo');
    }

    final String path = '${externalDir.path}/ClickPalmData/Maps';
    final Directory targetDir = Directory(path);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return targetDir.path;
  }

  Future<bool> _checkAndRequestStoragePermissions() async {
    try {
      if (!Platform.isAndroid) return false;

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      if (sdkVersion >= 33) {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;

        if (photosStatus.isGranted && videosStatus.isGranted) return true;

        final result = await [
          Permission.photos,
          Permission.videos,
        ].request();

        return result[Permission.photos]?.isGranted == true &&
            result[Permission.videos]?.isGranted == true;
      }

      if (sdkVersion >= 30) {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isGranted) return true;

        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }

      // Android 6 - 10
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
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
                  Icons.check_circle_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Descarga Completa!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).info,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El mapa de Colombia se ha descargado\ncorrectamente y está listo para usar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
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
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _downloadComplete
                  ? _buildCompleteScreen()
                  : _hasError
                      ? _buildErrorScreen()
                      : _buildDownloadScreen(),
            ),
          ],
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
              Icons.map_rounded,
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
                  'Mapa Offline',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Colombia - PMTiles',
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
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: FlutterFlowTheme.of(context).info),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono principal
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  _isDownloading
                      ? Icons.downloading_rounded
                      : Icons.cloud_download_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 70,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Título
            Text(
              _isDownloading
                  ? (_isPaused ? 'Descarga Pausada' : 'Descargando Mapa...')
                  : 'Listo para Descargar',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtítulo
            Text(
              _isDownloading
                  ? (_isPaused
                      ? 'Descarga pausada - Esperando conexión...'
                      : 'No cierres la aplicación durante la descarga')
                  : 'Descarga el mapa de Colombia para usar sin conexión',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),

            // Estado de conexión y reintentos
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Estado de conexión
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _connectionStatus == 'Sin conexión'
                          ? FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.1)
                          : FlutterFlowTheme.of(context)
                              .success
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _connectionStatus == 'Sin conexión'
                            ? FlutterFlowTheme.of(context).error
                            : FlutterFlowTheme.of(context).success,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _connectionStatus == 'WiFi'
                              ? Icons.wifi_rounded
                              : _connectionStatus == 'Móvil'
                                  ? Icons.signal_cellular_alt_rounded
                                  : Icons.signal_wifi_off_rounded,
                          size: 14,
                          color: _connectionStatus == 'Sin conexión'
                              ? FlutterFlowTheme.of(context).error
                              : FlutterFlowTheme.of(context).success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: _connectionStatus == 'Sin conexión'
                                ? FlutterFlowTheme.of(context).error
                                : FlutterFlowTheme.of(context).success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Estrategia de descarga
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentStrategy == DownloadStrategy.parallel
                            ? FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.1)
                            : _currentStrategy == DownloadStrategy.adaptive
                                ? FlutterFlowTheme.of(context)
                                    .warning
                                    .withValues(alpha: 0.1)
                                : FlutterFlowTheme.of(context)
                                    .tertiary
                                    .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentStrategy == DownloadStrategy.parallel
                              ? FlutterFlowTheme.of(context).primary
                              : _currentStrategy == DownloadStrategy.adaptive
                                  ? FlutterFlowTheme.of(context).warning
                                  : FlutterFlowTheme.of(context).tertiary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentStrategy == DownloadStrategy.parallel
                                ? Icons.flash_on_rounded
                                : _currentStrategy == DownloadStrategy.adaptive
                                    ? Icons.auto_awesome_rounded
                                    : Icons.timer_rounded,
                            size: 14,
                            color:
                                _currentStrategy == DownloadStrategy.parallel
                                    ? FlutterFlowTheme.of(context).primary
                                    : _currentStrategy ==
                                            DownloadStrategy.adaptive
                                        ? FlutterFlowTheme.of(context).warning
                                        : FlutterFlowTheme.of(context).tertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentStrategy == DownloadStrategy.parallel
                                ? 'Paralelo ${_activeChunks}x'
                                : _currentStrategy == DownloadStrategy.adaptive
                                    ? 'Adaptativo'
                                    : 'Secuencial',
                            style: TextStyle(
                              fontSize: 12,
                              color: _currentStrategy ==
                                      DownloadStrategy.parallel
                                  ? FlutterFlowTheme.of(context).primary
                                  : _currentStrategy ==
                                          DownloadStrategy.adaptive
                                      ? FlutterFlowTheme.of(context).warning
                                      : FlutterFlowTheme.of(context).tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Indicador de reintentos
                  if (_retryCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).warning,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: FlutterFlowTheme.of(context).warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reintento $_retryCount/${DownloadConfig.maxRetries}',
                            style: TextStyle(
                              fontSize: 12,
                              color: FlutterFlowTheme.of(context).warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],


            if (_isDownloading) ...[
              const SizedBox(height: 40),

              // Barra de progreso moderna
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(20),
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
                child: Column(
                  children: [
                    // Porcentaje
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [
                              FlutterFlowTheme.of(context).primary,
                              FlutterFlowTheme.of(context).secondary,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Barra de progreso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 12,
                        child: Stack(
                          children: [
                            // Fondo
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).alternate,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            // Progreso
                            FractionallySizedBox(
                              widthFactor: _downloadProgress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      FlutterFlowTheme.of(context).primary,
                                      FlutterFlowTheme.of(context).secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Información de descarga
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descargado',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _totalBytes > 0
                                  ? '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}'
                                  : _formatBytes(_downloadedBytes),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          ],
                        ),
                        if (_downloadSpeed.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Velocidad',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _downloadSpeed,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    if (_timeRemaining.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeRemaining,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (!_isDownloading) ...[
              const SizedBox(height: 40),

              // Información del archivo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                        Icons.insert_drive_file_rounded, 'Archivo', _fileName),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        Icons.storage_rounded, 'Tamaño aprox.', '~200 MB'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.map_rounded, 'Región', 'Colombia'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Botón de descarga
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _startDownloadWithRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: FlutterFlowTheme.of(context).info,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Iniciar Descarga',
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: FlutterFlowTheme.of(context).primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).success,
                    FlutterFlowTheme.of(context).success.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: FlutterFlowTheme.of(context).info,
                size: 70,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Mapa Disponible',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'El mapa de Colombia está listo\npara usar sin conexión',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
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
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    color: FlutterFlowTheme.of(context).success,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatBytes(_downloadedBytes),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Descargado',
                    style: TextStyle(
                      fontSize: 13,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
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
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      color: FlutterFlowTheme.of(context).info,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continuar',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).error,
                    FlutterFlowTheme.of(context).error.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .error
                        .withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: FlutterFlowTheme.of(context).info,
                size: 70,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Error en la Descarga',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Ocurrió un error durante la descarga',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary,
                    FlutterFlowTheme.of(context).secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                    _retryCount = 0;
                  });
                  _startDownloadWithRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: FlutterFlowTheme.of(context).info,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Reintentar',
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
            ),
          ],
        ),
      ),
    );
  }
}
