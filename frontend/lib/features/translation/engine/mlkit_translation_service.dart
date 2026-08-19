import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Lifecycle of a language's on-device ML Kit model, as shown to the UI.
enum ModelDownloadState {
  /// Not checked yet.
  unknown,

  /// ML Kit has no model for this language (e.g. Sinhala) — the app still
  /// translates it, just via the offline heritage dictionary instead.
  notSupported,

  /// Actively downloading the ~25-30MB language pack right now.
  downloading,

  /// Confirmed present on device — translations for this language run
  /// fully offline with no further download.
  ready,

  /// Download attempted and failed (e.g. no storage). Word/dictionary-level
  /// translation still works as a fallback.
  failed,
}

/// Wraps Google ML Kit on-device translation with model download management.
///
/// Used as Layer 2 fallback when heritage KB and phrase matcher miss.
/// Note: ML Kit does not support Sinhala (`si`); those pairs fall through safely to offline dictionary.
class MlKitTranslationService {
  MlKitTranslationService._();
  static final MlKitTranslationService instance = MlKitTranslationService._();

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  final Map<String, OnDeviceTranslator> _translators = {};
  final Set<String> _downloadedModels = {};

  // ── Download status, broadcast so any screen can show a live, honest
  // "downloading / ready / not needed" indicator instead of guessing. ──────
  final Map<String, ModelDownloadState> _status = {};
  final StreamController<Map<String, ModelDownloadState>> _statusController =
      StreamController<Map<String, ModelDownloadState>>.broadcast();

  /// Emits the full status map every time any language's state changes.
  Stream<Map<String, ModelDownloadState>> get statusStream =>
      _statusController.stream;

  /// Current status snapshot — use as StreamBuilder initialData.
  Map<String, ModelDownloadState> get statusSnapshot =>
      Map.unmodifiable(_status);

  ModelDownloadState statusFor(String code) =>
      _status[code] ?? ModelDownloadState.unknown;

  void _setStatus(String code, ModelDownloadState state) {
    if (_status[code] == state) return;
    _status[code] = state;
    if (!_statusController.isClosed) {
      _statusController.add(Map.unmodifiable(_status));
    }
  }

  /// Returns true when both languages are supported by ML Kit.
  bool isPairSupported(String sourceCode, String targetCode) {
    if (sourceCode == targetCode) return false;
    return _toTranslateLanguage(sourceCode) != null &&
        _toTranslateLanguage(targetCode) != null;
  }

  /// Best-effort, non-blocking check of whether [code]'s model is already
  /// on device. Checks the in-memory cache first (instant), then falls back
  /// to asking the platform.
  Future<bool> isModelReady(String code) async {
    if (_downloadedModels.contains(code)) return true;
    final lang = _toTranslateLanguage(code);
    if (lang == null) return false;
    try {
      final ready = await _modelManager
          .isModelDownloaded(lang.bcpCode)
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (ready) {
        _downloadedModels.add(code);
        _setStatus(code, ModelDownloadState.ready);
      }
      return ready;
    } catch (_) {
      return false;
    }
  }

  /// Downloads language packs for the given pair (Wi‑Fi not required),
  /// updating [statusStream] as each side progresses.
  Future<void> ensureModels(String sourceCode, String targetCode) async {
    if (!isPairSupported(sourceCode, targetCode)) {
      _setStatus(targetCode, ModelDownloadState.notSupported);
      return;
    }

    for (final code in [sourceCode, targetCode]) {
      if (_downloadedModels.contains(code)) {
        _setStatus(code, ModelDownloadState.ready);
        continue;
      }

      final lang = _toTranslateLanguage(code);
      if (lang == null) {
        _setStatus(code, ModelDownloadState.notSupported);
        continue;
      }

      final bcp = lang.bcpCode;
      _setStatus(code, ModelDownloadState.downloading);
      try {
        var ready = await _modelManager
            .isModelDownloaded(bcp)
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
        if (!ready) {
          // Language model packs are ~25-30MB; a short timeout here used to
          // silently "succeed" on timeout and mark the model as downloaded
          // even though nothing was fetched, permanently skipping the real
          // download for the rest of the app session. Give it real time to
          // finish, and only mark it done if it actually is.
          await _modelManager
              .downloadModel(bcp, isWifiRequired: false)
              .timeout(const Duration(seconds: 60), onTimeout: () => false);
          ready = await _modelManager
              .isModelDownloaded(bcp)
              .timeout(const Duration(seconds: 2), onTimeout: () => false);
        }
        if (ready) {
          _downloadedModels.add(code);
          _setStatus(code, ModelDownloadState.ready);
        } else {
          _setStatus(code, ModelDownloadState.failed);
        }
      } catch (e) {
        debugPrint('ML Kit ensureModels notice ($code): $e');
        _setStatus(code, ModelDownloadState.failed);
      }
    }
  }

  /// Downloads every language in [targetCodes] against [pivot], one at a
  /// time (sequential on purpose — parallel downloads would fight each
  /// other for bandwidth/CPU on first launch). Meant to be called once,
  /// fire-and-forget, right after the app starts, so models are already
  /// on-device by the time the user opens the AR translator instead of
  /// downloading silently on first use.
  Future<void> preloadLanguages(
    List<String> targetCodes, {
    String pivot = 'en',
  }) async {
    for (final code in targetCodes) {
      if (code == pivot) continue;
      try {
        await ensureModels(pivot, code);
      } catch (e) {
        debugPrint('ML Kit preload notice ($code): $e');
        _setStatus(code, ModelDownloadState.failed);
      }
    }
  }

  /// Translates [text] offline. Returns null if unsupported or on failure.
  Future<String?> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final source = _toTranslateLanguage(sourceLanguage);
    final target = _toTranslateLanguage(targetLanguage);
    if (source == null || target == null) return null;

    try {
      await ensureModels(sourceLanguage, targetLanguage).timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      final pairKey = '${source.bcpCode}_${target.bcpCode}';
      final translator = _translators.putIfAbsent(
        pairKey,
        () => OnDeviceTranslator(
          sourceLanguage: source,
          targetLanguage: target,
        ),
      );

      final result = await translator.translateText(trimmed).timeout(
            const Duration(seconds: 3),
            onTimeout: () => '',
          );
      if (result.trim().isEmpty || result.trim() == trimmed) return null;
      return result;
    } catch (e, st) {
      debugPrint('MlKitTranslationService error: $e\n$st');
      return null;
    }
  }

  TranslateLanguage? _toTranslateLanguage(String code) {
    for (final lang in TranslateLanguage.values) {
      if (lang.bcpCode == code) return lang;
    }
    return null;
  }

  Future<void> dispose() async {
    for (final translator in _translators.values) {
      try {
        await translator.close();
      } catch (_) {}
    }
    _translators.clear();
    _downloadedModels.clear();
  }
}
