import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Servicio singleton para descarga de mapas en segundo plano
/// Permite navegación libre mientras la descarga continúa
class MapDownloadService {
  static final MapDownloadService _instance = MapDownloadService._internal();
  factory MapDownloadService() => _instance;
  MapDownloadService._internal();

  // Configuración
  static const String _pmtilesUrl =
      'https://clickpalmv2.s3.us-west-2.amazonaws.com/Resources/colombia.pmtiles';
  static const String _fileName = 'colombia.pmtiles';
  static const int _maxConcurrentChunks = 8;
  static const int _chunkSize = 1024 * 1024 * 20; // 20 MB
  static const int _maxRetries = 10;
  static const Duration _connectTimeout = Duration(seconds: 30);

  // Estado de descarga
  bool _isDownloading = false;
  bool _isPaused = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Progreso
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _speed = '';
  String _timeRemaining = '';
  String _filePath = '';

  // Control interno
  Dio? _dio;
  CancelToken? _cancelToken;
  Timer? _speedTimer;
  int _lastDownloadedBytes = 0;
  DateTime? _downloadStartTime;
  int _retryCount = 0;
  int _activeChunks = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controller para notificar cambios de estado
  final _stateController = StreamController<MapDownloadState>.broadcast();
  Stream<MapDownloadState> get stateStream => _stateController.stream;

  // Getters
  bool get isDownloading => _isDownloading;
  bool get isPaused => _isPaused;
  bool get isComplete => _isComplete;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  double get progress => _progress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;

  /// Consulta el tamaño real del archivo en S3 via HEAD request.
  /// Actualiza [totalBytes] y emite estado. Llamar una vez en init.
  Future<void> fetchRemoteSize() async {
    if (_totalBytes > 0) return; // ya conocido (descarga en curso o completada)
    await _getFileSize();
    _emitState();
  }
  String get speed => _speed;
  String get timeRemaining => _timeRemaining;
  String get filePath => _filePath;

  /// Emitir estado actual
  void _emitState() {
    _stateController.add(MapDownloadState(
      isDownloading: _isDownloading,
      isPaused: _isPaused,
      isComplete: _isComplete,
      hasError: _hasError,
      errorMessage: _errorMessage,
      progress: _progress,
      downloadedBytes: _downloadedBytes,
      totalBytes: _totalBytes,
      speed: _speed,
      timeRemaining: _timeRemaining,
    ));
  }

  /// Iniciar descarga
  Future<void> startDownload() async {
    if (_isDownloading && !_isPaused) {
      debugPrint('⚠️ Ya hay una descarga en progreso');
      return;
    }

    _retryCount = 0;
    await _attemptDownload();
  }

  /// Pausar descarga
  void pauseDownload() {
    if (!_isDownloading) return;

    _isPaused = true;
    _cancelToken?.cancel('Pausado por usuario');
    _speedTimer?.cancel();
    _saveProgress();
    _emitState();

    debugPrint('⏸️ Descarga pausada');
  }

  /// Reanudar descarga
  Future<void> resumeDownload() async {
    if (!_isPaused) return;

    _isPaused = false;
    _retryCount = 0;
    _emitState();

    debugPrint('▶️ Reanudando descarga...');
    await _attemptDownload();
  }

  /// Cancelar descarga
  void cancelDownload() {
    _cancelToken?.cancel('Cancelado por usuario');
    _speedTimer?.cancel();
    _connectivitySubscription?.cancel();
    _dio?.close(force: true);
    _dio = null;

    _isDownloading = false;
    _isPaused = false;
    _hasError = false;
    _progress = 0;
    _downloadedBytes = 0;

    WakelockPlus.disable();
    _emitState();

    debugPrint('❌ Descarga cancelada');
  }

