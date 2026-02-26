"""
onnx_to_tflite.py
─────────────────
Converts the ONNX model → TensorFlow SavedModel → TensorFlow Lite.

Dependencies:
    pip install onnx-tf tensorflow

Usage:
    python conversion/onnx_to_tflite.py
"""

import os
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import ONNX_MODEL_PATH, TFLITE_MODEL_PATH

TF_SAVED_MODEL_DIR = str(Path(TFLITE_MODEL_PATH).parent / "tf_saved_model")


def convert_onnx_to_tflite():
    # ── Step 1: ONNX → TensorFlow SavedModel ─────────────────────────────
    print("Step 1: Converting ONNX → TensorFlow SavedModel …")
    import onnx
    from onnx_tf.backend import prepare

    onnx_model = onnx.load(ONNX_MODEL_PATH)
    tf_rep     = prepare(onnx_model)
    Path(TF_SAVED_MODEL_DIR).mkdir(parents=True, exist_ok=True)
    tf_rep.export_graph(TF_SAVED_MODEL_DIR)
    print(f"  SavedModel → {TF_SAVED_MODEL_DIR}")

    # ── Step 2: TensorFlow SavedModel → TFLite ────────────────────────────
    print("Step 2: Converting TensorFlow SavedModel → TFLite …")
    import tensorflow as tf

    converter = tf.lite.TFLiteConverter.from_saved_model(TF_SAVED_MODEL_DIR)
    tflite_model = converter.convert()

    Path(TFLITE_MODEL_PATH).parent.mkdir(parents=True, exist_ok=True)
    with open(TFLITE_MODEL_PATH, "wb") as f:
        f.write(tflite_model)

    size_kb = Path(TFLITE_MODEL_PATH).stat().st_size / 1024
    print(f"✅ TFLite model saved → {TFLITE_MODEL_PATH}  ({size_kb:.1f} KB)")


if __name__ == "__main__":
    convert_onnx_to_tflite()
