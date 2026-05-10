import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final int classIndex;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.classIndex,
  });
}

/// Real YOLOv8 TFLite recognition service.
///
/// Expects a model exported from Ultralytics YOLOv8 and stored at:
/// `assets/models/landmark_model.tflite`.
class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();

  static const List<String> labels = [
    'sigiriya_entrance',
    'sigiriya_lion_rock',
    'sigiriya_mirror_wall',
    'sigiriya_lion_staircase',
    'sigiriya_throne',
  ];

  Interpreter? _interpreter;
  String? _loadError;
  int _inputWidth = 640;
  int _inputHeight = 640;

  bool get isLoaded => _interpreter != null;
  String? get loadError => _loadError;

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      final modelData =
          await rootBundle.load('assets/models/landmark_model.tflite');
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromBuffer(
        modelData.buffer.asUint8List(),
        options: options,
      );

      final inputShape = _interpreter!.getInputTensor(0).shape;
      if (inputShape.length >= 4) {
        _inputHeight = inputShape[1];
        _inputWidth = inputShape[2];
      }
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
      print('Failed to load TFLite model: $_loadError');
      _interpreter = null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  Future<DetectionResult?> predict(
    CameraImage image, {
    int sensorOrientation = 0,
    double threshold = 0.35,
  }) async {
    if (_interpreter == null) {
      await loadModel();
    }
    if (_interpreter == null) return null;

    final decoded = _cameraImageToImage(image);
    if (decoded == null) return null;

    final rotated = _rotateImage(decoded, sensorOrientation);
    final resized = img.copyResize(
      rotated,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    final input = _imageToFloat32List(resized);
    final output = _createOutputBuffer(_interpreter!.getOutputTensor(0).shape);

    _interpreter!.run(input, output);

    return _extractBestDetection(
      output,
      normalizedWidth: _inputWidth.toDouble(),
      normalizedHeight: _inputHeight.toDouble(),
      threshold: threshold,
    );
  }

  DetectionResult? _extractBestDetection(
    dynamic output, {
    required double normalizedWidth,
    required double normalizedHeight,
    required double threshold,
  }) {
    final candidates = <List<double>>[];
    _collectCandidateRows(output, candidates);

    DetectionResult? best;
    for (final row in candidates) {
      final detection = _parseCandidateRow(
        row,
        normalizedWidth: normalizedWidth,
        normalizedHeight: normalizedHeight,
        threshold: threshold,
      );
      if (detection == null) continue;

      if (best == null || detection.confidence > best.confidence) {
        best = detection;
      }
    }

    return best;
  }

  DetectionResult? _parseCandidateRow(
    List<double> row, {
    required double normalizedWidth,
    required double normalizedHeight,
    required double threshold,
  }) {
    if (row.length < 6) return null;

    final box = _decodeBoundingBox(
      row.sublist(0, 4),
      normalizedWidth: normalizedWidth,
      normalizedHeight: normalizedHeight,
    );
    if (box == null) return null;

    if (row.length == 6) {
      final confidence = row[4];
      final classIndex = row[5].round();
      if (confidence < threshold) return null;
      if (classIndex < 0 || classIndex >= labels.length) return null;

      return DetectionResult(
        label: labels[classIndex],
        confidence: confidence,
        boundingBox: box,
        classIndex: classIndex,
      );
    }

    final scores = row.sublist(4);
    var bestScore = double.negativeInfinity;
    var bestIndex = -1;
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIndex = i;
      }
    }

    if (bestIndex < 0 || bestIndex >= labels.length) return null;
    if (bestScore < threshold) return null;

    return DetectionResult(
      label: labels[bestIndex],
      confidence: bestScore,
      boundingBox: box,
      classIndex: bestIndex,
    );
  }

  void _collectCandidateRows(dynamic node, List<List<double>> rows) {
    if (node is List) {
      if (node.isNotEmpty && node.first is num) {
        rows.add(node.map((value) => (value as num).toDouble()).toList());
        return;
      }

      final numericChildren = node
          .whereType<List>()
          .where((child) => child.isNotEmpty && child.first is num)
          .toList();
      if (numericChildren.isNotEmpty && numericChildren.length == node.length) {
        final childLengths =
            numericChildren.map((child) => child.length).toSet();
        if (childLengths.length == 1) {
          final childLength = childLengths.first;
          if (node.length <= childLength) {
            for (final child in numericChildren) {
              rows.add(
                  child.map((value) => (value as num).toDouble()).toList());
            }
            return;
          }

          for (var i = 0; i < childLength; i++) {
            final row = <double>[];
            for (final child in numericChildren) {
              row.add((child[i] as num).toDouble());
            }
            rows.add(row);
          }
          return;
        }
      }

      for (final child in node) {
        _collectCandidateRows(child, rows);
      }
    }
  }

  Rect? _decodeBoundingBox(
    List<double> raw, {
    required double normalizedWidth,
    required double normalizedHeight,
  }) {
    // Try corner format first: x1, y1, x2, y2.
    final cornerBox = _normalizeBox(
      raw[0],
      raw[1],
      raw[2],
      raw[3],
      normalizedWidth: normalizedWidth,
      normalizedHeight: normalizedHeight,
      isCornerFormat: true,
    );
    if (cornerBox != null) return cornerBox;

    // Fallback to center format: cx, cy, w, h.
    return _normalizeBox(
      raw[0],
      raw[1],
      raw[2],
      raw[3],
      normalizedWidth: normalizedWidth,
      normalizedHeight: normalizedHeight,
      isCornerFormat: false,
    );
  }

  Rect? _normalizeBox(
    double a,
    double b,
    double c,
    double d, {
    required double normalizedWidth,
    required double normalizedHeight,
    required bool isCornerFormat,
  }) {
    final valuesLookNormalized =
        [a, b, c, d].every((value) => value.abs() <= 1.5);

    double left;
    double top;
    double right;
    double bottom;

    if (isCornerFormat) {
      if (valuesLookNormalized) {
        left = a * normalizedWidth;
        top = b * normalizedHeight;
        right = c * normalizedWidth;
        bottom = d * normalizedHeight;
      } else {
        left = a;
        top = b;
        right = c;
        bottom = d;
      }

      if (right <= left || bottom <= top) return null;
    } else {
      double cx;
      double cy;
      double width;
      double height;

      if (valuesLookNormalized) {
        cx = a * normalizedWidth;
        cy = b * normalizedHeight;
        width = c * normalizedWidth;
        height = d * normalizedHeight;
      } else {
        cx = a;
        cy = b;
        width = c;
        height = d;
      }

      left = cx - width / 2;
      top = cy - height / 2;
      right = cx + width / 2;
      bottom = cy + height / 2;
    }

    left = left.clamp(0.0, normalizedWidth);
    top = top.clamp(0.0, normalizedHeight);
    right = right.clamp(0.0, normalizedWidth);
    bottom = bottom.clamp(0.0, normalizedHeight);

    if (right - left < 2 || bottom - top < 2) return null;

    return Rect.fromLTRB(
      left / normalizedWidth,
      top / normalizedHeight,
      right / normalizedWidth,
      bottom / normalizedHeight,
    );
  }

  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0.0);
    }
    return List.generate(
      shape.first,
      (_) => _createOutputBuffer(shape.sublist(1)),
    );
  }

  Float32List _imageToFloat32List(img.Image image) {
    final buffer = Float32List(_inputWidth * _inputHeight * 3);
    var pixelIndex = 0;

    for (var y = 0; y < _inputHeight; y++) {
      for (var x = 0; x < _inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return buffer;
  }

  img.Image _rotateImage(img.Image source, int sensorOrientation) {
    final rotation = sensorOrientation % 360;
    if (rotation == 0) return source;
    return img.copyRotate(source, angle: rotation.toDouble());
  }

  img.Image? _cameraImageToImage(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) {
      return null;
    }

    final width = image.width;
    final height = image.height;
    final converted = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final yRowOffset = yRowStride * y;
      final uvRowOffset = uvRowStride * (y >> 1);

      for (var x = 0; x < width; x++) {
        final yIndex = yRowOffset + x;
        final uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;

        final yValue = yBytes[yIndex];
        final uValue = uBytes[uvIndex];
        final vValue = vBytes[uvIndex];

        final rgb = _yuvToRgb(yValue, uValue, vValue);
        converted.setPixelRgba(x, y, rgb[0], rgb[1], rgb[2], 255);
      }
    }

    return converted;
  }

  List<int> _yuvToRgb(int y, int u, int v) {
    final yValue = y.toDouble();
    final uValue = u.toDouble() - 128.0;
    final vValue = v.toDouble() - 128.0;

    int clampInt(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

    final red = clampInt((yValue + 1.402 * vValue).round());
    final green =
        clampInt((yValue - 0.344136 * uValue - 0.714136 * vValue).round());
    final blue = clampInt((yValue + 1.772 * uValue).round());

    return [red, green, blue];
  }
}
