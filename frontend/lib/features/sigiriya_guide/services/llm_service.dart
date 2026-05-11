import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

typedef ProgressCallback = void Function(double progress, String status);

class LlmService {
  static LlmService? _instance;

  Llama? _llama;
  bool _ready = false;
  bool _loading = false;
  String? _cachedModelPath;

  static const _modelFileName = 'Phi-3-mini-4k-instruct-q4.gguf';

  // ── FIX 1: Match notebook exactly: brief=350, detailed=2000 ──────────────
  static const int _maxTokensBrief = 350;
  static const int _maxTokensDetailed = 2000;
  static const int _contextSize = 4096;

  // ── FIX 2: Match notebook SYSTEM_PROMPT exactly ───────────────────────────
  static const String _systemPrompt =
      'You are a knowledgeable and friendly guide for Sigiriya, '
      'the UNESCO World Heritage Site in Sri Lanka. '
      'Answer questions based on the provided context. '
      'Be informative, accurate, and engaging. '
      "If the context doesn't contain relevant information, "
      "say you don't have that information.";

  LlmService._();
  factory LlmService() => _instance ??= LlmService._();

  bool get isReady => _ready;
  bool get isLoading => _loading;

  // ── Model path resolution with Auto-Copy Fix ──────────────────────────────

  Future<String> get _modelPath async {
    if (_cachedModelPath != null) return _cachedModelPath!;

    final dir = await getApplicationDocumentsDirectory();
    final internalPath = '${dir.path}/$_modelFileName';

    if (await File(internalPath).exists()) {
      debugPrint('[LlmService] Found model in app documents: $internalPath');
      _cachedModelPath = internalPath;
      return internalPath;
    }

    final externalCandidates = [
      '/storage/emulated/0/heritageAR-chatbot/heritageAR-chatbot/models/$_modelFileName',
      '/storage/emulated/0/$_modelFileName',
      '/sdcard/heritageAR-chatbot/heritageAR-chatbot/models/$_modelFileName',
    ];

    for (final p in externalCandidates) {
      final externalFile = File(p);
      if (await externalFile.exists()) {
        debugPrint('[LlmService] Found model at external path: $p');
        debugPrint('[LlmService] Copying to internal storage...');
        try {
          await externalFile.copy(internalPath);
          debugPrint('[LlmService] Copy successful!');
          _cachedModelPath = internalPath;
          return internalPath;
        } catch (e) {
          debugPrint('[LlmService] Copy failed: $e. Trying direct load.');
          return p;
        }
      }
    }

    return internalPath;
  }

  Future<bool> isModelDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    if (await File('${dir.path}/$_modelFileName').exists()) return true;

    final candidates = [
      '/storage/emulated/0/heritageAR-chatbot/heritageAR-chatbot/models/$_modelFileName',
      '/storage/emulated/0/$_modelFileName',
    ];
    for (final p in candidates) {
      if (await File(p).exists()) return true;
    }
    return false;
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init({ProgressCallback? onProgress}) async {
    if (_ready) return;
    if (_loading) return;
    _loading = true;

    try {
      onProgress?.call(0.1, 'Resolving model path…');
      final path = await _modelPath;

      if (!await File(path).exists()) {
        throw Exception(
          'Model file not found. Please ensure the GGUF is in '
          'Downloads/heritageAR-chatbot/heritageAR-chatbot/models/',
        );
      }

      onProgress?.call(0.4, 'Initializing Llama (CPU)…');
      debugPrint('[LlmService] Initializing Llama with path: $path');

      final modelParams = ModelParams()
        ..nGpuLayers = 0
        ..useMemorymap = true
        ..useMemoryLock = false;

      final contextParams = ContextParams()
        ..nCtx = _contextSize
        ..nPredict = -1;

      _llama = Llama(
        path,
        modelParams: modelParams,
        contextParams: contextParams,
      );

      _ready = true;
      _loading = false;
      onProgress?.call(1.0, 'Phi-3 ready ✓');
    } catch (e) {
      _loading = false;
      debugPrint('[LlmService] Initialization Error: $e');
      rethrow;
    }
  }

