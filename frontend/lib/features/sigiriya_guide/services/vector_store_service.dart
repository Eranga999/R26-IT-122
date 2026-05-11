import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class Chunk {
  final int id;
  final String source;
  final String text;

  Chunk({required this.id, required this.source, required this.text});

  factory Chunk.fromJson(Map<String, dynamic> j) => Chunk(
        id: j['id'] as int,
        source: j['source'] as String,
        text: j['text'] as String,
      );
}

class RetrievedChunk {
  final Chunk chunk;
  final double score;
  RetrievedChunk({required this.chunk, required this.score});
}

class VectorStoreService {
  static VectorStoreService? _instance;

  List<Chunk> _chunks = [];
  bool _ready = false;

  VectorStoreService._();
  factory VectorStoreService() => _instance ??= VectorStoreService._();

  bool get isReady => _ready;
  int get numChunks => _chunks.length;

  /// Load chunks.json and vectors.json from Flutter assets.
  Future<void> init() async {
    if (_ready) return;

    final raw = await rootBundle
        .loadString('assets/embeddings/sigiriya_embeddings.json');
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final chunksList =
        (parsed['chunks'] as List<dynamic>? ?? const <dynamic>[]);
    _chunks = <Chunk>[];
    for (var i = 0; i < chunksList.length; i++) {
      _chunks.add(
        Chunk(
          id: i,
          source: 'sigiriya_embeddings.json',
          text: chunksList[i].toString(),
        ),
      );
    }

    _ready = true;
  }

  /// Return the top-K most similar chunks to [queryText].
  /// [noInfoThreshold] mirrors Python's NO_INFO_THRESHOLD = 0.25
  List<RetrievedChunk> search(
    String queryText, {
    int topK = 3,
    double noInfoThreshold = 0.25,
  }) {
    if (!_ready) throw StateError('VectorStoreService not initialised');

    final scores = <RetrievedChunk>[];

    for (int i = 0; i < _chunks.length; i++) {
      final score = _keywordScore(queryText, _chunks[i].text);
      if (score >= noInfoThreshold) {
        scores.add(RetrievedChunk(chunk: _chunks[i], score: score));
      }
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(topK).toList();
  }

  double _keywordScore(String query, String text) {
    final queryTerms = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((term) => term.length > 2)
        .toSet();
    if (queryTerms.isEmpty) return 0;

    final textLower = text.toLowerCase();
    double score = 0;
    for (final term in queryTerms) {
      if (textLower.contains(term)) {
        score += term.length >= 6 ? 0.45 : 0.30;
      }
    }
    return min(score, 1.0);
  }

  void dispose() {
    _chunks.clear();
    _ready = false;
    _instance = null;
  }
}
