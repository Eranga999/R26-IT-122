"""
test_tflite_model.py
--------------------
Validates exported YOLO TFLite model on dataset split.

Usage:
    python conversion/test_tflite_model.py \
        --tflite_model backend/output/sigiriya_best_quantized.tflite \
        --data_yaml backend/training/sigiriya_yolov8_data.yaml \
        --split test
"""

import argparse
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate YOLO TFLite model")
    parser.add_argument(
        "--tflite_model",
        type=str,
        default="backend/output/sigiriya_best_quantized.tflite",
        help="Path to exported TFLite model",
    )
    parser.add_argument(
        "--data_yaml",
        type=str,
        default="backend/training/sigiriya_yolov8_data.yaml",
        help="YOLO data yaml",
    )
    parser.add_argument(
        "--split",
        type=str,
        default="test",
        choices=["train", "val", "test"],
        help="Dataset split for validation",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Validation image size",
    )
    return parser.parse_args()


def test_tflite(model_path: str, data_yaml: str, split: str, imgsz: int) -> None:
    model_file = Path(model_path)
    if not model_file.exists():
        raise FileNotFoundError(f"TFLite model not found: {model_path}")

    data_file = Path(data_yaml)
    if not data_file.exists():
        raise FileNotFoundError(f"Data yaml not found: {data_yaml}")

    model = YOLO(str(model_file))
    results = model.val(data=str(data_file), split=split, imgsz=imgsz)

    print("\n" + "=" * 52)
    print(f"YOLO TFLite Validation ({split})")
    print("=" * 52)
    print(f"mAP@0.5      : {results.box.map50:.4f} ({results.box.map50 * 100:.2f}%)")
    print(f"mAP@0.5:0.95 : {results.box.map:.4f} ({results.box.map * 100:.2f}%)")
    print(f"Precision    : {results.box.p.mean():.4f} ({results.box.p.mean() * 100:.2f}%)")
    print(f"Recall       : {results.box.r.mean():.4f} ({results.box.r.mean() * 100:.2f}%)")
    print("=" * 52)
    print(f"Validation artifacts: {results.save_dir}")


if __name__ == "__main__":
    args = parse_args()
    test_tflite(args.tflite_model, args.data_yaml, args.split, args.imgsz)
