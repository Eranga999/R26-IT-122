import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/services.dart' show rootBundle;

class OfflineChatbotService {
  OfflineChatbotService._();

  static final OfflineChatbotService instance = OfflineChatbotService._();

  static const String _datasetAssetPath = 'assets/data/sigiriya_chat_dataset.json';

  Future<List<_KnowledgeEntry>>? _datasetFuture;

  final Map<String, Map<String, dynamic>> _replyTemplates = {
    'en': {
      'offline_load_error': 'Error: Could not load the offline guide data.',
      'greetings': [
        'Greetings! 🏛️',
        'Welcome to our heritage exploration! ✨',
        "Hello there! I'm your virtual guide. 🦁",
        "It's a pleasure to share this history with you. 📜",
        "Ah, a great question! Let me tell you more. 🏺",
      ],
      'help': 'I am your Heritage Guide. How can I help you explore the wonders of Sri Lanka today? 🏛️',
      'thanks': "You're very welcome! 😊 It's my passion to keep these stories alive. Do you have any other questions about our heritage?",
      'no_results': "I'm sorry, I couldn't find specific information about that in my records. Perhaps you could ask something else about this beautiful site? 🏛️",
      'fact_prefix': '✨',
      'templates': <String, String>{
        'history': 'History tells us that {text}. It remains one of the defining stories of {landmark}.',
        'architecture': 'Architecturally, {text}. That is part of what makes {landmark} remarkable.',
        'engineering': 'From an engineering perspective, {text}. That innovation still stands out at {landmark}.',
        'art': 'Artistically, {text}. This is one of the most distinctive features of {landmark}.',
        'culture': 'Culturally, {text}. It helps explain why {landmark} matters so much.',
        'facts': 'A useful fact is that {text}. That gives important context about {landmark}.',
        'tourism': 'For visitors, {text}. That is one reason {landmark} attracts so many travelers.',
        'archaeology': 'Archaeologically, {text}. This evidence helps researchers understand {landmark}.',
        'religion': 'Religiously, {text}. It reflects an important chapter in the history of {landmark}.',
        'environment': 'Environmentally, {text}. The surrounding landscape is part of the experience at {landmark}.',
        'gardens': 'The gardens are described as follows: {text}. They are a signature feature of {landmark}.',
        'fortress': '{text}. That is what gives {landmark} its fortress character.',
        'default': '{text}. That is one of the reasons {landmark} is so memorable.',
      },
    },
    'hi': {
      'offline_load_error': 'त्रुटि: ऑफ़लाइन गाइड डेटा लोड नहीं हो सका।',
      'greetings': [
        'नमस्ते! 🏛️',
        'हमारी विरासत यात्रा में आपका स्वागत है! ✨',
        'हैलो! मैं आपका virtual guide हूं. 🦁',
      ],
      'help': 'मैं आपका Heritage Guide हूं। आज मैं आपको श्रीलंका की विरासत खोजने में कैसे मदद कर सकता हूं?',
      'thanks': 'आपका स्वागत है! 😊 इन विरासत कथाओं को साझा करना मेरे लिए खुशी की बात है। क्या आपका कोई और प्रश्न है?',
      'no_results': 'क्षमा करें, मुझे इस विषय पर अपने रिकॉर्ड में स्पष्ट जानकारी नहीं मिली। कृपया इस स्थल के बारे में कोई और प्रश्न पूछें। 🏛️',
      'fact_prefix': '✨ रोचक जानकारी:',
      'templates': <String, String>{
        'history': 'इतिहास बताता है कि {text}. यह {landmark} की सबसे महत्वपूर्ण कहानियों में से एक है।',
        'architecture': 'वास्तुकला की दृष्टि से, {text}. यही {landmark} को खास बनाता है।',
        'engineering': 'इंजीनियरिंग के लिहाज़ से, {text}. यह नवाचार {landmark} पर आज भी प्रभावशाली है।',
        'art': 'कला की दृष्टि से, {text}. यह {landmark} की सबसे विशिष्ट विशेषताओं में से एक है।',
        'culture': 'सांस्कृतिक रूप से, {text}. यह समझने में मदद करता है कि {landmark} इतना महत्वपूर्ण क्यों है।',
        'facts': 'एक उपयोगी तथ्य यह है कि {text}. यह {landmark} के बारे में महत्वपूर्ण संदर्भ देता है।',
        'tourism': 'पर्यटकों के लिए, {text}. यह एक कारण है कि {landmark} इतने यात्रियों को आकर्षित करता है।',
        'archaeology': 'पुरातात्विक रूप से, {text}. यह साक्ष्य शोधकर्ताओं को {landmark} समझने में मदद करता है।',
        'religion': 'धार्मिक रूप से, {text}. यह {landmark} के इतिहास के एक महत्वपूर्ण अध्याय को दिखाता है।',
        'environment': 'पर्यावरण की दृष्टि से, {text}. आसपास का परिदृश्य {landmark} के अनुभव का हिस्सा है।',
        'gardens': 'उद्यानों का वर्णन इस प्रकार है: {text}. यह {landmark} की पहचान है।',
        'fortress': '{text}. यही {landmark} को एक किले जैसा स्वरूप देता है।',
        'default': '{text}. यही कारणों में से एक है कि {landmark} इतना यादगार है।',
      },
    },
    'zh': {
      'offline_load_error': '错误：无法加载离线导览数据。',
      'greetings': [
        '您好！🏛️',
        '欢迎来到我们的遗产探索之旅！✨',
        '你好！我是您的 virtual guide。🦁',
      ],
      'help': '我是您的 Heritage Guide。今天我可以如何帮助您探索斯里兰卡的文化遗产？',
      'thanks': '不客气！😊 我很高兴与您分享这些遗产故事。您还有其他问题吗？',
      'no_results': '抱歉，我的资料中没有找到关于该问题的明确信息。您可以问问这个景点的其他内容。🏛️',
      'fact_prefix': '✨ 趣味小知识:',
      'templates': <String, String>{
        'history': '历史告诉我们，{text}。这也是 {landmark} 最重要的故事之一。',
        'architecture': '从建筑角度看，{text}。这正是 {landmark} 的特别之处。',
        'engineering': '从工程角度看，{text}。这种创新在 {landmark} 依然非常突出。',
        'art': '从艺术角度看，{text}。这是 {landmark} 最独特的特征之一。',
        'culture': '从文化角度看，{text}。这有助于理解 {landmark} 为什么如此重要。',
        'facts': '一个有用的事实是：{text}。这为 {landmark} 提供了重要背景。',
        'tourism': '对于游客来说，{text}。这也是 {landmark} 吸引众多旅行者的原因之一。',
        'archaeology': '从考古角度看，{text}。这些证据帮助研究者理解 {landmark}。',
        'religion': '从宗教角度看，{text}。这体现了 {landmark} 历史中的重要篇章。',
        'environment': '从环境角度看，{text}。周边景观是 {landmark} 体验的一部分。',
        'gardens': '园林可以这样描述：{text}。它们是 {landmark} 的标志性特色。',
        'fortress': '{text}。这就是 {landmark} 具有要塞特征的原因。',
        'default': '{text}。这也是 {landmark} 如此令人难忘的原因之一。',
      },
    },
    'ru': {
      'offline_load_error': 'Ошибка: не удалось загрузить офлайн-данные гида.',
      'greetings': [
        'Здравствуйте! 🏛️',
        'Добро пожаловать в наше путешествие по наследию! ✨',
        'Привет! Я ваш virtual guide. 🦁',
      ],
      'help': 'Я ваш Heritage Guide. Чем я могу помочь вам в изучении наследия Шри-Ланки сегодня?',
      'thanks': 'Пожалуйста! 😊 Мне очень приятно делиться историями этого наследия. Есть ли у вас еще вопросы?',
      'no_results': 'Извините, в моих записях не найдено точной информации по этому вопросу. Попробуйте спросить что-то еще об этом месте. 🏛️',
      'fact_prefix': '✨ Интересный факт:',
      'templates': <String, String>{
        'history': 'История говорит нам, что {text}. Это одна из главных историй {landmark}.',
        'architecture': 'С архитектурной точки зрения, {text}. Именно это делает {landmark} особенным.',
        'engineering': 'С инженерной точки зрения, {text}. Это новшество по-прежнему впечатляет в {landmark}.',
        'art': 'С художественной точки зрения, {text}. Это одна из самых характерных черт {landmark}.',
        'culture': 'С культурной точки зрения, {text}. Это помогает понять, почему {landmark} так важен.',
        'facts': 'Полезный факт: {text}. Это даёт важный контекст о {landmark}.',
        'tourism': 'Для туристов, {text}. Это одна из причин, почему {landmark} привлекает путешественников.',
        'archaeology': 'С археологической точки зрения, {text}. Эти данные помогают исследователям понять {landmark}.',
        'religion': 'С религиозной точки зрения, {text}. Это отражает важную главу в истории {landmark}.',
        'environment': 'С экологической точки зрения, {text}. Окружающий ландшафт является частью опыта в {landmark}.',
        'gardens': 'Сады можно описать так: {text}. Это фирменная особенность {landmark}.',
        'fortress': '{text}. Именно это придаёт {landmark} характер крепости.',
        'default': '{text}. Это одна из причин, почему {landmark} так запоминается.',
      },
    },
    'de': {
      'offline_load_error': 'Fehler: Die Offline-Guidedaten konnten nicht geladen werden.',
      'greetings': [
        'Hallo! 🏛️',
        'Willkommen zu unserer Entdeckungsreise durch das Kulturerbe! ✨',
        'Guten Tag! Ich bin Ihr virtual guide. 🦁',
      ],
      'help': 'Ich bin Ihr Heritage Guide. Wie kann ich Ihnen heute helfen, das Kulturerbe Sri Lankas zu entdecken?',
      'thanks': 'Sehr gerne! 😊 Es ist mir eine Freude, diese Geschichten des Kulturerbes zu teilen. Haben Sie noch weitere Fragen?',
      'no_results': 'Entschuldigung, ich konnte dazu keine genauen Informationen in meinen Daten finden. Fragen Sie gern etwas anderes zu diesem Ort. 🏛️',
      'fact_prefix': '✨ Interessanter Fakt:',
      'templates': <String, String>{
        'history': 'Die Geschichte sagt uns, dass {text}. Das ist eine der wichtigsten Geschichten von {landmark}.',
        'architecture': 'Architektonisch gesehen gilt: {text}. Genau das macht {landmark} besonders.',
        'engineering': 'Aus technischer Sicht: {text}. Diese Innovation sticht in {landmark} noch heute hervor.',
        'art': 'Kuenstlerisch gesehen, {text}. Das ist eines der markantesten Merkmale von {landmark}.',
        'culture': 'Kulturell gesehen, {text}. Das hilft zu verstehen, warum {landmark} so wichtig ist.',
        'facts': 'Ein nuetzlicher Fakt ist: {text}. Das gibt wichtigen Kontext zu {landmark}.',
        'tourism': 'Fuer Besucher gilt: {text}. Das ist einer der Gruende, warum {landmark} so viele Reisende anzieht.',
        'archaeology': 'Archäologisch gesehen, {text}. Diese Belege helfen Forschern, {landmark} zu verstehen.',
        'religion': 'Religiös gesehen, {text}. Das zeigt ein wichtiges Kapitel in der Geschichte von {landmark}.',
        'environment': 'Umweltbezogen gilt: {text}. Die Landschaft gehoert zum Erlebnis in {landmark}.',
        'gardens': 'Die Gaerten kann man so beschreiben: {text}. Das ist ein Markenzeichen von {landmark}.',
        'fortress': '{text}. Genau das verleiht {landmark} seinen Festungscharakter.',
        'default': '{text}. Das ist einer der Gruende, warum {landmark} so unvergesslich ist.',
      },
    },
    'si': {
      'offline_load_error': 'දෝෂයක්: offline guide data load කරන්න බැරි වුණා.',
      'greetings': [
        'ආයුබෝවන්! 🏛️',
        'අපේ උරුම ගවේෂණයට සාදරයෙන් පිළිගනිමු! ✨',
        'හෙලෝ! මම ඔබගේ virtual guide. 🦁',
      ],
      'help': 'මම ඔබගේ Heritage Guide. ශ්‍රී ලංකාවේ උරුම අරුම පුදුම සොයා යාමට අද ඔබට මම කොහොම උදව් කරන්නද?',
      'thanks': 'බොහොම ස්තුතියි! 😊 අපේ උරුම කතා ජීවත් කරවීම මගේ සතුටයි. තවත් ප්‍රශ්නයක් තියෙනවද?',
      'no_results': 'සමාවෙන්න, ඒ ගැන නිශ්චිත තොරතුරු මගේ වාර්තා වල හමු නොවුණා. මේ ස්ථානය ගැන වෙනත් ප්‍රශ්නයක් අහන්න පුළුවන්. 🏛️',
      'fact_prefix': '✨ අමතර තොරතුරක්:',
      'templates': <String, String>{
        'history': 'ඉතිහාසය අනුව, {text}. එය {landmark} හි වැදගත්ම කතාවලින් එකකි.',
        'architecture': 'වාස්තු විද්‍යාත්මකව, {text}. ඒක {landmark} විශේෂ කරන දෙයක්.',
        'engineering': 'ඉංජිනේරු දෘෂ්ටිකෝණයෙන්, {text}. ඒ නවෝත්පාදනය අදත් {landmark} හි කැපී පෙනේ.',
        'art': 'කලාත්මකව, {text}. එය {landmark} හි විශේෂම ලක්ෂණවලින් එකකි.',
        'culture': 'සංස්කෘතිකව, {text}. එය {landmark} මෙතරම් වැදගත් වන්නේ ඇයිද යන්න පැහැදිලි කරයි.',
        'facts': 'ප්‍රයෝජනවත් කරුණක් වන්නේ {text}. මෙය {landmark} ගැන වැදගත් පසුබිමක් දේ.',
        'tourism': 'සංචාරකයන් සඳහා, {text}. ඒක {landmark} ට බොහෝ සංචාරකයන් ආකර්ෂණය කරන එක් හේතුවක්.',
        'archaeology': 'පුරාවිද්‍යාත්මකව, {text}. මෙම සාක්ෂි පර්යේෂකයන්ට {landmark} තේරුම් ගන්න උදව් කරනවා.',
        'religion': 'ආගමිකව, {text}. එය {landmark} හි ඉතිහාසයේ වැදගත් පරිච්ඡේදයක් පෙන්වයි.',
        'environment': 'පරිසරමයව, {text}. අවට භූ දර්ශනය {landmark} අත්දැකීමේ කොටසකි.',
        'gardens': 'උද්‍යාන මෙසේ විස්තර කළ හැක: {text}. එය {landmark} හි හඳුනාගත හැකි ලක්ෂණයකි.',
        'fortress': '{text}. එයම {landmark} ට බලකොටු ස්වභාවයක් ලබා දෙයි.',
        'default': '{text}. ඒක {landmark} මෙතරම් අමතක නොවෙන තැනක් වීමට එක් හේතුවකි.',
      },
    },
    'ta': {
      'offline_load_error': 'பிழை: offline guide தரவை ஏற்ற முடியவில்லை.',
      'greetings': [
        'வணக்கம்! 🏛️',
        'எங்கள் பாரம்பரிய பயணத்திற்கு வரவேற்கிறோம்! ✨',
        'ஹலோ! நான் உங்கள் virtual guide. 🦁',
      ],
      'help': 'நான் உங்கள் Heritage Guide. இலங்கையின் பாரம்பரிய அதிசயங்களை அறிய இன்று எப்படி உதவலாம்?',
      'thanks': 'மிகுந்த நன்றி! 😊 இந்த பாரம்பரியக் கதைகளை உயிரோட்டமாக வைத்திருப்பது எனக்கு மகிழ்ச்சி. இன்னும் ஏதேனும் கேள்விகள் உள்ளனவா?',
      'no_results': 'மன்னிக்கவும், அதைப் பற்றிய குறிப்பிட்ட தகவல் எனது பதிவுகளில் கிடைக்கவில்லை. இந்த அழகான இடத்தைப் பற்றி வேறு கேள்வி கேளுங்கள். 🏛️',
      'fact_prefix': '✨ கூடுதல் தகவல்:',
      'templates': <String, String>{
        'history': 'வரலாறு சொல்லுவது: {text}. இது {landmark} பற்றிய முக்கியமான கதைகளில் ஒன்றாகும்.',
        'architecture': 'கட்டிடக்கலை நோக்கில், {text}. அதுவே {landmark} ஐ தனித்துவமாக்குகிறது.',
        'engineering': 'பொறியியல் நோக்கில், {text}. அந்த புதுமை இன்று கூட {landmark} இல் தெளிவாகத் தெரிகிறது.',
        'art': 'கலை நோக்கில், {text}. இது {landmark} இன் மிக முக்கியமான அம்சங்களில் ஒன்று.',
        'culture': 'கலாச்சார ரீதியில், {text}. இதுவே {landmark} ஏன் முக்கியம் என்பதை விளக்குகிறது.',
        'facts': 'பயனுள்ள एक உண்மை: {text}. இது {landmark} பற்றி முக்கியமான பின்னணியை தருகிறது.',
        'tourism': 'பார்வையாளர்களுக்காக, {text}. இதுவே {landmark} பல பயணிகளை ஈர்க்கும் காரணங்களில் ஒன்று.',
        'archaeology': 'பாரம்பரிய ஆய்வில், {text}. இந்த சான்றுகள் ஆராய்ச்சியாளர்களுக்கு {landmark} ஐ புரிந்துகொள்ள உதவுகின்றன.',
        'religion': 'மத ரீதியில், {text}. இது {landmark} வரலாற்றின் முக்கியமான அத்தியாயத்தை காட்டுகிறது.',
        'environment': 'சுற்றுச்சூழல் ரீதியில், {text}. சுற்றுப்புற இயற்கை {landmark} அனுபவத்தின் ஒரு பகுதி.',
        'gardens': 'தோட்டங்களை இப்படியாக விவரிக்கலாம்: {text}. இது {landmark} இன் அடையாள அம்சம்.',
        'fortress': '{text}. அதுவே {landmark} க்கு கோட்டைத் தன்மையை வழங்குகிறது.',
        'default': '{text}. அதுவே {landmark} இவ்வளவு நினைவில் நிற்கும் இடமாக இருப்பதற்கான காரணங்களில் ஒன்று.',
      },
    },
  };

