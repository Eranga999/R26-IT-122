import 'package:flutter/foundation.dart';
import '../data/sigiriya_knowledge_base.dart';
import 'embedding_service.dart';
import 'vector_store_service.dart';
import 'semantic_cache_service.dart';

// ── Constants — mirror the notebook exactly ───────────────────────────────────
const double _noInfoThreshold = 0.25;
const int _topKBrief = 2;
const int _topKDetailed = 3;

// ── Status ────────────────────────────────────────────────────────────────────

class RagInitStatus {
  final bool embeddingReady;
  final bool vectorStoreReady;
  final bool cacheReady;
  final String? error;

  const RagInitStatus({
    this.embeddingReady = false,
    this.vectorStoreReady = false,
    this.cacheReady = false,
    this.error,
  });

  bool get fullyReady => embeddingReady && vectorStoreReady && cacheReady;
}

// ── Main service ──────────────────────────────────────────────────────────────

class RagService {
  final _embedding = EmbeddingService();
  final _vectorStore = VectorStoreService();
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

    _status = RagInitStatus(
      cacheReady: _status.cacheReady,
      vectorStoreReady: _status.vectorStoreReady,
      embeddingReady: _status.embeddingReady,
    );

    onProgress?.call('Ready (RAG only)', 1.0);
  }

  // ── ask ───────────────────────────────────────────────────────────────────

  Future<String> ask(
    String place,
    String mode, {
    void Function(String token)? onToken,
  }) async {
    final location = findLocation(place);

    if (location != null) {
      final directAnswer =
          mode == 'brief' ? location.briefSummary : location.detailedInfo;

      try {
        await _cache.init();
        await _cache.set(place, mode, directAnswer, const <double>[]);
      } catch (e) {
        debugPrint('[RagService] Cache write failed for direct answer: $e');
      }

      return directAnswer;
    }

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
        return _buildRagOnlyAnswer(place, [], mode);
      }
    }

    // Step 1: exact cache hit
    final (exactCached, _) = await _cache.get(place, mode);
    if (exactCached != null) {
      final cleaned = _stripLegacyRagFooter(exactCached);
      if (cleaned != exactCached) {
        await _cache.set(place, mode, cleaned, const <double>[]);
      }
      return cleaned;
    }

    // Step 2: vector search
    final topK = mode == 'brief' ? _topKBrief : _topKDetailed;
    final results = _vectorStore.search(
      place,
      topK: topK,
      noInfoThreshold: _noInfoThreshold,
    );

    // Step 3: no relevant info check
    if (results.isEmpty) {
      return "I'm sorry, I don't have any information about '$place' "
          'in my Sigiriya knowledge base. Please try another location name.';
    }

    // Step 4: collect chunks and build a retrieval-only answer.
    final chunks = results.map((r) => r.chunk.text).toList();

    final answer = _buildRagOnlyAnswer(place, chunks, mode);

    // Step 5: cache the answer
    await _cache.set(place, mode, answer, const <double>[]);

    return answer;
  }

  // ── Retrieval-only answer builder ─────────────────────────────────────────

  String _buildRagOnlyAnswer(String place, List<String> chunks, String mode) {
    final header = mode == 'brief'
        ? '📍 **$place** — Retrieved summary\n\n'
        : '📍 **$place** — Retrieved details\n\n';

    final selectedChunks = chunks.take(mode == 'brief' ? 1 : 3).toList();
    if (selectedChunks.isEmpty) {
      return '$header No relevant information was found in the knowledge base.';
    }

    final body = selectedChunks
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value.trim()}')
        .join('\n\n');

    return '$header$body';
  }

  String _stripLegacyRagFooter(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\n\n---\n\*This answer is built only from the local RAG knowledge base\.\s*No LLM is used\.\*\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trimRight();
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  Future<int> get cacheSize => _cache.size;
  Future<void> clearCache() => _cache.clear();
  bool get fullyReady => _status.fullyReady;
}
