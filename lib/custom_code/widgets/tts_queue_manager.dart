// Archivo compartido: clases TTS reutilizadas desde offline_map_tracker_visits.dart
// Usado por: compass_clickpalm.dart y futuras integraciones de voz.
// NO modificar la lógica — es la misma que los mapas offline.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechPriority { low, normal, high, critical }

class SpeechMessage {
  final String text;
  final SpeechPriority priority;
  final DateTime timestamp;

  SpeechMessage({
    required this.text,
    required this.priority,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Gestor de cola de mensajes TTS con sistema de cooldown.
/// Idéntico al usado en offline_map_tracker_visits.dart y offline_map_tracker.dart.
class TTSQueueManager {
  final FlutterTts _tts = FlutterTts();
  final List<SpeechMessage> _queue = [];
  bool _isSpeaking = false;
  final Map<String, DateTime> _lastAnnouncementTime = {};

  bool get isSpeaking => _isSpeaking;

  TTSQueueManager() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("es-CO");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue();
    });

    _tts.setErrorHandler((msg) {
      debugPrint('❌ Error TTS: $msg');
      _isSpeaking = false;
      _processQueue();
    });
  }

  void enqueueSpeech(
    String text,
    String messageKey,
    SpeechPriority priority,
    Duration cooldown,
  ) {
    if (!_canAnnounce(messageKey, cooldown)) return;

    _lastAnnouncementTime[messageKey] = DateTime.now();

    _queue.add(SpeechMessage(text: text, priority: priority));
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _processQueue();
  }

  bool _canAnnounce(String messageKey, Duration cooldown) {
    final lastTime = _lastAnnouncementTime[messageKey];
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > cooldown;
  }

  Future<void> _processQueue() async {
    if (_isSpeaking || _queue.isEmpty) return;

    final message = _queue.removeAt(0);
    _isSpeaking = true;

    try {
      await _tts.stop();
      await _tts.speak(message.text);
    } catch (e) {
      debugPrint('❌ Error al hablar: $e');
      _isSpeaking = false;
      _processQueue();
    }
  }

  void clearQueue() {
    _queue.clear();
    _tts.stop();
    _isSpeaking = false;
  }

  Future<void> speakImmediately(String text) async {
    await _tts.stop();
    _queue.clear();
    _isSpeaking = true;

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('❌ Error al hablar inmediatamente: $e');
      _isSpeaking = false;
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
    _queue.clear();
  }
}
