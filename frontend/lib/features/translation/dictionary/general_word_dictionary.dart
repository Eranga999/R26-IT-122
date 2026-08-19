import 'dart:convert';
import 'package:flutter/services.dart';

/// Full offline word & phrase dictionary loaded from assets/data/offline_word_dictionary.json
/// Supports bidirectional translation (English -> Targets AND Sinhala/Targets -> English).
class GeneralWordDictionary {
  static Map<String, Map<String, String>> _words = {};
  // Reverse map: targetLang -> (sourceWordInTargetLang -> englishWord)
  static final Map<String, Map<String, String>> _reverseWords = {};
  static bool _loaded = false;

  static const String _unicodeSanitizeRegex =
      r'[^\p{L}\p{N}\p{M}\s\u200D]';
  // Compiled once instead of on every _cleanKey() call (called per word,
  // per candidate, on every capture).
  static final RegExp _unicodeSanitizeCompiled =
      RegExp(_unicodeSanitizeRegex, unicode: true);

  /// Load dictionary from asset file. Call once at app start.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle
          .loadString('assets/data/offline_word_dictionary.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;

      _words = {};
      _reverseWords.clear();

      decoded.forEach((key, value) {
        final englishKey = key.trim().toLowerCase();
        final translations = <String, String>{};

        if (value is Map<String, dynamic>) {
          value.forEach((lang, trans) {
            final transStr = trans.toString().trim();
            translations[lang] = transStr;

            // Build reverse index: targetLang -> (cleanTargetWord -> englishKey)
            final langMap = _reverseWords.putIfAbsent(lang, () => {});
            final cleanTrans = _cleanKey(transStr);
            if (cleanTrans.isNotEmpty) {
              langMap[cleanTrans] = englishKey;

              // Also index individual words in multi-word translations
              for (final subWord in transStr.split(RegExp(r'\s+'))) {
                final cleanSub = _cleanKey(subWord);
                if (cleanSub.length >= 2) {
                  langMap.putIfAbsent(cleanSub, () => englishKey);
                }
              }
            }
          });
        }
        _words[englishKey] = translations;
      });

      _loaded = true;
    } catch (e) {
      _words = {};
      _reverseWords.clear();
      _loaded = true;
    }
  }

  static String _cleanKey(String text) {
    return text.trim().toLowerCase().replaceAll(_unicodeSanitizeCompiled, '');
  }

  /// Translate a single word from English to [targetLang]. Returns null if not found.
  static String? translate(String word, String targetLang) {
    if (!_loaded) return null;
    final key = _cleanKey(word);
    return _words[key]?[targetLang];
  }

  /// Translate a single word/phrase from [sourceLang] (e.g. 'si', 'de') into English.
  static String? translateToEnglish(String sourceWord, String sourceLang) {
    if (!_loaded) return null;
    final key = _cleanKey(sourceWord);
    if (key.isEmpty) return null;

    final langMap = _reverseWords[sourceLang];
    return langMap?[key];
  }

  /// Translate a full sentence word-by-word bidirectionally across all supported languages.
  /// Supports: English -> Target, Target -> English, and Target1 -> English -> Target2 pivot translation.
  static Map<String, dynamic> translateSentence(
      String sentence, String targetLang, {String sourceLang = 'en'}) {
    if (!_loaded) {
      return {
        'text': sentence,
        'coverage': 0.0,
        'matchedWords': 0,
        'totalWords': 0
      };
    }

    final words = sentence.trim().split(RegExp(r'\s+'));
    final translated = <String>[];
    int matched = 0;

    // Try full sentence/phrase lookup in reverse map if non-English source
    if (sourceLang != 'en') {
      final fullEnglish = translateToEnglish(sentence, sourceLang);
      if (fullEnglish != null && fullEnglish.isNotEmpty) {
        if (targetLang == 'en') {
          return {
            'text': fullEnglish,
            'coverage': 1.0,
            'matchedWords': words.length,
            'totalWords': words.length,
          };
        } else {
          final pivotFull = translate(fullEnglish, targetLang);
          if (pivotFull != null && pivotFull.isNotEmpty) {
            return {
              'text': pivotFull,
              'coverage': 1.0,
              'matchedWords': words.length,
              'totalWords': words.length,
            };
          }
        }
      }
    }

    for (final word in words) {
      final clean = _cleanKey(word);
      String? t;

      if (sourceLang == 'en' && targetLang != 'en') {
        t = translate(clean, targetLang);
      } else if (sourceLang != 'en' && targetLang == 'en') {
        t = translateToEnglish(clean, sourceLang);
      } else if (sourceLang != 'en' && targetLang != 'en' && sourceLang != targetLang) {
        // Safe pivot translation through canonical English
        final englishKey = translateToEnglish(clean, sourceLang);
        if (englishKey != null && englishKey.isNotEmpty) {
          t = translate(englishKey, targetLang);
        }
      } else {
        t = translate(clean, targetLang);
      }

      if (t != null && t.isNotEmpty) {
        translated.add(t);
        matched++;
      } else {
        translated.add(word);
      }
    }

    final coverage = words.isEmpty ? 0.0 : matched / words.length;
    return {
      'text': translated.join(' '),
      'coverage': coverage,
      'matchedWords': matched,
      'totalWords': words.length,
    };
  }

  static bool get isLoaded => _loaded;
  static int get wordCount => _words.length;
}

