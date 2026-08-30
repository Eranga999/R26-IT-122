import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../processors/ocr_text_processor.dart';

/// Fully offline Sinhala OCR Engine.
///
/// Extracts text from captured signboard photos using local character/glyph
/// feature recognition model loaded from `assets/data/sinhala_ocr_model.json`.
class SinhalaOcrEngine {
  SinhalaOcrEngine._();
  static final SinhalaOcrEngine instance = SinhalaOcrEngine._();

  final OcrTextProcessor _processor = const OcrTextProcessor();
  bool _initialized = false;
  final List<Map<String, dynamic>> _glyphTemplates = [];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/sinhala_ocr_model.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final templates = data['glyph_templates'] as List<dynamic>? ?? [];

      _glyphTemplates.clear();
      for (final item in templates) {
        if (item is Map<String, dynamic>) {
          _glyphTemplates.add(item);
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[SinhalaOcrEngine] Failed to initialize model: $e');
      _initialized = true;
    }
  }

  /// Processes an image file offline and returns recognized Sinhala [RecognizedText].
  ///
  /// NOTE: This engine currently returns empty results because the glyph
  /// template model is a placeholder. Real Sinhala OCR requires a proper
  /// on-device model (e.g. TFLite). Returning empty gracefully prevents
  /// fake blocks from polluting the AR overlay.
  Future<RecognizedText> recognizeTextFromFile(String imagePath) async {
    await initialize();

    final file = File(imagePath);
    if (!await file.exists()) {
      return RecognizedText(text: '', blocks: []);
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return RecognizedText(text: '', blocks: []);

      // The glyph template model is a placeholder — do not emit fake blocks.
      // Real Sinhala OCR would analyze the image here and return real blocks.
      return RecognizedText(text: '', blocks: []);
    } catch (e, st) {
      debugPrint('[SinhalaOcrEngine] Error recognizing image: $e\n$st');
      return RecognizedText(text: '', blocks: []);
    }
  }

  /// Simulates glyph feature extraction & OCR block segmentation from image bytes
  List<TextBlock> _extractSinhalaBlocks(
      Uint8List bytes, double imageWidth, double imageHeight) {
    if (_glyphTemplates.isEmpty) return [];

    final blocks = <TextBlock>[];

    // Map template glyphs based on spatial layout & image dimensions
    for (var i = 0; i < _glyphTemplates.length; i++) {
      final tmpl = _glyphTemplates[i];
      final rawText = tmpl['text'] as String? ?? '';
      if (rawText.isEmpty) continue;

      final normalizedText = _processor.normalizeSinhala(rawText);

      // Generate realistic bounding box coordinates matching signboard dimensions
      final topFraction = 0.15 + (i * 0.08) % 0.65;
      const leftFraction = 0.10;
      const rightFraction = 0.90;
      final bottomFraction = topFraction + 0.06;

      final rect = Rect.fromLTRB(
        leftFraction * imageWidth,
        topFraction * imageHeight,
        rightFraction * imageWidth,
        bottomFraction * imageHeight,
      );

      final cornerPoints = [
        Point<int>(rect.left.toInt(), rect.top.toInt()),
        Point<int>(rect.right.toInt(), rect.top.toInt()),
        Point<int>(rect.right.toInt(), rect.bottom.toInt()),
        Point<int>(rect.left.toInt(), rect.bottom.toInt()),
      ];

      final line = TextLine(
        text: normalizedText,
        elements: [
          TextElement(
            text: normalizedText,
            boundingBox: rect,
            cornerPoints: cornerPoints,
            confidence: 0.92,
            symbols: const [],
            recognizedLanguages: const ['si'],
            angle: null,
          ),
        ],
        boundingBox: rect,
        cornerPoints: cornerPoints,
        confidence: 0.92,
        recognizedLanguages: const ['si'],
        angle: null,
      );

      final block = TextBlock(
        text: normalizedText,
        lines: [line],
        boundingBox: rect,
        cornerPoints: cornerPoints,
        recognizedLanguages: const ['si'],
      );

      blocks.add(block);

      // Limit initial OCR extraction to prominent text lines
      if (blocks.length >= 6) break;
    }

    return blocks;
  }

  Size _extractJpegDimensions(Uint8List bytes) {
    if (bytes.length < 10 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return const Size(1080, 1920);
    }
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
        break;
      }
      if (i + 3 >= bytes.length) break;
      final segmentLen = (bytes[i + 2] << 8) | bytes[i + 3];
      if (segmentLen < 2) break;
      i += 2 + segmentLen;
    }
    return const Size(1080, 1920);
  }
}
