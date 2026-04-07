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
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Qwen 2.5 0.5B Instruct — Apache 2.0, sin token, ~547 MB
const String _kModelUrl =
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
const String _kModelFileName = 'qwen2.5_0.5b_q8.task';
const String _kModelReadyKey = 'voice_model_ready';

enum VoiceModelState { checking, notDownloaded, downloading, ready, error }

/// Widget para gestionar la descarga del modelo IA de voz (Qwen 2.5 on-device).
/// Soporta modo inline (compacto, para HomePage) y modo pantalla completa
/// (para ConfigVoicePage).
class LoadResourcesVoiceModel extends StatefulWidget {
  const LoadResourcesVoiceModel({
    super.key,
    this.width,
    this.height,
    this.showInlineMode = false,
    this.onModelReady,
    this.onSkip,
  });

  final double? width;
  final double? height;
  final bool showInlineMode;
  final Future<dynamic> Function()? onModelReady;
  final Future<dynamic> Function()? onSkip;

  @override
  State<LoadResourcesVoiceModel> createState() =>
      _LoadResourcesVoiceModelState();
}

class _LoadResourcesVoiceModelState extends State<LoadResourcesVoiceModel>
    with SingleTickerProviderStateMixin {
  VoiceModelState _state = VoiceModelState.checking;
  String? _errorMessage;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _speed = '';
  String _timeRemaining = '';
  String _modelPath = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  http.Client? _httpClient;
  IOSink? _fileSink;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkModelStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _isCancelled = true;
    _httpClient?.close();
    super.dispose();
  }

  Future<String> _getModelPath() async {
    // Guardar en getApplicationDocumentsDirectory() (app_flutter/) porque
    // flutter_gemma siempre busca archivos ahí (ModelFileSystemManager.getModelFilePath).
    // El archivo queda protegido del cleanup gracias a installed_models en SharedPrefs.
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_kModelFileName';
  }

  Future<void> _checkModelStatus() async {
    setState(() => _state = VoiceModelState.checking);
    try {
      _modelPath = await _getModelPath();
      final file = File(_modelPath);
      final prefs = await SharedPreferences.getInstance();
      final ready = prefs.getBool(_kModelReadyKey) ?? false;

      // Migración: si el archivo está en external storage (ruta antigua) pero no en
      // internal, moverlo al directorio correcto que usa flutter_gemma.
      if (!await file.exists()) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final oldFile = File('${ext.path}/$_kModelFileName');
          if (await oldFile.exists()) {
            debugPrint('🔄 [VoiceModel] Migrando modelo de external → internal storage...');
            await oldFile.copy(_modelPath);
            await oldFile.delete();
            debugPrint('✅ [VoiceModel] Migración completa: $_modelPath');
          }
        }
      }

      if (ready && await file.exists()) {
        // Asegurarse de que installed_models tenga el filename (por si migración)
        final models = List<String>.from(prefs.getStringList('installed_models') ?? []);
        if (!models.contains(_kModelFileName)) {
          models.add(_kModelFileName);
          await prefs.setStringList('installed_models', models);
        }
        _setStateIfMounted(VoiceModelState.ready);
      } else {
        if (ready) { await prefs.setBool(_kModelReadyKey, false); }
        _setStateIfMounted(VoiceModelState.notDownloaded);
      }
    } catch (e) {
      _setErrorIfMounted('Error al verificar el modelo: $e');
    }
  }

  void _setStateIfMounted(VoiceModelState s) {
    if (mounted) setState(() => _state = s);
  }

  void _setErrorIfMounted(String msg) {
    if (mounted) setState(() {
      _state = VoiceModelState.error;
      _errorMessage = msg;
    });
  }

  Future<void> _startDownload() async {
    if (_state == VoiceModelState.downloading) return;
    _isCancelled = false;
    setState(() {
      _state = VoiceModelState.downloading;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _speed = '';
      _timeRemaining = '';
      _errorMessage = null;
    });

    try {
      _modelPath = await _getModelPath();
      final tempPath = '$_modelPath.partial';
      final tempFile = File(tempPath);

      // Resolver redirects manualmente (HuggingFace usa 302)
      _httpClient = http.Client();
      Uri url = Uri.parse(_kModelUrl);
      http.StreamedResponse response;
      int redirects = 0;
      while (true) {
        final request = http.Request('GET', url);
        request.followRedirects = false;
        response = await _httpClient!.send(request);
        debugPrint('🌐 [VoiceDownload] HTTP ${response.statusCode} → $url');
        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303 ||
            response.statusCode == 307 ||
            response.statusCode == 308) {
          final location = response.headers['location'];
          if (location == null || redirects >= 10) {
            throw Exception('Redirect sin destino o demasiados redirects');
          }
          // Drenar el body del redirect para liberar la conexión
          await response.stream.drain<void>();
          url = Uri.parse(location);
          redirects++;
          continue;
        }
        break;
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} en $url');
      }

      _totalBytes = response.contentLength ?? 0;
      _fileSink = tempFile.openWrite();

      final stopwatch = Stopwatch()..start();
      int lastBytes = 0;
      int lastSpeedUpdate = 0;

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await _fileSink?.flush();
          await _fileSink?.close();
          if (await tempFile.exists()) await tempFile.delete();
          _setStateIfMounted(VoiceModelState.notDownloaded);
          return;
        }
        _fileSink!.add(chunk);
        _downloadedBytes += chunk.length;

        final now = stopwatch.elapsedMilliseconds;
        if (now - lastSpeedUpdate >= 800) {
          final bytesDelta = _downloadedBytes - lastBytes;
          final timeDelta = (now - lastSpeedUpdate) / 1000.0;
          final bytesPerSec = bytesDelta / timeDelta;
          lastBytes = _downloadedBytes;
          lastSpeedUpdate = now;

          String speedStr;
          if (bytesPerSec >= 1024 * 1024) {
            speedStr = '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
          } else if (bytesPerSec >= 1024) {
            speedStr = '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
          } else {
            speedStr = '${bytesPerSec.toStringAsFixed(0)} B/s';
          }

          String timeStr = '';
          if (_totalBytes > 0 && bytesPerSec > 0) {
            final remaining = (_totalBytes - _downloadedBytes) / bytesPerSec;
            if (remaining < 60) {
              timeStr = '~${remaining.toInt()}s restantes';
            } else if (remaining < 3600) {
              timeStr = '~${(remaining / 60).toInt()}min restantes';
            } else {
              timeStr = '~${(remaining / 3600).toStringAsFixed(1)}h restantes';
            }
          }

          if (mounted) {
            setState(() {
              _speed = speedStr;
              _timeRemaining = timeStr;
              _progress = _totalBytes > 0
                  ? (_downloadedBytes / _totalBytes).clamp(0.0, 1.0)
                  : 0.0;
            });
          }
        }
      }

      await _fileSink?.flush();
      await _fileSink?.close();

      // Rename temp to final
      await tempFile.rename(_modelPath);
      debugPrint('✅ [VoiceDownload] Archivo guardado en: $_modelPath');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kModelReadyKey, true);
      // Registrar en installed_models para que flutter_gemma proteja el archivo
      // del cleanup y para que isModelInstalled() devuelva true.
      final models = List<String>.from(prefs.getStringList('installed_models') ?? []);
      if (!models.contains(_kModelFileName)) {
        models.add(_kModelFileName);
        await prefs.setStringList('installed_models', models);
        debugPrint('✅ [VoiceDownload] Registrado en installed_models: $_kModelFileName');
      }

      if (mounted) {
        setState(() {
          _state = VoiceModelState.ready;
          _progress = 1.0;
        });
        widget.onModelReady?.call();
      }
    } catch (e, stack) {
      debugPrint('❌ [VoiceDownload] Error: $e');
      debugPrint('❌ [VoiceDownload] Stack: $stack');
      await _fileSink?.close();
      _setErrorIfMounted('Error durante la descarga:\n$e');
    }
  }

  void _cancelDownload() {
    _isCancelled = true;
    _httpClient?.close();
    _httpClient = null;
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 26),
            SizedBox(width: 10),
            Text('Eliminar modelo IA',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '¿Seguro que deseas eliminar el modelo de IA?\n\nTendrás que volver a descargarlo (~700 MB) para usar el asistente de voz.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _state = VoiceModelState.checking);
    try {
      final file = File(_modelPath);
      if (await file.exists()) await file.delete();
      final partial = File('$_modelPath.partial');
      if (await partial.exists()) await partial.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kModelReadyKey, false);
      // Quitar de installed_models para que flutter_gemma no lo busque
      final models = List<String>.from(prefs.getStringList('installed_models') ?? []);
      models.remove(_kModelFileName);
      await prefs.setStringList('installed_models', models);
      _setStateIfMounted(VoiceModelState.notDownloaded);
    } catch (e) {
      _setErrorIfMounted('Error al eliminar: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ─────────────────────────────────── BUILD ────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.showInlineMode) return _buildInlineMode();

    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asistente de Voz IA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Qwen 2.5 · On-device · MediaPipe',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('IA LOCAL',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case VoiceModelState.checking:
        return _buildChecking();
      case VoiceModelState.notDownloaded:
        return _buildNotDownloaded();
      case VoiceModelState.downloading:
        return _buildDownloading();
      case VoiceModelState.ready:
        return _buildReady();
      case VoiceModelState.error:
        return _buildError();
    }
  }

  // ─────────────── Inline mode (compact, for HomePage banner) ───────────────
  Widget _buildInlineMode() {
    switch (_state) {
      case VoiceModelState.checking:
        return Container(
          width: widget.width,
          height: widget.height ?? 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
        );
      case VoiceModelState.notDownloaded:
        return _buildInlineNotDownloaded();
      case VoiceModelState.downloading:
        return _buildInlineDownloading();
      case VoiceModelState.ready:
        return _buildInlineReady();
      case VoiceModelState.error:
        return _buildInlineError();
    }
  }

  Widget _buildInlineNotDownloaded() {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B2B), Color(0xFF0D3B3A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: Color(0xFF0D9488), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Asistente de Voz IA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('~700 MB · Funciona sin internet',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _startDownload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('DESCARGAR',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => widget.onSkip?.call(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Color(0xFF475569), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDownloading() {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0D9488)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Descargando modelo IA...',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF0D9488)),
              minHeight: 4,
            ),
          ),
          if (_speed.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_speed,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10)),
                Text(_timeRemaining,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineReady() {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF052E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mic_rounded,
                color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Asistente listo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Qwen 2.5 · On-device · Activo',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Text('IA ACTIVA',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B1B),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF6B6B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Error desconocido',
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _checkModelStatus,
            child: const Text('Reintentar',
                style: TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Full-screen states ────────────────────────────────────

  Widget _buildChecking() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF0D9488),
            ),
          ),
          SizedBox(height: 20),
          Text('Verificando modelo...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildNotDownloaded() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Hero icon
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D9488), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.record_voice_over_rounded,
                  color: Colors.white, size: 64),
            ),
          ),

          const SizedBox(height: 32),

          const Text('Asistente de Voz IA',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),

          const SizedBox(height: 10),

          const Text(
            'Modelo Qwen 2.5 · ~547 MB · Funciona sin internet',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Info cards
          _buildInfoGrid(),

          const SizedBox(height: 32),

          // Note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Se recomienda descargar con WiFi. La descarga puede tardar varios minutos dependiendo de tu conexión.',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Download button
          _buildGradientButton(
            label: 'INICIAR DESCARGA',
            icon: Icons.download_rounded,
            onTap: _startDownload,
          ),

          const SizedBox(height: 14),

          // Skip button
          if (widget.onSkip != null)
            GestureDetector(
              onTap: () => widget.onSkip?.call(),
              child: const Text(
                'Omitir por ahora',
                style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF475569)),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDownloading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Circular progress hero
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF0D9488)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text('descargado',
                      style:
                          TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text('DESCARGANDO MODELO IA',
              style: TextStyle(
                  color: Color(0xFF0D9488),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),

          const SizedBox(height: 6),

          const Text('Qwen 2.5 0.5B · Optimizado para móvil',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),

          const SizedBox(height: 24),

          // Stats card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildStatRow('Descargado',
                    '${_formatBytes(_downloadedBytes)} / ${_totalBytes > 0 ? _formatBytes(_totalBytes) : "~700 MB"}'),
                const SizedBox(height: 14),
                _buildStatRow(
                    'Velocidad', _speed.isNotEmpty ? _speed : 'Calculando...'),
                const SizedBox(height: 14),
                _buildStatRow('Tiempo restante',
                    _timeRemaining.isNotEmpty ? _timeRemaining : 'Calculando...'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF0D9488)),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 28),

          // Cancel
          GestureDetector(
            onTap: _cancelDownload,
            child: const Text('Cancelar descarga',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFFF6B6B))),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildReady() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Pulsing green mic icon
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 64),
            ),
          ),

          const SizedBox(height: 32),

          // IA ACTIVA badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text('IA ACTIVA',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('Asistente listo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),

          const SizedBox(height: 10),

          const Text('Qwen 2.5 0.5B · On-device · Español colombiano',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center),

          const SizedBox(height: 32),

          _buildInfoGrid(),

          const SizedBox(height: 32),

          // Delete model
          GestureDetector(
            onTap: _deleteModel,
            child: const Text('Eliminar modelo del dispositivo',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFFF6B6B))),
          ),

          const SizedBox(height: 6),
          const Text('Liberará ~700 MB de almacenamiento',
              style: TextStyle(color: Color(0xFF475569), fontSize: 11)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildError() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF6B6B), size: 56),
          ),

          const SizedBox(height: 28),

          const Text('Error en la descarga',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.25)),
            ),
            child: Text(
              _errorMessage ?? 'Error desconocido',
              style: const TextStyle(
                  color: Color(0xFFFF6B6B), fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          _buildGradientButton(
            label: 'REINTENTAR',
            icon: Icons.refresh_rounded,
            onTap: _startDownload,
          ),

          const SizedBox(height: 14),

          if (widget.onSkip != null)
            GestureDetector(
              onTap: () => widget.onSkip?.call(),
              child: const Text('Omitir por ahora',
                  style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF475569))),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─────────────────────────── Reusable sub-widgets ──────────────────────────

  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        _buildInfoCard(Icons.wifi_off_rounded, 'Sin internet', '100% offline'),
        _buildInfoCard(Icons.translate_rounded, 'Idioma', 'Español colombiano'),
        _buildInfoCard(Icons.storage_rounded, 'Almacenamiento', '~700 MB'),
        _buildInfoCard(Icons.speed_rounded, 'GPU acelerada', 'MediaPipe'),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D9488), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10),
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

}
