// ADB NFC Client Service
// Mobile-side WebSocket client for tag-transfer-adb-from fields.
// Connects to ws://localhost:8080 (reachable via: adb forward tcp:8080 tcp:8080).
// Only active when a tag-transfer-adb-from field is rendered in do_visits_form_page.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdbNfcClientService {
  AdbNfcClientService._();
  static final AdbNfcClientService instance = AdbNfcClientService._();

  WebSocket? _socket;
  final StreamController<bool> _connectedController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _serverCommandController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get onConnectionChanged => _connectedController.stream;

  /// Emite comandos recibidos desde el servidor Windows (p.ej. 'request_nfc_read').
  Stream<Map<String, dynamic>> get onServerCommand =>
      _serverCommandController.stream;

  bool get isConnected => _socket != null;

  Future<bool> connect() async {
    if (Platform.isWindows) return false; // client is mobile-only
    if (_socket != null) return true;

    try {
      _socket = await WebSocket.connect('ws://127.0.0.1:8080')
          .timeout(const Duration(seconds: 5));
      debugPrint('🟢 AdbNfcClientService: Connected to server at :8080');
      _connectedController.add(true);

      _socket!.listen(
        (data) {
          // Procesar comandos enviados desde el servidor Windows → Android
          try {
            final Map<String, dynamic> msg = jsonDecode(data as String);
            debugPrint('📨 AdbNfcClientService: Comando del servidor: $msg');
            _serverCommandController.add(msg);
          } catch (e) {
            debugPrint('❌ AdbNfcClientService: Mensaje inválido del servidor: $e');
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

  /// Send the NFC tag content to the desktop server.
  /// [tagContent] is the raw NFC content string already read from the tag.
  Future<bool> sendTagData({
    required String tagContent,
    String? productName,
  }) async {
    if (_socket == null) return false;
    try {
      final payload = jsonEncode({
        'type': 'nfc_tag_read',
        'payload': {
          'tagContent': tagContent,
          'productName': productName ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
      _socket!.add(payload);
      debugPrint('📤 AdbNfcClientService: Tag sent to server');
      return true;
    } catch (e) {
      debugPrint('❌ AdbNfcClientService: Send failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _connectedController.add(false);
  }
}
