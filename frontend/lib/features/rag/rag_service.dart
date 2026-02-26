import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';

/// A minimal offline Retrieval-Augmented Generation (RAG) assistant.
///
/// Currently performs keyword search over pre-indexed JSON embeddings
/// stored in [assets/embeddings/].  Replace with vector-similarity search
/// once a suitable on-device library is available.
class RagService {
  RagService._();
  static final RagService instance = RagService._();

  /// Map of landmark name → list of text chunks.
  final Map<String, List<String>> _index = {};

  bool get isLoaded => _index.isNotEmpty;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads the embedding index from [assets/embeddings/<landmark>.json].
  ///
  /// Each JSON file must follow the schema:
  /// ```json
  /// { "landmark": "Sigiriya", "chunks": ["text1", "text2"] }
  /// ```
  Future<void> loadIndex(List<String> landmarkNames) async {
    for (final name in landmarkNames) {
      final path =
          '${AppConstants.embeddingsPath}${name.toLowerCase()}_embeddings.json';
      try {
        final raw = await rootBundle.loadString(path);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _index[name.toLowerCase()] = (json['chunks'] as List).cast<String>();
      } catch (_) {
        // File not yet present – silently skip.
      }
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Returns the most relevant text chunk for [query] about [landmarkName].
  ///
  /// The simple strategy: count keyword overlaps between query tokens and
  /// each chunk.  Replace with cosine similarity over stored vectors later.
  String query(String landmarkName, String query) {
    final chunks = _index[landmarkName.toLowerCase()];
    if (chunks == null || chunks.isEmpty) {
      return 'No offline information available for $landmarkName.';
    }

    final queryTokens = query.toLowerCase().split(RegExp(r'\W+')).toSet();

    String bestChunk = chunks.first;
    int bestScore = 0;

    for (final chunk in chunks) {
      final chunkTokens = chunk.toLowerCase().split(RegExp(r'\W+')).toSet();
      final score = queryTokens.intersection(chunkTokens).length;
      if (score > bestScore) {
        bestScore = score;
        bestChunk = chunk;
      }
    }
    return bestChunk;
  }
}
