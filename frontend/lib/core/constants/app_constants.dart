/// Central constants for HeritageAR.
class AppConstants {
  AppConstants._();

  // ── App metadata ─────────────────────────────────────────────────────────
  static const String appName = 'HeritageAR';
  static const String appVersion = '1.0.0';

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const String modelPath = 'assets/models/landmark_model.tflite';
  static const String imagesPath = 'assets/images/';
  static const String embeddingsPath = 'assets/embeddings/';

  // ── Database ──────────────────────────────────────────────────────────────
  static const String dbName = 'heritage_ar.db';
  static const int dbVersion = 2;
  static const String landmarksTable = 'landmarks';
  static const String subLandmarksTable = 'sub_landmarks';

  // ── AI Model ──────────────────────────────────────────────────────────────
  static const int inputImageSize = 224; // MobileNetV2 input size
  static const int numClasses = 10; // Update to match training classes

  // ── UI ────────────────────────────────────────────────────────────────────
  static const double cardBorderRadius = 16.0;
  static const double defaultPadding = 16.0;
}
