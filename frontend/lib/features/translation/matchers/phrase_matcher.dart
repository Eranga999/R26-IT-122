import 'dart:math' as math;
import '../models/heritage_entry.dart';
import '../models/translation_result.dart';
import '../processors/ocr_text_processor.dart';

class MatchCandidate {
  final HeritageEntry entry;
  final MatchType matchType;
  final double confidence;

  const MatchCandidate({
    required this.entry,
    required this.matchType,
    required this.confidence,
  });
}

/// Precomputed, normalized candidate strings for one [HeritageEntry].
/// Cached for the app's lifetime — see [PhraseMatcher._candidatesFor].
class _EntryCandidates {
  final Set<String> rawCanonicalAndTranslationsTrimmed;
  final Set<String> normalizedAliases;
  final Set<String> normalizedCanonicalAndTranslations;
  final Set<String> normalizedAll;

  const _EntryCandidates({
    required this.rawCanonicalAndTranslationsTrimmed,
    required this.normalizedAliases,
    required this.normalizedCanonicalAndTranslations,
    required this.normalizedAll,
  });
}

class PhraseMatcher {
  final OcrTextProcessor textProcessor;

  const PhraseMatcher({
    this.textProcessor = const OcrTextProcessor(),
  });

  // Per-entry candidate strings, normalized once and reused for the app's
  // lifetime. Knowledge-base entries are loaded once at startup and the same
  // instances are handed back on every match() call, so keying the cache by
  // entry.id is safe. Without this, every capture re-ran Unicode-aware regex
  // normalization on every candidate string of every entry, up to 3 times
  // (levels 2, 4, 5) per OCR block — the main cause of post-capture jank.
  static final Map<String, _EntryCandidates> _cache = {};

  _EntryCandidates _candidatesFor(HeritageEntry entry) {
    final cached = _cache[entry.id];
    if (cached != null) return cached;

    final canonicalAndTranslations = <String>{
      ...entry.canonical.values,
      ...entry.translations.values,
    };
    final normalizedAliases = entry.aliases
        .map(textProcessor.normalize)
        .where((s) => s.isNotEmpty)
        .toSet();
    final normalizedCanonicalAndTranslations = canonicalAndTranslations
        .map(textProcessor.normalize)
        .where((s) => s.isNotEmpty)
        .toSet();

    final result = _EntryCandidates(
      rawCanonicalAndTranslationsTrimmed:
          canonicalAndTranslations.map((s) => s.trim()).toSet(),
      normalizedAliases: normalizedAliases,
      normalizedCanonicalAndTranslations: normalizedCanonicalAndTranslations,
      normalizedAll: {...normalizedAliases, ...normalizedCanonicalAndTranslations},
    );
    _cache[entry.id] = result;
    return result;
  }

  /// Match normalized input text against knowledge base entries.
  MatchCandidate? match(String rawInput, List<HeritageEntry> entries) {
    if (rawInput.trim().isEmpty || entries.isEmpty) return null;

    final normalizedInput = textProcessor.normalize(rawInput);
    final rawTrimmed = rawInput.trim();

    // ── Level 1: Exact Canonical / Translation Match ───────────────────────────
    for (final entry in entries) {
      if (_candidatesFor(entry)
          .rawCanonicalAndTranslationsTrimmed
          .contains(rawTrimmed)) {
        return MatchCandidate(
          entry: entry,
          matchType: MatchType.exactCanonical,
          confidence: 1.00,
        );
      }
    }

    // ── Level 2: Normalized Exact Match ────────────────────────────────────────
    for (final entry in entries) {
      if (_candidatesFor(entry)
          .normalizedCanonicalAndTranslations
          .contains(normalizedInput)) {
        return MatchCandidate(
          entry: entry,
          matchType: MatchType.normalizedExact,
          confidence: 0.98,
        );
      }
    }

    // ── Level 3: Alias Match ───────────────────────────────────────────────────
    for (final entry in entries) {
      if (_candidatesFor(entry).normalizedAliases.contains(normalizedInput)) {
        return MatchCandidate(
          entry: entry,
          matchType: MatchType.alias,
          confidence: 0.95,
        );
      }
    }

    // ── Level 4: Phrase Containment ───────────────────────────────────────────
    HeritageEntry? bestContainmentEntry;
    int longestContainmentLen = 0;

    for (final entry in entries) {
      for (final normCand in _candidatesFor(entry).normalizedAll) {
        if (normCand.length >= 3 && normalizedInput.contains(normCand)) {
          if (normCand.length > longestContainmentLen) {
            longestContainmentLen = normCand.length;
            bestContainmentEntry = entry;
          }
        }
      }
    }

    if (bestContainmentEntry != null) {
      return MatchCandidate(
        entry: bestContainmentEntry,
        matchType: MatchType.phraseContainment,
        confidence: 0.85,
      );
    }

    // ── Level 5: Fuzzy Matching (OCR Noise & Small Typo Correction) ──────────
    HeritageEntry? bestFuzzyEntry;
    double maxFuzzyScore = 0.0;

    for (final entry in entries) {
      for (final normCandidate in _candidatesFor(entry).normalizedAll) {
        // Skip fuzzy match if length disparity is too high
        if ((normCandidate.length - normalizedInput.length).abs() > 4) continue;

        final similarity = _calculateSimilarity(normalizedInput, normCandidate);
        if (similarity >= 0.75 && similarity > maxFuzzyScore) {
          maxFuzzyScore = similarity;
          bestFuzzyEntry = entry;
        }
      }
    }

    if (bestFuzzyEntry != null) {
      return MatchCandidate(
        entry: bestFuzzyEntry,
        matchType: MatchType.fuzzy,
        confidence: math.min(0.79, maxFuzzyScore * 0.85),
      );
    }

    // ── Level 6: Safe Fallback (No Match) ─────────────────────────────────────
    return null;
  }

  /// Calculates Normalized Levenshtein Similarity (0.0 to 1.0).
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final dist = _levenshteinDistance(s1, s2);
    final maxLen = math.max(s1.length, s2.length);
    return 1.0 - (dist / maxLen);
  }

  /// Levenshtein Distance algorithm.
  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
        dp[i][j] = math.min(
          dp[i - 1][j] + 1,
          math.min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost),
        );
      }
    }
    return dp[m][n];
  }
}
