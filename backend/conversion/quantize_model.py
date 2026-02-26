"""
quantize_model.py
─────────────────
Applies INT8 post-training quantization to the TFLite model
to reduce model size and improve on-device inference speed.

Usage:
    python conversion/quantize_model.py
"""

import glob
import os
import numpy as np
from pathlib import Path
from PIL import Image
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import (
    TFLITE_MODEL_PATH, TFLITE_QUANT_PATH,
    TRAIN_DIR, INPUT_SIZE, CLASS_NAMES
)


def representative_dataset():
    """Yields calibration samples from the training set (100 images)."""
    count = 0
    for class_name in CLASS_NAMES:
        pattern = os.path.join(TRAIN_DIR, class_name, "*.jpg")
        for img_path in glob.glob(pattern)[:34]:    # ~100 total across classes
            img = Image.open(img_path).convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
            arr = np.array(img, dtype=np.float32)
            arr = (arr / 127.5) - 1.0               # normalise to [-1, 1]
            yield [arr[np.newaxis, ...]]             # add batch dimension
            count += 1
    print(f"  Calibration samples used: {count}")


def quantize():
    import tensorflow as tf

    print(f"Loading TFLite model: {TFLITE_MODEL_PATH}")
    converter = tf.lite.TFLiteConverter.from_saved_model(
        str(Path(TFLITE_MODEL_PATH).parent / "tf_saved_model")
    )

    converter.optimizations          = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type   = tf.int8
    converter.inference_output_type  = tf.int8

    quant_model = converter.convert()

    Path(TFLITE_QUANT_PATH).parent.mkdir(parents=True, exist_ok=True)
    with open(TFLITE_QUANT_PATH, "wb") as f:
        f.write(quant_model)

    original_kb = Path(TFLITE_MODEL_PATH).stat().st_size / 1024
    quant_kb    = Path(TFLITE_QUANT_PATH).stat().st_size / 1024
    reduction   = (1 - quant_kb / original_kb) * 100

    print(f"\n✅ Quantized model saved → {TFLITE_QUANT_PATH}")
    print(f"   Original : {original_kb:.1f} KB")
    print(f"   Quantized: {quant_kb:.1f} KB  ({reduction:.1f}% smaller)")


if __name__ == "__main__":
    quantize()
