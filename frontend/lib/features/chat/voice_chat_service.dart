import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Offline-first voice chat service.
///
/// **STT** – uses the device's built-in speech recognition engine
/// (Google on Android, Apple on iOS). It prefers the on-device model and
/// only reaches the network engine when the device has no offline pack
/// for the requested language.
///
/// **TTS** – uses the device's built-in text-to-speech engine.
/// Fully offline when the language voice data is installed on the device.
class VoiceChatService {
  VoiceChatService._();

  static final VoiceChatService instance = VoiceChatService._();

  // ── STT ──────────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttInitialized = false;

  // Callbacks for the currently active listen session (re-set on every
  // startListening call, cleared on dispose). Routed here from the single
  // initialize()-time handlers so the UI can always react to status / errors.
  void Function(SpeechRecognitionResult result)? _onResult;
  void Function(String status)? _onStatus;
  void Function(String errorMsg)? _onError;

  // ── TTS ──────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;
  bool _isSpeaking = false;

  /// Whether the TTS engine is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Whether a listen session is currently active.
  bool get isListening => _stt.isListening;

  /// Whether STT initialised successfully (engine present + permission granted).
  bool get isSttAvailable => _sttInitialized;

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
        onError: _handleSttError,
        onStatus: _handleSttStatus,
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
      // Makes speak() resolve only once playback finishes and keeps the
      // start / completion handlers reliable on Android.
      await _tts.awaitSpeakCompletion(true);
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

  // ── STT event routing ───────────────────────────────────────────────────

  void _handleSttStatus(String status) {
    debugPrint('[VoiceChat] STT status: $status');
    _onStatus?.call(status);
  }

  void _handleSttError(SpeechRecognitionError error) {
    debugPrint('[VoiceChat] STT error: ${error.errorMsg} '
        '(permanent=${error.permanent})');
    _onError?.call(error.errorMsg);
  }

  // ── STT control ─────────────────────────────────────────────────────────

  /// Starts listening with on-device recognition preferred.
  ///
  /// [onResult] fires on every partial / final result.
  /// [onStatus] fires on engine lifecycle changes ('listening', 'notListening',
  /// 'done') so the caller can always leave the "listening" UI state.
  /// [onError] fires with the raw plugin error code on failure.
  /// [languageCode] should be one of the app's 7 supported codes.
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    required String languageCode,
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
  }) async {
    if (!_sttInitialized) {
      final ok = await initStt();
      if (!ok) {
        onError?.call('unavailable');
        return;
      }
    }

    _onResult = onResult;
    _onStatus = onStatus;
    _onError = onError;

    final localeId = _localeMap[languageCode] ?? 'en-US';
    try {
      await _stt.listen(
        onResult: (r) => _onResult?.call(r),
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 4),
          // NOTE: intentionally NOT on-device-only. `onDevice: true` makes the
          // whole attempt fail on any device without the offline pack for this
          // locale (most non-English locales, sometimes English too), which
          // silently broke voice input. With this off the engine still uses
          // the on-device model whenever it is installed and only falls back
          // to the network engine when it is not.
          onDevice: false,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[VoiceChat] listen() failed: $e');
      _onError?.call('listen_failed');
    }
  }

  /// Stops listening (processes and yields a final result if available).
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
    if (cleaned.trim().isEmpty) return;

    // Fall back to English if the requested voice isn't installed, otherwise
    // setLanguage() throws / speak() silently does nothing.
    final preferred = _localeMap[languageCode] ?? 'en-US';
    var locale = preferred;
    try {
      final available = await _tts.isLanguageAvailable(preferred);
      if (available != true && available != 1) locale = 'en-US';
    } catch (_) {
      locale = 'en-US';
    }

    await _tts.stop(); // never overlap two utterances
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
    await cancelListening();
    await stopSpeaking();
    // Drop references to the (now disposed) screen's callbacks so a late
    // engine event can't call into dead State.
    _onResult = null;
    _onStatus = null;
    _onError = null;
  }
}
