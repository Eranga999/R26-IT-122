import 'package:flutter_test/flutter_test.dart';
import 'package:r26_it_122/features/translation/detectors/language_detector.dart';
import 'package:r26_it_122/features/translation/engine/offline_translation_engine.dart';
import 'package:r26_it_122/features/translation/knowledge_base/sigiriya_knowledge_base.dart';
import 'package:r26_it_122/features/translation/matchers/phrase_matcher.dart';
import 'package:r26_it_122/features/translation/models/translation_result.dart';
import 'package:r26_it_122/features/translation/processors/ocr_text_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sinhala Pipeline Tests', () {
    late OcrTextProcessor processor;
    late LanguageDetector detector;
    late SigiriyaKnowledgeBase knowledgeBase;
    late PhraseMatcher matcher;

    final mockDataset = [
      {
        'id': 'sig_main_entrance',
        'canonical': {
          'en': 'Main Entrance',
          'si': 'ප්‍රධාන දොරටුව',
          'ta': 'முதன்மை நுழைவாயில்'
        },
        'aliases': ['Main Gate', 'ප්‍රධාන ගේට්ටුව'],
        'category': 'Signboard',
        'translations': {
          'en': 'Main Entrance',
          'si': 'ප්‍රධාන දොරටුව',
          'ta': 'முதன்மை நுழைவாயில்'
        }
      },
      {
        'id': 'sig_mirror_wall',
        'canonical': {
          'en': 'Mirror Wall',
          'si': 'කැඩපත් පවුර',
          'ta': 'கண்ணாடிச் சுவர்'
        },
        'aliases': ['Mirror Wall Gallery', 'කැඩපත් පවුරු ගැලරිය'],
        'category': 'Monument',
        'translations': {
          'en': 'Mirror Wall',
          'si': 'කැඩපත් පවුර',
          'ta': 'கண்ணாடிச் சுவர்'
        }
      },
      {
        'id': 'sig_lions_paw',
        'canonical': {
          'en': 'Lion Paw Terrace',
          'si': 'සිංහ පාද මළුව',
          'ta': 'சிங்க பாத முற்றம்'
        },
        'aliases': ['Lions Paw', 'සිංහ පාදය'],
        'category': 'Landmark',
        'translations': {
          'en': 'Lion Paw Terrace',
          'si': 'සිංහ පාද මළුව',
          'ta': 'சிங்க பாத முற்றம்'
        }
      }
    ];

    setUp(() {
      processor = const OcrTextProcessor();
      detector = const LanguageDetector();
      knowledgeBase = SigiriyaKnowledgeBase();
      knowledgeBase.initializeWithList(mockDataset);
      matcher = PhraseMatcher(textProcessor: processor);
    });

    test('1. OcrTextProcessor - Sinhala Unicode Normalization', () {
      const rawSinhala = 'ප්‍රධාන   දොරටුව\u200C';
      final normalized = processor.normalize(rawSinhala);

      expect(processor.containsSinhala(normalized), isTrue);
      expect(normalized, contains('ප්‍රධාන දොරටුව'));
    });

    test('2. LanguageDetector - Detects Sinhala Language Code', () {
      const text = 'ප්‍රධාන දොරටුව';
      final lang = detector.detectLanguage(text);

      expect(lang, equals('si'));
    });

    test('3. PhraseMatcher - Sinhala to English Exact Match', () {
      const input = 'ප්‍රධාන දොරටුව';
      final candidate = matcher.match(input, knowledgeBase.getAllEntries());

      expect(candidate, isNotNull);
      expect(candidate!.matchType, equals(MatchType.exactCanonical));
      expect(candidate.entry.translations['en'], equals('Main Entrance'));
    });

    test('4. PhraseMatcher - Sinhala Alias Match to English', () {
      const input = 'කැඩපත් පවුරු ගැලරිය';
      final candidate = matcher.match(input, knowledgeBase.getAllEntries());

      expect(candidate, isNotNull);
      expect(candidate!.matchType, equals(MatchType.alias));
      expect(candidate.entry.translations['en'], equals('Mirror Wall'));
    });

    test('5. OfflineTranslationEngine - Full Sinhala to English Translation Flow', () async {
      final engine = OfflineTranslationEngine(
        textProcessor: processor,
        languageDetector: detector,
        knowledgeBase: knowledgeBase,
        phraseMatcher: matcher,
      );

      final result = await engine.translate(
        rawInput: 'සිංහ පාද මළුව',
        targetLanguage: 'en',
      );

      expect(result.status, equals(TranslationStatus.success));
      expect(result.sourceLanguage, equals('si'));
      expect(result.targetLanguage, equals('en'));
      expect(result.translatedText, equals('Lion Paw Terrace'));
    });
  });
}
