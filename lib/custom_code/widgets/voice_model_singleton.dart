import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kVoiceModelFileName  = 'qwen2.5_0.5b_q8.task';
const String kVoiceModelReadyKey  = 'voice_model_ready';

// ─────────────────────────────────────────────────────────────────────────────
// Singleton de acceso al modelo LLM on-device.
//
// Resuelve los siguientes problemas de la implementación anterior:
//   1. _initCompleter no se resetea tras error → ahora se llama close()
//      antes de reintentar, que fuerza _initCompleter = null en flutter_gemma.
//   2. Compass y VisitVoice compartían el mismo InferenceModel sin saberlo,
//      con maxTokens diferentes → aquí hay UN solo punto de creación.
//   3. Sin mutex entre inferencias concurrentes → _isInferring es global.
//   4. System prompt iba en isUser:true → ahora dos addQueryChunk separados.
//   5. Sin timeout en getResponseAsync() → timeout de 45 s.
// ─────────────────────────────────────────────────────────────────────────────
class VoiceModelSingleton {
  VoiceModelSingleton._();
  static final VoiceModelSingleton instance = VoiceModelSingleton._();

  InferenceModel? _model;
  bool _isInferring = false;

  /// Indica si el modelo está cargado y listo para inferencia.
  bool get isReady => _model != null;

  /// Indica si hay una inferencia en curso (usado por UI y guards).
  bool get isInferring => _isInferring;

  // ─── Inicialización ───────────────────────────────────────────────────────

  /// Carga el modelo en memoria.
  /// Es seguro llamar múltiples veces: es idempotente si ya está cargado.
  Future<bool> initialize() async {
    if (_model != null) {
      debugPrint('🤖 [VoiceSingleton] Modelo ya cargado — reutilizando');
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(kVoiceModelReadyKey) ?? false)) {
        debugPrint('🤖 [VoiceSingleton] voice_model_ready=false — abortando');
        return false;
      }

      final modelPath = await resolveModelPath();
      if (!await File(modelPath).exists()) {
        debugPrint('🤖 [VoiceSingleton] Archivo no encontrado: $modelPath');
        return false;
      }

      debugPrint('🤖 [VoiceSingleton] Inicializando modelo: $modelPath');

      // Si había un modelo previo fallido, cerrarlo para resetear _initCompleter
      // en flutter_gemma (de lo contrario createModel() devuelve el error cacheado).
      await _closeExistingModel();

      await _patchInstalledModels(modelPath);

      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.qwen,
        fileType:  ModelFileType.task,
        maxTokens: 256,
      );

      debugPrint('🤖 [VoiceSingleton] ✅ Modelo listo');
      return true;
    } catch (e) {
      debugPrint('🤖 [VoiceSingleton] ❌ Error al inicializar: $e');
      _model = null;
      return false;
    }
  }

  // ─── Inferencia ───────────────────────────────────────────────────────────

  /// Ejecuta una inferencia con system prompt + user prompt separados.
  ///
  /// Retorna el texto generado, o `null` si el modelo no está listo,
  /// hay una inferencia en curso, o ocurre un error.
  ///
  /// [systemPrompt] se envía como `isUser: false` (rol system en Qwen chat template).
  /// [userPrompt]   se envía como `isUser: true`.
  /// [timeoutSecs]  máximo de segundos esperando respuesta (default: 45).
  Future<String?> infer({
    required String systemPrompt,
    required String userPrompt,
    double temperature  = 0.7,
    int    topK         = 40,
    int    randomSeed   = 42,
    int    timeoutSecs  = 45,
  }) async {
    if (_model == null) {
      debugPrint('🤖 [VoiceSingleton] infer() — modelo no cargado');
      return null;
    }
    if (_isInferring) {
      debugPrint('🤖 [VoiceSingleton] infer() — inferencia en curso, ignorando');
      return null;
    }

    _isInferring = true;
    debugPrint('🤖 [VoiceSingleton] ─── INICIO INFERENCIA ───');
    debugPrint('🤖 [VoiceSingleton] SYSTEM: $systemPrompt');
    debugPrint('🤖 [VoiceSingleton] USER:   $userPrompt');

    final session = await _model!.createSession(
      temperature: temperature,
      topK:        topK,
      randomSeed:  randomSeed,
    );

    try {
      // Formato de chat correcto para Qwen 2.5 Instruct:
      //   <|im_start|>system\n{systemPrompt}<|im_end|>
      //   <|im_start|>user\n{userPrompt}<|im_end|>
      //   <|im_start|>assistant
      await session.addQueryChunk(
        Message.text(text: systemPrompt, isUser: false),
      );
      await session.addQueryChunk(
        Message.text(text: userPrompt, isUser: true),
      );

      final buf = StringBuffer();
      await for (final token in session.getResponseAsync().timeout(
        Duration(seconds: timeoutSecs),
        onTimeout: (sink) {
          debugPrint('🤖 [VoiceSingleton] ⏱ Timeout ($timeoutSecs s) — cerrando stream');
          sink.close();
        },
      )) {
        buf.write(token);
      }

      final text = buf.toString().trim();
      debugPrint('🤖 [VoiceSingleton] RESPUESTA: "$text"');
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('🤖 [VoiceSingleton] ❌ Error en sesión: $e');
      return null;
    } finally {
      await session.close();
      _isInferring = false;
      debugPrint('🤖 [VoiceSingleton] ─── FIN INFERENCIA ───');
    }
  }

  // ─── Limpieza ─────────────────────────────────────────────────────────────

  /// Cierra el modelo y libera recursos nativos.
  /// Después de esto, [isReady] es false y se puede llamar [initialize()] de nuevo.
  Future<void> dispose() async {
    await _closeExistingModel();
    debugPrint('🤖 [VoiceSingleton] Modelo liberado');
  }

  // ─── Privados ─────────────────────────────────────────────────────────────

  Future<void> _closeExistingModel() async {
    if (_model != null) {
      try {
        await _model!.close();
      } catch (_) {}
      _model = null;
    }
  }

  /// Registra el archivo en `installed_models` de SharedPreferences.
  /// flutter_gemma 0.11.0 bug: registerExternalFile() no lo agrega,
  /// y isModelInstalled() lo requiere para devolver true.
  Future<void> _patchInstalledModels(String modelPath) async {
    await FlutterGemmaPlugin.instance.modelManager.setModelPath(modelPath);
    final prefs    = await SharedPreferences.getInstance();
    final fileName = modelPath.split('/').last; // 'qwen2.5_0.5b_q8.task'
    final models   = List<String>.from(prefs.getStringList('installed_models') ?? []);
    debugPrint('🤖 [VoiceSingleton] installed_models actual: $models');
    if (!models.contains(fileName)) {
      models.add(fileName);
      await prefs.setStringList('installed_models', models);
      debugPrint('🤖 [VoiceSingleton] Patch installed_models → $fileName');
    }
  }
}

/// Resuelve la ruta del modelo en getApplicationDocumentsDirectory() (app_flutter/),
/// que es exactamente donde flutter_gemma busca con ModelFileSystemManager.
Future<String> resolveModelPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$kVoiceModelFileName';
}
