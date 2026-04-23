// ADB NFC Bridge Service
// Singleton WebSocket server that runs on port 8080 (desktop side).
// Mobile connects via: adb reverse tcp:8080 tcp:8080
// Only active when a tag-transfer-adb-server field is rendered in the form.
//
// Uses HttpServer + WebSocketTransformer — the official Dart approach.
//
// Funciona en cualquier desktop (Windows, Linux, macOS) siempre que `adb` esté
// en PATH. En Linux: `sudo apt install android-tools-adb` (Debian/Ubuntu) o
// `sudo pacman -S android-tools` (Arch).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '/custom_code/platform_utils.dart';

class AdbNfcBridgeService {
  AdbNfcBridgeService._();
  static final AdbNfcBridgeService instance = AdbNfcBridgeService._();

  HttpServer? _server;
  WebSocket? _client;
  StreamSubscription<HttpRequest>? _serverSub;

  /// Ruta resuelta de adb (se cachea tras la primera búsqueda).
  String? _adbPath;

  /// Busca adb.exe en PATH y en rutas conocidas del Android SDK.
  /// Retorna la ruta completa o null si no se encuentra.
  Future<String?> _findAdb() async {
    if (_adbPath != null) return _adbPath;

    // 1. Probar si adb está en PATH
    try {
      final result = await Process.run('adb', ['version']);
      if (result.exitCode == 0) {
        _adbPath = 'adb';
        return _adbPath;
      }
    } catch (_) {}

    // 2. Buscar en rutas conocidas del Android SDK
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ?? '';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';

    final candidatePaths = <String>[
      // Windows: Android Studio SDK default
      '$localAppData/Android/Sdk/platform-tools/adb.exe',
      '$home/AppData/Local/Android/Sdk/platform-tools/adb.exe',
      // ANDROID_HOME / ANDROID_SDK_ROOT
      if (Platform.environment['ANDROID_HOME'] != null)
        '${Platform.environment['ANDROID_HOME']}/platform-tools/adb.exe',
      if (Platform.environment['ANDROID_SDK_ROOT'] != null)
        '${Platform.environment['ANDROID_SDK_ROOT']}/platform-tools/adb.exe',
      // Linux
      '$home/Android/Sdk/platform-tools/adb',
      '/usr/bin/adb',
      '/usr/local/bin/adb',
      // macOS
      '$home/Library/Android/sdk/platform-tools/adb',
    ];

    for (final path in candidatePaths) {
      final normalized = path.replaceAll('/', Platform.pathSeparator);
      if (await File(normalized).exists()) {
        _adbPath = normalized;
        debugPrint('AdbNfcBridgeService: adb encontrado en: $_adbPath');
        return _adbPath;
      }
    }

    return null;
  }

  final StreamController<Map<String, dynamic>> _tagController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<AdbBridgeStatus> _statusController =
      StreamController<AdbBridgeStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _geoLocationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onTagReceived => _tagController.stream;
  Stream<AdbBridgeStatus> get onStatusChanged => _statusController.stream;

  bool get isServerRunning => _server != null;
  bool get isClientConnected => _client != null;

  AdbBridgeStatus get currentStatus {
    if (!isServerRunning) return AdbBridgeStatus.serverDown;
    if (isClientConnected) return AdbBridgeStatus.clientConnected;
    return AdbBridgeStatus.waitingForClient;
  }

  Future<bool> start() async {
    if (!Platforms.isDesktop) return false; // Solo desktop (Windows/Linux/macOS)
    if (_server != null) return true; // Already running

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      debugPrint('🟢 AdbNfcBridgeService: HTTP server on 127.0.0.1:8080 — awaiting WS upgrade');
      _statusController.add(AdbBridgeStatus.waitingForClient);

      // Configurar ADB reverse automáticamente para que Android pueda conectarse
      _setupAdbReverse();

      // Keep a StreamSubscription so the server is not garbage collected
      final server = _server!;
      _serverSub = server.listen(
        _handleRequest,
        onError: (e) => debugPrint('❌ AdbNfcBridgeService: Server stream error: $e'),
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcBridgeService: Failed to start: $e');
      _server = null;
      _statusController.add(AdbBridgeStatus.serverDown);
      return false;
    }
  }

  /// Mensaje de error para la UI cuando adb no se encuentra.
  String? adbError;

