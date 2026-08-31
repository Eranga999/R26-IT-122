import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'offline_chatbot_service.dart';
import 'voice_chat_service.dart';

class RagChatScreen extends StatefulWidget {
  final String? landmarkName;
  final String? landmarkId;
  const RagChatScreen({super.key, this.landmarkName, this.landmarkId});

  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final List<Map<String, String>> _messages;
  bool _isLoading = false;
  String _selectedLanguageCode = 'en';

  /// Minimum time the "typing…" indicator stays on screen before a reply is
  /// shown, so answers never snap in instantly. The real lookup usually
  /// finishes well inside this window.
  static const Duration _minThinkTime = Duration(milliseconds: 3500);

  // ── Voice state ─────────────────────────────────────────────────────────
  final VoiceChatService _voice = VoiceChatService.instance;
  bool _voiceReady = false;
  bool _isListening = false;
  bool _autoSpeak = false; // read bot replies aloud
  String _partialStt = '';
  // One-shot latch: the STT engine (esp. on Android) can deliver a final
  // result — and the 'done' status — more than once per session. This makes
  // sure the captured phrase is dispatched to the chat exactly once, until
  // the next startListening() call resets it.
  bool _voiceDispatched = false;
  late AnimationController _pulseController;

  static const Map<String, String> _languageLabels = {
    'en': 'English',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'ru': 'Russian',
    'de': 'German',
    'si': 'Sinhala',
    'ta': 'Tamil',
  };

  String get _currentLandmarkId {
    final providedId = widget.landmarkId?.trim();
    if (providedId != null && providedId.isNotEmpty) {
      return providedId.toLowerCase();
    }
    final landmarkName = widget.landmarkName?.trim();
    if (landmarkName != null && landmarkName.isNotEmpty) {
      return landmarkName.toLowerCase().replaceAll(' ', '_');
    }
    return 'sigiriya';
  }

  String get _currentLandmarkLabel {
    final landmarkName = widget.landmarkName?.trim();
    if (landmarkName != null && landmarkName.isNotEmpty) return landmarkName;
    return 'Sigiriya';
  }

  @override
  void initState() {
    super.initState();
    _messages = [
      {'bot': _welcomeMessage()}
    ];
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.init();
    if (mounted) setState(() => _voiceReady = ok);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _pulseController.dispose();
    _voice.dispose();
    super.dispose();
  }

  /// Smoothly scrolls the transcript to the newest message / typing bubble.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Translation helper ──────────────────────────────────────────────────
  String _tr({
    required String en,
    String? hi, String? zh, String? ru, String? de, String? si, String? ta,
  }) {
    switch (_selectedLanguageCode) {
      case 'hi': return hi ?? en;
      case 'zh': return zh ?? en;
      case 'ru': return ru ?? en;
      case 'de': return de ?? en;
      case 'si': return si ?? en;
      case 'ta': return ta ?? en;
      default: return en;
    }
  }

  String _welcomeMessage() => _tr(
    en: 'Greetings! I am your Heritage Guide. I can tell you all about the history, architecture, and hidden secrets of $_currentLandmarkLabel. How can I help you today?',
    hi: 'नमस्ते! मैं आपका Heritage Guide हूँ। मैं आपको $_currentLandmarkLabel के इतिहास, वास्तुकला और रोचक रहस्यों के बारे में बता सकता हूँ। आज मैं आपकी कैसे मदद कर सकता हूँ?',
    zh: '您好！我是您的 Heritage Guide。我可以为您介绍 $_currentLandmarkLabel 的历史、建筑和隐藏故事。今天我可以如何帮助您？',
    ru: 'Здравствуйте! Я ваш Heritage Guide. Я могу рассказать вам об истории, архитектуре и тайнах $_currentLandmarkLabel. Чем я могу помочь вам сегодня?',
    de: 'Hallo! Ich bin Ihr Heritage Guide. Ich kann Ihnen alles ueber die Geschichte, Architektur und Geheimnisse von $_currentLandmarkLabel erzaehlen. Wie kann ich Ihnen heute helfen?',
    si: 'ආයුබෝවන්! මම ඔබගේ Heritage Guide. $_currentLandmarkLabel හි ඉතිහාසය, වාස්තු විද්‍යාව සහ රහස් ගැන ඔබට කියා දිය හැක. අද ඔබට කෙසේ උදව් කළ හැකිද?',
    ta: 'வணக்கம்! நான் உங்கள் Heritage Guide. $_currentLandmarkLabel பற்றிய வரலாறு, கட்டிடக்கலை மற்றும் சுவாரஸ்ய தகவல்களை பகிரலாம். இன்று உங்களுக்கு எப்படி உதவலாம்?',
  );

