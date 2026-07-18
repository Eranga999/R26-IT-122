import 'dart:io';
import 'package:flutter/foundation.dart';
import 'embedding_service.dart';
import 'vector_store_service.dart';
import 'llm_service.dart';
import 'semantic_cache_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Constants — mirror the notebook exactly ───────────────────────────────────
const double _noInfoThreshold = 0.25;
const int _topKBrief = 2;
const int _topKDetailed = 3;

// ── Status ────────────────────────────────────────────────────────────────────

class RagInitStatus {
  final bool embeddingReady;
  final bool vectorStoreReady;
  final bool llmReady;
  final bool cacheReady;
  final String? error;

  const RagInitStatus({
    this.embeddingReady = false,
    this.vectorStoreReady = false,
    this.llmReady = false,
    this.cacheReady = false,
    this.error,
  });

  bool get fullyReady =>
      embeddingReady && vectorStoreReady && llmReady && cacheReady;
}

// ── Main service ──────────────────────────────────────────────────────────────

class RagService {
  final _embedding = EmbeddingService();
  final _vectorStore = VectorStoreService();
  final _llm = LlmService();
  final _cache = SemanticCache();

  RagInitStatus _status = const RagInitStatus();
  RagInitStatus get status => _status;

  // ── init ──────────────────────────────────────────────────────────────────

  Future<void> init({
    void Function(String step, double progress)? onProgress,
  }) async {
    // 1. Cache
    try {
      onProgress?.call('Loading cache…', 0.1);
      await _cache.init();
      _status = const RagInitStatus(cacheReady: true);
    } catch (e) {
      _status = RagInitStatus(error: 'Cache init failed: $e');
      return;
    }

    // 2. Vector store
    try {
      onProgress?.call('Loading vector store…', 0.3);
      await _vectorStore.init();
      _status = RagInitStatus(
        cacheReady: _status.cacheReady,
        vectorStoreReady: true,
      );
    } catch (e) {
      _status = RagInitStatus(
        cacheReady: _status.cacheReady,
        error: 'Vector store failed: $e\n\n'
            'Run tools/convert_to_flutter.py on your PC first, '
            'then copy assets/data/ into the Flutter project.',
      );
      return;
    }

    // 3. Embedding model
    try {
      onProgress?.call('Loading embedding model…', 0.55);
      await _embedding.init();
      _status = RagInitStatus(
        cacheReady: _status.cacheReady,
        vectorStoreReady: _status.vectorStoreReady,
        embeddingReady: true,
      );
    } catch (e) {
      debugPrint('[RagService] Embedding init failed (continuing): $e');
      _status = RagInitStatus(
        cacheReady: _status.cacheReady,
        vectorStoreReady: _status.vectorStoreReady,
        embeddingReady: false,
      );
    }

    // 4. LLM
    try {
      onProgress?.call('Checking LLM…', 0.75);
      final downloaded = await _llm.isModelDownloaded();
      if (downloaded) {
        await _llm.init(
          onProgress: (p, s) => onProgress?.call(s, 0.75 + p * 0.25),
        );
        _status = RagInitStatus(
          cacheReady: _status.cacheReady,
          vectorStoreReady: _status.vectorStoreReady,
          embeddingReady: _status.embeddingReady,
          llmReady: true,
        );
      } else {
        _status = RagInitStatus(
          cacheReady: _status.cacheReady,
          vectorStoreReady: _status.vectorStoreReady,
          embeddingReady: _status.embeddingReady,
          llmReady: false,
        );
      }
    } catch (e) {
      _status = RagInitStatus(
        cacheReady: _status.cacheReady,
        vectorStoreReady: _status.vectorStoreReady,
        embeddingReady: _status.embeddingReady,
        error: 'LLM init failed: $e',
      );
    }

    onProgress?.call('Ready', 1.0);
  }

  // ── ask ───────────────────────────────────────────────────────────────────

