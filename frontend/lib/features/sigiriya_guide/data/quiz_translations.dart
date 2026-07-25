// lib/features/sigiriya_guide/data/quiz_translations.dart
//
// Multi-language quiz content for the Sigiriya Heritage Quiz.
// Languages: English (en), Chinese Simplified (zh), Spanish (es), Hindi (hi), Arabic (ar).
// These are the top 5 most-used languages on Google Search globally.

/// Represents a single quiz question in any language.
class QuizQuestionData {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestionData({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// Supported languages for the quiz.
enum QuizLanguage {
  english,
  chinese,
  spanish,
  hindi,
  arabic,
}

extension QuizLanguageInfo on QuizLanguage {
  String get displayName {
    switch (this) {
      case QuizLanguage.english:
        return 'English';
      case QuizLanguage.chinese:
        return '中文';
      case QuizLanguage.spanish:
        return 'Español';
      case QuizLanguage.hindi:
        return 'हिंदी';
      case QuizLanguage.arabic:
        return 'العربية';
    }
  }

  String get flag {
    switch (this) {
      case QuizLanguage.english:
        return '🇬🇧';
      case QuizLanguage.chinese:
        return '🇨🇳';
      case QuizLanguage.spanish:
        return '🇪🇸';
      case QuizLanguage.hindi:
        return '🇮🇳';
      case QuizLanguage.arabic:
        return '🇸🇦';
    }
  }

  /// Whether the language is RTL (right-to-left).
  bool get isRtl => this == QuizLanguage.arabic;
}

/// Returns the full list of quiz questions for the given language.
List<QuizQuestionData> getQuizQuestions(QuizLanguage lang) {
  switch (lang) {
    case QuizLanguage.english:
      return _englishQuestions;
    case QuizLanguage.chinese:
      return _chineseQuestions;
    case QuizLanguage.spanish:
      return _spanishQuestions;
    case QuizLanguage.hindi:
      return _hindiQuestions;
    case QuizLanguage.arabic:
      return _arabicQuestions;
  }
}

// ─────────────────────────────────────────────
// ENGLISH
// ─────────────────────────────────────────────
const List<QuizQuestionData> _englishQuestions = [
  QuizQuestionData(
    question: 'Which site is a UNESCO World Heritage Site in Sri Lanka?',
    options: [
      'Sigiriya Rock Fortress',
      'Bentota Beach',
      'Nuwara Eliya Town',
      'Kandy Railway Station',
    ],
    correctIndex: 0,
    explanation:
        'Sigiriya Rock Fortress was inscribed as a UNESCO World Heritage Site in 1982.',
  ),
  QuizQuestionData(
    question: 'What animal is symbolically linked to the Lion Gate?',
    options: ['Elephant', 'Lion', 'Peacock', 'Dragon'],
    correctIndex: 1,
    explanation:
        'The entrance is known as Lion Gate because it once featured a colossal lion form.',
  ),
  QuizQuestionData(
    question: 'What is the Mirror Wall famous for?',
    options: [
      'Ancient poetic graffiti',
      'Hidden treasure maps',
      'Modern murals',
      'Water storage',
    ],
    correctIndex: 0,
    explanation:
        'Visitors wrote poems and inscriptions on the wall from the 6th century onward.',
  ),
  QuizQuestionData(
    question:
        'Which part of Sigiriya shows advanced hydraulic engineering?',
    options: [
      'Water Gardens',
      'Summit Palace',
      'Gallery entrance',
      'Lion paws',
    ],
    correctIndex: 0,
    explanation:
        'The Water Gardens contain ponds, channels, and fountain systems powered by ancient hydraulics.',
  ),
  QuizQuestionData(
    question: 'Who built Sigiriya Rock Fortress as a royal capital?',
    options: [
      'King Dutugemunu',
      'King Kashyapa I',
      'King Parakramabahu',
      'King Valagamba',
    ],
    correctIndex: 1,
    explanation:
        'King Kashyapa I built the site during his reign between 477 and 495 AD.',
  ),
  QuizQuestionData(
    question: 'What do the Sigiriya frescoes mainly depict?',
    options: [
      'Warriors on horseback',
      'Celestial maidens',
      'Market scenes',
      'Royal elephants only',
    ],
    correctIndex: 1,
    explanation:
        'The frescoes depict Sigiriya Maidens, often described as celestial female figures.',
  ),
  QuizQuestionData(
    question:
        'Approximately how high does the Sigiriya rock rise above the plains?',
    options: ['50 metres', '100 metres', '200 metres', '500 metres'],
    correctIndex: 2,
    explanation: 'The rock rises about 200 metres above the surrounding plains.',
  ),
  QuizQuestionData(
    question:
        'What was the original purpose of the site before it became a royal citadel?',
    options: [
      'Fishing port',
      'Buddhist monastery',
      'Tea estate',
      'Military airport',
    ],
    correctIndex: 1,
    explanation:
        'The site had earlier served as a Buddhist monastery before being transformed by King Kashyapa.',
  ),
  QuizQuestionData(
    question: 'What is the best description of the treasure hunt mechanic?',
    options: [
      'One fixed route with no progress',
      'Clue-based discovery with rewards',
      'Only reading long paragraphs',
      'Random guessing game',
    ],
    correctIndex: 1,
    explanation:
        'The gamified layer is designed around clue trails, discovery, and achievements.',
  ),
  QuizQuestionData(
    question: 'How many questions are included in this quiz set?',
    options: ['5', '7', '10', '12'],
    correctIndex: 2,
    explanation: 'This quiz set contains 10 multiple-choice questions.',
  ),
];

// ─────────────────────────────────────────────
// CHINESE SIMPLIFIED (中文)
// ─────────────────────────────────────────────
const List<QuizQuestionData> _chineseQuestions = [
  QuizQuestionData(
    question: '斯里兰卡哪处遗址是联合国教科文组织世界遗产？',
    options: ['锡吉里耶岩石堡垒', '本托塔海滩', '努沃勒埃利耶镇', '康提火车站'],
    correctIndex: 0,
    explanation: '锡吉里耶岩石堡垒于1982年被列为联合国教科文组织世界遗产。',
  ),
  QuizQuestionData(
    question: '哪种动物与狮子门有象征性联系？',
    options: ['大象', '狮子', '孔雀', '龙'],
    correctIndex: 1,
    explanation: '该入口被称为狮子门，因为它曾经有一个巨大的狮子造型。',
  ),
  QuizQuestionData(
    question: '镜墙以什么著名？',
    options: ['古代诗歌涂鸦', '隐藏的藏宝图', '现代壁画', '储水'],
    correctIndex: 0,
    explanation: '从6世纪起，游客在墙上写诗和铭文。',
  ),
  QuizQuestionData(
    question: '锡吉里耶的哪个部分展示了先进的水利工程？',
    options: ['水上花园', '山顶宫殿', '画廊入口', '狮子爪'],
    correctIndex: 0,
    explanation: '水上花园包含由古代水力驱动的池塘、水渠和喷泉系统。',
  ),
  QuizQuestionData(
    question: '谁将锡吉里耶岩石堡垒建成皇家首都？',
    options: ['杜图杰穆努国王', '卡西帕一世国王', '帕拉克拉马巴胡国王', '瓦拉甘巴国王'],
    correctIndex: 1,
    explanation: '卡西帕一世国王在477年至495年统治期间建造了该遗址。',
  ),
  QuizQuestionData(
    question: '锡吉里耶壁画主要描绘什么？',
    options: ['骑马的战士', '天界仙女', '市场场景', '仅有皇家大象'],
    correctIndex: 1,
    explanation: '壁画描绘了锡吉里耶仙女，通常被描述为天界女性形象。',
  ),
  QuizQuestionData(
    question: '锡吉里耶岩石大约比平原高多少米？',
    options: ['50米', '100米', '200米', '500米'],
    correctIndex: 2,
    explanation: '该岩石比周围平原高约200米。',
  ),
  QuizQuestionData(
    question: '该遗址成为皇家城堡之前的最初用途是什么？',
    options: ['渔港', '佛教寺院', '茶园', '军用机场'],
    correctIndex: 1,
    explanation: '该遗址早期曾是一座佛教寺院，后来被卡西帕国王改造。',
  ),
  QuizQuestionData(
    question: '对寻宝游戏机制的最佳描述是什么？',
    options: ['一条没有进展的固定路线', '基于线索的探索与奖励', '只阅读长段落', '随机猜测游戏'],
    correctIndex: 1,
    explanation: '游戏化层面围绕线索路径、探索和成就来设计。',
  ),
  QuizQuestionData(
    question: '这套测验共包含多少道题？',
    options: ['5', '7', '10', '12'],
    correctIndex: 2,
    explanation: '这套测验包含10道选择题。',
  ),
];

// ─────────────────────────────────────────────
// SPANISH (Español)
// ─────────────────────────────────────────────
const List<QuizQuestionData> _spanishQuestions = [
  QuizQuestionData(
    question: '¿Cuál sitio es Patrimonio Mundial de la UNESCO en Sri Lanka?',
    options: [
      'Fortaleza de la Roca de Sigiriya',
      'Playa de Bentota',
      'Ciudad de Nuwara Eliya',
      'Estación de tren de Kandy',
    ],
    correctIndex: 0,
    explanation:
        'La Fortaleza de la Roca de Sigiriya fue inscrita como Patrimonio Mundial de la UNESCO en 1982.',
  ),
  QuizQuestionData(
    question: '¿Qué animal está simbólicamente vinculado a la Puerta del León?',
    options: ['Elefante', 'León', 'Pavo real', 'Dragón'],
    correctIndex: 1,
    explanation:
        'La entrada se conoce como Puerta del León porque alguna vez tuvo una forma colosal de león.',
  ),
  QuizQuestionData(
    question: '¿Por qué es famosa la Pared Espejo?',
    options: [
      'Grafitis poéticos antiguos',
      'Mapas del tesoro ocultos',
      'Murales modernos',
      'Almacenamiento de agua',
    ],
    correctIndex: 0,
    explanation:
        'Los visitantes escribieron poemas e inscripciones en la pared desde el siglo VI en adelante.',
  ),
  QuizQuestionData(
    question:
        '¿Qué parte de Sigiriya muestra ingeniería hidráulica avanzada?',
    options: [
      'Jardines de agua',
      'Palacio de la cima',
      'Entrada de la galería',
      'Patas de león',
    ],
    correctIndex: 0,
    explanation:
        'Los Jardines de Agua contienen estanques, canales y sistemas de fuentes impulsados por hidráulica antigua.',
  ),
  QuizQuestionData(
    question: '¿Quién construyó la Fortaleza de la Roca de Sigiriya como capital real?',
    options: [
      'Rey Dutugemunu',
      'Rey Kashyapa I',
      'Rey Parakramabahu',
      'Rey Valagamba',
    ],
    correctIndex: 1,
    explanation:
        'El Rey Kashyapa I construyó el sitio durante su reinado entre 477 y 495 d.C.',
  ),
  QuizQuestionData(
    question: '¿Qué representan principalmente los frescos de Sigiriya?',
    options: [
      'Guerreros a caballo',
      'Doncellas celestiales',
      'Escenas de mercado',
      'Solo elefantes reales',
    ],
    correctIndex: 1,
    explanation:
        'Los frescos representan a las Doncellas de Sigiriya, a menudo descritas como figuras femeninas celestiales.',
  ),
  QuizQuestionData(
    question:
        '¿Aproximadamente cuánto se eleva la roca de Sigiriya sobre las llanuras?',
    options: ['50 metros', '100 metros', '200 metros', '500 metros'],
    correctIndex: 2,
    explanation: 'La roca se eleva unos 200 metros sobre las llanuras circundantes.',
  ),
  QuizQuestionData(
    question:
        '¿Cuál era el propósito original del sitio antes de convertirse en ciudadela real?',
    options: [
      'Puerto pesquero',
      'Monasterio budista',
      'Finca de té',
      'Aeropuerto militar',
    ],
    correctIndex: 1,
    explanation:
        'El sitio había servido antes como monasterio budista antes de ser transformado por el Rey Kashyapa.',
  ),
  QuizQuestionData(
    question:
        '¿Cuál es la mejor descripción del mecanismo de búsqueda del tesoro?',
    options: [
      'Una ruta fija sin progreso',
      'Descubrimiento basado en pistas con recompensas',
      'Solo leer párrafos largos',
      'Juego de adivinación aleatoria',
    ],
    correctIndex: 1,
    explanation:
        'La capa gamificada está diseñada en torno a rutas de pistas, descubrimiento y logros.',
  ),
  QuizQuestionData(
    question: '¿Cuántas preguntas incluye este conjunto de cuestionario?',
    options: ['5', '7', '10', '12'],
    correctIndex: 2,
    explanation: 'Este conjunto de cuestionario contiene 10 preguntas de opción múltiple.',
  ),
];

// ─────────────────────────────────────────────
// HINDI (हिंदी)
// ─────────────────────────────────────────────
const List<QuizQuestionData> _hindiQuestions = [
  QuizQuestionData(
    question: 'श्रीलंका में कौन सी साइट यूनेस्को विश्व धरोहर स्थल है?',
    options: ['सिगिरिया रॉक किला', 'बेंटोटा बीच', 'नुवारा एलिया टाउन', 'कैंडी रेलवे स्टेशन'],
    correctIndex: 0,
    explanation: 'सिगिरिया रॉक किले को 1982 में यूनेस्को विश्व धरोहर स्थल के रूप में अंकित किया गया था।',
  ),
  QuizQuestionData(
    question: 'कौन सा जानवर प्रतीकात्मक रूप से लायन गेट से जुड़ा है?',
    options: ['हाथी', 'शेर', 'मोर', 'अजगर'],
    correctIndex: 1,
    explanation: 'प्रवेश द्वार को लायन गेट के नाम से जाना जाता है क्योंकि इसमें एक बार एक विशाल शेर का रूप था।',
  ),
  QuizQuestionData(
    question: 'मिरर वॉल किसके लिए प्रसिद्ध है?',
    options: ['प्राचीन काव्य भित्तिचित्र', 'छिपे हुए खजाने के नक्शे', 'आधुनिक भित्तिचित्र', 'जल भंडारण'],
    correctIndex: 0,
    explanation: '6वीं सदी से आगंतुकों ने दीवार पर कविताएं और शिलालेख लिखे।',
  ),
  QuizQuestionData(
    question: 'सिगिरिया का कौन सा हिस्सा उन्नत हाइड्रोलिक इंजीनियरिंग दिखाता है?',
    options: ['वाटर गार्डन', 'समिट पैलेस', 'गैलरी प्रवेश', 'शेर के पंजे'],
    correctIndex: 0,
    explanation: 'वाटर गार्डन में प्राचीन हाइड्रोलिक्स द्वारा संचालित तालाब, चैनल और फव्वारा प्रणालियाँ हैं।',
  ),
  QuizQuestionData(
    question: 'सिगिरिया रॉक किले को शाही राजधानी के रूप में किसने बनाया?',
    options: ['राजा दुतुगेमुनु', 'राजा काश्यप प्रथम', 'राजा पराक्रमबाहु', 'राजा वलगम्बा'],
    correctIndex: 1,
    explanation: 'राजा काश्यप प्रथम ने 477 से 495 ईस्वी के बीच अपने शासनकाल में इस स्थल का निर्माण किया।',
  ),
  QuizQuestionData(
    question: 'सिगिरिया भित्तिचित्र मुख्य रूप से क्या दर्शाते हैं?',
    options: ['घुड़सवार योद्धा', 'दिव्य कन्याएं', 'बाजार के दृश्य', 'केवल शाही हाथी'],
    correctIndex: 1,
    explanation: 'भित्तिचित्र सिगिरिया कन्याओं को दर्शाते हैं, जिन्हें अक्सर दिव्य महिला आकृतियों के रूप में वर्णित किया जाता है।',
  ),
  QuizQuestionData(
    question: 'सिगिरिया की चट्टान मैदानों से लगभग कितनी ऊँची है?',
    options: ['50 मीटर', '100 मीटर', '200 मीटर', '500 मीटर'],
    correctIndex: 2,
    explanation: 'चट्टान आसपास के मैदानों से लगभग 200 मीटर ऊपर उठती है।',
  ),
  QuizQuestionData(
    question: 'शाही गढ़ बनने से पहले इस स्थल का मूल उद्देश्य क्या था?',
    options: ['मछली पकड़ने का बंदरगाह', 'बौद्ध मठ', 'चाय बागान', 'सैन्य हवाई अड्डा'],
    correctIndex: 1,
    explanation: 'यह स्थल राजा काश्यप द्वारा रूपांतरित होने से पहले एक बौद्ध मठ के रूप में कार्य करता था।',
  ),
  QuizQuestionData(
    question: 'खजाना खोज तंत्र का सबसे अच्छा विवरण क्या है?',
    options: ['बिना प्रगति के एक निश्चित मार्ग', 'पुरस्कारों के साथ सुराग-आधारित खोज', 'केवल लंबे पैराग्राफ पढ़ना', 'यादृच्छिक अनुमान खेल'],
    correctIndex: 1,
    explanation: 'गेमीफाइड परत सुराग पथ, खोज और उपलब्धियों के आसपास डिज़ाइन की गई है।',
  ),
  QuizQuestionData(
    question: 'इस क्विज़ सेट में कितने प्रश्न शामिल हैं?',
    options: ['5', '7', '10', '12'],
    correctIndex: 2,
    explanation: 'इस क्विज़ सेट में 10 बहुविकल्पीय प्रश्न हैं।',
  ),
];

// ─────────────────────────────────────────────
// ARABIC (العربية)
// ─────────────────────────────────────────────
const List<QuizQuestionData> _arabicQuestions = [
  QuizQuestionData(
    question: 'أي موقع في سريلانكا يُعدّ موقعاً لتراث اليونسكو العالمي؟',
    options: ['قلعة صخرة سيغيريا', 'شاطئ بينتوتا', 'مدينة نواراإليا', 'محطة قطار كاندي'],
    correctIndex: 0,
    explanation: 'تم تسجيل قلعة صخرة سيغيريا في قائمة التراث العالمي لليونسكو عام 1982.',
  ),
  QuizQuestionData(
    question: 'أي حيوان مرتبط رمزياً ببوابة الأسد؟',
    options: ['الفيل', 'الأسد', 'الطاووس', 'التنين'],
    correctIndex: 1,
    explanation: 'يُعرف المدخل ببوابة الأسد لأنه كان يتميز بشكل أسد ضخم.',
  ),
  QuizQuestionData(
    question: 'بمَ تشتهر جدار المرآة؟',
    options: ['نقوش شعرية قديمة', 'خرائط كنوز مخفية', 'جداريات حديثة', 'تخزين المياه'],
    correctIndex: 0,
    explanation: 'كتب الزوار قصائد ونقوشاً على الجدار منذ القرن السادس الميلادي.',
  ),
  QuizQuestionData(
    question: 'أي جزء من سيغيريا يُظهر هندسة هيدروليكية متقدمة؟',
    options: ['حدائق المياه', 'قصر القمة', 'مدخل المعرض', 'مخالب الأسد'],
    correctIndex: 0,
    explanation: 'تحتوي حدائق المياه على برك وقنوات وأنظمة نوافير تعمل بالهيدروليك القديم.',
  ),
  QuizQuestionData(
    question: 'من بنى قلعة صخرة سيغيريا عاصمةً ملكية؟',
    options: ['الملك دوتوغيمونو', 'الملك كاشياباI', 'الملك باراكراماباهو', 'الملك فالاغامبا'],
    correctIndex: 1,
    explanation: 'بنى الملك كاشيابا الأول الموقع خلال فترة حكمه بين عامَي 477 و495 ميلادية.',
  ),
  QuizQuestionData(
    question: 'ما الذي تصوّره لوحات سيغيريا الجدارية في معظمها؟',
    options: ['محاربون على ظهور الخيل', 'عذارى سماويات', 'مشاهد السوق', 'الأفيال الملكية فقط'],
    correctIndex: 1,
    explanation: 'تصوّر اللوحات الجداريةُ عذارى سيغيريا، وهن شخصيات أنثوية سماوية.',
  ),
  QuizQuestionData(
    question: 'بكم متراً تقريباً ترتفع صخرة سيغيريا عن السهول؟',
    options: ['50 متراً', '100 متر', '200 متر', '500 متر'],
    correctIndex: 2,
    explanation: 'ترتفع الصخرة حوالي 200 متر فوق السهول المحيطة بها.',
  ),
  QuizQuestionData(
    question: 'ما الغرض الأصلي للموقع قبل أن يصبح قلعة ملكية؟',
    options: ['ميناء صيد', 'دير بوذي', 'مزرعة شاي', 'مطار عسكري'],
    correctIndex: 1,
    explanation: 'كان الموقع في السابق ديراً بوذياً قبل أن يحوّله الملك كاشيابا.',
  ),
  QuizQuestionData(
    question: 'ما أفضل وصف لآلية البحث عن الكنز؟',
    options: [
      'مسار ثابت بلا تقدم',
      'اكتشاف قائم على الأدلة مع مكافآت',
      'قراءة فقرات طويلة فقط',
      'لعبة تخمين عشوائية',
    ],
    correctIndex: 1,
    explanation: 'تم تصميم الطبقة المُلعَبة حول مسارات الأدلة والاكتشاف والإنجازات.',
  ),
  QuizQuestionData(
    question: 'كم عدد الأسئلة المتضمنة في هذه المجموعة؟',
    options: ['5', '7', '10', '12'],
    correctIndex: 2,
    explanation: 'تحتوي هذه المجموعة على 10 أسئلة اختيار من متعدد.',
  ),
];