  Future<List<_KnowledgeEntry>> _loadDataset() {
    return _datasetFuture ??= _readDataset();
  }

  Future<List<_KnowledgeEntry>> _readDataset() async {
    final jsonString = await rootBundle.loadString(_datasetAssetPath);
    final rawList = jsonDecode(jsonString) as List<dynamic>;
    return rawList
        .map((item) => _KnowledgeEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> answer({
    required String question,
    required String landmarkId,
    required String language,
  }) async {
    final normalizedLanguage = _supportedLanguage(language);
    final localized = _localized(normalizedLanguage);
    final normalizedQuestion = _normalize(question);

    if (_isGreeting(normalizedQuestion, normalizedLanguage)) {
      return '${localized['greetings']!.first} ${localized['help']}';
    }

    if (_isThanks(normalizedQuestion, normalizedLanguage)) {
      return localized['thanks']!;
    }

    late final List<_KnowledgeEntry> dataset;
    try {
      dataset = await _loadDataset();
    } catch (_) {
      return localized['offline_load_error']!;
    }

    final landmarkKey = _normalize(landmarkId);
    final candidates = dataset.where((entry) => _normalize(entry.landmark).contains(landmarkKey)).toList();
    final searchSpace = candidates.isNotEmpty ? candidates : dataset;

    final best = _rankEntries(searchSpace, normalizedQuestion, normalizedLanguage).firstOrNull;
    if (best == null || best.score <= 0) {
      return localized['no_results']!;
    }

    final templateMap = localized['templates'] as Map<String, String>;
    final template = templateMap[best.entry.category.toLowerCase()] ?? templateMap['default']!;
    
    final bestText = best.entry.getLocalizedText(normalizedLanguage);
    final bestLandmark = _getLocalizedLandmark(best.entry.landmark, normalizedLanguage);

    final formatted = template
        .replaceAll('{text}', bestText)
        .replaceAll('{landmark}', bestLandmark)
        .replaceAll('{category}', best.entry.category);

    final fact = _optionalFact(normalizedLanguage, landmarkKey);
    return '${_randomGreeting(normalizedLanguage)} $formatted$fact';
  }

  Map<String, dynamic> _localized(String language) => _replyTemplates[language] ?? _replyTemplates['en']!;

  String _supportedLanguage(String language) {
    const supported = {'en', 'hi', 'zh', 'ru', 'de', 'si', 'ta'};
    return supported.contains(language) ? language : 'en';
  }

  bool _isGreeting(String question, String language) {
    const greetings = {
      'en': ['hello', 'hi', 'hey', 'greetings', 'good morning', 'good afternoon'],
      'hi': ['namaste', 'hello', 'hi', 'hey', 'नमस्ते'],
      'zh': ['nihao', 'hello', 'hi', 'hey', '你好', '您好'],
      'ru': ['privet', 'hello', 'hi', 'hey', 'привет', 'здравствуйте'],
      'de': ['hallo', 'hello', 'hi', 'hey', 'guten tag'],
      'si': ['hello', 'hi', 'hey', 'ayubowan', 'ආයුබෝවන්'],
      'ta': ['hello', 'hi', 'hey', 'vanakkam', 'வணக்கம்'],
    };
    return greetings[language]?.contains(question) ?? greetings['en']!.contains(question);
  }

  bool _isThanks(String question, String language) {
    const thanks = {
      'en': ['thank', 'thanks', 'thx'],
      'hi': ['thank', 'thanks', 'thx', 'धन्यवाद', 'शुक्रिया'],
      'zh': ['thank', 'thanks', 'thx', '谢谢', '多谢'],
      'ru': ['thank', 'thanks', 'thx', 'спасибо'],
      'de': ['thank', 'thanks', 'thx', 'danke', 'danke schoen'],
      'si': ['thank', 'thanks', 'thx', 'ස්තුතියි'],
      'ta': ['thank', 'thanks', 'thx', 'நன்றி'],
    };

    return thanks[language]?.any(question.contains) ?? thanks['en']!.any(question.contains);
  }

  List<_ScoredEntry> _rankEntries(List<_KnowledgeEntry> entries, String question, String language) {
    final queryTokens = _tokens(question);
    final weightedCategory = _categoryHints(question);

    final scored = entries.map((entry) {
      var score = 0;
      final text = _normalize(entry.getLocalizedText(language));
      final category = _normalize(entry.category);
      final landmark = _normalize(_getLocalizedLandmark(entry.landmark, language));

      if (landmark.contains('sigiriya') || landmark.contains('සීගිරිය') || landmark.contains('सिगिरिया')) {
        score += 2;
      }

      for (final token in queryTokens) {
        if (text.contains(token)) score += 3;
        if (category.contains(token)) score += 2;
        if (landmark.contains(token)) score += 2;
      }

      score += weightedCategory[entry.category.toLowerCase()] ?? 0;
      return _ScoredEntry(entry: entry, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  Map<String, int> _categoryHints(String question) {
    final hints = <String, int>{};
    final q = question;
    if (q.contains('lion') || q.contains('gate') || q.contains('stairs') || q.contains('stair')) {
      hints['architecture'] = 3;
      hints['fortress'] = 2;
    }
    if (q.contains('fresco') || q.contains('painting') || q.contains('art')) {
      hints['art'] = 3;
    }
    if (q.contains('water') || q.contains('garden') || q.contains('fountain') || q.contains('hydraulic')) {
      hints['engineering'] = 3;
      hints['gardens'] = 2;
    }
    if (q.contains('history') || q.contains('king') || q.contains('kashyapa') || q.contains('capital')) {
      hints['history'] = 3;
    }
    if (q.contains('monk') || q.contains('buddhist') || q.contains('religion') || q.contains('monastery')) {
      hints['religion'] = 3;
    }
    if (q.contains('tour') || q.contains('visit') || q.contains('ticket') || q.contains('climb')) {
      hints['tourism'] = 3;
    }
    if (q.contains('dig') || q.contains('excavat') || q.contains('archaeolog')) {
      hints['archaeology'] = 3;
    }
    if (q.contains('weather') || q.contains('forest') || q.contains('wildlife') || q.contains('environment')) {
      hints['environment'] = 3;
    }
    if (q.contains('fact') || q.contains('how many') || q.contains('where') || q.contains('when')) {
      hints['facts'] = 2;
    }
    if (q.contains('culture') || q.contains('graffiti') || q.contains('identity')) {
      hints['culture'] = 3;
    }
    return hints;
  }

  String _randomGreeting(String language) {
    final greetings = _localized(language)['greetings'] as List;
    if (greetings.isEmpty) return 'Greetings!';
    final randomIndex = Random().nextInt(greetings.length);
    return greetings[randomIndex] as String;
  }

  String _getLocalizedLandmark(String landmark, String language) {
    final key = landmark.toLowerCase().trim();
    const translations = {
      'sigiriya': {
        'en': 'Sigiriya',
        'hi': 'सिगिरिया',
        'zh': '锡吉里耶',
        'ru': 'Сигирия',
        'de': 'Sigiriya',
        'si': 'සීගිරිය',
        'ta': 'சிகிரியா',
      },
      'dambulla': {
        'en': 'Dambulla',
        'hi': 'डंबुला',
        'zh': '丹布勒',
        'ru': 'Дамбулла',
        'de': 'Dambulla',
        'si': 'දඹුල්ල',
        'ta': 'தம்புள்ளை',
      },
      'polonnaruwa': {
        'en': 'Polonnaruwa',
        'hi': 'पोलोन्नरुवा',
        'zh': '波隆纳鲁沃',
        'ru': 'Полоннарува',
        'de': 'Polonnaruwa',
        'si': 'පොළොන්නරුව',
        'ta': 'பொலன்னறுவை',
      }
    };
    return translations[key]?[language] ?? landmark;
  }

  String _optionalFact(String language, String landmarkKey) {
    if (landmarkKey != 'sigiriya') {
      return '';
    }

    final factPrefix = _localized(language)['fact_prefix'] as String;
    
    final Map<String, List<String>> localizedFacts = {
      'en': [
        "Sigiriya is often called the Eighth Wonder of the World.",
        "The site has over 1,202 steps to the summit.",
        "Its water gardens are among the oldest landscaped gardens in Asia.",
        "The Mirror Wall contains ancient graffiti from visitors centuries ago.",
      ],
      'hi': [
        "सिगिरिया को अक्सर दुनिया का आठवां अजूबा कहा जाता है।",
        "शिखर तक पहुँचने के लिए यहाँ 1,202 से अधिक सीढ़ियाँ हैं।",
        "इसके जल उद्यान एशिया के सबसे पुराने भूदृश्य उद्यानों में से हैं।",
        "दर्पण दीवार (Mirror Wall) पर सदियों पहले के आगंतुकों के प्राचीन भित्तिचित्र हैं।",
      ],
      'zh': [
        "锡吉里耶常被誉为世界第八大奇迹。",
        "到达岩顶共有1,202级台阶。",
        "它的水上花园是亚洲最古老的景观花园之一。",
        "镜墙上保留着数百年前游客留下的古老涂鸦。",
      ],
      'ru': [
        "Сигирию часто называют восьмым чудом света.",
        "На вершину скалы ведет более 1202 ступеней.",
        "Ее водяные сады являются одними из старейших ландшафтных садов в Азии.",
        "Зеркальная стена содержит древние граффити, оставленные посетителями много веков назад.",
      ],
      'de': [
        "Sigiriya wird oft als das achte Weltwunder bezeichnet.",
        "Es gibt über 1.202 Stufen bis zum Gipfel.",
        "Die Wassergärten gehören zu den ältesten Landschaftsgärten Asiens.",
        "Die Spiegelwand enthält antike Graffiti von Besuchern vor Jahrhunderten.",
      ],
      'si': [
        "සීගිරිය බොහෝ විට ලෝකයේ අටවන පුදුමය ලෙස හඳුන්වනු ලැබේ.",
        "මුදුනට ළඟා වීමට පියගැට 1,202 කට වඩා තිබේ.",
        "එහි දිය උද්‍යාන ආසියාවේ පැරණිතම උද්‍යාන සැලසුම් අතර වේ.",
        "කැඩපත් පවුරේ සියවස් ගණනාවකට පෙර පැමිණි අමුත්තන්ගේ පැරණි කුරුටු ගී අඩංගු වේ.",
      ],
      'ta': [
        "சிகிரியா பெரும்பாலும் உலகின் எட்டாவது அதிசயம் என்று அழைக்கப்படுகிறது.",
        "உச்சிக்கு செல்ல 1,202 க்கும் மேற்பட்ட படிகள் உள்ளன.",
        "இதன் நீர் பூங்காக்கள் ஆசியாவிலேயே மிக பழமையான நிலப்பரப்பு பூங்காக்களில் ஒன்றாகும்.",
        "கண்ணாடிச் சுவரில் பல நூற்றாண்டுகளுக்கு முன்பு வந்த பார்வையாளர்களின் பண்டைய சுவரெழுத்துக்கள் உள்ளன.",
      ],
    };

    final facts = localizedFacts[language] ?? localizedFacts['en']!;
    final randomIndex = Random().nextInt(facts.length);
    return ' $factPrefix ${facts[randomIndex]}';
  }

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAllMapped(RegExp(r'.', dotAll: true), (match) {
        final ch = match.group(0)!;
        final code = ch.codeUnitAt(0);
        final isAsciiAlphaNumeric = (code >= 48 && code <= 57) || (code >= 97 && code <= 122);
        final isWhitespace = ch.trim().isEmpty;
        final isUnicodeLetterOrDigit = code > 127;
        return (isAsciiAlphaNumeric || isWhitespace || isUnicodeLetterOrDigit) ? ch : ' ';
      })
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _tokens(String input) => _normalize(input)
      .split(' ')
      .where((token) => token.length > 2)
      .toList();
}

class _KnowledgeEntry {
  final String id;
  final String landmark;
  final String category;
  final String text;
  final Map<String, String> translations;

  _KnowledgeEntry({
    required this.id,
    required this.landmark,
    required this.category,
    required this.text,
    required this.translations,
  });

  factory _KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    final rawTranslations = json['translations'] as Map<String, dynamic>? ?? {};
    final Map<String, String> translationsMap = {};
    rawTranslations.forEach((k, v) => translationsMap[k] = v.toString());

    return _KnowledgeEntry(
      id: json['id'] as String? ?? '',
      landmark: json['landmark'] as String? ?? 'Sigiriya',
      category: json['category'] as String? ?? 'default',
      text: json['text'] as String? ?? '',
      translations: translationsMap,
    );
  }

  String getLocalizedText(String languageCode) {
    if (languageCode == 'en') return text;
    final translated = translations[languageCode];
    if (translated == null || translated.isEmpty) return text;
    return translated;
  }
}

class _ScoredEntry {
  final _KnowledgeEntry entry;
  final int score;

  const _ScoredEntry({required this.entry, required this.score});
}
