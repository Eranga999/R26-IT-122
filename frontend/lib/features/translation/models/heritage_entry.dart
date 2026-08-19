class HeritageEntry {
  final String id;
  final String category;
  final Map<String, String> canonical;
  final List<String> aliases;
  final Map<String, String> translations;
  final double confidence;
  final String source;
  final String reviewStatus;

  const HeritageEntry({
    required this.id,
    required this.category,
    required this.canonical,
    required this.aliases,
    required this.translations,
    required this.confidence,
    required this.source,
    required this.reviewStatus,
  });

  factory HeritageEntry.fromJson(Map<String, dynamic> json) {
    final canonicalMap = <String, String>{};
    final rawCanonical = json['canonical'] as Map<String, dynamic>? ?? {};
    rawCanonical.forEach((k, v) => canonicalMap[k] = v.toString());

    final translationsMap = <String, String>{};
    final rawTranslations = json['translations'] as Map<String, dynamic>? ?? {};
    rawTranslations.forEach((k, v) => translationsMap[k] = v.toString());

    final rawAliases = json['aliases'] as List<dynamic>? ?? [];
    final aliasList = rawAliases.map((a) => a.toString()).toList();

    return HeritageEntry(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      canonical: canonicalMap,
      aliases: aliasList,
      translations: translationsMap,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      source: json['source']?.toString() ?? 'unknown',
      reviewStatus: json['review_status']?.toString() ?? 'unverified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'canonical': canonical,
      'aliases': aliases,
      'translations': translations,
      'confidence': confidence,
      'source': source,
      'review_status': reviewStatus,
    };
  }
}
