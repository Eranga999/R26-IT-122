import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/theme/app_theme.dart';
import '../translation/engine/offline_translation_engine.dart';
import '../translation/engine/mlkit_translation_service.dart';
import '../translation/models/translation_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AR Translator Screen — Google Lens-style in-place text translation
// ─────────────────────────────────────────────────────────────────────────────

class ArTranslatorScreen extends StatefulWidget {
  const ArTranslatorScreen({super.key});

  @override
  State<ArTranslatorScreen> createState() => _ArTranslatorScreenState();
}

class _ArTranslatorScreenState extends State<ArTranslatorScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isFrozen = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  Timer? _captureWatchdog;
  String? _frozenImagePath;

  // ── OCR / Translation ───────────────────────────────────────────────────────
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final OfflineTranslationEngine _translationEngine =
      OfflineTranslationEngine.instance;

  List<_TranslatedBlock> _translatedBlocks = [];
  int? _selectedBlockIndex;
  String _targetLanguageCode = 'si';

  // Bumped every time the in-flight capture/translate should be abandoned
  // (e.g. user hits Cancel). Async steps check their captured token against
  // this before applying results, so a cancelled run can no longer resurrect
  // the frozen/translating UI after the fact.
  int _captureToken = 0;

  // Scripts whose glyphs need extra line-height and don't have a true bold
  // weight everywhere — rendering them with Latin defaults (tight
  // line-height, forced synthetic bold) is what made Hindi/Tamil/Sinhala/
  // Chinese text look clipped and smudged instead of clean.
  static const _complexScripts = {'hi', 'ta', 'si', 'zh'};
  bool _isComplexScript(String langCode) => _complexScripts.contains(langCode);

  static final RegExp _nonLatinPattern = RegExp(
    r'[ऀ-ॿ஀-௿඀-෿一-鿿]',
  );
  bool _looksNonLatin(String text) => _nonLatinPattern.hasMatch(text);

  // ── Coordinate mapping ──────────────────────────────────────────────────────
  Size _cameraImageSize = Size.zero;
  int _sensorOrientation = 0;

  // ── Box smoothing ────────────────────────────────────────────────────────────
  final Map<String, Rect> _smoothedBoxes = {};
  static const double _boxAlpha = 0.4;

  // ── Scan-line animation ─────────────────────────────────────────────────────
  late final AnimationController _scanAnim;

  // ── Overlay fade ─────────────────────────────────────────────────────────────
  double _overlayOpacity = 0.0;

  final Map<String, String> _supportedLanguages = {
    'si': 'සිංහල',
    'ta': 'தமிழ்',
    'en': 'English',
    'hi': 'हिंदी',
    'zh': '中文',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  // ─── Language full names for the picker ─────────────────────────────────────
  final Map<String, String> _languageFullNames = {
    'si': 'සිංහල (Sinhala)',
    'ta': 'தமிழ் (Tamil)',
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'zh': '中文 (Chinese)',
    'es': 'Español (Spanish)',
    'fr': 'Français (French)',
    'de': 'Deutsch (German)',
  };

  // ─────────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _translationEngine.initialize().then((_) {
        _translationEngine.preloadMlKitModels(_targetLanguageCode);
      });
    });

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      c.pausePreview().catchError((_) {});
    } else if (state == AppLifecycleState.resumed && !_isFrozen) {
      c.resumePreview().catchError((_) {});
    }
  }

  @override
  void deactivate() {
    _controller?.pausePreview().catchError((_) {});
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (!_isFrozen) _controller?.resumePreview().catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnim.dispose();
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) {
        c.stopImageStream().whenComplete(c.dispose);
      } else {
        c.dispose();
      }
    }
    _textRecognizer.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Camera init
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        Platform.isAndroid ? ResolutionPreset.low : ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      _sensorOrientation = _controller!.description.sensorOrientation;
      final preview = _controller!.value.previewSize;
      if (preview != null) {
        final isRotated90 =
            _sensorOrientation == 90 || _sensorOrientation == 270;
        _cameraImageSize = Size(
          isRotated90 ? preview.height : preview.width,
          isRotated90 ? preview.width : preview.height,
        );
      }

      setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Effective sizes
  // ─────────────────────────────────────────────────────────────────────────────

  Size? get _effectivePreviewSize {
    if (_isFrozen && _cameraImageSize != Size.zero) return _cameraImageSize;
    return _controller?.value.previewSize;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Language change
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _onLanguageChanged(String? langCode) async {
    if (langCode == null || langCode == _targetLanguageCode) return;
    setState(() => _targetLanguageCode = langCode);
    // MlKitTranslationService.statusStream (subscribed in the top bar and
    // language picker below) reflects this in real time — the app also
    // kicks this off for every supported language at startup in main.dart,
    // so most of the time this call finds the model already downloaded.
    _translationEngine.preloadMlKitModels(langCode);

    if (_translatedBlocks.isNotEmpty) {
      // Re-translate all blocks in parallel
      final results = await Future.wait(
        _translatedBlocks.map((b) async {
          final r = await _translationEngine
              .translate(
                rawInput: b.result.inputText,
                targetLanguage: _targetLanguageCode,
              )
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => TranslationResult.unsupported(
                  inputText: b.result.inputText,
                  normalizedText: b.result.inputText,
                  sourceLanguage: 'unknown',
                  targetLanguage: _targetLanguageCode,
                ),
              );
          return _TranslatedBlock(
            id: b.id,
            boundingBox: b.boundingBox,
            result: r,
            isNormalized: b.isNormalized,
          );
        }),
      );
      if (mounted) setState(() => _translatedBlocks = results);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Capture & translate
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _captureAndTranslate() async {
    if (_controller == null ||
        !_isCameraReady ||
        _isCapturing ||
        _isProcessing) {
      return;
    }

    // Stop the scan-line ticker — it was still animating every frame during
    // capture/translation, competing with that work for the same frame
    // budget right when it's most needed.
    _scanAnim.stop();

    // Snapshot the token: if the user cancels while this run is still in
    // flight, _resumeLiveScan() bumps _captureToken and every check below
    // starts failing, so the cancelled run's late results never get applied.
    final myToken = ++_captureToken;

    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _selectedBlockIndex = null;
      _overlayOpacity = 0.0;
    });

    // Watchdog: force-reset if the whole process takes too long
    _captureWatchdog?.cancel();
    _captureWatchdog = Timer(const Duration(seconds: 20), () {
      debugPrint('Capture watchdog fired — forcing reset');
      _resumeLiveScan();
    });

    try {
      final photo = await _controller!.takePicture().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Camera capture timed out'),
          );
      _smoothedBoxes.clear();

      if (!mounted || myToken != _captureToken) return;

      setState(() {
        _isFrozen = true;
        _frozenImagePath = photo.path;
        _sensorOrientation = 0;
      });
      await _controller!.pausePreview().catchError((e) {
        debugPrint('pausePreview notice: $e');
      });

      final bytes = await File(photo.path).readAsBytes();
      Size? imageSize = _jpegDimensions(bytes);
      if (imageSize == null) {
        try {
          final decoded = await decodeImageFromList(bytes);
          imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
        } catch (_) {}
      }
      if (imageSize != null && imageSize != Size.zero) {
        _cameraImageSize = imageSize;
      }

      final inputImage = InputImage.fromFilePath(photo.path);

      // NOTE: SinhalaOcrEngine is currently a placeholder that always
      // returns an empty result (real glyph-model recognition isn't wired
      // up yet — see its class doc). Calling it here used to cost a second
      // full read of the captured photo file plus a JSON asset parse on
      // every single capture for zero benefit, adding to the post-shutter
      // lag. Skipped until real Sinhala OCR is implemented.
      final combinedRecognizedText = await _textRecognizer
          .processImage(inputImage)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => RecognizedText(text: '', blocks: []),
          );

      if (!mounted || myToken != _captureToken) return;

      await _applyRecognizedText(
        combinedRecognizedText,
        maxBlocks: 8,
        cancelToken: myToken,
      );

      if (myToken != _captureToken) return;

      // Fade in the overlay after translation is done
      if (mounted) {
        setState(() => _overlayOpacity = 1.0);
        if (_translatedBlocks.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No text detected in this photo. Aim closer at signs or text.'),
              backgroundColor: Color(0xFF2A1A08),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('Capture error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not capture frame. Try again: ${e.toString().split('\n').first}'),
            backgroundColor: const Color(0xFF1A0A00),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (myToken == _captureToken) await _resumeLiveScan();
    } finally {
      _captureWatchdog?.cancel();
      _captureWatchdog = null;
      // Only clear the busy flags if this is still the active run — a
      // cancelled run's finally block must not stomp on a newer one.
      if (myToken == _captureToken) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _isProcessing = false;
          });
        } else {
          _isCapturing = false;
          _isProcessing = false;
        }
      }
    }
  }

  // Signboards occasionally contain a full paragraph of text. Translating
  // (and later laying out / painting) hundreds of characters per block is
  // what made captures of long text feel laggy — cap each candidate so the
  // OCR→translate→paint pipeline stays bounded regardless of how much text
  // was on the sign. The AR overlay only ever shows 3 lines anyway.
  static const int _maxCandidateChars = 240;

  String _capText(String text) => text.length > _maxCandidateChars
      ? text.substring(0, _maxCandidateChars)
      : text;

  Future<void> _applyRecognizedText(
    RecognizedText recognizedText, {
    int? maxBlocks,
    int? cancelToken,
  }) async {
    // Flatten every recognized line, ignoring which ML Kit "block" it was
    // grouped into — ML Kit frequently splits one visual paragraph into
    // several blocks (different font weights, a line with slightly more
    // spacing, etc.), which was exactly why one signboard paragraph used to
    // show up as many small overlapping boxes. Clustering below regroups
    // lines by actual on-screen layout instead of trusting ML Kit's block
    // boundaries, so a paragraph becomes one box with one translation.
    final lines = <({String text, Rect box})>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final lineText = line.text.trim();
        if (lineText.length < 2) continue;
        lines.add((text: lineText, box: line.boundingBox));
      }
    }

    final candidates = _clusterLinesIntoParagraphs(lines, maxBlocks: maxBlocks)
        .map((c) => (text: _capText(c.text), box: c.box))
        .toList();

    if (candidates.isEmpty) {
      if (mounted && (cancelToken == null || cancelToken == _captureToken)) {
        setState(() {
          _translatedBlocks = [];
          _selectedBlockIndex = null;
        });
      }
      return;
    }

    // ML Kit sometimes emits multiple overlapping blocks/lines for the same
    // physical text (e.g. a block plus a near-duplicate line region), which
    // used to render as stacked, unreadable ghost boxes on screen. Keep only
    // the longest candidate among any set of significantly overlapping ones.
    final dedupedCandidates = _dedupeOverlappingCandidates(candidates);

    // Translate all candidates in parallel with per-call timeout
    final results = await Future.wait(
      dedupedCandidates.map((c) async {
        try {
          final result = await _translationEngine
              .translate(
                rawInput: c.text,
                targetLanguage: _targetLanguageCode,
              )
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => TranslationResult.unsupported(
                  inputText: c.text,
                  normalizedText: c.text,
                  sourceLanguage: 'unknown',
                  targetLanguage: _targetLanguageCode,
                ),
              );
          return (text: c.text, box: c.box, result: result);
        } catch (_) {
          return (
            text: c.text,
            box: c.box,
            result: TranslationResult.unsupported(
              inputText: c.text,
              normalizedText: c.text,
              sourceLanguage: 'unknown',
              targetLanguage: _targetLanguageCode,
            ),
          );
        }
      }),
    );

    final List<_TranslatedBlock> newBlocks = [];
    for (final r in results) {
      if (r.result.translatedText.isNotEmpty &&
          r.result.status != TranslationStatus.empty) {
        final id = _blockId(r.text, r.box);
        newBlocks.add(_TranslatedBlock(
          id: id,
          boundingBox: _smoothBox(id, r.box),
          result: r.result,
        ));
      }
    }

    final activeIds = newBlocks.map((b) => b.id).toSet();
    _smoothedBoxes.removeWhere((k, _) => !activeIds.contains(k));

    if (mounted && (cancelToken == null || cancelToken == _captureToken)) {
      setState(() {
        _translatedBlocks = newBlocks;
        if (_selectedBlockIndex != null &&
            _selectedBlockIndex! >= newBlocks.length) {
          _selectedBlockIndex = null;
        }
      });
    }
  }

  Future<void> _resumeLiveScan() async {
    // Invalidate any capture/translate work still in flight (this is what
    // makes the Cancel button actually cancel — without it, a translation
    // that finishes after Cancel was tapped would setState() and silently
    // re-show the frozen/translated screen).
    _captureToken++;
    _captureWatchdog?.cancel();
    _captureWatchdog = null;
    if (!mounted) return;
    setState(() {
      _isFrozen = false;
      _frozenImagePath = null;
      _translatedBlocks = [];
      _selectedBlockIndex = null;
      _isCapturing = false;
      _isProcessing = false;
      _overlayOpacity = 0.0;
      _smoothedBoxes.clear();
    });
    _scanAnim.repeat();
    try {
      await _controller?.resumePreview();
    } catch (e) {
      debugPrint('Resume preview error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  String _blockId(String text, Rect box) =>
      '${text.hashCode}_${box.left.toInt()}_${box.top.toInt()}';

  /// Groups OCR lines into paragraph-shaped clusters by actual layout
  /// (vertical adjacency + horizontal overlap) rather than by ML Kit's own
  /// block boundaries, then merges each cluster into a single candidate
  /// (concatenated text, union bounding box). This is what turns "one
  /// paragraph → five small boxes" into "one paragraph → one box".
  List<({String text, Rect box})> _clusterLinesIntoParagraphs(
    List<({String text, Rect box})> lines, {
    int? maxBlocks,
  }) {
    if (lines.isEmpty) return const [];

    final sorted = [...lines]..sort((a, b) => a.box.top.compareTo(b.box.top));
    final clusters = <List<({String text, Rect box})>>[];

    for (final line in sorted) {
      List<({String text, Rect box})>? target;
      for (final cluster in clusters) {
        final last = cluster.last;
        final verticalGap = line.box.top - last.box.bottom;
        final lineHeight = math.max(last.box.height, line.box.height);

        final overlapLeft = math.max(last.box.left, line.box.left);
        final overlapRight = math.min(last.box.right, line.box.right);
        final horizontalOverlap = math.max(0.0, overlapRight - overlapLeft);
        final minWidth = math.min(last.box.width, line.box.width);
        final overlapRatio = minWidth > 0 ? horizontalOverlap / minWidth : 0.0;

        // Same paragraph if the next line starts close beneath this one
        // (allowing for normal line spacing) and the two lines line up
        // horizontally (same column of text, not an unrelated label off
        // to the side).
        if (verticalGap < lineHeight * 0.9 && overlapRatio > 0.35) {
          target = cluster;
          break;
        }
      }
      if (target != null) {
        target.add(line);
      } else {
        clusters.add([line]);
      }
    }

    final merged = clusters.map((cluster) {
      final text = cluster.map((l) => l.text).join(' ');
      var box = cluster.first.box;
      for (final l in cluster.skip(1)) {
        box = box.expandToInclude(l.box);
      }
      return (text: text, box: box);
    }).toList();

    // Keep the most substantial paragraphs if capped — a partial word
    // fragment shouldn't bump a full sentence off the list.
    merged.sort((a, b) => b.text.length.compareTo(a.text.length));
    if (maxBlocks != null && merged.length > maxBlocks) {
      return merged.sublist(0, maxBlocks);
    }
    return merged;
  }

  List<({String text, Rect box})> _dedupeOverlappingCandidates(
      List<({String text, Rect box})> candidates) {
    final sorted = [...candidates]
      ..sort((a, b) => b.text.length.compareTo(a.text.length));
    final kept = <({String text, Rect box})>[];
    for (final c in sorted) {
      final overlapsKept = kept.any((k) => _iou(c.box, k.box) > 0.4);
      if (!overlapsKept) kept.add(c);
    }
    return kept;
  }

  double _iou(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final interArea = intersection.width * intersection.height;
    final unionArea = a.width * a.height + b.width * b.height - interArea;
    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  Rect _smoothBox(String id, Rect raw) {
    final prev = _smoothedBoxes[id];
    if (prev == null) {
      _smoothedBoxes[id] = raw;
      return raw;
    }
    final s = Rect.fromLTRB(
      prev.left * (1 - _boxAlpha) + raw.left * _boxAlpha,
      prev.top * (1 - _boxAlpha) + raw.top * _boxAlpha,
      prev.right * (1 - _boxAlpha) + raw.right * _boxAlpha,
      prev.bottom * (1 - _boxAlpha) + raw.bottom * _boxAlpha,
    );
    _smoothedBoxes[id] = s;
    return s;
  }

  Size? _jpegDimensions(Uint8List bytes) {
    if (bytes.length < 10 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    var i = 2;
    while (i + 8 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
        return null;
      }
      if (i + 3 >= bytes.length) break;
      final segmentLen = (bytes[i + 2] << 8) | bytes[i + 3];
      if (segmentLen < 2) break;
      i += 2 + segmentLen;
    }
    return null;
  }

  TextDirection _textDirectionFor(String langCode) {
    return langCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }

  void _onOverlayTap(TapUpDetails details, Size widgetSize) {
    if (_translatedBlocks.isEmpty) return;
    final previewSize = _effectivePreviewSize;
    if (previewSize == null || _cameraImageSize == Size.zero) return;

    for (var i = 0; i < _translatedBlocks.length; i++) {
      final screenRect = _OcrOverlayMapper.mapPixelRectToWidget(
        pixelRect: _translatedBlocks[i].boundingBox,
        cameraImageSize: _cameraImageSize,
        previewSize: previewSize,
        sensorOrientation: _sensorOrientation,
        widgetSize: widgetSize,
        isNormalized: _translatedBlocks[i].isNormalized,
      );
      if (screenRect.contains(details.localPosition)) {
        setState(() => _selectedBlockIndex = i);
        return;
      }
    }
    setState(() => _selectedBlockIndex = null);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Camera / frozen frame ─────────────────────────────────────────
          if (_isFrozen && _frozenImagePath != null)
            Positioned.fill(
              // RepaintBoundary isolates the (larger, static) frozen photo
              // from the overlay/detail-card repaints happening above it.
              child: RepaintBoundary(
                child: Image.file(
                  File(_frozenImagePath!),
                  fit: BoxFit.cover,
                  // Decode at roughly screen resolution instead of full
                  // camera-sensor resolution — displaying an undecoded
                  // multi-megapixel JPEG at full size was a real source of
                  // jank on lower-end devices during the freeze/translate
                  // step.
                  cacheWidth: (screenSize.width * devicePixelRatio).round(),
                ),
              ),
            )
          else if (_isCameraReady && _controller != null)
            Positioned.fill(
              child: RepaintBoundary(child: CameraPreview(_controller!)),
            )
          else
            _buildCameraPlaceholder(),

          // ── 2. Animated scan line (live mode only) ───────────────────────────
          if (!_isFrozen && _isCameraReady && !_isCapturing)
            _buildScanLine(screenSize),

          // ── 3. Capture overlay ───────────────────────────────────────────────
          if (_isCapturing) _buildCapturingOverlay(),

          // ── 4. AR translation overlay (Google Lens-style) ───────────────────
          if (_translatedBlocks.isNotEmpty)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _overlayOpacity,
                duration: const Duration(milliseconds: 400),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) => _onOverlayTap(d, screenSize),
                  child: CustomPaint(
                    painter: _GoogleLensArTextPainter(
                      blocks: _translatedBlocks,
                      cameraImageSize: _cameraImageSize,
                      previewSize: _effectivePreviewSize,
                      sensorOrientation: _sensorOrientation,
                      widgetSize: screenSize,
                      targetLang: _targetLanguageCode,
                      selectedIndex: _selectedBlockIndex,
                      textDirection: _textDirectionFor(_targetLanguageCode),
                      topInset: MediaQuery.of(context).padding.top + 96,
                      bottomInset: _isFrozen ? 132.0 : 178.0,
                    ),
                  ),
                ),
              ),
            ),

          // ── 5. Top app bar ───────────────────────────────────────────────────
          _buildTopBar(),

          // ── 6. Bottom controls ───────────────────────────────────────────────
          _buildBottomBar(screenSize),

          // ── 7. Detail card ───────────────────────────────────────────────────
          // Painted last (on top of the bottom bar) so its content can never
          // end up hidden underneath the bottom bar's gradient/buttons — that
          // stacking order was why the box could look like it was "under the
          // screen" until something else forced a repaint.
          if (_selectedBlockIndex != null &&
              _selectedBlockIndex! < _translatedBlocks.length)
            _buildDetailCard(
                _translatedBlocks[_selectedBlockIndex!], screenSize),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  UI sub-widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCameraPlaceholder() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B0800),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing camera…',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanLine(Size screenSize) {
    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (_, __) {
        final t = _scanAnim.value;
        final y = screenSize.height * t;
        return Positioned(
          left: 0,
          right: 0,
          top: y - 1,
          child: IgnorePointer(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFFFB300).withValues(alpha: 0.0),
                    const Color(0xFFFFB300).withValues(alpha: 0.85),
                    const Color(0xFFFFE082).withValues(alpha: 0.95),
                    const Color(0xFFFFB300).withValues(alpha: 0.85),
                    const Color(0xFFFFB300).withValues(alpha: 0.0),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCapturingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isFrozen ? 'Translating text…' : 'Scanning…',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Recognising and translating text',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              // Cancel button
              GestureDetector(
                onTap: _resumeLiveScan,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    // Subscribing here — instead of duplicating per-language download state
    // on this screen — means the header always reflects what
    // MlKitTranslationService is actually doing (including the app-startup
    // preload in main.dart), never a stale local guess.
    return StreamBuilder<Map<String, ModelDownloadState>>(
      stream: MlKitTranslationService.instance.statusStream,
      initialData: MlKitTranslationService.instance.statusSnapshot,
      builder: (context, snapshot) {
        final status =
            snapshot.data?[_targetLanguageCode] ?? ModelDownloadState.unknown;
        final languageName =
            _supportedLanguages[_targetLanguageCode] ?? _targetLanguageCode;
        final isDownloading =
            !_isFrozen && status == ModelDownloadState.downloading;

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding:
                const EdgeInsets.only(top: 52, left: 8, right: 12, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.88),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Back button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.translate_rounded,
                              color: Color(0xFFFFB300), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _isFrozen ? 'Translation Result' : 'AR Translator',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isDownloading) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFFFFD54F),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              isDownloading
                                  ? 'Downloading $languageName pack for offline use…'
                                  : _isFrozen
                                      ? '${_translatedBlocks.length} block${_translatedBlocks.length == 1 ? '' : 's'} found — tap to inspect'
                                      : 'Point at text, then tap the shutter',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFFFD54F), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Language chip
                _buildLanguageChip(status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageChip(ModelDownloadState status) {
    final supportsMlKit =
        MlKitTranslationService.instance.isPairSupported('en', _targetLanguageCode);

    // A real label instead of a color dot — the whole point is that a
    // glance answers "is this language ready to use offline right now?".
    final (String badgeLabel, Color badgeColor, Widget badgeIcon) =
        !supportsMlKit
            ? (
                'Built-in dictionary',
                Colors.white54,
                const Icon(Icons.menu_book_rounded,
                    size: 11, color: Colors.white54),
              )
            : switch (status) {
                ModelDownloadState.downloading => (
                    'Downloading…',
                    const Color(0xFFFFD54F),
                    const SizedBox(
                      width: 9,
                      height: 9,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Color(0xFFFFD54F)),
                    ),
                  ),
                ModelDownloadState.ready => (
                    'Offline ready',
                    const Color(0xFF66BB6A),
                    const Icon(Icons.cloud_done_rounded,
                        size: 11, color: Color(0xFF66BB6A)),
                  ),
                ModelDownloadState.failed => (
                    'Download failed — using dictionary',
                    const Color(0xFFEF5350),
                    const Icon(Icons.error_outline_rounded,
                        size: 11, color: Color(0xFFEF5350)),
                  ),
                _ => (
                    'Checking…',
                    Colors.white54,
                    const Icon(Icons.cloud_queue_rounded,
                        size: 11, color: Colors.white54),
                  ),
              };

    return GestureDetector(
      onTap: _showLanguagePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.7), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded,
                    color: Color(0xFFFFB300), size: 15),
                const SizedBox(width: 5),
                Text(
                  _supportedLanguages[_targetLanguageCode] ??
                      _targetLanguageCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFFFB300), size: 15),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badgeIcon,
                const SizedBox(width: 4),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Size screenSize) {
    // When result card is visible, push controls up
    final cardVisible = _selectedBlockIndex != null &&
        _selectedBlockIndex! < _translatedBlocks.length;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: cardVisible ? 230 : 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _isFrozen ? _buildFrozenControls() : _buildLiveControls(),
        ),
      ),
    );
  }

  Widget _buildLiveControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status pill
        if (_translatedBlocks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white54, size: 14),
                SizedBox(width: 8),
                Text(
                  'Point camera at signboard and tap shutter',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Shutter
        _buildShutterButton(),
      ],
    );
  }

  Widget _buildFrozenControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scan Again
        GestureDetector(
          onTap: _isCapturing ? null : _resumeLiveScan,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Scan Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Small shutter (retranslate)
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _isCapturing ? null : _resumeLiveScan,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
            ),
            child: const Icon(Icons.cameraswitch_rounded,
                color: Color(0xFFFFB300), size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _captureAndTranslate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isCapturing ? Colors.white38 : Colors.white,
            width: 3.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isCapturing
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                    ),
              color: _isCapturing ? Colors.white24 : null,
              boxShadow: _isCapturing
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: _isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(_TranslatedBlock block, Size screenSize) {
    final result = block.result;

    final (statusLabel, statusColor) = switch (result.matchType) {
      MatchType.exactCanonical ||
      MatchType.normalizedExact ||
      MatchType.alias ||
      MatchType.phraseContainment ||
      MatchType.fuzzy =>
        ('Verified · Heritage dictionary', const Color(0xFF66BB6A)),
      MatchType.mlKit => (
          'AI · Offline ML translation',
          const Color(0xFF42A5F5)
        ),
      MatchType.wordLevel => (
          'Partial · Word-level match',
          const Color(0xFFFF9800)
        ),
      MatchType.none => switch (result.status) {
          TranslationStatus.unsupported => (
              'Not in dictionary',
              Colors.orange.shade300
            ),
          _ => ('', Colors.white54),
        },
    };

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: Offset.zero,
          child: Material(
            elevation: 16,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF5100C04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              // Bound the card's height and let long translations scroll
              // inside it — previously a long/multi-line translation could
              // grow the card taller than the space the bottom bar left for
              // it, pushing its lower half off-screen (or under the bottom
              // bar) with no way to reach it except by chance re-taps.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(screenSize.height * 0.42, 360),
                ),
                child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300)
                                    .withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.g_translate_rounded,
                                  color: Color(0xFFFFB300), size: 20),
                            ),
                            const SizedBox(width: 12),

                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Original text
                                  Row(
                                    children: [
                                      const Text(
                                        'ORIGINAL',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Confidence badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${(result.confidence * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(builder: (_) {
                                    // Italicising Devanagari/Tamil/Sinhala/
                                    // CJK is a synthetic (faked) oblique —
                                    // there's no real italic glyph set for
                                    // these scripts, so it just smeared
                                    // conjuncts into an unreadable mess.
                                    // Only italicise genuinely Latin text.
                                    final nonLatin =
                                        _looksNonLatin(result.inputText);
                                    return Text(
                                      result.inputText,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontStyle: nonLatin
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                        height: nonLatin ? 1.6 : 1.4,
                                      ),
                                    );
                                  }),

                                  const SizedBox(height: 10),
                                  Container(
                                    height: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  const SizedBox(height: 10),

                                  // Translation label
                                  Text(
                                    _languageFullNames[_targetLanguageCode] ??
                                        _targetLanguageCode.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Translated text (big) — when nothing
                                  // offline could translate this, say so
                                  // instead of echoing the original text
                                  // back as if it were a translation.
                                  Builder(builder: (_) {
                                    final unsupported = result.status ==
                                        TranslationStatus.unsupported;
                                    // Devanagari/Tamil/Sinhala/CJK need real
                                    // room for stacked matras and conjuncts,
                                    // and most fonts only ship a true bold
                                    // weight for Latin — forcing
                                    // FontWeight.bold on these scripts fakes
                                    // it by thickening strokes, which is what
                                    // made translated Hindi look smudged.
                                    final complex =
                                        _isComplexScript(_targetLanguageCode);
                                    return Text(
                                      unsupported
                                          ? 'No offline translation available'
                                          : result.translatedText,
                                      style: TextStyle(
                                        color: unsupported
                                            ? Colors.white38
                                            : const Color(0xFFFFD54F),
                                        fontSize: unsupported ? 15 : 22,
                                        fontWeight: unsupported
                                            ? FontWeight.w500
                                            : complex
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                        fontStyle: unsupported
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        height: complex ? 1.6 : 1.3,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                            // Close
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white38, size: 22),
                              onPressed: () =>
                                  setState(() => _selectedBlockIndex = null),
                            ),
                          ],
                        ),

                        // Status bar
                        if (statusLabel.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                  width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: statusColor, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Language picker bottom sheet
  // ─────────────────────────────────────────────────────────────────────────────

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF140A02),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFFFFB300), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.translate_rounded,
                    color: Color(0xFFFFB300), size: 20),
                SizedBox(width: 8),
                Text(
                  'Translate to',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose your target language for AR overlay',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: StreamBuilder<Map<String, ModelDownloadState>>(
                stream: MlKitTranslationService.instance.statusStream,
                initialData: MlKitTranslationService.instance.statusSnapshot,
                builder: (context, snapshot) {
                  final statuses = snapshot.data ?? const {};
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _languageFullNames.entries.map((e) {
                        final selected = e.key == _targetLanguageCode;
                        final supportsMlKit = MlKitTranslationService.instance
                            .isPairSupported('en', e.key);
                        final status = statuses[e.key] ?? ModelDownloadState.unknown;

                        final Widget trailing = !supportsMlKit
                            ? const Tooltip(
                                message:
                                    'Translated via the built-in offline dictionary',
                                child: Icon(Icons.menu_book_rounded,
                                    color: Colors.white38, size: 18),
                              )
                            : switch (status) {
                                ModelDownloadState.downloading => const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Color(0xFFFFD54F)),
                                  ),
                                ModelDownloadState.ready => const Tooltip(
                                    message: 'Downloaded — works fully offline',
                                    child: Icon(Icons.cloud_done_rounded,
                                        color: Color(0xFF66BB6A), size: 20),
                                  ),
                                ModelDownloadState.failed => IconButton(
                                    tooltip: 'Download failed — tap to retry',
                                    icon: const Icon(Icons.refresh_rounded,
                                        color: Color(0xFFEF5350), size: 20),
                                    onPressed: () => MlKitTranslationService
                                        .instance
                                        .ensureModels('en', e.key),
                                  ),
                                _ => const Icon(Icons.cloud_download_outlined,
                                    color: Colors.white38, size: 20),
                              };

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFB300).withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFFB300).withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            leading: selected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFFFFB300))
                                : Icon(Icons.radio_button_unchecked_rounded,
                                    color: Colors.white.withValues(alpha: 0.3)),
                            title: Text(
                              e.value,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFFFFB300)
                                    : Colors.white,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            trailing: trailing,
                            onTap: () {
                              Navigator.pop(context);
                              _onLanguageChanged(e.key);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data class
// ─────────────────────────────────────────────────────────────────────────────

class _TranslatedBlock {
  final String id;
  final Rect boundingBox;
  final TranslationResult result;
  final bool isNormalized;

  const _TranslatedBlock({
    required this.id,
    required this.boundingBox,
    required this.result,
    this.isNormalized = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  OCR → screen coordinate mapper
// ─────────────────────────────────────────────────────────────────────────────

class _OcrOverlayMapper {
  static Rect mapPixelRectToWidget({
    required Rect pixelRect,
    required Size cameraImageSize,
    required Size previewSize,
    required int sensorOrientation,
    required Size widgetSize,
    bool isNormalized = false,
  }) {
    final isRotated90 = sensorOrientation == 90 || sensorOrientation == 270;
    final pvW = isRotated90 ? previewSize.height : previewSize.width;
    final pvH = isRotated90 ? previewSize.width : previewSize.height;

    Rect normRect;
    if (isNormalized) {
      normRect = pixelRect;
    } else if (cameraImageSize.width <= 0 || cameraImageSize.height <= 0) {
      return Rect.zero;
    } else {
      final nLeft = pixelRect.left / cameraImageSize.width;
      final nTop = pixelRect.top / cameraImageSize.height;
      final nRight = pixelRect.right / cameraImageSize.width;
      final nBottom = pixelRect.bottom / cameraImageSize.height;
      normRect = switch (sensorOrientation) {
        90 => Rect.fromLTRB(nTop, 1 - nRight, nBottom, 1 - nLeft),
        270 => Rect.fromLTRB(1 - nBottom, nLeft, 1 - nTop, nRight),
        180 => Rect.fromLTRB(1 - nRight, 1 - nBottom, 1 - nLeft, 1 - nTop),
        _ => Rect.fromLTRB(nLeft, nTop, nRight, nBottom),
      };
    }

    final scaleX = widgetSize.width / pvW;
    final scaleY = widgetSize.height / pvH;
    final scale = math.max(scaleX, scaleY);
    final scaledW = pvW * scale;
    final scaledH = pvH * scale;
    final offsetX = (widgetSize.width - scaledW) / 2;
    final offsetY = (widgetSize.height - scaledH) / 2;

    return Rect.fromLTRB(
      offsetX + normRect.left * scaledW,
      offsetY + normRect.top * scaledH,
      offsetX + normRect.right * scaledW,
      offsetY + normRect.bottom * scaledH,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Google Lens-style AR text painter
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLensArTextPainter extends CustomPainter {
  final List<_TranslatedBlock> blocks;
  final Size cameraImageSize;
  final Size? previewSize;
  final int sensorOrientation;
  final Size widgetSize;
  final String targetLang;
  final int? selectedIndex;
  final TextDirection textDirection;
  final double topInset;
  final double bottomInset;

  const _GoogleLensArTextPainter({
    required this.blocks,
    required this.cameraImageSize,
    required this.previewSize,
    required this.sensorOrientation,
    required this.widgetSize,
    required this.targetLang,
    this.selectedIndex,
    this.textDirection = TextDirection.ltr,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (blocks.isEmpty || previewSize == null) return;

    // Keep AR boxes clear of the top app bar and bottom control bar — they
    // used to render underneath those gradients too, stacking with the UI
    // chrome into unreadable, overlapping clutter.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, topInset, size.width, math.max(topInset, size.height - bottomInset)),
    );

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final rect = _OcrOverlayMapper.mapPixelRectToWidget(
        pixelRect: block.boundingBox,
        cameraImageSize: cameraImageSize,
        previewSize: previewSize!,
        sensorOrientation: sensorOrientation,
        widgetSize: widgetSize,
        isNormalized: block.isNormalized,
      );
      if (rect.width < 4 || rect.height < 4) continue;

      final padded = Rect.fromLTRB(
        math.max(0, rect.left - 6),
        math.max(0, rect.top - 4),
        math.min(widgetSize.width, rect.right + 6),
        math.min(widgetSize.height, rect.bottom + 4),
      );

      final isSelected = selectedIndex == i;
      final isMlKit = block.result.matchType == MatchType.mlKit;
      final isPartial = block.result.status == TranslationStatus.unsupported ||
          block.result.matchType == MatchType.wordLevel;

      final rrect = RRect.fromRectAndRadius(padded, const Radius.circular(9));

      // Background fill
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Color(
            isPartial
                ? 0xF0181208
                : isMlKit
                    ? 0xF0090F1A
                    : 0xF0120B04,
          ),
      );

      // Border
      final borderColor = isSelected
          ? const Color(0xFFFFD54F)
          : isPartial
              ? const Color(0xFFFF9800)
              : isMlKit
                  ? const Color(0xFF42A5F5)
                  : const Color(0xFFFFB300);

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.5,
      );

      // Small language indicator dot
      final dotPaint = Paint()..color = borderColor;
      canvas.drawCircle(
        Offset(padded.right - 6, padded.top + 6),
        3,
        dotPaint,
      );

      // Translated text — for unsupported blocks, the "translation" is just
      // the original text echoed back, which reads as a broken/no-op
      // translation when overlaid in place of the original. Say so plainly
      // instead of duplicating the sign's own text over itself.
      final translatedStr = block.result.status == TranslationStatus.unsupported
          ? 'No offline translation'
          : block.result.translatedText;

      // Devanagari/Tamil/Sinhala/CJK conjuncts and stacked matras get
      // clipped at small sizes/tight line-height and look smudged under a
      // forced synthetic bold — give them more room and a real weight the
      // font actually ships instead of faking one.
      final isComplexScript = const {'hi', 'ta', 'si', 'zh'}.contains(targetLang);
      final fontSize = (padded.height * 0.44)
          .clamp(isComplexScript ? 13.0 : 11.0, 24.0);

      final textSpan = TextSpan(
        text: translatedStr,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: isComplexScript ? FontWeight.w600 : FontWeight.bold,
          height: isComplexScript ? 1.4 : 1.15,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: textDirection,
        maxLines: 3,
        ellipsis: '…',
      );
      textPainter.layout(maxWidth: math.max(10.0, padded.width - 14));

      final textX = padded.left + 7;
      final textY = padded.top + (padded.height - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(textX, math.max(padded.top + 3, textY)));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLensArTextPainter old) =>
      old.blocks != blocks ||
      old.selectedIndex != selectedIndex ||
      old.targetLang != targetLang ||
      old.topInset != topInset ||
      old.bottomInset != bottomInset;
}
