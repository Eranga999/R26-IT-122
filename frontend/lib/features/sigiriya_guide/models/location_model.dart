// lib/models/location_model.dart

class SigiriyaLocation {
  final String id;
  final String name;
  final String emoji;
  final String briefSummary;
  final String detailedInfo;
  final List<String> imageAssets; // asset paths
  final List<String> tags;
  final List<double> embedding; // pre-computed embedding (cosine similarity)

  const SigiriyaLocation({
    required this.id,
    required this.name,
    required this.emoji,
    required this.briefSummary,
    required this.detailedInfo,
    required this.imageAssets,
    required this.tags,
    this.embedding = const [],
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? location;
  final String? mode; // 'brief' or 'detailed'

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.location,
    this.mode,
  });
}

class SearchResult {
  final SigiriyaLocation location;
  final double score;

  SearchResult({required this.location, required this.score});
}
