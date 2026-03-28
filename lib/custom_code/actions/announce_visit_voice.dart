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

import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/backend/sqlite/global_db_singleton.dart';
import '/custom_code/widgets/tts_queue_manager.dart';

// Singleton para reutilizar el modelo entre visitas sucesivas
InferenceModel? _cachedVoiceModel;

const String _kModelReadyKey   = 'voice_model_ready';
const String _kModelFileName   = 'qwen2.5_0.5b_q8.task';

Future<String> _resolveModelPath() async {
  final ext = await getExternalStorageDirectory();
  if (ext != null) return '${ext.path}/$_kModelFileName';
  final dir = await getApplicationDocumentsDirectory();
  final sub = Directory('${dir.path}/voice_models');
  await sub.create(recursive: true);
  return '${sub.path}/$_kModelFileName';
}

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
  final _TopOption top = await _getTopStatusOption();

  debugPrint('🎙️ [VisitVoice] totalVisits=$totalVisits');
  debugPrint('🎙️ [VisitVoice] topOption="${top.option}" count=${top.count}');

  // 2. Verificar modelo
  final bool modelOk = await _isModelAvailable();
  debugPrint('🎙️ [VisitVoice] modelAvailable=$modelOk  cachedModel=${_cachedVoiceModel != null ? "YA CARGADO" : "NULL"}');

  if (modelOk) {
    try {
      await _speakWithLLM(totalVisits, top);
      debugPrint('🎙️ [VisitVoice] ✅ LLM completado exitosamente');
      return;
    } catch (e, stack) {
      debugPrint('🎙️ [VisitVoice] ❌ Error LLM: $e');
      debugPrint('🎙️ [VisitVoice] Stack: $stack');
      _cachedVoiceModel = null;
    }
  } else {
    debugPrint('🎙️ [VisitVoice] ⚠️ Modelo no disponible → usando fallback TTS');
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

// ─── Verificación del modelo ─────────────────────────────────────────────────

Future<bool> _isModelAvailable() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final prefReady = prefs.getBool(_kModelReadyKey) ?? false;
    debugPrint('🎙️ [VisitVoice] SharedPrefs voice_model_ready=$prefReady');
    if (!prefReady) return false;

    final path = await _resolveModelPath();
    final file = File(path);
    final exists = file.existsSync();
    debugPrint('🎙️ [VisitVoice] Archivo modelo: $path → exists=$exists');
    return exists;
  } catch (e) {
    debugPrint('🎙️ [VisitVoice] ❌ Error verificando modelo: $e');
    return false;
  }
}

// ─── Workaround flutter_gemma 0.11.0: registerExternalFile() no agrega el
// archivo a `installed_models`, que es lo que verifica isModelInstalled().
// Sin este patch, createModel() lanza "Active model is no longer installed".
Future<void> _patchFlutterGemmaInstalled(String modelPath) async {
  await FlutterGemmaPlugin.instance.modelManager.setModelPath(modelPath);
  final prefs = await SharedPreferences.getInstance();
  // flutter_gemma usa el nombre SIN extensión en installed_models
  final fileName = modelPath.split('/').last;
  final modelName = fileName.endsWith('.task')
      ? fileName.substring(0, fileName.length - 5)
      : fileName;
  final models = List<String>.from(prefs.getStringList('installed_models') ?? []);
  debugPrint('🔧 [VisitVoice] installed_models actual: $models');
  if (!models.contains(modelName)) {
    models.add(modelName);
    await prefs.setStringList('installed_models', models);
    debugPrint('🔧 [VisitVoice] Patched installed_models → agregado: $modelName');
  } else {
    debugPrint('🔧 [VisitVoice] installed_models ya contiene: $modelName');
  }
}

// ─── LLM ─────────────────────────────────────────────────────────────────────

Future<void> _speakWithLLM(int totalVisits, _TopOption top) async {
  final modelPath = await _resolveModelPath();

  if (_cachedVoiceModel == null) {
    debugPrint('🎙️ [VisitVoice] 🔄 Inicializando modelo por primera vez...');
    debugPrint('🎙️ [VisitVoice]    patchFlutterGemmaInstalled → $modelPath');
    await _patchFlutterGemmaInstalled(modelPath);
    debugPrint('🎙️ [VisitVoice]    createModel(qwen, task, maxTokens:128)...');
    _cachedVoiceModel = await FlutterGemmaPlugin.instance.createModel(
      modelType: ModelType.qwen,
      fileType:  ModelFileType.task,
      maxTokens: 128,
    );
    debugPrint('🎙️ [VisitVoice] ✅ Modelo inicializado y cacheado');
  } else {
    debugPrint('🎙️ [VisitVoice] ♻️  Reutilizando modelo cacheado');
  }

  final prompt = _buildPrompt(totalVisits, top);
  debugPrint('🎙️ [VisitVoice] ─── PROMPT ENVIADO AL LLM ───────────────────');
  debugPrint(prompt);
  debugPrint('🎙️ [VisitVoice] ────────────────────────────────────────────');

  debugPrint('🎙️ [VisitVoice] Creando sesión (temp=0.6, topK=40, seed=1)...');
  final session = await _cachedVoiceModel!.createSession(
    temperature: 0.6,
    topK:        40,
    randomSeed:  1,
  );
  debugPrint('🎙️ [VisitVoice] ✅ Sesión creada, enviando query...');

  try {
    await session.addQueryChunk(Message.text(text: prompt, isUser: true));
    debugPrint('🎙️ [VisitVoice] Leyendo stream de respuesta...');
    final buf = StringBuffer();
    await for (final token in session.getResponseAsync()) {
      buf.write(token);
    }
    final text = buf.toString().trim();
    debugPrint('🎙️ [VisitVoice] ─── RESPUESTA LLM ──────────────────────────');
    debugPrint('🎙️ [VisitVoice] "$text"');
    debugPrint('🎙️ [VisitVoice] ─────────────────────────────────────────────');
    if (text.isNotEmpty) {
      TTSQueueManager().enqueueSpeech(
        text,
        'visit_complete',
        SpeechPriority.high,
        const Duration(seconds: 5),
      );
      debugPrint('🎙️ [VisitVoice] ✅ Texto encolado en TTS');
    } else {
      debugPrint('🎙️ [VisitVoice] ⚠️ Respuesta LLM vacía');
    }
  } finally {
    await session.close();
    debugPrint('🎙️ [VisitVoice] Sesión cerrada');
  }
}

String _buildPrompt(int totalVisits, _TopOption top) {
  final buf = StringBuffer();
  buf.writeln(_kVisitSystemPrompt);
  buf.writeln();
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
