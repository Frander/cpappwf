// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/global_db_singleton.dart';
import '/custom_code/widgets/tts_queue_manager.dart';
import '/custom_code/widgets/voice_model_singleton.dart';

// kVoiceModelReadyKey y resolveModelPath() vienen de voice_model_singleton.dart

const String _kVisitSystemPrompt =
    'Eres un asistente de campo para operarios de palma africana en Colombia. '
    'Habla en español colombiano, máximo 2 oraciones cortas, sin símbolos ni emojis. '
    'Solo texto para lectura en voz alta.';

Future<void> announceVisitVoice() async {
  debugPrint('🎙️ ════════════════════════════════════════');
  debugPrint('🎙️ [VisitVoice] INICIO announceVisitVoice()');
  debugPrint('🎙️ ════════════════════════════════════════');

  // 1. Consultar datos
  final int totalVisits = await _getTotalVisits();
  final _TopOption top  = await _getTopStatusOption();

  debugPrint('🎙️ [VisitVoice] totalVisits=$totalVisits');
  debugPrint('🎙️ [VisitVoice] topOption="${top.option}" count=${top.count}');

  // 2. Asegurar que el modelo esté cargado (idempotente si ya está listo)
  final singleton = VoiceModelSingleton.instance;
  if (!singleton.isReady) {
    debugPrint('🎙️ [VisitVoice] Modelo no cargado — inicializando...');
    await singleton.initialize();
  }
  debugPrint('🎙️ [VisitVoice] singleton.isReady=${singleton.isReady}  isInferring=${singleton.isInferring}');

  if (singleton.isReady && !singleton.isInferring) {
    final userPrompt = _buildUserPrompt(totalVisits, top);
    debugPrint('🎙️ [VisitVoice] ─── PROMPT ───────────────────────────────');
    debugPrint(userPrompt);
    debugPrint('🎙️ [VisitVoice] ─────────────────────────────────────────');

    final text = await singleton.infer(
      systemPrompt: _kVisitSystemPrompt,
      userPrompt:   userPrompt,
      temperature:  0.6,
      topK:         40,
      randomSeed:   1,
      timeoutSecs:  30,
    );

    debugPrint('🎙️ [VisitVoice] ─── RESPUESTA ───────────────────────────');
    debugPrint('🎙️ [VisitVoice] "$text"');
    debugPrint('🎙️ [VisitVoice] ─────────────────────────────────────────');

    if (text != null && text.isNotEmpty) {
      TTSQueueManager().enqueueSpeech(
        text, 'visit_complete', SpeechPriority.high, const Duration(seconds: 5),
      );
      debugPrint('🎙️ [VisitVoice] ✅ LLM completado y encolado en TTS');
      return;
    }
  } else {
    debugPrint('🎙️ [VisitVoice] ⚠️ Modelo no disponible o infiriendo → fallback TTS');
  }

  _speakFallback(totalVisits, top);
  debugPrint('🎙️ [VisitVoice] ✅ Fallback TTS encolado');
}

// ─── Helpers de datos ────────────────────────────────────────────────────────

Future<int> _getTotalVisits() async {
  try {
    debugPrint('🎙️ [VisitVoice] Consultando COUNT(*) FROM Visits...');
    return await globalDb.executeOperation((db) async {
      final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM Visits');
      final count = rows.isNotEmpty ? (rows.first['cnt'] as int? ?? 0) : 0;
      debugPrint('🎙️ [VisitVoice] COUNT result: $count');
      return count;
    });
  } catch (e) {
    debugPrint('🎙️ [VisitVoice] ❌ Error contando visitas: $e');
    return 0;
  }
}

class _TopOption {
  final String option;
  final int count;
  const _TopOption(this.option, this.count);
}

Future<_TopOption> _getTopStatusOption() async {
  try {
    debugPrint('🎙️ [VisitVoice] Consultando top Status_option en Visits_details...');
    return await globalDb.executeOperation((db) async {
      final rows = await db.rawQuery('''
        SELECT Status_option, COUNT(*) AS cnt
        FROM Visits_details
        WHERE Id_activity_status > 0
          AND Status_option IS NOT NULL
          AND Status_option != ''
        GROUP BY Status_option
        ORDER BY cnt DESC
        LIMIT 1
      ''');
      if (rows.isNotEmpty) {
        final option = rows.first['Status_option'] as String? ?? '';
        final count  = rows.first['cnt'] as int? ?? 1;
        debugPrint('🎙️ [VisitVoice] Top option: "$option" x$count');
        return _TopOption(option, count);
      }
      debugPrint('🎙️ [VisitVoice] Sin registros en Visits_details aún');
      return const _TopOption('', 0);
    });
  } catch (e) {
    debugPrint('🎙️ [VisitVoice] ❌ Error obteniendo opción top: $e');
    return const _TopOption('', 0);
  }
}

// ─── Construcción del prompt de usuario ──────────────────────────────────────

String _buildUserPrompt(int totalVisits, _TopOption top) {
  final buf = StringBuffer();
  buf.writeln('Datos de la visita recién registrada:');
  buf.writeln('- Total visitas registradas en la sesión: $totalVisits');
  if (top.option.isNotEmpty) {
    buf.writeln('- Opción más seleccionada: "${top.option}" (${top.count} veces)');
    buf.writeln();
    buf.writeln('Informa el total de visitas y destaca la opción más repetida de forma motivante.');
  } else {
    buf.writeln();
    buf.writeln('Felicita al operario por la visita registrada e informa el total.');
  }
  return buf.toString();
}

// ─── Fallback TTS ─────────────────────────────────────────────────────────────

void _speakFallback(int totalVisits, _TopOption top) {
  String text;
  if (top.option.isNotEmpty) {
    text = 'Visita número $totalVisits registrada. '
        'La opción más frecuente es "${top.option}" con ${top.count} selecciones.';
  } else {
    text = 'Visita número $totalVisits registrada exitosamente.';
  }
  debugPrint('🎙️ [VisitVoice] Fallback TTS: "$text"');
  TTSQueueManager().enqueueSpeech(
    text,
    'visit_complete',
    SpeechPriority.high,
    const Duration(seconds: 5),
  );
}
