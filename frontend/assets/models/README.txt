Place your trained TensorFlow Lite model here.
Expected filename: landmark_model.tflite

To generate one:
  1. Train a MobileNetV2 classifier in PyTorch (one class per heritage site).
  2. Export to ONNX.
  3. Convert to TFLite via onnx-tf + TFLite converter.
  4. (Optional) Apply int8 quantisation for smaller size.
