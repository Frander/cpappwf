// ADB NFC Client Service
// Mobile-side WebSocket client for tag-transfer-adb-from fields.
// Connects to ws://localhost:8080 (reachable via: adb forward tcp:8080 tcp:8080).
// Only active when a tag-transfer-adb-from field is rendered in do_visits_form_page.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '/custom_code/platform_utils.dart';
import '/backend/sqlite/global_db_singleton.dart';

class AdbNfcClientService {
  AdbNfcClientService._();
  static final AdbNfcClientService instance = AdbNfcClientService._();

  WebSocket? _socket;
  // Completer para esperar el ACK del servidor tras enviar un tag.
  // null cuando no hay envío pendiente.
  Completer<bool>? _pendingTagAck;
  final StreamController<bool> _connectedController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _serverCommandController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<double> _dbProgressController =
      StreamController<double>.broadcast();
  final StreamController<DbTransferCompleteEvent> _dbCompleteController =
      StreamController<DbTransferCompleteEvent>.broadcast();

  // Estado interno de ensamblado de BD
  List<int> _dbBuffer = [];
  int _dbTotalBytes = 0;
  DateTime? _dbTransferStart;

  Stream<bool> get onConnectionChanged => _connectedController.stream;

  /// Emite comandos recibidos desde el servidor Windows (p.ej. 'request_nfc_read').
  Stream<Map<String, dynamic>> get onServerCommand =>
      _serverCommandController.stream;

  /// Progreso de recepción de BD (0.0 – 1.0).
  Stream<double> get onDbTransferProgress => _dbProgressController.stream;

  /// Emite el resultado cuando la transferencia de BD está completa.
  Stream<DbTransferCompleteEvent> get onDbTransferComplete =>
      _dbCompleteController.stream;

  bool get isConnected => _socket != null;

