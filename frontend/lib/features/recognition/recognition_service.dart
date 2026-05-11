import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox; // normalised 0..1 in model input space
  final int classIndex;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.classIndex,
  });
}

/// YOLOv8 TFLite inference service.
///
/// Handles both common export layouts:
///   • Transposed  [1, num_classes+4, num_anchors]  ← default ultralytics export
///   • Standard    [1, num_anchors,   num_classes+4]
///
/// Labels MUST match the order used during training.
class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();

  // ── Labels – MUST match your training class order exactly ──────────────────
  static const List<String> labels = [
    'sigiriya_lion_paws',
    'sigiriya_lion_rock',
    'sigiriya_mirror_wall',
    'sigiriya_throne',
    'sigiriya_ticket_counter',
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  Interpreter? _interpreter;
  String? _loadError;

  int _inputWidth = 640;
  int _inputWidth = 640;
  int _inputHeight = 640;

  /// Shape of the output tensor (without the batch dim).
  /// E.g. [9, 8400] or [8400, 9].
  List<int> _outputShape = [];

  bool get isLoaded => _interpreter != null;
  bool get isLoaded => _interpreter != null;
  String? get loadError => _loadError;
  int get inputWidth => _inputWidth;
  int get inputHeight => _inputHeight;
  int get inputWidth => _inputWidth;
  int get inputHeight => _inputHeight;

  // ── Model loading ──────────────────────────────────────────────────────────
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

      // Read input metadata
      final inputTensors = _interpreter!.getInputTensors();
      debugPrint(
          '[RecognitionService] Model loaded. Inputs: ${inputTensors.length}, Outputs: ${_interpreter!.getOutputTensors().length}');

      debugPrint(
          '[RecognitionService] Model loaded. Inputs: ${inputTensors.length}, Outputs: ${_interpreter!.getOutputTensors().length}');

      final inTensor = _interpreter!.getInputTensor(0);
      final inShape = inTensor.shape;
      final inType = inTensor.type;
      debugPrint('[RecognitionService] Input[0]: shape=$inShape, type=$inType');

      if (inShape.length >= 4) {
        _inputHeight = inShape[1];
        _inputWidth = inShape[2];
        _inputWidth = inShape[2];
      }

      // Read output shape – strip the leading batch dim (1)
      final outTensor = _interpreter!.getOutputTensor(0);
      final outShape = outTensor.shape;
      debugPrint(
          '[RecognitionService] Default Output[0] shape: $outShape, type: ${outTensor.type}, name: ${outTensor.name}');
      debugPrint(
          '[RecognitionService] Default Output[0] shape: $outShape, type: ${outTensor.type}, name: ${outTensor.name}');
      _outputShape = outShape.length > 1 ? outShape.sublist(1) : outShape;

      _interpreter!.allocateTensors();
      debugPrint('[RecognitionService] Tensors allocated successfully');

      _loadError = null;
    } catch (e, stack) {
      _loadError = e.toString();
      debugPrint('[RecognitionService] Failed to load model: $_loadError');
      debugPrint(stack.toString());
      _interpreter = null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  // ── Inference ──────────────────────────────────────────────────────────────
  Future<List<DetectionResult>> predictAll(
    CameraImage image, {
    int sensorOrientation = 0,
    double threshold = 0.30,
    double nmsIouThreshold = 0.45,
  }) async {
    if (_interpreter == null) await loadModel();
    if (_interpreter == null) return [];

    // 1. Convert camera frame → RGB image
    final stopwatch = Stopwatch()..start();
    final decoded = _cameraImageToImage(image);
    if (decoded == null) {
      print('[RecognitionService] CameraImage conversion failed');
      return [];
    }

    // 2. Rotate to correct orientation then resize to model input
    final rotated = _rotateForInference(decoded, sensorOrientation);
    final resized = img.copyResize(rotated,
        width: _inputWidth,
        height: _inputHeight,
        interpolation: img.Interpolation.linear);

    // 3. Build input tensor [1, H, W, 3] – values in [0, 1]
    // Keep the tensor rank explicit so the TFLite interpreter receives a 4D
    // input instead of a flattened 1D buffer.
    final inputTensor =
        _imageToNestedFloat32([resized], _inputWidth, _inputHeight);

    // 4. Allocate output buffer
    final outTensor = _interpreter!.getOutputTensor(0);
    final outShape = outTensor.shape;
    final outShape = outTensor.shape;
    // Usually [1, numBoxFields, numAnchors]
    final dynamic rawOutput = _buildNestedOutputBuffer(outShape);

    try {
      // Create a map for outputs if multi-output, but here we just have 1
      final Map<int, Object> outputs = {0: rawOutput as Object};
      _interpreter!.runForMultipleInputs([inputTensor], outputs);
    } catch (e) {
      debugPrint('[RecognitionService] Inference run failed: $e');
      return [];
    }

    // 5. Parse detections
    final detections = _parseOutput(_flattenOutput(rawOutput), threshold);
    final nmsResults = _nms(detections, nmsIouThreshold);

    if (kDebugMode) {
      debugPrint(
          '[RecognitionService] Inference took ${stopwatch.elapsedMilliseconds}ms, found ${nmsResults.length} detections');
      debugPrint(
          '[RecognitionService] Inference took ${stopwatch.elapsedMilliseconds}ms, found ${nmsResults.length} detections');
    }
    return nmsResults;
  }

  dynamic _buildNestedOutputBuffer(List<int> shape) {
    if (shape.isEmpty) {
      return 0.0;
    }
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0, growable: false);
    }
    return List.generate(
      shape[0],
      (_) => _buildNestedOutputBuffer(shape.sublist(1)),
      growable: false,
    );
  }

  Float32List _flattenOutput(dynamic value) {
    final buffer = <double>[];
    _collectOutputValues(value, buffer);
    return Float32List.fromList(buffer);
  }

  void _collectOutputValues(dynamic value, List<double> buffer) {
    if (value is num) {
      buffer.add(value.toDouble());
      return;
    }
    if (value is List) {
      for (final item in value) {
        _collectOutputValues(item, buffer);
      }
    }
  }

  /// Convenience: returns only the single best detection (highest confidence).
  Future<DetectionResult?> predict(
    CameraImage image, {
    int sensorOrientation = 0,
    double threshold = 0.30,
  }) async {
    final all = await predictAll(image,
        sensorOrientation: sensorOrientation, threshold: threshold);
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  // ── Output parsing ─────────────────────────────────────────────────────────

  /// Determine whether the tensor is transposed (YOLOv8 default) or standard.
  ///
  ///  Transposed: shape = [numClasses+4, numAnchors]  → numAnchors >> numClasses
  ///  Standard  : shape = [numAnchors,  numClasses+4] → same but swapped
  bool get _isTransposed {
    if (_outputShape.length < 2) return false;
    // heuristic: the anchors dim is always the larger one
    return _outputShape[0] < _outputShape[1];
  }

  List<DetectionResult> _parseOutput(Float32List flat, double threshold) {
    if (_outputShape.length < 2) return [];

    final int rows;
    final int cols;

    if (_isTransposed) {
      // Shape: [numBoxFields, numAnchors]  e.g. [9, 8400]
      rows = _outputShape[0]; // numBoxFields  = 4 + numClasses
      cols = _outputShape[1]; // numAnchors
    } else {
      // Shape: [numAnchors, numBoxFields]  e.g. [8400, 9]
      rows = _outputShape[1]; // numBoxFields
      cols = _outputShape[0]; // numAnchors
    }

    final int numAnchors = cols;
    final int numAnchors = cols;
    final int numBoxFields = rows;
    final int numClasses = numBoxFields - 4; // cx,cy,w,h + class scores
    final int numClasses = numBoxFields - 4; // cx,cy,w,h + class scores
    final int effectiveClasses = numClasses;

    final results = <DetectionResult>[];

    for (int a = 0; a < numAnchors; a++) {
      double cx, cy, bw, bh;

      if (_isTransposed) {
        // flat is stored row-major for [numBoxFields, numAnchors]
        // value at [field, anchor] = flat[field * numAnchors + anchor]
        cx = flat[0 * numAnchors + a];
        cy = flat[1 * numAnchors + a];
        bw = flat[2 * numAnchors + a];
        bh = flat[3 * numAnchors + a];
      } else {
        // flat is stored row-major for [numAnchors, numBoxFields]
        // value at [anchor, field] = flat[anchor * numBoxFields + field]
        cx = flat[a * numBoxFields + 0];
        cy = flat[a * numBoxFields + 1];
        bw = flat[a * numBoxFields + 2];
        bh = flat[a * numBoxFields + 3];
      }

      // Find best class score
      double bestScore = -1;
      int bestClass = -1;
      for (int c = 0; c < effectiveClasses; c++) {
        double score;
        if (_isTransposed) {
          score = flat[(4 + c) * numAnchors + a];
        } else {
          score = flat[a * numBoxFields + 4 + c];
        }
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestClass < 0 || bestScore < threshold) continue;

      final labelStr =
          (bestClass < labels.length) ? labels[bestClass] : 'CLASS_$bestClass';

      final labelStr =
          (bestClass < labels.length) ? labels[bestClass] : 'CLASS_$bestClass';

      // YOLOv8 boxes are in pixel space relative to input size (cx,cy,w,h)
      // Normalise to 0..1
      // HEURISTIC: If cx/cy are > 1, they are pixel-space. If < 1, they are already normalized.
      double nx1, ny1, nx2, ny2;
      if (cx > 1.5 || bw > 1.5) {
        nx1 = ((cx - bw / 2) / _inputWidth).clamp(0.0, 1.0);
        ny1 = ((cy - bh / 2) / _inputHeight).clamp(0.0, 1.0);
        nx2 = ((cx + bw / 2) / _inputWidth).clamp(0.0, 1.0);
        ny2 = ((cy + bh / 2) / _inputHeight).clamp(0.0, 1.0);
      } else {
        nx1 = (cx - bw / 2).clamp(0.0, 1.0);
        ny1 = (cy - bh / 2).clamp(0.0, 1.0);
        nx2 = (cx + bw / 2).clamp(0.0, 1.0);
        ny2 = (cy + bh / 2).clamp(0.0, 1.0);
      }

      if (nx2 <= nx1 || ny2 <= ny1) continue; // degenerate box

      results.add(DetectionResult(
        label: labelStr,
        confidence: bestScore,
        boundingBox: Rect.fromLTRB(nx1, ny1, nx2, ny2),
        classIndex: bestClass,
      ));
    }

    if (results.isNotEmpty && kDebugMode) {
      debugPrint(
          '[RecognitionService] Raw detections before NMS: ${results.length}');
      for (var r in results.take(3)) {
        debugPrint(
            '  - ${r.label} conf=${r.confidence.toStringAsFixed(3)} box=${r.boundingBox}');
      }
      debugPrint(
          '[RecognitionService] Raw detections before NMS: ${results.length}');
      for (var r in results.take(3)) {
        debugPrint(
            '  - ${r.label} conf=${r.confidence.toStringAsFixed(3)} box=${r.boundingBox}');
      }
    }

    return results;
  }

  // ── NMS ───────────────────────────────────────────────────────────────────
  List<DetectionResult> _nms(
      List<DetectionResult> detections, double iouThreshold) {
    if (detections.isEmpty) return [];

    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <DetectionResult>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      kept.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i].boundingBox, detections[j].boundingBox) >
            iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  double _iou(Rect a, Rect b) {
    final ix1 = max(a.left, b.left);
    final iy1 = max(a.top, b.top);
    final ix2 = min(a.right, b.right);
    final ix1 = max(a.left, b.left);
    final iy1 = max(a.top, b.top);
    final ix2 = min(a.right, b.right);
    final iy2 = min(a.bottom, b.bottom);
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final aArea = a.width * a.height;
    final bArea = b.width * b.height;
    return inter / (aArea + bArea - inter);
  }

  // ── Tensor utilities ───────────────────────────────────────────────────────
  /// Build a [1, H, W, 3] tensor from a list of images.
  ///
  /// The interpreter expects the full 4D shape, so we preserve the nesting
  /// rather than flattening the pixels into a 1D buffer.
  List<List<List<List<double>>>> _imageToNestedFloat32(
    List<img.Image> images,
    int w,
    int h,
  ) {
    return images
        .map(
          (image) => List.generate(
            h,
            (y) => List.generate(
              w,
              (x) {
                final p = image.getPixel(x, y);
                return <double>[p.r / 255.0, p.g / 255.0, p.b / 255.0];
              },
              growable: false,
            ),
            growable: false,
          ),
        )
        .toList(growable: false);
  }

  // ── Image conversion ───────────────────────────────────────────────────────
  img.Image? _cameraImageToImage(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToImage(image);
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToImage(image);
      default:
        return null;
    }
  }

  img.Image _yuv420ToImage(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final out = img.Image(width: w, height: h);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yStride = yPlane.bytesPerRow;
    final uvStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final yVal = yBytes[yStride * y + x];
        final uvIdx = uvStride * (y >> 1) + (x >> 1) * uvPixelStride;
        final uVal = uBytes[uvIdx];
        final vVal = vBytes[uvIdx];
        final uVal = uBytes[uvIdx];
        final vVal = vBytes[uvIdx];
        final yf = yVal.toDouble();
        final uf = uVal.toDouble() - 128.0;
        final vf = vVal.toDouble() - 128.0;
        final r = (yf + 1.402 * vf).round().clamp(0, 255);
        final r = (yf + 1.402 * vf).round().clamp(0, 255);
        final g = (yf - 0.344136 * uf - 0.714136 * vf).round().clamp(0, 255);
        final b = (yf + 1.772 * uf).round().clamp(0, 255);
        final b = (yf + 1.772 * uf).round().clamp(0, 255);
        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return out;
  }

  img.Image _bgra8888ToImage(CameraImage image) {
    final plane = image.planes[0];
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Rotate image so that the top of frame matches portrait orientation.
  /// On Android the back camera is typically rotated 90°.
  img.Image _rotateForInference(img.Image src, int sensorOrientation) {
    if (sensorOrientation == 90) return img.copyRotate(src, angle: 90);
    if (sensorOrientation == 90) return img.copyRotate(src, angle: 90);
    if (sensorOrientation == 180) return img.copyRotate(src, angle: 180);
    if (sensorOrientation == 270) return img.copyRotate(src, angle: 270);
    return src; // 0 – no rotation needed
  }
}
