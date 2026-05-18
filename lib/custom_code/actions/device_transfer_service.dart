// Servicio de transferencia de BD entre dispositivos Android via red local.
// ORIGEN: levanta servidor HTTP en puerto 8082 que sirve clickpalm_database.db
// DESTINO: descarga la BD y reemplaza la local.
// Funciona sobre USB tethering (192.168.42.1 / 192.168.44.1) o cualquier red local.

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '/backend/sqlite/global_db_singleton.dart';

enum TransferServerEvent { waiting, transferring, complete, error }

class DeviceTransferService {
  DeviceTransferService._();
  static final DeviceTransferService instance = DeviceTransferService._();

  HttpServer? _server;
  Timer? _timeoutTimer;
  final StreamController<TransferServerEvent> _eventController =
      StreamController<TransferServerEvent>.broadcast();

  bool get isServerRunning => _server != null;
  String? serverIp;

  static const int port = 8082;
  String get serverUrl => 'http://$serverIp:$port/db';

  /// Emite eventos de estado: waiting → transferring → complete / error
  Stream<TransferServerEvent> get onEvent => _eventController.stream;

  /// IPs de gateway predecibles cuando Android activa USB tethering
  static const List<String> kUsbGatewayIps = ['192.168.42.1', '192.168.44.1'];

  /// Inicia el servidor HTTP en ORIGEN.
  /// Hace WAL checkpoint, detecta IP y escucha en 0.0.0.0:8082.
  /// Se auto-detiene tras 1 transferencia exitosa o tras 5 minutos.
  Future<bool> startTransferServer() async {
    if (_server != null) return true;
    try {
      await globalDb.executeOperation((db) async {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      });

      serverIp = await getLocalIpAddress();
      if (serverIp == null) {
        debugPrint('❌ DeviceTransferService: No se pudo obtener IP local');
        return false;
      }

      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('🟢 DeviceTransferService: Servidor en 0.0.0.0:$port (IP: $serverIp)');
      _eventController.add(TransferServerEvent.waiting);

      _timeoutTimer = Timer(const Duration(minutes: 5), () {
        debugPrint('⏱ DeviceTransferService: timeout 5 min — deteniendo servidor');
        stopTransferServer();
      });

      _server!.listen(
        (request) async {
          final isDbPath = request.uri.path == '/db';

          if (request.method == 'HEAD' && isDbPath) {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.set('Content-Type', 'application/octet-stream');
            await request.response.close();
            return;
          }

          if (request.method == 'GET' && isDbPath) {
            _eventController.add(TransferServerEvent.transferring);
            try {
              final dbPath = await globalDb.dbPath;
              final file = File(dbPath);
              if (!await file.exists()) {
                request.response.statusCode = HttpStatus.notFound;
                await request.response.close();
                return;
              }
              final bytes = await file.readAsBytes();
              request.response
                ..statusCode = HttpStatus.ok
                ..headers.set('Content-Type', 'application/octet-stream')
                ..headers.set('Content-Length', '${bytes.length}')
                ..headers.set(
                    'Content-Disposition', 'attachment; filename="clickpalm_database.db"')
                ..add(bytes);
              await request.response.close();
              debugPrint('📤 DeviceTransferService: BD enviada (${bytes.length} bytes)');
              _eventController.add(TransferServerEvent.complete);
              await Future.delayed(const Duration(seconds: 1));
              stopTransferServer();
            } catch (e) {
              debugPrint('❌ DeviceTransferService: Error enviando BD: $e');
              _eventController.add(TransferServerEvent.error);
              try {
                request.response.statusCode = HttpStatus.internalServerError;
                await request.response.close();
              } catch (_) {}
            }
            return;
          }

          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        },
        onError: (e) => debugPrint('❌ DeviceTransferService: Error en servidor: $e'),
      );

      return true;
    } catch (e) {
      debugPrint('❌ DeviceTransferService: Error iniciando servidor: $e');
      _server = null;
      return false;
    }
  }

  Future<void> stopTransferServer() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _server?.close(force: true);
    _server = null;
    debugPrint('🔴 DeviceTransferService: Servidor detenido');
  }

  /// Sondea si hay un servidor de transferencia activo en [url] (timeout 2s).
  Future<bool> probeServer(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      client.close();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    }
  }

  /// Descarga la BD desde [url] y reemplaza la base de datos local.
  /// Llama [onProgress] con valores 0.0–1.0 durante la descarga.
  Future<bool> downloadDatabase(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'transfer_db_temp.db');

      final dio = Dio();
      await dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception('Archivo descargado vacío o inexistente');
      }

      // Obtener ruta ANTES de cerrar la BD (evita re-apertura prematura)
      final dbPath = await globalDb.dbPath;

      await globalDb.close();
      await tempFile.copy(dbPath);
      await globalDb.database; // Reabre la BD con el archivo nuevo

      debugPrint('✅ DeviceTransferService: BD transferida desde $url');
      return true;
    } catch (e) {
      debugPrint('❌ DeviceTransferService: Error descargando BD: $e');
      try { await globalDb.database; } catch (_) {}
      return false;
    }
  }

  /// Devuelve la primera IP IPv4 no-loopback del dispositivo.
  Future<String?> getLocalIpAddress() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ DeviceTransferService: No se pudo obtener IP: $e');
    }
    return null;
  }
}