  Future<void> _setupAdbReverse() async {
    final adb = await _findAdb();
    if (adb == null) {
      adbError = 'adb no encontrado. Instala Android Platform-Tools.';
      debugPrint('⚠️ AdbNfcBridgeService: $adbError');
      debugPrint('   Rutas buscadas: LOCALAPPDATA/Android/Sdk/platform-tools/, '
          'ANDROID_HOME, ANDROID_SDK_ROOT, PATH');
      return;
    }
    adbError = null;

    try {
      final result = await Process.run(adb, ['reverse', 'tcp:8080', 'tcp:8080']);
      if (result.exitCode == 0) {
        debugPrint('AdbNfcBridgeService: adb reverse tcp:8080 tcp:8080 OK (usando: $adb)');
      } else {
        adbError = 'adb reverse fallo: ${result.stderr}';
        debugPrint('⚠️ AdbNfcBridgeService: $adbError');
      }
    } catch (e) {
      adbError = 'Error ejecutando adb: $e';
      debugPrint('⚠️ AdbNfcBridgeService: $adbError');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    debugPrint('📨 AdbNfcBridgeService: Incoming request ${request.method} ${request.uri}'
        ' from ${request.connectionInfo?.remoteAddress?.address}');

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      debugPrint('⚠️ AdbNfcBridgeService: Not a WS upgrade — headers: ${request.headers}');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket upgrade required')
        ..close();
      return;
    }

    try {
      final ws = await WebSocketTransformer.upgrade(request);
      debugPrint('🔗 AdbNfcBridgeService: Mobile client connected');
      _client = ws;
      _statusController.add(AdbBridgeStatus.clientConnected);

      ws.listen(
        _handleMessage,
        onDone: () {
          debugPrint('🔌 AdbNfcBridgeService: Mobile client disconnected');
          _client = null;
          if (isServerRunning) _statusController.add(AdbBridgeStatus.waitingForClient);
        },
        onError: (e) {
          debugPrint('❌ AdbNfcBridgeService: WebSocket error: $e');
          _client = null;
          if (isServerRunning) _statusController.add(AdbBridgeStatus.waitingForClient);
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      debugPrint('❌ AdbNfcBridgeService: WS upgrade failed: $e\n$st');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> msg = jsonDecode(data as String);
      if (msg['type'] == 'nfc_tag_read') {
        final payload = msg['payload'] as Map<String, dynamic>;
        debugPrint('📡 AdbNfcBridgeService: NFC tag received: $payload');
        _tagController.add(payload);
      } else if (msg['type'] == 'geo_location_response') {
        final payload = msg['payload'] as Map<String, dynamic>;
        debugPrint('📍 AdbNfcBridgeService: GPS response received: $payload');
        _geoLocationController.add(payload);
      }
    } catch (e) {
      debugPrint('❌ AdbNfcBridgeService: Invalid message: $e');
    }
  }

  /// Solicita la geolocalización actual al cliente Android y espera la respuesta.
  /// Retorna null si no hay cliente conectado o se agota el tiempo de espera.
  Future<Map<String, dynamic>?> requestAndWaitGeoLocation({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_client == null) {
      debugPrint('⚠️ AdbNfcBridgeService: requestAndWaitGeoLocation — no hay cliente conectado');
      return null;
    }
    try {
      final future = _geoLocationController.stream.first
          .timeout(timeout, onTimeout: () => <String, dynamic>{});
      _client!.add(jsonEncode({'type': 'request_geo_location'}));
      debugPrint('📤 AdbNfcBridgeService: request_geo_location enviado al Android');
      final result = await future;
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('❌ AdbNfcBridgeService: requestAndWaitGeoLocation falló: $e');
      return null;
    }
  }

  /// Envía una solicitud de lectura NFC al cliente Android conectado.
  /// Retorna false si no hay cliente conectado o el envío falla.
  bool sendRequestRead() {
    if (_client == null) {
      debugPrint('⚠️ AdbNfcBridgeService: sendRequestRead — no hay cliente conectado');
      return false;
    }
    try {
      _client!.add(jsonEncode({'type': 'request_nfc_read'}));
      debugPrint('📤 AdbNfcBridgeService: request_nfc_read enviado al Android');
      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcBridgeService: sendRequestRead falló: $e');
      return false;
    }
  }

  Future<void> stop() async {
    await _serverSub?.cancel();
    _serverSub = null;
    await _client?.close();
    _client = null;
    await _server?.close(force: true);
    _server = null;
    _statusController.add(AdbBridgeStatus.serverDown);
    debugPrint('🔴 AdbNfcBridgeService: Server stopped');
  }
}

enum AdbBridgeStatus {
  serverDown,       // Server not running — red badge
  waitingForClient, // Server up, no mobile connected — yellow/orange badge
  clientConnected,  // Server up + mobile connected — green badge
}
