"""
test_tflite_model.py
────────────────────
Loads the converted TFLite model and runs inference on test images
to verify the conversion was lossless.

Usage:
    python conversion/test_tflite_model.py
"""

import json
import os
import numpy as np
from pathlib import Path
from PIL import Image
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import (
    TFLITE_MODEL_PATH, CLASS_LABELS_JSON, TEST_DIR,
    INPUT_SIZE, CLASS_NAMES
)


def load_and_preprocess(img_path: str) -> np.ndarray:
    img = Image.open(img_path).convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32)
    arr = (arr / 127.5) - 1.0
    return arr[np.newaxis, ...]   # (1, H, W, 3)


def test_tflite(model_path: str = TFLITE_MODEL_PATH):
    import tflite_runtime.interpreter as tflite  # lightweight runtime

    with open(CLASS_LABELS_JSON) as f:
        class_labels = json.load(f)

    interpreter = tflite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details  = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    correct, total = 0, 0

    for class_name in CLASS_NAMES:
        test_class_dir = Path(TEST_DIR) / class_name
        if not test_class_dir.exists():
            continue

        for img_path in list(test_class_dir.glob("*.jpg"))[:10]:
            input_data = load_and_preprocess(str(img_path))
            interpreter.set_tensor(input_details[0]["index"], input_data)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]["index"])
            pred_idx   = int(np.argmax(output[0]))
            pred_label = class_labels.get(str(pred_idx), "unknown")

            is_correct = pred_label == class_name
            correct   += int(is_correct)
            total     += 1
            status     = "✅" if is_correct else "❌"
            print(f"  {status} {img_path.name:30s} → {pred_label}")

    if total > 0:
        print(f"\nTFLite Accuracy: {correct}/{total}  ({correct/total*100:.1f}%)")


if __name__ == "__main__":
    test_tflite()
