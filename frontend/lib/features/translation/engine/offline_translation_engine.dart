import 'package:flutter/foundation.dart';

import '../detectors/language_detector.dart';
import '../dictionary/general_word_dictionary.dart';
import '../knowledge_base/heritage_site_knowledge_base.dart';
import '../knowledge_base/sigiriya_knowledge_base.dart';
import '../matchers/phrase_matcher.dart';
import '../models/translation_result.dart';
import '../processors/ocr_text_processor.dart';
import 'mlkit_translation_service.dart';

class OfflineTranslationEngine {
  final OcrTextProcessor textProcessor;
  final LanguageDetector languageDetector;
  final HeritageSiteKnowledgeBase knowledgeBase;
  final PhraseMatcher phraseMatcher;

  final Map<String, TranslationResult> _cache = {};
  static const int maxCacheEntries = 200;

  OfflineTranslationEngine({
    this.textProcessor = const OcrTextProcessor(),
    this.languageDetector = const LanguageDetector(),
    HeritageSiteKnowledgeBase? knowledgeBase,
    PhraseMatcher? phraseMatcher,
  })  : knowledgeBase = knowledgeBase ?? SigiriyaKnowledgeBase(),
        phraseMatcher = phraseMatcher ?? const PhraseMatcher();

  static final OfflineTranslationEngine instance = OfflineTranslationEngine();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Future.wait([
      knowledgeBase.initialize(),
      GeneralWordDictionary.load(),
    ]);
    _initialized = true;
  }

  /// Translates input OCR text into target language offline.
  ///
  /// Strategy:
  ///   1. Empty / whitespace → [TranslationStatus.empty]
  ///   2. Source == Target   → return as-is (already in target language)
  ///   3. Heritage KB phrase match (Levels 1-5)
  ///   4. ML Kit on-device translation (general sentences, offline)
  ///   5. General word-by-word dictionary (Level 6 fallback)
  ///   6. Unsupported — return original with [TranslationStatus.unsupported]
  Future<TranslationResult> translate({
    required String rawInput,
    required String targetLanguage,
  }) async {
    if (rawInput.trim().isEmpty) {
      return TranslationResult.empty(targetLanguage: targetLanguage);
    }

    final normalized = textProcessor.normalize(rawInput);
    final cacheKey = '$targetLanguage:$normalized';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    await initialize();

    final sourceLang = languageDetector.detectLanguage(rawInput);

    // ── Step 2: Already in target language ────────────────────────────────
    if (sourceLang == targetLanguage) {
      final res = TranslationResult(
        inputText: rawInput,
        normalizedText: normalized,
        sourceLanguage: sourceLang,
        targetLanguage: targetLanguage,
        translatedText: rawInput,
        matchedEntry: null,
        matchType: MatchType.exactCanonical,
        confidence: 1.0,
        status: TranslationStatus.success,
        isOffline: true,
      );
      _addToCache(cacheKey, res);
      return res;
    }

    // ── Step 3: Heritage Knowledge Base phrase matching ────────────────────
    final entries = knowledgeBase.getAllEntries();
    final candidate = phraseMatcher.match(rawInput, entries);

    if (candidate != null) {
      final entry = candidate.entry;
      final translatedText = entry.translations[targetLanguage] ??
          entry.canonical[targetLanguage] ??
          entry.canonical['en'] ??
          rawInput;

      final result = TranslationResult(
        inputText: rawInput,
        normalizedText: normalized,
        sourceLanguage: sourceLang,
        targetLanguage: targetLanguage,
        translatedText: translatedText,
        matchedEntry: entry,
        matchType: candidate.matchType,
        confidence: candidate.confidence,
        status: TranslationStatus.success,
        isOffline: true,
      );
      _addToCache(cacheKey, result);
      return result;
    }

    // ── Step 4: ML Kit on-device translation ───────────────────────────────
    final mlSource = sourceLang == 'unknown' ? 'en' : sourceLang;
    if (MlKitTranslationService.instance.isPairSupported(
        mlSource, targetLanguage)) {
      try {
        final mlText = await MlKitTranslationService.instance.translate(
          text: rawInput,
          sourceLanguage: mlSource,
          targetLanguage: targetLanguage,
        );
        if (mlText != null && mlText.trim().isNotEmpty) {
          final result = TranslationResult(
            inputText: rawInput,
            normalizedText: normalized,
            sourceLanguage: sourceLang,
            targetLanguage: targetLanguage,
            translatedText: mlText,
            matchedEntry: null,
            matchType: MatchType.mlKit,
            confidence: 0.85,
            status: TranslationStatus.success,
            isOffline: true,
          );
          _addToCache(cacheKey, result);
          return result;
        }
      } catch (e) {
        debugPrint('ML Kit translation fallback failed: $e');
      }
    }

    // ── Step 5: General word-by-word dictionary fallback ──────────────────
    // Applies for any source language (English, Sinhala, Tamil, etc.)
    final wordResult = GeneralWordDictionary.translateSentence(
      normalized,
      targetLanguage,
      sourceLang: sourceLang,
    );
    final translatedText = wordResult['text'] as String;
    final coverage = wordResult['coverage'] as double;

    // Accept if at least 1 word was translated
    if (coverage > 0.0 && translatedText != normalized) {
      final result = TranslationResult(
        inputText: rawInput,
        normalizedText: normalized,
        sourceLanguage: sourceLang,
        targetLanguage: targetLanguage,
        translatedText: translatedText,
        matchedEntry: null,
        matchType: MatchType.wordLevel,
        confidence: (coverage * 0.7 + 0.2).clamp(0.3, 0.8),
        status: TranslationStatus.partial,
        isOffline: true,
      );
      _addToCache(cacheKey, result);
      return result;
    }

    // ── Step 6: Unsupported ───────────────────────────────────────────────
    final fallback = TranslationResult.unsupported(
      inputText: rawInput,
      normalizedText: normalized,
      sourceLanguage: sourceLang,
      targetLanguage: targetLanguage,
    );
    _addToCache(cacheKey, fallback);
    return fallback;
  }

  void _addToCache(String key, TranslationResult result) {
    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  void clearCache() {
    _cache.clear();
  }

  /// Pre-download ML Kit language packs for the active target language.
  Future<void> preloadMlKitModels(String targetLanguage) async {
    await initialize();
    if (!MlKitTranslationService.instance
        .isPairSupported('en', targetLanguage)) {
      return;
    }
    await MlKitTranslationService.instance.ensureModels('en', targetLanguage);
  }

  /// Downloads ML Kit models for every language the app offers, one at a
  /// time, in the background. Intended to run once at app startup so the
  /// packs are already on-device by the time a user opens the AR
  /// translator — first use should feel instant offline, not trigger a
  /// silent ~25MB download.
  Future<void> preloadAllOfflineModels(List<String> targetLanguages) async {
    await initialize();
    await MlKitTranslationService.instance.preloadLanguages(targetLanguages);
  }
}