  // ── Generation Logic ─────────────────────────────────────────────────────

  Future<String> generate({
    required String place,
    required List<String> contextChunks,
    required String mode,
    void Function(String token)? onToken,
  }) async {
    if (!_ready || _llama == null) {
      throw StateError('LlmService not initialised.');
    }

    // ── FIX 3: Use separate prompt builders matching the notebook exactly ──
    final prompt = mode == 'brief'
        ? _buildBriefPrompt(place, contextChunks)
        : _buildDetailedPrompt(place, contextChunks);

    final maxTokens = mode == 'brief' ? _maxTokensBrief : _maxTokensDetailed;
    final stopTokens = {'<|end|>', '<|user|>', '</s>', '<|endoftext|>'};
    final buffer = StringBuffer();
    int chunkCount = 0;

    try {
      final llama = _llama!;
      llama.clear();
      llama.setPrompt(prompt);

      await for (final text in llama.generateText()) {
        buffer.write(text);
        chunkCount++;

        onToken?.call(text);

        if (chunkCount >= maxTokens ||
            _containsStopToken(buffer.toString(), stopTokens)) {
          break;
        }
      }
    } on LlamaException catch (e) {
      debugPrint('[LlmService] Generation error: $e');
      rethrow;
    }

    return _cleanResponse(buffer.toString(), stopTokens);
  }

  bool _containsStopToken(String text, Set<String> stops) {
    final tail = text.length > 30 ? text.substring(text.length - 30) : text;
    for (final s in stops) {
      if (tail.contains(s)) return true;
    }
    return false;
  }

  String _cleanResponse(String text, Set<String> stops) {
    String cleaned = text;
    for (final s in stops) {
      if (cleaned.contains(s)) {
        cleaned = cleaned.split(s).first;
      }
    }
    return cleaned.trim();
  }

  // ── FIX 5: Separate prompt builders — mirrors notebook exactly ────────────
  //
  // Notebook build_brief_prompt():
  //   "Give a SHORT summarized overview (3-5 sentences) about '{place}'
  //    at Sigiriya heritage site. Focus on what it is and why it is
  //    historically significant."
  //
  // Notebook build_detailed_prompt():
  //   "Give a DETAILED and comprehensive description of '{place}' at Sigiriya
  //    heritage site. Cover its history, architectural features, significance,
  //    and any interesting facts. Organize the answer clearly."

  String _buildBriefPrompt(String place, List<String> chunks) {
    // Brief uses TOP_K_BRIEF=2 chunks — no need to trim further
    final context = chunks.join('\n\n');
    return '<|system|>\n$_systemPrompt<|end|>\n'
        '<|user|>\n'
        'Context:\n$context\n\n'
        "Give a SHORT summarized overview (3-5 sentences) about '$place' "
        'at Sigiriya heritage site. Focus on what it is and why it is '
        'historically significant.<|end|>\n'
        '<|assistant|>\n';
  }

  String _buildDetailedPrompt(String place, List<String> chunks) {
    // ── FIX 6: Detailed uses TOP_K_DETAILED=3 chunks — include ALL of them.
    // The old code was truncating to take(3) which was harmless when topK=3,
    // but the prompt itself was weak. Now we use the full notebook wording.
    final context = chunks.join('\n\n');
    return '<|system|>\n$_systemPrompt<|end|>\n'
        '<|user|>\n'
        'Context:\n$context\n\n'
        "Give a detailed but COMPLETE description of '$place' at Sigiriya (140–160 words). "
        "Include history, architecture, purpose, significance, and key facts. "
        "Ensure it is clear and fully finished.<|end|>\n"
        '<|assistant|>\n';
  }

  Future<void> dispose() async {
    _llama?.dispose();
    _llama = null;
    _ready = false;
    _instance = null;
  }
}
