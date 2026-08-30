import 'heritage_entry.dart';

enum MatchType {
  exactCanonical,
  normalizedExact,
  alias,
  phraseContainment,
  fuzzy,
  mlKit,
  wordLevel,
  none,
}

enum TranslationStatus {
  success,
  partial,
  unsupported,
  empty,
}

class TranslationResult {
  final String inputText;
  final String normalizedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String translatedText;
  final HeritageEntry? matchedEntry;
  final MatchType matchType;
  final double confidence;
  final TranslationStatus status;
  final bool isOffline;

  const TranslationResult({
    required this.inputText,
    required this.normalizedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translatedText,
    this.matchedEntry,
    required this.matchType,
    required this.confidence,
    required this.status,
    this.isOffline = true,
  });

  factory TranslationResult.unsupported({
    required String inputText,
    required String normalizedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return TranslationResult(
      inputText: inputText,
      normalizedText: normalizedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      translatedText: inputText,
      matchedEntry: null,
      matchType: MatchType.none,
      confidence: 0.0,
      status: TranslationStatus.unsupported,
      isOffline: true,
    );
  }

  factory TranslationResult.empty({
    required String targetLanguage,
  }) {
    return TranslationResult(
      inputText: '',
      normalizedText: '',
      sourceLanguage: 'unknown',
      targetLanguage: targetLanguage,
      translatedText: '',
      matchedEntry: null,
      matchType: MatchType.none,
      confidence: 0.0,
      status: TranslationStatus.empty,
      isOffline: true,
    );
  }

  bool get isSupported => status == TranslationStatus.success || status == TranslationStatus.partial;

  @override
  String toString() {
    return 'TranslationResult(input: "$inputText", translated: "$translatedText", lang: $sourceLanguage->$targetLanguage, match: $matchType, conf: ${confidence.toStringAsFixed(2)}, status: $status)';
  }
}