  String _languageChangedMessage() => _tr(
    en: 'Language changed to ${_languageLabels[_selectedLanguageCode]}.',
    hi: 'भाषा ${_languageLabels[_selectedLanguageCode]} में बदल दी गई है।',
    zh: '语言已切换为 ${_languageLabels[_selectedLanguageCode]}。',
    ru: 'Язык переключен на ${_languageLabels[_selectedLanguageCode]}.',
    de: 'Sprache wurde auf ${_languageLabels[_selectedLanguageCode]} umgestellt.',
    si: 'භාෂාව ${_languageLabels[_selectedLanguageCode]} ලෙස වෙනස් කළා.',
    ta: 'மொழி ${_languageLabels[_selectedLanguageCode]} ஆக மாற்றப்பட்டது.',
  );

  List<String> _suggestions() {
    if (_selectedLanguageCode == 'hi') {
      return const ['Sigiriya किसने बनवाया?', 'फ्रेस्को के बारे में बताइए', 'शिखर तक कितनी सीढ़ियाँ हैं?', 'Lion Gate क्या है?'];
    }
    if (_selectedLanguageCode == 'zh') {
      return const ['是谁建造了 Sigiriya？', '请介绍一下壁画', '上山有多少级台阶？', 'Lion Gate 是什么？'];
    }
    if (_selectedLanguageCode == 'ru') {
      return const ['Кто построил Sigiriya?', 'Расскажите о фресках', 'Сколько ступеней до вершины?', 'Что такое Lion Gate?'];
    }
    if (_selectedLanguageCode == 'de') {
      return const ['Wer hat Sigiriya gebaut?', 'Erzaehlen Sie mir ueber die Fresken', 'Wie viele Stufen fuehren nach oben?', 'Was ist das Lion Gate?'];
    }
    if (_selectedLanguageCode == 'si') {
      return const ['Sigiriya නිර්මාණය කළේ කවුද?', 'frescoes ගැන කියන්න', 'සිගිරියට පියවර කීයක් තියෙනවාද?', 'Lion Gate කියන්නේ මොකක්ද?'];
    }
    if (_selectedLanguageCode == 'ta') {
      return const ['Sigiriya-வை யார் கட்டினார்?', 'frescoes பற்றி சொல்லுங்கள்', 'மேலே ஏற எத்தனை படிகள் உள்ளன?', 'Lion Gate என்றால் என்ன?'];
    }
    return const ['Who built Sigiriya?', 'Tell me about the frescoes', 'How many steps are there?', 'What is the Lion Gate?'];
  }

  void _changeLanguage(String languageCode) {
    if (_selectedLanguageCode == languageCode || _isLoading) return;
    setState(() {
      _selectedLanguageCode = languageCode;
      _messages.add({'bot': _languageChangedMessage()});
    });
  }

