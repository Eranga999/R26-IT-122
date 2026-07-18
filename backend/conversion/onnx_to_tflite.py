"""
onnx_to_tflite.py
-----------------
YOLOv8 export: PyTorch checkpoint (.pt) -> TensorFlow Lite (.tflite).

Note: script name is kept for backward compatibility in docs, but YOLO export
works best directly from .pt rather than converting from .onnx.

Usage:
    python conversion/onnx_to_tflite.py \
        --input_model runs/detect/sigiriya_v1/weights/best.pt \
        --output_model backend/output/sigiriya_best.tflite
"""

import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export YOLOv8 .pt to TFLite")
    parser.add_argument(
        "--input_model",
        type=str,
        default="runs/detect/sigiriya_v1/weights/best.pt",
        help="Path to YOLO .pt model",
    )
    parser.add_argument(
        "--output_model",
        type=str,
        default="backend/output/sigiriya_best.tflite",
        help="Target TFLite path",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Export image size",
    )
    return parser.parse_args()


def convert_to_tflite(input_model: str, output_model: str, imgsz: int) -> Path:
    input_path = Path(input_model)
    if not input_path.exists():
        raise FileNotFoundError(f"Input model not found: {input_model}")
    if input_path.suffix.lower() != ".pt":
        raise ValueError(
            "YOLO TFLite export expects a .pt model file. "
            "Use runs/detect/.../best.pt as --input_model."
        )

    print(f"Loading YOLO model: {input_path}")
    model = YOLO(str(input_path))

    exported_path = Path(
        model.export(
            format="tflite",
            imgsz=imgsz,
            int8=False,
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
    print(f"✅ TFLite model saved -> {target_path} ({size_mb:.2f} MB)")
    return target_path


if __name__ == "__main__":
    args = parse_args()
    convert_to_tflite(args.input_model, args.output_model, args.imgsz)