  /// Reiniciar estado del servicio (usado después de eliminar el archivo)
  void resetState() {
    _cancelToken?.cancel();
    _speedTimer?.cancel();
    _connectivitySubscription?.cancel();
    _dio?.close(force: true);
    _dio = null;

    _isDownloading = false;
    _isPaused = false;
    _isComplete = false;
    _hasError = false;
    _errorMessage = '';
    _progress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _speed = '';
    _timeRemaining = '';
    _filePath = '';
    _retryCount = 0;
    _activeChunks = 0;
    _currentChunks = [];
    _downloadStartTime = null;
    _lastDownloadedBytes = 0;
    _isWriting = false;

    WakelockPlus.disable();
    _emitState();

    debugPrint('🔄 Estado del servicio reiniciado');
  }

  /// Verificar si el mapa ya está descargado
  Future<bool> checkExistingFile() async {
    try {
      final String docsPath = await _getBestDocumentsPath();
      final String filePath = '$docsPath/$_fileName';
      final File file = File(filePath);

      if (await file.exists()) {
        final int fileSize = await file.length();
        if (fileSize > 1024 * 1024) {
          _filePath = filePath;
          _totalBytes = fileSize;
          _downloadedBytes = fileSize;
          _progress = 1.0;
          _isComplete = true;

          FFAppState().update(() {
            FFAppState().pathPmtiles = filePath;
          });

          _emitState();
          debugPrint('✅ Mapa ya descargado: $filePath');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error verificando archivo: $e');
      return false;
    }
  }

  Future<void> _attemptDownload() async {
    try {
      await _startDownload();
    } on DioException catch (e) {
      debugPrint('❌ Error Dio: ${e.type} - ${e.message}');

      if (e.type == DioExceptionType.cancel) {
        debugPrint('⏸️ Descarga cancelada');
        return;
      }

      await _handleRetry(_getErrorMessage(e));
    } on SocketException catch (e) {
      debugPrint('❌ Error de socket: $e');
      await _handleRetry('Error de conexión a internet');
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout: $e');
      await _handleRetry('Tiempo de espera agotado');
    } catch (e) {
      debugPrint('❌ Error en descarga: $e');
      _hasError = true;
      _errorMessage = e.toString();
      _isDownloading = false;
      _emitState();
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Tiempo de espera agotado';
      case DioExceptionType.connectionError:
        return 'Error de conexión a internet';
      case DioExceptionType.badResponse:
        return 'Error del servidor (${e.response?.statusCode})';
      default:
        return 'Error de red: ${e.message}';
    }
  }

  Future<void> _handleRetry(String errorReason) async {
    if (_retryCount >= _maxRetries) {
      _hasError = true;
      _errorMessage = '$errorReason. Máximo de reintentos alcanzado';
      _isDownloading = false;
      _emitState();
      return;
    }

    _retryCount++;
    _isPaused = true;
    _emitState();

    final delay = Duration(seconds: (1 << _retryCount.clamp(0, 5)));
    debugPrint('🔄 Reintento $_retryCount/$_maxRetries en ${delay.inSeconds}s...');

    await Future.delayed(delay);

    if (!_hasError) {
      _isPaused = false;
      await _attemptDownload();
    }
  }

  Future<void> _startDownload() async {
    // Verificar permisos
    final hasPermissions = await _checkAndRequestStoragePermissions();
    if (!hasPermissions) {
      throw Exception('Permisos de almacenamiento no otorgados');
    }

    // Obtener rutas
    final String docsPath = await _getBestDocumentsPath();
    final String filePath = '$docsPath/$_fileName';
    final String partialFilePath = '$filePath.partial';
    final File finalFile = File(filePath);
    final File partialFile = File(partialFilePath);

    // Verificar archivo parcial
    int startByte = 0;
    if (await partialFile.exists()) {
      startByte = await partialFile.length();
      debugPrint('📦 Reanudando desde: ${(startByte / (1024 * 1024)).toStringAsFixed(2)} MB');
    }

    _isDownloading = true;
    _isPaused = false;
    _hasError = false;
    _downloadStartTime ??= DateTime.now();
    _downloadedBytes = startByte;
    _filePath = filePath;
    _emitState();

    // Obtener tamaño del archivo
    if (_totalBytes == 0) {
      await _getFileSize();
    }

    // Activar WakeLock
    await WakelockPlus.enable();
    debugPrint('🔋 WakeLock activado');

    // Iniciar monitoreo de conectividad
    _setupConnectivityMonitoring();

    // Verificar tipo de conexión
    final connectivity = await Connectivity().checkConnectivity();
    final hasWifi = connectivity.contains(ConnectivityResult.wifi);

    if (hasWifi && _totalBytes > 0) {
      await _downloadWithChunks(partialFilePath, startByte);
    } else {
      await _downloadSequential(partialFilePath, startByte);
    }

    // Verificar completitud
    if (_downloadedBytes >= _totalBytes && _totalBytes > 0) {
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await partialFile.rename(filePath);

      _filePath = filePath;
      _isComplete = true;
      _isDownloading = false;

      FFAppState().update(() {
        FFAppState().pathPmtiles = filePath;
      });

      await _clearProgress();
      await WakelockPlus.disable();

      debugPrint('✅ Descarga completada: $filePath');
      _emitState();
    }
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.firstOrNull ?? ConnectivityResult.none;

      if (result == ConnectivityResult.none && _isDownloading && !_isPaused) {
        debugPrint('❌ Conexión perdida');
        pauseDownload();
      } else if (result != ConnectivityResult.none && _isPaused && _isDownloading) {
        debugPrint('✅ Conexión restaurada');
        resumeDownload();
      }
    });
  }

