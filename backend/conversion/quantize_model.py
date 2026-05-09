"""
quantize_model.py
-----------------
YOLOv8 export: PyTorch checkpoint (.pt) -> INT8 TFLite (.tflite).

Usage:
    python conversion/quantize_model.py \
        --input_model runs/detect/sigiriya_v1/weights/best.pt \
        --output_model backend/output/sigiriya_best_quantized.tflite \
        --data_yaml backend/training/sigiriya_yolov8_data.yaml
"""

import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export YOLOv8 .pt to INT8 TFLite")
    parser.add_argument(
        "--input_model",
        type=str,
        default="runs/detect/sigiriya_v1/weights/best.pt",
        help="Path to YOLO .pt model",
    )
    parser.add_argument(
        "--output_model",
        type=str,
        default="backend/output/sigiriya_best_quantized.tflite",
        help="Target quantized TFLite path",
    )
    parser.add_argument(
        "--data_yaml",
        type=str,
        default="backend/training/sigiriya_yolov8_data.yaml",
        help="YOLO data yaml used for INT8 calibration",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Export image size",
    )
    return parser.parse_args()


def quantize_to_int8(input_model: str, output_model: str, data_yaml: str, imgsz: int) -> Path:
    input_path = Path(input_model)
    if not input_path.exists():
        raise FileNotFoundError(f"Input model not found: {input_model}")
    if input_path.suffix.lower() != ".pt":
        raise ValueError("YOLO INT8 export requires a .pt model file")

    data_path = Path(data_yaml)
    if not data_path.exists():
        raise FileNotFoundError(f"Calibration data yaml not found: {data_yaml}")

    print(f"Loading YOLO model: {input_path}")
    model = YOLO(str(input_path))

    exported_path = Path(
        model.export(
            format="tflite",
            int8=True,
            data=str(data_path),
            imgsz=imgsz,
            nms=True,
        )
    )

    target_path = Path(output_model)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if exported_path.resolve() != target_path.resolve():
        shutil.copy2(exported_path, target_path)
    else:
        target_path = exported_path

    size_mb = target_path.stat().st_size / (1024 * 1024)
    print(f"✅ Quantized TFLite saved -> {target_path} ({size_mb:.2f} MB)")
    return target_path


if __name__ == "__main__":
    args = parse_args()
    quantize_to_int8(args.input_model, args.output_model, args.data_yaml, args.imgsz)
