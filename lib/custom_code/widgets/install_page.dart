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
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../actions/persistent_id_paths.dart';
import '../actions/backup_storage_paths.dart';

// ============================================================================
// CONFIGURACIÓN DE ACTUALIZACIÓN
// ============================================================================

class UpdateConfig {
  static const String apiBaseUrl = 'https://api.clickpalm.com';
  static const String s3BaseUrl =
      'https://clickpalmv2.s3.us-west-2.amazonaws.com';
  static const String s3Prefix = 'Installers/Versions';
  static const int maxRetries = 5;
  static const Duration chunkTimeout = Duration(seconds: 30);
  static const Duration initialRetryDelay = Duration(seconds: 2);
}

// ============================================================================
// MODELO DE VERSIÓN
// ============================================================================

class AppVersion {
  final int versionNumber;
  final String fileName;
  final String downloadUrl;
  final int? fileSizeBytes;

  AppVersion({
    required this.versionNumber,
    required this.fileName,
    required this.downloadUrl,
    this.fileSizeBytes,
  });

  factory AppVersion.fromS3Object(Map<String, dynamic> json) {
    // Extraer número de versión del key
    // Ejemplo: "Installers/Versions/Version17/ClickPalm APP-release (17).apk" -> 17
    final key = json['key'] as String? ?? '';
    final regex = RegExp(r'Version(\d+)');
    final match = regex.firstMatch(key);
    final versionNumber = match != null ? int.parse(match.group(1)!) : 0;

    // Usar la URL ya proporcionada por la API
    final url = json['url'] as String? ?? '';

    return AppVersion(
      versionNumber: versionNumber,
      fileName: json['fileName'] as String? ?? key.split('/').last,
      downloadUrl: url.isNotEmpty ? url : '${UpdateConfig.s3BaseUrl}/$key',
      fileSizeBytes: json['size'] as int?,
    );
  }
}

// ============================================================================
// WIDGET PRINCIPAL - ACTUALIZACIÓN DE APP
// ============================================================================

class InstallPage extends StatefulWidget {
  const InstallPage({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<InstallPage> createState() => _InstallPageState();
}

class _InstallPageState extends State<InstallPage>
    with SingleTickerProviderStateMixin {
  // Estado general
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _downloadComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _statusMessage = 'Verificando actualizaciones...';

  // Información de versiones
  int _currentVersion = 0;
  AppVersion? _latestVersion;
  bool _updateAvailable = false;

  // Progreso de descarga
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _downloadSpeed = '';
  String _timeRemaining = '';

  // Ruta del APK descargado
  String _apkFilePath = '';

  // Desinstalación completa
  bool _isUninstalling = false;
  String _uninstallStatus = '';

  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Conectividad y reintentos
  int _retryCount = 0;
  bool _isPaused = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _connectionStatus = 'Verificando...';
  DateTime? _downloadStartTime;
  Timer? _speedTimer;
  int _lastDownloadedBytes = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupConnectivityMonitoring();
    _initialize();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speedTimer?.cancel();
    _connectivitySubscription?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // INICIALIZACIÓN Y VERIFICACIÓN DE VERSIÓN
  // ==========================================================================

  Future<void> _initialize() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Obteniendo versión actual...';
      });

      // Obtener versión actual de la app
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('📱 Versión actual instalada: $_currentVersion');

      setState(() {
        _statusMessage = 'Consultando servidor...';
      });