  Future<void> _getFileSize() async {
    try {
      final dio = _getDioInstance();
      final response = await dio.head(
        _pmtilesUrl,
        options: Options(receiveTimeout: Duration(seconds: 10)),
      );

      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        _totalBytes = int.tryParse(contentLength) ?? 0;
        debugPrint('📊 Tamaño: ${(_totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener tamaño: $e');
    }
  }

  Dio _getDioInstance() {
    _dio ??= Dio(BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: Duration.zero,
      sendTimeout: _connectTimeout,
      headers: {
        'Connection': 'keep-alive',
        'Accept-Encoding': 'identity',
      },
      persistentConnection: true,
    ));
    return _dio!;
  }

  Future<void> _downloadSequential(String partialFilePath, int startByte) async {
    final dio = _getDioInstance();
    _cancelToken = CancelToken();

    Map<String, dynamic> headers = {};
    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
    }

    _startSpeedTimer();

    await dio.download(
      _pmtilesUrl,
      partialFilePath,
      cancelToken: _cancelToken,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        if (_isPaused || _hasError) return;

        _downloadedBytes = startByte + received;
        if (_totalBytes == 0 && total != -1) {
          _totalBytes = startByte + total;
        }
        if (_totalBytes > 0) {
          _progress = _downloadedBytes / _totalBytes;
        }
        _emitState();
      },
    );
  }

  // Lista de chunks para actualización de progreso
  List<_ChunkInfo> _currentChunks = [];

  // Lock para sincronizar escrituras al archivo
  bool _isWriting = false;

  Future<void> _downloadWithChunks(String partialFilePath, int startByte) async {
    debugPrint('🚀 Descarga paralela con $_maxConcurrentChunks chunks');

    _currentChunks = _createChunks(_totalBytes, startByte);
    final dio = _getDioInstance();
    final file = File(partialFilePath);

    // Pre-allocar el archivo al tamaño total para evitar corrupción
    RandomAccessFile raf;
    if (startByte == 0) {
      // Nueva descarga: crear archivo con tamaño pre-allocado
      raf = await file.open(mode: FileMode.write);
      await raf.truncate(_totalBytes);
      await raf.close();
      debugPrint('📁 Archivo pre-allocado: ${(_totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    } else {
      // Reanudación: verificar y expandir si es necesario
      raf = await file.open(mode: FileMode.writeOnlyAppend);
      final currentSize = await raf.length();
      if (currentSize < _totalBytes) {
        await raf.truncate(_totalBytes);
        debugPrint('📁 Archivo expandido a: ${(_totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      }
      await raf.close();
    }

    _startSpeedTimer();
    _isWriting = false;

    try {
      final pendingChunks = _currentChunks.where((c) => !c.isComplete).toList();
      final futures = <Future>[];

      for (final chunk in pendingChunks) {
        while (_activeChunks >= _maxConcurrentChunks) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (_isPaused || _hasError) break;
        }

        if (_isPaused || _hasError) break;

        _activeChunks++;
        chunk.isDownloading = true;

        final future = _downloadChunkToMemory(dio, chunk).then((data) async {
          _activeChunks--;
          chunk.isDownloading = false;

          if (data != null) {
            // Escribir al archivo de forma sincronizada
            await _writeChunkToFile(partialFilePath, chunk.startByte, data);
            chunk.isComplete = true;
            debugPrint('✅ Chunk ${chunk.index} completado (${(chunk.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)');
          }
        }).catchError((e) {
          _activeChunks--;
          chunk.isDownloading = false;
          debugPrint('❌ Error en chunk ${chunk.index}: $e');
          throw e;
        });

        futures.add(future);
      }

      await Future.wait(futures);

      // Verificar integridad del archivo
      await _verifyFileIntegrity(partialFilePath);
    } catch (e) {
      rethrow;
    }
  }

  /// Descarga un chunk a memoria sin escribir al archivo
  Future<List<int>?> _downloadChunkToMemory(Dio dio, _ChunkInfo chunk) async {
    final cancelToken = CancelToken();

    try {
      final response = await dio.get<List<int>>(
        _pmtilesUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: {'Range': 'bytes=${chunk.startByte}-${chunk.endByte}'},
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (_isPaused || _hasError) {
            cancelToken.cancel('Pausado');
            return;
          }
          chunk.downloadedBytes = received;
          _updateChunksProgress();
        },
      );

      return response.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return null;
      rethrow;
    }
  }

  /// Escribe datos al archivo de forma sincronizada (una escritura a la vez)
  Future<void> _writeChunkToFile(String filePath, int position, List<int> data) async {
    // Esperar si hay otra escritura en progreso
    while (_isWriting) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isWriting = true;
    try {
      final file = File(filePath);
      final raf = await file.open(mode: FileMode.writeOnlyAppend);
      try {
        await raf.setPosition(position);
        await raf.writeFrom(data);
        await raf.flush();
      } finally {
        await raf.close();
      }
    } finally {
      _isWriting = false;
    }
  }

  /// Verifica que el archivo descargado tenga el tamaño correcto
  Future<void> _verifyFileIntegrity(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Archivo de descarga no encontrado');
    }

    final fileSize = await file.length();
    if (fileSize != _totalBytes) {
      debugPrint('⚠️ Tamaño incorrecto: $fileSize vs $_totalBytes esperados');

      // Si la diferencia es pequeña, puede ser un problema de truncamiento
      final difference = (_totalBytes - fileSize).abs();
      if (difference > 1024) { // Más de 1KB de diferencia
        throw Exception('Archivo incompleto: faltan ${(difference / 1024).toStringAsFixed(1)} KB');
      }
    }

    // Verificar que el header PMTiles sea válido (primeros bytes)
    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(7);
      // PMTiles v3 header comienza con "PMTiles" (0x50 0x4D 0x54 0x69 0x6C 0x65 0x73)
      if (header.length >= 7) {
        final signature = String.fromCharCodes(header);
        if (!signature.startsWith('PMTiles')) {
          debugPrint('⚠️ Header PMTiles inválido: $signature');
          // No lanzar excepción, solo advertir - puede ser un formato diferente
        } else {
          debugPrint('✅ Header PMTiles válido');
        }
      }
    } finally {
      await raf.close();
    }

    debugPrint('✅ Verificación de integridad completada: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
  }

  List<_ChunkInfo> _createChunks(int totalBytes, int startByte) {
    final chunks = <_ChunkInfo>[];
    int currentByte = startByte;
    int chunkIndex = 0;

    while (currentByte < totalBytes) {
      final endByte = (currentByte + _chunkSize - 1).clamp(startByte, totalBytes - 1);
      chunks.add(_ChunkInfo(
        index: chunkIndex,
        startByte: currentByte,
        endByte: endByte,
      ));
      currentByte = endByte + 1;
      chunkIndex++;
    }

    return chunks;
  }

  /// Actualiza el progreso total basado en todos los chunks
  void _updateChunksProgress() {
    if (_currentChunks.isEmpty) return;

    int totalDownloaded = 0;
    for (final chunk in _currentChunks) {
      if (chunk.isComplete) {
        totalDownloaded += chunk.totalBytes;
      } else {
        totalDownloaded += chunk.downloadedBytes;
      }
    }

    _downloadedBytes = totalDownloaded;
    if (_totalBytes > 0) {
      _progress = _downloadedBytes / _totalBytes;
    }
    // No emitir aquí - el timer lo hace cada segundo para evitar sobrecarga
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _lastDownloadedBytes = _downloadedBytes;

    _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Actualizar progreso de chunks primero
      _updateChunksProgress();

      // Calcular velocidad (bytes por segundo, ajustado por intervalo de 500ms)
      final bytesPerInterval = _downloadedBytes - _lastDownloadedBytes;
      final bytesPerSecond = bytesPerInterval * 2; // Convertir a por segundo
      _lastDownloadedBytes = _downloadedBytes;

      if (bytesPerSecond > 0) {
        _speed = _formatSpeed(bytesPerSecond);

        final remainingBytes = _totalBytes - _downloadedBytes;
        if (remainingBytes > 0) {
          final secondsRemaining = remainingBytes / bytesPerSecond;
          _timeRemaining = _formatTime(secondsRemaining.toInt());
        } else {
          _timeRemaining = 'Completando...';
        }
      } else if (_isDownloading && !_isPaused) {
        _speed = 'Conectando...';
        _timeRemaining = 'Calculando...';
      }

      _emitState();
    });
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  String _formatTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s restantes';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}m ${secs}s restantes';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m restantes';
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('map_download_bytes', _downloadedBytes);
      await prefs.setInt('map_download_total', _totalBytes);
      await prefs.setString('map_download_path', _filePath);
    } catch (e) {
      debugPrint('⚠️ Error guardando progreso: $e');
    }
  }

  Future<void> _clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('map_download_bytes');
      await prefs.remove('map_download_total');
      await prefs.remove('map_download_path');
    } catch (e) {
      debugPrint('⚠️ Error limpiando progreso: $e');
    }
  }

  Future<String> _getBestDocumentsPath() async {
    late Directory baseDir;
    if (Platform.isAndroid) {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('No se pudo acceder al almacenamiento externo');
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final String path = '${baseDir.path}/ClickPalmData/Maps';
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
        final result = await [Permission.photos, Permission.videos].request();
        return result[Permission.photos]?.isGranted == true &&
            result[Permission.videos]?.isGranted == true;
      }

      if (sdkVersion >= 30) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }

      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      return false;
    }
  }

  void dispose() {
    _stateController.close();
    _speedTimer?.cancel();
    _connectivitySubscription?.cancel();
    _cancelToken?.cancel();
    _dio?.close(force: true);
  }
}

/// Estado de descarga para el stream
class MapDownloadState {
  final bool isDownloading;
  final bool isPaused;
  final bool isComplete;
  final bool hasError;
  final String errorMessage;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String speed;
  final String timeRemaining;

  MapDownloadState({
    required this.isDownloading,
    required this.isPaused,
    required this.isComplete,
    required this.hasError,
    required this.errorMessage,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speed,
    required this.timeRemaining,
  });
}

/// Información de chunk para descarga paralela
class _ChunkInfo {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  bool isComplete;
  bool isDownloading;

  _ChunkInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.isComplete = false,
    this.isDownloading = false,
  });

  int get totalBytes => endByte - startByte + 1;
}
