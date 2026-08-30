import 'package:flutter_test/flutter_test.dart';
import 'package:r26_it_122/features/translation/engine/offline_translation_engine.dart';
import 'package:r26_it_122/features/translation/detectors/language_detector.dart';
import 'package:r26_it_122/features/translation/knowledge_base/sigiriya_knowledge_base.dart';
import 'package:r26_it_122/features/translation/matchers/phrase_matcher.dart';
import 'package:r26_it_122/features/translation/models/translation_result.dart';
import 'package:r26_it_122/features/translation/processors/ocr_text_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SigiriyaKnowledgeBase knowledgeBase;
  late OfflineTranslationEngine engine;
  late OcrTextProcessor processor;
  late LanguageDetector detector;

  setUp(() {
    processor = const OcrTextProcessor();
    detector = const LanguageDetector();
    knowledgeBase = SigiriyaKnowledgeBase();

    // Initialize knowledge base with structured mock dataset
    knowledgeBase.initializeWithList([
      {
        "id": "SIG_001",
        "category": "heritage_feature",
        "canonical": {
          "en": "Mirror Wall",
          "si": "කැඩපත් පවුර",
          "ta": "கண்ணாடிச் சுவர்"
        },
        "aliases": ["mirror wall", "the mirror wall", "MIRROR WALL"],
        "translations": {
          "en": "Mirror Wall",
          "si": "කැඩපත් පවුර",
          "ta": "கண்ணாடிச் சுவர்",
          "hi": "दर्पण दीवार",
          "zh": "镜墙",
          "es": "Pared de Espejo"
        },
        "confidence": 1.0,
        "source": "Archaeological Survey",
        "review_status": "verified"
      },
      {
        "id": "SIG_002",
        "category": "safety",
        "canonical": {
          "en": "Please Do Not Touch The Ancient Frescoes",
          "si": "කරුණාකර පුරාණ බිතුසිතුවම් ස්පර්ශ නොකරන්න",
          "ta": "தயவுசெய்து பழங்கால சுவரோவியங்களைத் தொடவேண்டாம்"
        },
        "aliases": ["please do not touch the ancient frescoes", "do not touch frescoes"],
        "translations": {
          "en": "Please Do Not Touch The Ancient Frescoes",
          "si": "කරුණාකර පුරාණ බිතුසිතුවම් ස්පර්ශ නොකරන්න",
          "ta": "தயவுசெய்து பழங்கால சுவரோவியங்களைத் தொடவேண்டாம்",
          "hi": "कृपया प्राचीन भित्तिचित्रों को न छुएं"
        },
        "confidence": 1.0,
        "source": "Archaeological Survey",
        "review_status": "verified"
      },
      {
        "id": "SIG_003",
        "category": "navigation",
        "canonical": {
          "en": "Ticket Counter",
          "si": "ප්‍රවේශ පත් කවුන්ටරය",
          "ta": "பயணச்சீட்டு அலுவலகம்"
        },
        "aliases": ["ticket counter", "tickets"],
        "translations": {
          "en": "Ticket Counter",
          "si": "ප්‍රවේශ පත් කවුන්ටරය",
          "ta": "பயණச்சீட்டு அலுவலகம்",
          "hi": "टिकट काउंटर"
        },
        "confidence": 1.0,
        "source": "Central Cultural Fund",
        "review_status": "verified"
      }
    ]);

    engine = OfflineTranslationEngine(
      textProcessor: processor,
      languageDetector: detector,
      knowledgeBase: knowledgeBase,
      phraseMatcher: const PhraseMatcher(),
    );
  });

  group('OcrTextProcessor Tests', () {
    test('Cleans whitespace, newlines, and OCR artifacts', () {
      const raw = '  MIRROR \n WALL  !!! ';
      final cleaned = processor.normalize(raw);
      expect(cleaned, equals('mirror wall'));
    });

    test('Extracts multiline blocks properly', () {
      const multiline = 'Main Entrance\nTicket Counter\nNo Littering';
      final lines = processor.extractLines(multiline);
      expect(lines.length, equals(3));
      expect(lines[0], equals('Main Entrance'));
    });
  });

  group('LanguageDetector Tests', () {
    test('Detects English/Latin script correctly', () {
      expect(detector.detectLanguage('Mirror Wall'), equals('en'));
    });

    test('Detects Sinhala script correctly', () {
      expect(detector.detectLanguage('කැඩපත් පවුර'), equals('si'));
    });

    test('Detects Tamil script correctly', () {
      expect(detector.detectLanguage('கண்ணாடிச் சுவர்'), equals('ta'));
    });
  });

  group('OfflineTranslationEngine Tests', () {
    test('Level 1: Exact Canonical Match', () async {
      final res = await engine.translate(
        rawInput: 'Mirror Wall',
        targetLanguage: 'si',
      );

      expect(res.status, equals(TranslationStatus.success));
      expect(res.matchType, equals(MatchType.exactCanonical));
      expect(res.confidence, equals(1.0));
      expect(res.translatedText, equals('කැඩපත් පවුර'));
    });

    test('Level 2: Normalized Match with Irregular Whitespace & Case', () async {
      final res = await engine.translate(
        rawInput: '  mirror   wall \n ',
        targetLanguage: 'ta',
      );

      expect(res.status, equals(TranslationStatus.success));
      expect(res.translatedText, equals('கண்ணாடிச் சுவர்'));
    });

    test('Level 3: Alias Match', () async {
      final res = await engine.translate(
        rawInput: 'THE MIRROR WALL',
        targetLanguage: 'hi',
      );

      expect(res.status, equals(TranslationStatus.success));
      expect(res.translatedText, equals('दर्पण दीवार'));
    });

    test('Level 5: Fuzzy Matching for OCR Typos', () async {
      final res = await engine.translate(
        rawInput: 'MIRROR WAL', // typo
        targetLanguage: 'si',
      );

      expect(res.status, equals(TranslationStatus.success));
      expect(res.matchType, equals(MatchType.fuzzy));
      expect(res.translatedText, equals('කැඩපත් පවුර'));
    });

    test('Long Signboard Phrase Match', () async {
      final res = await engine.translate(
        rawInput: 'Please Do Not Touch The Ancient Frescoes',
        targetLanguage: 'si',
      );

      expect(res.status, equals(TranslationStatus.success));
      expect(res.translatedText, equals('කරුණාකර පුරාණ බිතුසිතුවම් ස්පර්ශ නොකරන්න'));
    });

    test('Unsupported Unknown Text Handling', () async {
      final res = await engine.translate(
        rawInput: 'Random Unknown Text XYZ 1234',
        targetLanguage: 'si',
      );

      expect(res.status, equals(TranslationStatus.unsupported));
      expect(res.matchType, equals(MatchType.none));
      expect(res.confidence, equals(0.0));
      expect(res.translatedText, equals('Random Unknown Text XYZ 1234'));
    });

    test('Empty Input Handling', () async {
      final res = await engine.translate(
        rawInput: '   ',
        targetLanguage: 'si',
      );

      expect(res.status, equals(TranslationStatus.empty));
      expect(res.translatedText, equals(''));
    });
  });
}