      // Obtener última versión disponible
      await _fetchLatestVersion();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error en inicialización: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error al verificar actualizaciones: $e';
      });
    }
  }

  Future<void> _fetchLatestVersion() async {
    try {
      final dio = Dio();

      // Llamar al endpoint /S3Files/list con prefix de versiones
      final response = await dio.get(
        '${UpdateConfig.apiBaseUrl}/S3Files/list',
        queryParameters: {
          'prefix': UpdateConfig.s3Prefix,
          'maxKeys': 100,
        },
      );

      debugPrint('📡 Respuesta API S3Files: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Verificar si la respuesta tiene la estructura correcta
        if (responseData is! Map<String, dynamic> ||
            responseData['success'] != true) {
          throw Exception('Respuesta del servidor inválida');
        }

        final data = responseData['data'] as Map<String, dynamic>? ?? {};

        // Parsear archivos del bucket (la API devuelve 'files', no 'Contents')
        final files = (data['files'] as List?) ?? [];

        debugPrint('📦 Archivos encontrados: ${files.length}');

        // Filtrar solo APKs y extraer versiones
        final versions = files
            .where((file) {
          final key = file['key'] as String? ?? '';
          return key.toLowerCase().endsWith('.apk');
        })
            .map((file) => AppVersion.fromS3Object(file))
            .where((v) => v.versionNumber > 0)
            .toList();

        // Ordenar por número de versión descendente
        versions.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));

        debugPrint(
            '🔢 Versiones válidas encontradas: ${versions.map((v) => v.versionNumber).toList()}');

        if (versions.isNotEmpty) {
          _latestVersion = versions.first;
          _updateAvailable = _latestVersion!.versionNumber > _currentVersion;

          debugPrint(
              '✅ Última versión disponible: ${_latestVersion!.versionNumber}');
          debugPrint('🔄 Actualización disponible: $_updateAvailable');

          if (_updateAvailable) {
            setState(() {
              _statusMessage =
                  'Nueva versión disponible: ${_latestVersion!.versionNumber}';
            });
          } else {
            setState(() {
              _statusMessage = 'Ya tienes la última versión instalada';
            });
          }
        } else {
          throw Exception('No se encontraron versiones válidas en el servidor');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo última versión: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // GESTIÓN DE CONECTIVIDAD
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
    setState(() {
      _isPaused = true;
    });
    _cancelToken?.cancel('Descarga pausada por pérdida de conexión');
    _speedTimer?.cancel();
    debugPrint('⏸️ Descarga pausada');
  }

  void _resumeDownload() async {
    if (!_isPaused) return;

    setState(() {
      _isPaused = false;
      _retryCount = 0;
    });

    debugPrint('▶️ Reanudando descarga...');
    await _startDownloadWithRetry();
  }

  // ==========================================================================
  // DESCARGA DEL APK
  // ==========================================================================

  Future<void> _startDownloadWithRetry() async {
    _retryCount = 0;
    await _attemptDownload();
  }

  Future<void> _attemptDownload() async {
    try {
      await _downloadApk();
    } on SocketException catch (e) {
      debugPrint('❌ Error de red: $e');
      await _handleRetry('Error de conexión a internet');
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout: $e');
      await _handleRetry('Tiempo de espera agotado');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('🛑 Descarga cancelada');
        return;
      }
      debugPrint('🌐 Error Dio: $e');
      await _handleRetry('Error de descarga');
    } catch (e) {
      debugPrint('❌ Error en descarga: $e');

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
    if (_retryCount >= UpdateConfig.maxRetries) {
      setState(() {
        _hasError = true;
        _errorMessage =
            '$errorReason. Máximo de reintentos alcanzado (${UpdateConfig.maxRetries})';
        _isDownloading = false;
        _isPaused = false;
      });

      _cleanupDownload();
      return;
    }

    _retryCount++;
    final delay = UpdateConfig.initialRetryDelay * _retryCount;

    setState(() {
      _isPaused = true;
    });

    debugPrint(
        '🔄 Reintento $_retryCount/${UpdateConfig.maxRetries} en ${delay.inSeconds}s...');
    debugPrint('   Razón: $errorReason');

    await Future.delayed(delay);

    if (mounted && !_hasError) {
      setState(() {
        _isPaused = false;
      });
      await _attemptDownload();
    }
  }

  void _cleanupDownload() {
    _speedTimer?.cancel();
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  Future<void> _downloadApk() async {
    if (_latestVersion == null) {
      throw Exception('No se ha especificado versión para descargar');
    }

    try {
      // Verificar permisos
      final hasPermissions = await _checkAndRequestInstallPermissions();
      if (!hasPermissions) {
        throw Exception('Permisos necesarios no otorgados');
      }

      // Obtener ruta de almacenamiento
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('No se pudo acceder al almacenamiento');
      }

      final String downloadPath = '${externalDir.path}/ClickPalmData/Updates';
      final Directory downloadDir = Directory(downloadPath);

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      _apkFilePath = '$downloadPath/${_latestVersion!.fileName}';
      final File apkFile = File(_apkFilePath);

      // Si ya existe, eliminarlo
      if (await apkFile.exists()) {
        await apkFile.delete();
        debugPrint('🗑️ APK anterior eliminado');
      }

      setState(() {
        _isDownloading = true;
        _isPaused = false;
        _hasError = false;
        _downloadStartTime = DateTime.now();
        _downloadedBytes = 0;
        _downloadProgress = 0.0;
      });

      debugPrint('🚀 Descargando desde: ${_latestVersion!.downloadUrl}');
      debugPrint('📁 Guardando en: $_apkFilePath');

      // Iniciar timer de velocidad
      _startSpeedTimer();

      _cancelToken = CancelToken();

      // Intentar descarga con Dio; si falla por redirect S3, usar HttpClient
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 300),
          followRedirects: true,
          maxRedirects: 5,
        ));

        await dio.download(
          _latestVersion!.downloadUrl,
          _apkFilePath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadedBytes = received;
                _totalBytes = total;
                _downloadProgress = received / total;
              });
            }
          },
        );
      } catch (e) {
        // S3 devuelve 301 con endpoint en XML body (sin Location header)
        // Dart HttpClient no puede seguir este redirect, así que lo manejamos manualmente
        if (e.toString().contains('RedirectException') ||
            e.toString().contains('Location header')) {
          debugPrint(
              '⚠️ Redirect S3 sin Location header, descargando con HttpClient directo...');
          await _downloadWithHttpClient(
            _latestVersion!.downloadUrl,
            _apkFilePath,
          );
        } else {
          rethrow;
        }
      }

      debugPrint(
          '✅ Descarga completada: ${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB');

      setState(() {
        _downloadComplete = true;
        _isDownloading = false;
        _isPaused = false;
      });

      _cleanupDownload();

      // Mostrar diálogo de confirmación para instalar
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showInstallConfirmationDialog();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Descarga usando dart:io HttpClient para manejar redirects S3 problemáticos.
  /// S3 a veces devuelve 301 con el endpoint correcto en el body XML,
  /// no en el header Location. Dart HttpClient lanza RedirectException en este caso.
  Future<void> _downloadWithHttpClient(String url, String filePath) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = false;
      request.maxRedirects = 0;
      final response = await request.close();

      debugPrint(
          '📡 HttpClient status: ${response.statusCode} para $url');

      if (response.statusCode == 200) {
        // Respuesta directa - descargar normalmente
        await _streamResponseToFile(response, filePath);
      } else if (response.statusCode >= 300 && response.statusCode < 400) {
        // Redirect - intentar extraer endpoint del body XML de S3
        final body = await response.transform(utf8.decoder).join();
        debugPrint('📡 S3 redirect body: $body');

        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          // Tiene Location header - seguir redirect
          final redirectUrl = location.startsWith('http')
              ? location
              : Uri.parse(url).resolve(location).toString();
          debugPrint('🔄 Siguiendo redirect → $redirectUrl');
          client.close();
          return _downloadWithHttpClient(redirectUrl, filePath);
        }

        // Sin Location - extraer endpoint del XML de S3
        final endpointMatch =
            RegExp(r'<Endpoint>([^<]+)</Endpoint>').firstMatch(body);
        if (endpointMatch != null) {
          final correctEndpoint = endpointMatch.group(1)!;
          final uri = Uri.parse(url);
          final correctedUrl = 'https://$correctEndpoint${uri.path}';
          debugPrint('🔄 Endpoint S3 corregido: $correctedUrl');
          client.close();
          return _downloadWithHttpClient(correctedUrl, filePath);
        }

        // Último recurso: intentar sin región explícita en la URL
        final noRegionUrl = url.replaceFirst(
          RegExp(r'\.s3\.[a-z0-9-]+\.amazonaws\.com'),
          '.s3.amazonaws.com',
        );
        if (noRegionUrl != url) {
          debugPrint('🔄 Intentando URL sin región: $noRegionUrl');
          client.close();
          return _downloadWithHttpClient(noRegionUrl, filePath);
        }

        throw Exception(
            'S3 redirect sin destino válido (status ${response.statusCode})');
      } else {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Error HTTP ${response.statusCode}: $body');
      }
    } finally {
      client.close();
    }
  }

  /// Streams una respuesta HTTP a un archivo, actualizando progreso
  Future<void> _streamResponseToFile(
      HttpClientResponse response, String filePath) async {
    final file = File(filePath);
    final sink = file.openWrite();
    final total = response.contentLength;
    int received = 0;

    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (mounted && total > 0) {
        setState(() {
          _downloadedBytes = received;
          _totalBytes = total;
          _downloadProgress = received / total;
        });
      }
    }

    await sink.flush();
    await sink.close();

    debugPrint(
        '✅ Descarga HttpClient completada: '
        '${(received / (1024 * 1024)).toStringAsFixed(2)} MB');
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
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

  // ==========================================================================
  // INSTALACIÓN DEL APK
  // ==========================================================================

  Future<void> _installApk() async {
    try {
      // Mostrar diálogo de progreso
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context).primary,
                  FlutterFlowTheme.of(context).secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).info,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Iniciando instalación...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).info,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor, confirma en la ventana de instalación del sistema',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      debugPrint('📦 Iniciando instalación: $_apkFilePath');

      // Validar que el archivo APK existe
      final apkFile = File(_apkFilePath);
      if (!await apkFile.exists()) {
        if (mounted) Navigator.pop(context);
        throw Exception('Archivo APK no encontrado en: $_apkFilePath');
      }

      // Validar tamaño del archivo
      final fileSize = await apkFile.length();
      if (fileSize <= 0) {
        if (mounted) Navigator.pop(context);
        throw Exception('Archivo APK está vacío (${fileSize} bytes)');
      }
      
      debugPrint('✅ APK validado: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Verificar permisos de instalación nuevamente
      final hasPermissions = await _checkAndRequestInstallPermissions();
      if (!hasPermissions) {
        if (mounted) Navigator.pop(context);
        throw Exception('No se otorgó permiso para instalar paquetes. Por favor, habilita esto en Configuración > Apps > Acceso especial > Instalar apps desconocidas');
      }

      debugPrint('✅ Permisos validados');

      // Instalar usando install_plugin
      debugPrint('🚀 Enviando intent de instalación a través de install_plugin');
      await InstallPlugin.install(_apkFilePath);

      debugPrint('✅ Intent de instalación enviado correctamente');

      // Pequeño delay para asegurar que el diálogo se vea
      await Future.delayed(const Duration(milliseconds: 1000));

      // Cerrar el diálogo de progreso si todavía está abierto
      if (mounted) {
        Navigator.pop(context);
      }

      // Mostrar mensaje de éxito temporal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Abriendo instalador del sistema...'),
            backgroundColor: FlutterFlowTheme.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ Proceso de instalación completado. La app se cerrará cuando el usuario confirme');
      
    } catch (e) {
      debugPrint('❌ Error en instalación: $e');
      
      // Cerrar el diálogo de progreso si está abierto
      if (mounted && Navigator.canPop(context)) {
        try {
          Navigator.pop(context);
        } catch (e) {
          debugPrint('⚠️ Error cerrando diálogo de progreso: $e');
        }
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error en instalación: $e';
        });

        // Mostrar diálogo de error detallado
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: FlutterFlowTheme.of(context).info,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error en la instalación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).info,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context).info.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: FlutterFlowTheme.of(context).info,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).info,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Entendido',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).error,
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
    }
  }

  Future<bool> _checkAndRequestInstallPermissions() async {
    try {
      if (!Platform.isAndroid) return false;

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      // Android 8+ requiere permiso para instalar apps desconocidas
      if (sdkVersion >= 26) {
        final status = await Permission.requestInstallPackages.status;

        if (status.isGranted) {
          debugPrint('✅ Permiso de instalación ya otorgado');
          return true;
        }

        debugPrint('📋 Solicitando permiso de instalación...');
        final result = await Permission.requestInstallPackages.request();

        if (result.isGranted) {
          debugPrint('✅ Permiso de instalación otorgado');
          return true;
        } else {
          debugPrint('❌ Permiso de instalación denegado');
          return false;
        }
      }

      // Android < 8 no requiere permiso especial
      return true;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  // ==========================================================================
  // DIÁLOGOS
  // ==========================================================================

  void _showInstallConfirmationDialog() {
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
                  Icons.system_update_rounded,
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
                'La actualización se ha descargado correctamente.\n¿Deseas instalarla ahora?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Versión ${_latestVersion!.versionNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: TextStyle(
                        fontSize: 14,
                        color: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '⚠️ Tus datos se conservarán durante la actualización',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      FlutterFlowTheme.of(context).info.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context)
                            .info
                            .withValues(alpha: 0.2),
                        foregroundColor: FlutterFlowTheme.of(context).info,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Más tarde',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _installApk();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).info,
                        foregroundColor: FlutterFlowTheme.of(context).success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Instalar',
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
      ),
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

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
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingScreen()
                      : _hasError
                          ? _buildErrorScreen()
                          : _downloadComplete
                              ? _buildCompleteScreen()
                              : _isDownloading
                                  ? _buildDownloadingScreen()
                                  : _buildUpdateAvailableScreen(),
                ),
              ],
            ),
            _buildUninstallingOverlay(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DESINSTALACIÓN COMPLETA
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _showCompleteUninstallDialog() async {
    // Primera confirmación
    final first = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Color(0xFFFF5252), size: 28),
            SizedBox(width: 10),
            Text('Desinstalación Completa',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Se eliminarán permanentemente:',
                  style: TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...[
                '• Todos los datos de sesión y configuración',
                '• Base de datos SQLite (visitas, puntos, etc.)',
                '• ID de dispositivo persistente',
                '• Todos los backups guardados',
                '• Modelo de voz IA (Gemma)',
                '• Mapas descargados (pmtiles)',
              ].map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(t, style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
              )),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '⚠️ Esta acción no se puede deshacer.',
                  style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    // Segunda confirmación
    final second = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Completamente seguro?',
            style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
        content: const Text(
          'Esta es su última oportunidad. Todos los archivos y datos de la aplicación serán eliminados de forma irreversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, cancelar', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SÍ, ELIMINAR TODO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (second != true || !mounted) return;
    await _performCompleteUninstall();
  }

  Future<void> _performCompleteUninstall() async {
    if (!mounted) return;
    setState(() {
      _isUninstalling = true;
      _uninstallStatus = 'Limpiando preferencias...';
    });

    try {
      // 1. SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _setStatus('Reiniciando estado de la app...');

      // 2. FFAppState en memoria
      FFAppState().update(() {
        FFAppState().isSync = false;
        FFAppState().loginResponse = null;
        FFAppState().userSelected = UsersStruct();
        FFAppState().companyDefault = CompaniesStruct();
        FFAppState().deviceDefault = DevicesStruct();
        FFAppState().activityDefault = ActivitiesStruct();
        FFAppState().activitySelected = ActivitiesStruct();
        FFAppState().headquarterSelected = HeadquartersStruct();
        FFAppState().headquartersList = [];
        FFAppState().productsList = [];
        FFAppState().usersList = [];
        FFAppState().zonesList = [];
        FFAppState().visitsAdd = [];
        FFAppState().pathDatabase = '';
        FFAppState().androidID = '';
        FFAppState().isCalibrateVoice = false;
        FFAppState().calibrateCompass = false;
        FFAppState().listVoiceCalibration = [];
        FFAppState().currentActivity = null;
        FFAppState().pathPmtiles = ' ';
        FFAppState().geoLocationsList = [];
        FFAppState().visitDetails = [];
        FFAppState().headquartersSelectedList = [];
        FFAppState().newsList = [];
        FFAppState().newsSelected = [];
        FFAppState().activitiesStatusSelected = [];
        FFAppState().newsAdd = [];
        FFAppState().StatusAdd = [];
        FFAppState().lastLineInstall = 0;
        FFAppState().lastPalmInstall = 0;
      });

      // 3. Base de datos SQLite — eliminar carpeta ClickPalmData completa
      _setStatus('Eliminando base de datos...');
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final dbFolder = Directory('${extDir.path}/ClickPalmData');
          if (await dbFolder.exists()) await dbFolder.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando ClickPalmData: $e');
      }

      // 4. persistent_id.txt en todas las rutas accesibles
      _setStatus('Eliminando ID de dispositivo...');
      try {
        final paths = await discoverWritablePaths();
        for (final dirPath in paths.values) {
          final file = File('$dirPath/persistent_id.txt');
          if (await file.exists()) await file.delete();
        }
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando persistent_id: $e');
      }

      // 5. Backups en todas las rutas
      _setStatus('Eliminando backups...');
      try {
        final backupFolders = await findAllBackupFolders();
        for (final folder in backupFolders) {
          if (await folder.exists()) await folder.delete(recursive: true);
        }
        // También eliminar carpetas Backups/ raíz vacías
        final paths = await discoverWritablePaths();
        for (final dirPath in paths.values) {
          final backupsRoot = Directory('$dirPath/Backups');
          if (await backupsRoot.exists()) await backupsRoot.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando backups: $e');
      }

      // 6. Modelo de voz Gemma
      _setStatus('Eliminando modelo de IA...');
      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        final modelFile = File('${appDocsDir.path}/gemma3-1b-it-int4.task');
        if (await modelFile.exists()) await modelFile.delete();
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando modelo Gemma: $e');
      }

      // 7. Archivo pmtiles
      _setStatus('Eliminando mapas...');
      try {
        final pmtilesPath = FFAppState().pathPmtiles.trim();
        if (pmtilesPath.isNotEmpty) {
          final f = File(pmtilesPath);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando pmtiles: $e');
      }

      // 8. APK descargado previamente
      try {
        if (_apkFilePath.isNotEmpty) {
          final apk = File(_apkFilePath);
          if (await apk.exists()) await apk.delete();
        }
      } catch (e) {
        debugPrint('⚠️ [uninstall] Error borrando APK: $e');
      }

      if (!mounted) return;
      setState(() { _isUninstalling = false; _uninstallStatus = ''; });

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0A1F0A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 28),
              SizedBox(width: 10),
              Text('Limpieza Completa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Todos los datos han sido eliminados correctamente.\n\n'
            'Ahora puede desinstalar la aplicación desde:\n'
            'Configuración → Aplicaciones → ClickPalm APP → Desinstalar',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ [uninstall] Error general: $e');
      if (mounted) {
        setState(() { _isUninstalling = false; _uninstallStatus = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error durante la limpieza: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _uninstallStatus = msg);
    debugPrint('🗑️ [uninstall] $msg');
  }

  Widget _buildUninstallingOverlay() {
    if (!_isUninstalling) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF5252), strokeWidth: 3),
            const SizedBox(height: 24),
            const Text('Eliminando datos...',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_uninstallStatus,
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                  textAlign: TextAlign.center),
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
              Icons.system_update_alt_rounded,
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
                  'Actualización',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).info,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ClickPalm APP',
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
            onPressed: _isUninstalling ? null : _showCompleteUninstallDialog,
            icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF5252)),
            tooltip: 'Desinstalación Completa',
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

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                Icons.cloud_sync_rounded,
                color: FlutterFlowTheme.of(context).info,
                size: 70,
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailableScreen() {
    if (!_updateAvailable) {
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
                      FlutterFlowTheme.of(context)
                          .success
                          .withValues(alpha: 0.8),
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
                'Estás actualizado',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
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
                  color: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: FlutterFlowTheme.of(context).success,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Versión $_currentVersion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: FlutterFlowTheme.of(context).success,
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

    // Hay actualización disponible
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  Icons.system_update_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 70,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '¡Nueva Actualización!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Hay una nueva versión disponible',
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
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildVersionRow(
                    'Versión actual',
                    '$_currentVersion',
                    Icons.phone_android_rounded,
                    FlutterFlowTheme.of(context).secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  _buildVersionRow(
                    'Nueva versión',
                    '${_latestVersion!.versionNumber}',
                    Icons.new_releases_rounded,
                    FlutterFlowTheme.of(context).success,
                  ),
                  if (_latestVersion!.fileSizeBytes != null) ...[
                    const SizedBox(height: 16),
                    Divider(color: FlutterFlowTheme.of(context).alternate),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_download_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tamaño: ${_formatBytes(_latestVersion!.fileSizeBytes!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    FlutterFlowTheme.of(context).warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: FlutterFlowTheme.of(context).warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus datos y configuraciones se conservarán durante la actualización',
                      style: TextStyle(
                        fontSize: 12,
                        color: FlutterFlowTheme.of(context).warning,
                      ),
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
                      'Descargar Actualización',
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

  Widget _buildVersionRow(
      String label, String version, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 4),
              Text(
                version,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  Icons.downloading_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 70,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isPaused ? 'Descarga Pausada' : 'Descargando...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isPaused ? 'Esperando conexión...' : 'No cierres la aplicación',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Estado de conexión
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                if (_retryCount > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          'Reintento $_retryCount/${UpdateConfig.maxRetries}',
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
              ],
            ),
            const SizedBox(height: 40),
            // Barra de progreso
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 12,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).alternate,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
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
                              color: FlutterFlowTheme.of(context).secondaryText,
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
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
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
        ),
      ),
    );
  }

  Widget _buildCompleteScreen() {
    return Center(
      child: SingleChildScrollView(
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
              '¡Descarga Completa!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La actualización está lista para instalar',
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
                onPressed: _installApk,
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
                      Icons.install_mobile_rounded,
                      color: FlutterFlowTheme.of(context).info,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Instalar Actualización',
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
      child: SingleChildScrollView(
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
              'Error',
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
                  : 'Ocurrió un error inesperado',
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
                  _initialize();
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
