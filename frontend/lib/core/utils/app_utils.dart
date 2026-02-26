import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Miscellaneous utility helpers.
class AppUtils {
  AppUtils._();

  /// Shows a [SnackBar] with [message] on the current scaffold.
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Normalises a pixel value from [0, 255] → [-1, 1] (MobileNetV2 range).
  static double normalisePixel(int pixel) => (pixel / 127.5) - 1.0;

  /// Returns the index of the maximum value in [scores].
  static int argMax(List<double> scores) {
    int idx = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[idx]) idx = i;
    }
    return idx;
  }

  /// Converts raw RGBA [Uint8List] to a flat Float32 input tensor whose
  /// values are normalised to [-1, 1].
  static Float32List rgbaToFloat32(Uint8List rgba, int width, int height) {
    final tensor = Float32List(1 * height * width * 3);
    int offset = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      tensor[offset++] = normalisePixel(rgba[i]); // R
      tensor[offset++] = normalisePixel(rgba[i + 1]); // G
      tensor[offset++] = normalisePixel(rgba[i + 2]); // B
      // Alpha channel is discarded.
    }
    return tensor;
  }
}