  Future<bool> connect() async {
    if (!Platforms.isMobile) return false; // client is mobile-only
    if (_socket != null) return true;

    try {
      _socket = await WebSocket.connect('ws://127.0.0.1:8080')
          .timeout(const Duration(seconds: 5));
      debugPrint('🟢 AdbNfcClientService: Connected to server at :8080');
      _connectedController.add(true);

      _socket!.listen(
        (dynamic data) {
          if (data is List<int>) {
            _handleBinaryChunk(data);
          } else if (data is String) {
            _handleJsonMessage(data);
          }
        },
        onDone: () {
          debugPrint('🔌 AdbNfcClientService: Disconnected from server');
          _socket = null;
          _connectedController.add(false);
        },
        onError: (e) {
          debugPrint('❌ AdbNfcClientService: WebSocket error: $e');
          _socket = null;
          _connectedController.add(false);
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: Could not connect: $e');
      _socket = null;
      _connectedController.add(false);
      return false;
    }
  }

  void _handleJsonMessage(String data) {
    try {
      final Map<String, dynamic> msg = jsonDecode(data);
      debugPrint('📨 AdbNfcClientService: Mensaje del servidor: ${msg['type']}');
      switch (msg['type'] as String?) {
        case 'db_transfer_start':
          _dbTotalBytes = (msg['payload']['total_bytes'] as num).toInt();
          _dbTransferStart ??= DateTime.now();
          _dbBuffer = [];
          debugPrint('📦 AdbNfcClientService: Transferencia BD iniciada ($_dbTotalBytes bytes)');
          break;
        case 'db_transfer_complete':
          _saveTransferredDb();
          break;
        case 'nfc_tag_ack':
          final success = (msg['payload']?['success'] as bool?) ?? false;
          debugPrint('📨 AdbNfcClientService: nfc_tag_ack recibido (success=$success)');
          _pendingTagAck?.complete(success);
          _pendingTagAck = null;
          break;
        default:
          _serverCommandController.add(msg);
      }
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: Mensaje inválido del servidor: $e');
    }
  }

  void _handleBinaryChunk(List<int> bytes) {
    _dbBuffer.addAll(bytes);
    if (_dbTotalBytes > 0) {
      _dbProgressController.add(_dbBuffer.length / _dbTotalBytes);
    }
  }

  Future<void> _saveTransferredDb() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'adb_transfer.db');
      await File(tempPath).writeAsBytes(_dbBuffer);
      if (await File(tempPath).length() == 0) throw Exception('Archivo vacío');

      final dbPath = await globalDb.dbPath;
      await globalDb.close();
      await File(tempPath).copy(dbPath);
      await globalDb.database; // reabrir

      final duration =
          DateTime.now().difference(_dbTransferStart ?? DateTime.now());
      _dbCompleteController.add(DbTransferCompleteEvent(
        dbPath: dbPath,
        totalBytes: _dbBuffer.length,
        duration: duration,
      ));
      debugPrint('✅ AdbNfcClientService: BD guardada en $dbPath (${_dbBuffer.length} bytes)');
      _dbBuffer = [];
      _dbTotalBytes = 0;
      _dbTransferStart = null;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: Error guardando BD: $e');
      try {
        await globalDb.database;
      } catch (_) {}
    }
  }

  /// Solicita la transferencia de BD al servidor PC.
  Future<bool> requestDbTransfer() async {
    if (_socket == null || !isConnected) return false;
    _dbBuffer = [];
    _dbTotalBytes = 0;
    _dbTransferStart = DateTime.now();
    try {
      _socket!.add(jsonEncode({'type': 'request_db_transfer'}));
      debugPrint('📤 AdbNfcClientService: request_db_transfer enviado');
      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: requestDbTransfer falló: $e');
      return false;
    }
  }

  /// Envía el contenido del tag NFC al servidor desktop y espera su ACK.
  /// Retorna true SOLO si el servidor confirmó que procesó el tag correctamente.
  /// Si el ACK no llega en [ackTimeout] (default 5 s), retorna false → el tag NO se borra.
  Future<bool> sendTagData({
    required String tagContent,
    String? productName,
    Duration ackTimeout = const Duration(seconds: 5),
  }) async {
    if (_socket == null) return false;

    // Cancelar ACK pendiente anterior si lo hubiera (no debería ocurrir en uso normal)
    _pendingTagAck?.complete(false);
    _pendingTagAck = Completer<bool>();

    try {
      _socket!.add(jsonEncode({
        'type': 'nfc_tag_read',
        'payload': {
          'tagContent': tagContent,
          'productName': productName ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      }));
      debugPrint('📤 AdbNfcClientService: Tag enviado, esperando ACK del servidor...');

      final ack = await _pendingTagAck!.future.timeout(
        ackTimeout,
        onTimeout: () {
          debugPrint('⏰ AdbNfcClientService: Timeout ($ackTimeout) esperando ACK — tag NO se borrará');
          _pendingTagAck = null;
          return false;
        },
      );

      debugPrint(ack
          ? '✅ AdbNfcClientService: ACK success — tag será borrado'
          : '❌ AdbNfcClientService: ACK failure/timeout — tag NO será borrado');
      return ack;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: sendTagData falló: $e');
      _pendingTagAck?.complete(false);
      _pendingTagAck = null;
      return false;
    }
  }

  /// Envía la geolocalización actual al servidor Windows en respuesta a un request_geo_location.
  Future<bool> sendGeoLocation({
    required double latitude,
    required double longitude,
    double altitude = 0,
    double errorHorizontal = 0,
  }) async {
    if (_socket == null) return false;
    try {
      _socket!.add(jsonEncode({
        'type': 'geo_location_response',
        'payload': {
          'latitude': latitude,
          'longitude': longitude,
          'altitude': altitude,
          'errorHorizontal': errorHorizontal,
        },
      }));
      debugPrint('📍 AdbNfcClientService: geo_location_response enviado al servidor');
      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: sendGeoLocation falló: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _connectedController.add(false);
  }

  /// Desconecta (sin importar estado actual) y vuelve a conectar.
  Future<bool> forceReconnect() async {
    await disconnect();
    return connect();
  }
}

class DbTransferCompleteEvent {
  final String dbPath;
  final int totalBytes;
  final Duration duration;

  const DbTransferCompleteEvent({
    required this.dbPath,
    required this.totalBytes,
    required this.duration,
  });
}
