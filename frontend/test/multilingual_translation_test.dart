import 'package:flutter_test/flutter_test.dart';
import 'package:r26_it_122/features/translation/detectors/language_detector.dart';
import 'package:r26_it_122/features/translation/dictionary/general_word_dictionary.dart';
import 'package:r26_it_122/features/translation/engine/offline_translation_engine.dart';
import 'package:r26_it_122/features/translation/knowledge_base/sigiriya_knowledge_base.dart';
import 'package:r26_it_122/features/translation/matchers/phrase_matcher.dart';
import 'package:r26_it_122/features/translation/models/translation_result.dart';
import 'package:r26_it_122/features/translation/processors/ocr_text_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multilingual Offline Translation System Tests (All 8 Languages)', () {
    late OcrTextProcessor processor;
    late LanguageDetector detector;
    late SigiriyaKnowledgeBase knowledgeBase;
    late PhraseMatcher matcher;
    late OfflineTranslationEngine engine;

    setUp(() async {
      processor = const OcrTextProcessor();
      detector = const LanguageDetector();
      knowledgeBase = SigiriyaKnowledgeBase();
      matcher = const PhraseMatcher();

      // Initialize using real project dataset assets
      await knowledgeBase.initialize();
      await GeneralWordDictionary.load();

      engine = OfflineTranslationEngine(
        textProcessor: processor,
        languageDetector: detector,
        knowledgeBase: knowledgeBase,
        phraseMatcher: matcher,
      );
    });

    test('1. Language Detector - Correctly identifies all 8 supported languages', () {
      expect(detector.detectLanguage('Main Entrance'), equals('en'));
      expect(detector.detectLanguage('ප්‍රධාන දොරටුව'), equals('si'));
      expect(detector.detectLanguage('பிரதான நுழைவாயில்'), equals('ta'));
      expect(detector.detectLanguage('मुख्य द्वार'), equals('hi'));
      expect(detector.detectLanguage('主入口'), equals('zh'));
      expect(detector.detectLanguage('Entrada Principal de la cueva'), equals('es'));
      expect(detector.detectLanguage('Entrée Principale du musée'), equals('fr'));
      expect(detector.detectLanguage('Haupteingang des Museums'), equals('de'));
    });

    test('2. Unicode Normalization - Preserves non-Latin scripts, marks, & ZWJ', () {
      // Sinhala
      final normSi = processor.normalize('ප්‍රධාන  දොරටුව\u200C');
      expect(normSi, contains('ප්‍රධාන දොරටුව'));

      // Tamil
      final normTa = processor.normalize('பிரதான  நுழைவாயில்');
      expect(normTa, contains('பிரதான நுழைவாயில்'));

      // Devanagari / Hindi
      final normHi = processor.normalize('मुख्य  द्वार');
      expect(normHi, contains('मुख्य द्वार'));

      // Chinese
      final normZh = processor.normalize('主  入口');
      expect(normZh, contains('主 入口'));

      // European diacritics (German, French, Spanish)
      final normDe = processor.normalize('Haupteingang  der  Höhle');
      expect(normDe, equals('haupteingang der höhle'));
    });

    test('3. Multilingual Heritage Phrase Matcher - Real Sigiriya Dataset', () async {
      // English -> German
      final res1 = await engine.translate(
        rawInput: 'Main Entrance',
        targetLanguage: 'de',
      );
      expect(res1.status, equals(TranslationStatus.success));
      expect(res1.translatedText, equals('Haupteingang'));

      // Sinhala -> English
      final res2 = await engine.translate(
        rawInput: 'ප්‍රධාන දොරටුව',
        targetLanguage: 'en',
      );
      expect(res2.status, equals(TranslationStatus.success));
      expect(res2.translatedText, equals('Main Entrance'));

      // Sinhala -> German (Cross-Language Phrase Matching)
      final res3 = await engine.translate(
        rawInput: 'ප්‍රධාන දොරටුව',
        targetLanguage: 'de',
      );
      expect(res3.status, equals(TranslationStatus.success));
      expect(res3.translatedText, equals('Haupteingang'));

      // Tamil -> Spanish (Cross-Language Phrase Matching)
      final res4 = await engine.translate(
        rawInput: 'பிரதான நுழைவாயில்',
        targetLanguage: 'es',
      );
      expect(res4.status, equals(TranslationStatus.success));
      expect(res4.translatedText, equals('Entrada Principal'));

      // German -> Sinhala (Cross-Language Phrase Matching)
      final res5 = await engine.translate(
        rawInput: 'Haupteingang',
        targetLanguage: 'si',
      );
      expect(res5.status, equals(TranslationStatus.success));
      expect(res5.translatedText, equals('ප්‍රධාන දොරටුව'));

      // Chinese -> French
      final res6 = await engine.translate(
        rawInput: '主入口',
        targetLanguage: 'fr',
      );
      expect(res6.status, equals(TranslationStatus.success));
      expect(res6.translatedText, equals('Entrée Principale'));
    });

    test('4. General Word Dictionary - Pivot & Bidirectional Lookups', () {
      // English -> Target
      final enToSi = GeneralWordDictionary.translate('entrance', 'si');
      expect(enToSi, isNotNull);

      // Target -> English reverse lookup
      final siToEn = GeneralWordDictionary.translateToEnglish('ප්‍රධාන', 'si');
      expect(siToEn, equals('main'));

      // Sentence word translation with non-English source
      final sentenceRes = GeneralWordDictionary.translateSentence(
        'ප්‍රධාන',
        'de',
        sourceLang: 'si',
      );
      expect(sentenceRes['text'], isNotEmpty);
    });

    test('5. Offline Guarantee - All languages execute without network', () async {
      final languages = ['si', 'ta', 'hi', 'zh', 'es', 'fr', 'de'];

      for (final lang in languages) {
        final result = await engine.translate(
          rawInput: 'Ticket Counter',
          targetLanguage: lang,
        );
        expect(result.isOffline, isTrue);
        expect(result.translatedText, isNotEmpty);
      }
    });
  });
}
