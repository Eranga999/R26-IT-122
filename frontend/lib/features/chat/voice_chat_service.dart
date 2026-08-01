import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Fully-offline voice chat service.
///
/// **STT** – uses the device's built-in speech recognition engine
/// (Google on Android, Apple on iOS). Works offline when the user has
/// downloaded the relevant language pack in their device settings.
///
/// **TTS** – uses the device's built-in text-to-speech engine.
/// Also fully offline when language data is installed on the device.
class VoiceChatService {
  VoiceChatService._();

  static final VoiceChatService instance = VoiceChatService._();

  // ── STT ──────────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttInitialized = false;

  // ── TTS ──────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;
  bool _isSpeaking = false;

  /// Whether the TTS engine is currently speaking.
  bool get isSpeaking => _isSpeaking;

  // ── Language-to-locale mapping ───────────────────────────────────────────
  // Maps the app's language codes to BCP-47 locale strings expected by
  // the Android / iOS speech engines.
  static const Map<String, String> _localeMap = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'zh': 'zh-CN',
    'ru': 'ru-RU',
    'de': 'de-DE',
    'si': 'si-LK',
    'ta': 'ta-IN',
  };

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initializes STT. Returns `true` if speech recognition is available.
  Future<bool> initStt() async {
    if (_sttInitialized) return true;
    try {
      _sttInitialized = await _stt.initialize(
        onError: (error) => debugPrint('[VoiceChat] STT error: $error'),
        onStatus: (status) => debugPrint('[VoiceChat] STT status: $status'),
      );
    } catch (e) {
      debugPrint('[VoiceChat] STT init failed: $e');
      _sttInitialized = false;
    }
    return _sttInitialized;
  }

  /// Initializes TTS with sensible defaults.
  Future<void> initTts() async {
    if (_ttsInitialized) return;
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[VoiceChat] TTS error: $msg');
      });

      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[VoiceChat] TTS init failed: $e');
    }
  }

  /// Convenience: initialize both engines.
  Future<bool> init() async {
    final results = await Future.wait([initStt(), initTts().then((_) => true)]);
    return results[0]; // return STT availability
  }

  // ── STT helpers ─────────────────────────────────────────────────────────

  bool get isSttAvailable => _sttInitialized;
  bool get isListening => _stt.isListening;

  /// Starts listening with on-device recognition requested.
  ///
  /// [onResult] fires on every partial / final result.
  /// [languageCode] should be one of the app's 7 supported codes.
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    required String languageCode,
  }) async {
    if (!_sttInitialized) {
      final ok = await initStt();
      if (!ok) return;
    }

    final localeId = _localeMap[languageCode] ?? 'en-US';
    await _stt.listen(
      onResult: onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        onDevice: true, // request offline / on-device recognition
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// Stops listening.
  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  /// Cancels listening without processing the result.
  Future<void> cancelListening() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }

  // ── TTS helpers ─────────────────────────────────────────────────────────

  /// Speaks [text] in the given [languageCode].
  Future<void> speak(String text, {String languageCode = 'en'}) async {
    if (!_ttsInitialized) await initTts();

    // Strip emojis for cleaner speech output
    final cleaned = text.replaceAll(RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
        r'\u{1F1E0}-\u{1F1FF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}'
        r'\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}'
        r'\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}'
        r'\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
        unicode: true), '');

    final locale = _localeMap[languageCode] ?? 'en-US';
    await _tts.setLanguage(locale);
    await _tts.speak(cleaned);
  }

  /// Stops TTS playback immediately.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}