  void _sendSuggestedMessage(String msg) {
    if (_isLoading) return;
    _controller.text = msg;
    _sendMessage();
  }

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty || _isLoading) return;
    setState(() {
      _messages.add({'user': userMessage});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToEnd();

    // Hold the typing indicator for at least _minThinkTime, running in
    // parallel with the actual lookup so the total wait is the longer of
    // the two (almost always just the timer).
    final minThink = Future<void>.delayed(_minThinkTime);

    String reply;
    try {
      reply = await OfflineChatbotService.instance.answer(
        question: userMessage,
        landmarkId: _currentLandmarkId,
        language: _selectedLanguageCode,
      );
    } catch (_) {
      reply = _tr(
        en: 'Error: Could not load the offline guide data.',
        hi: 'त्रुटि: ऑफ़लाइन गाइड डेटा लोड नहीं हो सका।',
        zh: '错误：无法加载离线导览数据。',
        ru: 'Ошибка: не удалось загрузить офлайн-данные гида.',
        de: 'Fehler: Die Offline-Guidedaten konnten nicht geladen werden.',
        si: 'දෝෂයක්: offline guide data load කරන්න බැරි වුණා.',
        ta: 'பிழை: offline guide தரவை ஏற்ற முடியவில்லை.',
      );
    }

    await minThink;
    if (!mounted) return;
    setState(() {
      _messages.add({'bot': reply});
      _isLoading = false;
    });
    _scrollToEnd();

    // Auto-speak the bot reply if voice mode is on
    if (_autoSpeak) {
      _voice.speak(reply, languageCode: _selectedLanguageCode);
    }
  }

  // ── Voice actions ───────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      // Manual stop — flush whatever was captured.
      await _voice.stopListening();
      _consumeVoiceInput();
      return;
    }

    // (Re)check voice availability so a first-time permission grant works
    // without having to reopen the screen.
    if (!_voiceReady) {
      await _initVoice();
      if (!_voiceReady) {
        _showVoiceUnavailable();
        return;
      }
    }

    // Stop any ongoing TTS first
    if (_voice.isSpeaking) await _voice.stopSpeaking();
    _voiceDispatched = false;
    setState(() {
      _isListening = true;
      _partialStt = '';
    });

    await _voice.startListening(
      languageCode: _selectedLanguageCode,
      onResult: (result) {
        if (!mounted) return;
        if (result.recognizedWords.isNotEmpty) {
          setState(() => _partialStt = result.recognizedWords);
        }
        if (result.finalResult) _consumeVoiceInput();
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done') {
          _consumeVoiceInput();
        } else if (status == 'notListening' && _isListening) {
          // The engine stopped capturing. If no final result lands shortly
          // (on-device timeout, or partial results only) flush the partial so
          // the mic can never stay stuck in the "listening" state.
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && _isListening) _consumeVoiceInput();
          });
        }
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _partialStt = '';
        });
        _showVoiceError(msg);
      },
    );
  }

  /// Pushes captured speech into the input field and sends it, then leaves the
  /// listening state. Safe to call from several engine callbacks — it clears
  /// [_partialStt] on the first run so it can't double-send, and
  /// [_sendMessage] ignores an empty field.
  void _consumeVoiceInput() {
    if (!mounted || _voiceDispatched) return;
    final text = _partialStt.trim();
    if (text.isEmpty) {
      // Nothing captured yet — just leave the listening state; don't latch,
      // so a real result arriving later in this session still gets sent.
      if (_isListening) setState(() => _isListening = false);
      return;
    }
    _voiceDispatched = true;
    _partialStt = '';
    if (_isListening) setState(() => _isListening = false);
    _controller.text = text;
    _sendMessage();
  }

  void _showVoiceUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_tr(
          en: 'Microphone unavailable. Allow mic access in Settings to use voice input.',
          hi: 'माइक्रोफ़ोन उपलब्ध नहीं है। वॉइस इनपुट के लिए Settings में माइक की अनुमति दें।',
          zh: '麦克风不可用。请在设置中允许麦克风权限以使用语音输入。',
          ru: 'Микрофон недоступен. Разрешите доступ к микрофону в настройках для голосового ввода.',
          de: 'Mikrofon nicht verfügbar. Erlauben Sie den Mikrofonzugriff in den Einstellungen fuer die Spracheingabe.',
          si: 'මයික්‍රොෆෝනය නොමැත. හඬ ආදානය සඳහා Settings තුළ මයික් අවසරය දෙන්න.',
          ta: 'மைக்ரோஃபோன் கிடைக்கவில்லை. குரல் உள்ளீட்டைப் பயன்படுத்த Settings இல் மைக் அனுமதியை வழங்கவும்.',
        )),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _showVoiceError(String code) {
    if (!mounted) return;
    final unavailable = code == 'unavailable' || code == 'listen_failed';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(unavailable
            ? _tr(
                en: 'Voice input is unavailable on this device.',
                hi: 'इस डिवाइस पर वॉइस इनपुट उपलब्ध नहीं है।',
                zh: '此设备无法使用语音输入。',
                ru: 'Голосовой ввод недоступен на этом устройстве.',
                de: 'Spracheingabe ist auf diesem Geraet nicht verfuegbar.',
                si: 'මෙම උපාංගයේ හඬ ආදානය නොමැත.',
                ta: 'இந்த சாதனத்தில் குரல் உள்ளீடு கிடைக்கவில்லை.',
              )
            : _tr(
                en: "Didn't catch that — please try again or type your question.",
                hi: 'समझ नहीं आया — कृपया दोबारा बोलें या अपना प्रश्न टाइप करें।',
                zh: '没有听清 — 请重试或输入您的问题。',
                ru: 'Не расслышал — повторите или введите вопрос текстом.',
                de: 'Nicht verstanden — bitte erneut versuchen oder Frage eingeben.',
                si: 'තේරුම් ගත නොහැකි විය — නැවත උත්සාහ කරන්න හෝ ප්‍රශ්නය type කරන්න.',
                ta: 'கேட்கவில்லை — மீண்டும் முயற்சிக்கவும் அல்லது கேள்வியைத் தட்டச்சு செய்யவும்.',
              )),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _speakMessage(String text) {
    if (_voice.isSpeaking) {
      _voice.stopSpeaking();
    } else {
      _voice.speak(text, languageCode: _selectedLanguageCode);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Heritage Guide',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E1D0A), Color(0xFF8D4E1A)],
            ),
          ),
        ),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Auto-speak toggle
          IconButton(
            tooltip: _autoSpeak ? 'Mute voice' : 'Enable voice replies',
            icon: Icon(
              _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _autoSpeak ? AppTheme.secondary : Colors.white70,
            ),
            onPressed: () {
              setState(() => _autoSpeak = !_autoSpeak);
              if (!_autoSpeak) _voice.stopSpeaking();
            },
          ),
          // Language picker
          PopupMenuButton<String>(
            tooltip: 'Language',
            initialValue: _selectedLanguageCode,
            onSelected: _changeLanguage,
            icon: const Icon(Icons.translate_rounded, color: Colors.white),
            itemBuilder: (context) {
              return _languageLabels.entries
                  .map((entry) => PopupMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) return _buildTypingBubble();
                  final entry = _messages[index];
                  final isUser = entry.containsKey('user');
                  return _buildMessageBubble(entry.values.first, isUser);
                },
              ),
            ),
            // Listening indicator
            if (_isListening) _buildListeningOverlay(),
            _buildSuggestions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── Listening indicator ─────────────────────────────────────────────────
  Widget _buildListeningOverlay() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.08 + 0.06 * _pulseController.value),
                AppTheme.secondary.withOpacity(0.06 + 0.04 * _pulseController.value),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.secondary.withOpacity(0.3 + 0.3 * _pulseController.value),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.6 + 0.4 * _pulseController.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _partialStt.isNotEmpty
                      ? _partialStt
                      : _tr(
                          en: 'Listening… speak now',
                          hi: 'सुन रहा हूँ… अब बोलें',
                          zh: '正在聆听… 请说话',
                          ru: 'Слушаю… говорите',
                          de: 'Höre zu… sprechen Sie',
                          si: 'සවන් දෙමින්… දැන් කතා කරන්න',
                          ta: 'கேட்கிறேன்… இப்போது பேசுங்கள்',
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: _partialStt.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: const Color(0xFF4E342E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await _voice.cancelListening();
                  setState(() {
                    _isListening = false;
                    _partialStt = '';
                  });
                },
                child: const Icon(Icons.close, size: 20, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions().length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions()[i],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              onPressed: () => _sendSuggestedMessage(_suggestions()[i]),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          Flexible(
            child: GestureDetector(
              onLongPress: isUser ? null : () => _speakMessage(message),
              child: Container(
                margin: EdgeInsets.only(
                    left: isUser ? 50 : 8, right: isUser ? 8 : 50),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF4E342E),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    // Small speaker icon on bot messages
                    if (!isUser) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _speakMessage(message),
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 16,
                          color: AppTheme.primary.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  /// The "guide is typing" bubble — a bot-side bubble with three animated
  /// dots, shown while a reply is being prepared.
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(),
          Container(
            margin: const EdgeInsets.only(left: 8, right: 50),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.secondary, AppTheme.primary]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.3),
            blurRadius: 4, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
    );
  }

  Widget _buildUserAvatar() {
    return const CircleAvatar(
      backgroundColor: AppTheme.primary,
      radius: 18,
      child: Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mic button — always shown; a tap re-inits voice / re-requests the
          // mic permission when it isn't ready yet.
          GestureDetector(
            onTap: _isLoading ? null : _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _isListening ? Colors.redAccent : AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening
                      ? Colors.redAccent
                      : AppTheme.primary.withOpacity(0.25),
                ),
              ),
              child: Icon(
                _isListening
                    ? Icons.stop_rounded
                    : (_voiceReady ? Icons.mic_rounded : Icons.mic_off_rounded),
                color: _isListening
                    ? Colors.white
                    : (_voiceReady ? AppTheme.primary : Colors.grey),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _tr(
                    en: 'Ask your heritage guide...',
                    hi: 'अपने heritage guide से पूछें...',
                    zh: '向您的 heritage guide 提问...',
                    ru: 'Спросите вашего heritage guide...',
                    de: 'Fragen Sie Ihren heritage guide...',
                    si: 'ඔබගේ heritage guide ට ප්‍රශ්නයක් අහන්න...',
                    ta: 'உங்கள் heritage guide-ஐ கேளுங்கள்...',
                  ),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots that bounce and fade in a staggered wave — the classic
/// "someone is typing" affordance.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is 0.18 of the cycle behind the previous one.
            final phase = (_c.value + i * 0.18) % 1.0;
            // Triangle wave 0 → 1 → 0 across the cycle, then eased.
            final tri = (1 - (2 * phase - 1).abs()).clamp(0.0, 1.0);
            final hump = Curves.easeInOut.transform(tri);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, -4.0 * hump),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.35 + 0.55 * hump),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
