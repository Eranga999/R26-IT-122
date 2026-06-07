import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// ── Isolate Protocol Classes ─────────────────────────────────────────────────
class _InferenceWorkerInit {
  final SendPort replyPort;
  final Uint8List modelBytes;

  _InferenceWorkerInit({
    required this.replyPort,
    required this.modelBytes,
  });
}

class _InferenceWorkerReady {
  final SendPort sendPort;
  final int inputW;
  final int inputH;

  _InferenceWorkerReady({
    required this.sendPort,
    required this.inputW,
    required this.inputH,
  });
}

class _InferenceRequest {
  final SendPort replyPort;
  final int width;
  final int height;
  final int inputW;
  final int inputH;
  final String format;
  final int sensorOrientation;
  final List<Map<String, dynamic>> planes;
  final double threshold;
  final double nmsIouThreshold;
  final Set<String>? allowedLabels;

  _InferenceRequest({
    required this.replyPort,
    required this.width,
    required this.height,
    required this.inputW,
    required this.inputH,
    required this.format,
    required this.sensorOrientation,
    required this.planes,
    required this.threshold,
    required this.nmsIouThreshold,
    this.allowedLabels,
  });
}

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

// ── Background Worker Entry Point ────────────────────────────────────────────
void _inferenceIsolateEntry(SendPort mainSendPort) async {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  Interpreter? interpreter;
  int inputWidth = 640;
  int inputHeight = 640;
  List<int> outputShape = [];
  List<int> fullOutputShape = [];
  bool isTransposed = false;

  final labels = [
    'sigiriya_lion_paws',
    'sigiriya_lion_rock',
    'sigiriya_mirror_wall',
    'sigiriya_throne',
    'sigiriya_ticket_counter',
  ];

  // Helper functions inside isolate
  img.Image buildImageFromPlanes(_InferenceRequest req) {
    if (req.format == 'yuv420') {
      final yBytes = req.planes[0]['bytes'] as Uint8List;
      final uBytes = req.planes[1]['bytes'] as Uint8List;
      final vBytes = req.planes[2]['bytes'] as Uint8List;
      final yStride = req.planes[0]['bytesPerRow'] as int;
      final uvStride = req.planes[1]['bytesPerRow'] as int;
      final uvPixelStride = req.planes[1]['bytesPerPixel'] as int? ?? 1;

      final out = img.Image(width: req.width, height: req.height);
      for (int y = 0; y < req.height; y++) {
        for (int x = 0; x < req.width; x++) {
          final yVal = yBytes[yStride * y + x];
          final uvIdx = uvStride * (y >> 1) + (x >> 1) * uvPixelStride;
          final uVal = uBytes[uvIdx];
          final vVal = vBytes[uvIdx];
          final yf = yVal.toDouble();
          final uf = uVal.toDouble() - 128.0;
          final vf = vVal.toDouble() - 128.0;
          final r = (yf + 1.402 * vf).round().clamp(0, 255);
          final g = (yf - 0.344136 * uf - 0.714136 * vf).round().clamp(0, 255);
          final b = (yf + 1.772 * uf).round().clamp(0, 255);
          out.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return out;
    } else {
      final bytes = req.planes[0]['bytes'] as Uint8List;
      return img.Image.fromBytes(
          width: req.width,
          height: req.height,
          bytes: bytes.buffer,
          order: img.ChannelOrder.bgra);
    }
  }

  List<List<List<List<double>>>> preprocessImage(_InferenceRequest req) {
    img.Image src = buildImageFromPlanes(req);
    final orientation = req.sensorOrientation;
    if (orientation == 90) src = img.copyRotate(src, angle: 90);
    if (orientation == 180) src = img.copyRotate(src, angle: 180);
    if (orientation == 270) src = img.copyRotate(src, angle: 270);

    final resized = img.copyResize(src,
        width: req.inputW, height: req.inputH, interpolation: img.Interpolation.linear);

    return List<List<List<List<double>>>>.generate(
      1,
      (_) => List<List<List<double>>>.generate(
        req.inputH,
        (y) => List<List<double>>.generate(
          req.inputW,
          (x) {
            final p = resized.getPixel(x, y);
            return <double>[((p.r) / 255.0), ((p.g) / 255.0), ((p.b) / 255.0)];
          },
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );
  }

  dynamic _buildNestedOutputBuffer(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    if (shape.length == 1) return List<double>.filled(shape[0], 0.0, growable: false);
    return List.generate(
      shape[0],
      (_) => _buildNestedOutputBuffer(shape.sublist(1)),
      growable: false,
    );
  }

  void _collectOutputValues(dynamic value, List<double> buffer) {
    if (value is num) {
      buffer.add(value.toDouble());
    } else if (value is List) {
      for (final item in value) {
        _collectOutputValues(item, buffer);
      }
    }
  }

  Float32List _flattenOutput(dynamic value) {
    final buffer = <double>[];
    _collectOutputValues(value, buffer);
    return Float32List.fromList(buffer);
  }

  List<DetectionResult> _parseOutput(Float32List flat, _InferenceRequest req) {
    if (outputShape.length < 2) return [];

    final int rows;
    final int cols;
    if (isTransposed) {
      rows = outputShape[0]; 
      cols = outputShape[1]; 
    } else {
      rows = outputShape[1]; 
      cols = outputShape[0]; 
    }

    final int numAnchors = cols;
    final int numBoxFields = rows;
    final int numClasses = numBoxFields - 4; 

    final results = <DetectionResult>[];
    for (int a = 0; a < numAnchors; a++) {
      double cx, cy, bw, bh;
      if (isTransposed) {
        cx = flat[0 * numAnchors + a];
        cy = flat[1 * numAnchors + a];
        bw = flat[2 * numAnchors + a];
        bh = flat[3 * numAnchors + a];
      } else {
        cx = flat[a * numBoxFields + 0];
        cy = flat[a * numBoxFields + 1];
        bw = flat[a * numBoxFields + 2];
        bh = flat[a * numBoxFields + 3];
      }

      double bestScore = -1;
      int bestClass = -1;
      for (int c = 0; c < numClasses; c++) {
        double score = isTransposed 
            ? flat[(4 + c) * numAnchors + a] 
            : flat[a * numBoxFields + 4 + c];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestClass < 0 || bestScore < req.threshold) continue;

      final labelStr = (bestClass < labels.length) ? labels[bestClass] : 'CLASS_$bestClass';
      if (req.allowedLabels != null && !req.allowedLabels!.contains(labelStr)) {
        continue;
      }

      double nx1, ny1, nx2, ny2;
      if (cx > 1.5 || bw > 1.5) {
        nx1 = ((cx - bw / 2) / req.inputW).clamp(0.0, 1.0);
        ny1 = ((cy - bh / 2) / req.inputH).clamp(0.0, 1.0);
        nx2 = ((cx + bw / 2) / req.inputW).clamp(0.0, 1.0);
        ny2 = ((cy + bh / 2) / req.inputH).clamp(0.0, 1.0);
      } else {
        nx1 = (cx - bw / 2).clamp(0.0, 1.0);
        ny1 = (cy - bh / 2).clamp(0.0, 1.0);
        nx2 = (cx + bw / 2).clamp(0.0, 1.0);
        ny2 = (cy + bh / 2).clamp(0.0, 1.0);
      }

      if (nx2 <= nx1 || ny2 <= ny1) continue; 

      results.add(DetectionResult(
        label: labelStr,
        confidence: bestScore,
        boundingBox: Rect.fromLTRB(nx1, ny1, nx2, ny2),
        classIndex: bestClass,
      ));
    }
    return results;
  }

  double _iou(Rect a, Rect b) {
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

  List<DetectionResult> _nms(List<DetectionResult> detections, double iouThreshold) {
    if (detections.isEmpty) return [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <DetectionResult>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      kept.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i].boundingBox, detections[j].boundingBox) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  // Handle messages
  await for (final msg in receivePort) {
    if (msg is _InferenceWorkerInit) {
      try {
        interpreter = Interpreter.fromBuffer(msg.modelBytes, options: InterpreterOptions()..threads = 4);
        interpreter.allocateTensors();
        
        final inShape = interpreter.getInputTensor(0).shape;
        if (inShape.length >= 4) {
          inputHeight = inShape[1];
          inputWidth = inShape[2];
        }
        
        final outTensor = interpreter.getOutputTensor(0);
        final outShape = outTensor.shape;
        fullOutputShape = outShape;
        outputShape = outShape.length > 1 ? outShape.sublist(1) : outShape;
        isTransposed = outputShape.length >= 2 && outputShape[0] < outputShape[1];

        msg.replyPort.send(_InferenceWorkerReady(
          sendPort: receivePort.sendPort,
          inputW: inputWidth,
          inputH: inputHeight,
        ));
      } catch (e) {
        msg.replyPort.send(e.toString()); // Init error
      }
    } else if (msg is _InferenceRequest) {
      if (interpreter == null) {
        msg.replyPort.send(<DetectionResult>[]);
        continue;
      }

      try {
         // 1. Preprocess
         final inputTensor = preprocessImage(msg);
         
         // 2. Run Inference
         final rawOutput = _buildNestedOutputBuffer(fullOutputShape);
         interpreter.runForMultipleInputs([inputTensor], {0: rawOutput});

         // 3. Postprocess
         final flat = _flattenOutput(rawOutput);
         final detections = _parseOutput(flat, msg);
         final finalResults = _nms(detections, msg.nmsIouThreshold);

          msg.replyPort.send(finalResults);
      } catch (e, stack) {
         debugPrint('[RecognitionService] Isolate runtime error: $e\n$stack');
         msg.replyPort.send(<DetectionResult>[]);
      }
    }
  }
}


/// YOLOv8 TFLite inference service.
///
/// Handles both common export layouts and runs 100% off the UI thread 
/// to ensure extremely smooth frame rates and zero freezing!
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

  static const Map<String, List<String>> _siteLabels = {
    'Sigiriya': labels,
    'Dambulla Cave Temple': <String>[],
    'Polonnaruwa': <String>[],
  };

  static List<String> labelsForSite(String? siteName) {
    if (siteName == null) return const <String>[];
    return List<String>.unmodifiable(_siteLabels[siteName] ?? const <String>[]);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  String? _loadError;
  bool _isInitInProgress = false;

  int _inputWidth = 640;
  int _inputHeight = 640;

  bool get isLoaded => _workerSendPort != null;
  String? get loadError => _loadError;
  int get inputWidth => _inputWidth;
  int get inputHeight => _inputHeight;

  // ── Model loading (Spawns long-lived Isolate) ──────────────────────────────
  Future<void> loadModel() async {
    if (_workerSendPort != null || _isInitInProgress) return;
    _isInitInProgress = true;
    _loadError = null;

    try {
      final modelData = await rootBundle.load('assets/models/landmark_model.tflite');
      
      final initReceivePort = ReceivePort();
      _workerIsolate = await Isolate.spawn(_inferenceIsolateEntry, initReceivePort.sendPort);

      // Wait for isolate to turn on
      final workerPortMsg = await initReceivePort.first;
      if (workerPortMsg is! SendPort) {
        throw Exception("Failed to receive isolate communication port.");
      }
      final workerSendPort = workerPortMsg;

      final readyReceivePort = ReceivePort();
      workerSendPort.send(_InferenceWorkerInit(
        replyPort: readyReceivePort.sendPort, 
        modelBytes: modelData.buffer.asUint8List(),
      ));

      final readyMsg = await readyReceivePort.first;
      if (readyMsg is _InferenceWorkerReady) {
         _workerSendPort = workerSendPort;
         _inputWidth = readyMsg.inputW;
         _inputHeight = readyMsg.inputH;
         debugPrint('[RecognitionService] Fast Background Worker initialized smoothly.');
      } else {
         throw Exception("Isolate initialization failed: $readyMsg");
      }
    } catch (e, stack) {
      _loadError = e.toString();
      debugPrint('[RecognitionService] Failed to load model: $_loadError');
      dispose();
    } finally {
      _isInitInProgress = false;
    }
  }

  void dispose() {
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
  }

  // ── Inference (Zero main-thread blocking) ──────────────────────────────────
  Future<List<DetectionResult>> predictAll(
    CameraImage image, {
    int sensorOrientation = 0,
    double threshold = 0.30,
    double nmsIouThreshold = 0.45,
    Set<String>? allowedLabels,
  }) async {
    if (_workerSendPort == null) await loadModel();
    if (_workerSendPort == null) return [];

    final normalizedAllowedLabels = allowedLabels?.map((l) => l.trim().toLowerCase()).toSet();
    if (normalizedAllowedLabels != null && normalizedAllowedLabels.isEmpty) {
      return [];
    }

    final stopwatch = Stopwatch()..start();
    final planesForIsolate = image.planes
        .map((p) => {
              'bytes': p.bytes,
              'bytesPerRow': p.bytesPerRow,
              'bytesPerPixel': p.bytesPerPixel,
            })
        .toList(growable: false);

    final replyPort = ReceivePort();
    
    _workerSendPort!.send(_InferenceRequest(
      replyPort: replyPort.sendPort,
      width: image.width,
      height: image.height,
      inputW: _inputWidth,
      inputH: _inputHeight,
      format: image.format.group == ImageFormatGroup.yuv420 ? 'yuv420' : 'bgra8888',
      sensorOrientation: sensorOrientation,
      planes: planesForIsolate,
      threshold: threshold,
      nmsIouThreshold: nmsIouThreshold,
      allowedLabels: normalizedAllowedLabels,
    ));

    final result = await replyPort.first;
    
    if (kDebugMode) {
      final list = result as List<DetectionResult>;
      debugPrint('[RecognitionService] Background inference took ${stopwatch.elapsedMilliseconds}ms, found ${list.length} detections');
    }

    return result is List<DetectionResult> ? result : [];
  }

  Future<DetectionResult?> predict(
    CameraImage image, {
    int sensorOrientation = 0,
    double threshold = 0.30,
    Set<String>? allowedLabels,
  }) async {
    final all = await predictAll(image,
        sensorOrientation: sensorOrientation,
        threshold: threshold,
        allowedLabels: allowedLabels);
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }
}