  Future<String> ask(
    String place,
    String mode, {
    void Function(String token)? onToken,
  }) async {
    // Ensure core services are initialised (lazy init when user asks).
    try {
      await _cache.init();
    } catch (e) {
      debugPrint('[RagService] Cache init failed (continuing): $e');
    }

    if (!_vectorStore.isReady) {
      try {
        await _vectorStore.init();
      } catch (e) {
        debugPrint('[RagService] Vector store init failed: $e');
        return _buildDegradedAnswer(place, [], mode);
      }
    }

    if (!_embedding.isReady) {
      try {
        await _embedding.init();
      } catch (e) {
        debugPrint('[RagService] Embedding init failed (continuing): $e');
      }
    }

    // Step 1: exact cache hit
    final (exactCached, _) = await _cache.get(place, mode);
    if (exactCached != null) return exactCached;

    // Step 2: semantic cache hit (only when embeddings are available)
    List<double>? queryVec;
    if (_embedding.isReady) {
      queryVec = await _embedding.embed(place);
      final (semCached, _) = await _cache.getByEmbedding(queryVec, mode);
      if (semCached != null) return semCached;
    }

    // Step 4: vector search
    final topK = mode == 'brief' ? _topKBrief : _topKDetailed;
    final results = _vectorStore.search(
      place,
      topK: topK,
      noInfoThreshold: _noInfoThreshold,
    );

    // Step 5: no relevant info check
    if (results.isEmpty) {
      return "I'm sorry, I don't have any information about '$place' "
          'in my Sigiriya knowledge base. Please try another location name.';
    }

    // Step 6: collect chunks — DO NOT truncate here.
    // LlmService._buildDetailedPrompt() caps each chunk at 400 chars
    // internally to protect the context window budget.
    final chunks = results.map((r) => r.chunk.text).toList();

    // Step 7: generate
    final String answer;
    if (_llm.isReady) {
      answer = await _llm.generate(
        place: place,
        contextChunks: chunks,
        mode: mode,
        onToken: onToken,
      );
    } else {
      answer = _buildDegradedAnswer(place, chunks, mode);
    }

    // Step 8: cache the answer
    await _cache.set(place, mode, answer, queryVec ?? const <double>[]);

    return answer;
  }

  // ── LLM download / load ───────────────────────────────────────────────────

  Future<void> downloadLlm({
    void Function(double progress, String status)? onProgress,
  }) async {
    final bool exists = await _llm.isModelDownloaded();
    if (exists) {
      onProgress?.call(1.0, 'Model located successfully ✓');
    } else {
      onProgress?.call(0.0, 'Model not found');
      throw Exception(
        'Phi-3 model file not found.\n\n'
        'Please place "Phi-3-mini-4k-instruct-q4.gguf" in your '
        "phone's Download/heritageAR-chatbot/ folder.",
      );
    }
  }

  Future<void> requestStorageAccess() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  Future<void> loadLlmAfterDownload({
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.0, 'Checking storage permissions…');
    await requestStorageAccess();

    if (!await Permission.manageExternalStorage.isGranted) {
      onProgress?.call(0.0, 'Permission denied. Cannot load model.');
      return;
    }

    await _llm.init(onProgress: onProgress);

    _status = RagInitStatus(
      cacheReady: _status.cacheReady,
      vectorStoreReady: _status.vectorStoreReady,
      embeddingReady: _status.embeddingReady,
      llmReady: true,
    );
  }

  // ── Degraded mode — no LLM ────────────────────────────────────────────────

  String _buildDegradedAnswer(String place, List<String> chunks, String mode) {
    final header = mode == 'brief'
        ? '📍 **$place** — Summary\n\n'
        : '📍 **$place** — Detailed Information\n\n';
    final body = chunks.take(mode == 'brief' ? 1 : 3).join('\n\n---\n\n');
    const footer =
        '\n\n---\n*⚠️ LLM not loaded — showing raw PDF knowledge base. '
        'Download Phi-3 for AI-generated answers.*';
    return '$header$body$footer';
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  Future<int> get cacheSize => _cache.size;
  Future<void> clearCache() => _cache.clear();
  bool get llmReady => _llm.isReady;
  bool get fullyReady => _status.fullyReady;
}
