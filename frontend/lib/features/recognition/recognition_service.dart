import 'dart:typed_data';

/// Stub recognition service – TFLite model integration is pending.
/// Replace with real implementation once the .tflite model file is added.
class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();

  static const List<String> labels = ['Sigiriya', 'Dambulla', 'Polonnaruwa'];

  bool get isLoaded => false;

  Future<void> loadModel() async {}

  void dispose() {}

  Future<({String label, double confidence})?> predict(Uint8List bytes) async {
    return null;
  }
}
