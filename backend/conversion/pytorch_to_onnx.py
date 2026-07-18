"""
pytorch_to_onnx.py
------------------
YOLOv8 export: PyTorch checkpoint (.pt) -> ONNX (.onnx).

Usage:
    python conversion/pytorch_to_onnx.py \
        --input_model runs/detect/sigiriya_v1/weights/best.pt \
        --output_model backend/output/sigiriya_best.onnx
"""

import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export YOLOv8 .pt to ONNX")
    parser.add_argument(
        "--input_model",
        type=str,
        default="runs/detect/sigiriya_v1/weights/best.pt",
        help="Path to YOLO .pt model",
    )
    parser.add_argument(
        "--output_model",
        type=str,
        default="backend/output/sigiriya_best.onnx",
        help="Target ONNX path",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Export image size",
    )
    return parser.parse_args()


def convert_to_onnx(input_model: str, output_model: str, imgsz: int) -> Path:
    input_path = Path(input_model)
    if not input_path.exists():
        raise FileNotFoundError(f"Input model not found: {input_model}")
    if input_path.suffix.lower() != ".pt":
        raise ValueError("YOLO export requires a .pt model file")

    print(f"Loading YOLO model: {input_path}")
    model = YOLO(str(input_path))

    exported_path = Path(
        model.export(
            format="onnx",
            imgsz=imgsz,
            dynamic=True,
            simplify=True,
            opset=13,
        )
    )

    target_path = Path(output_model)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if exported_path.resolve() != target_path.resolve():
        shutil.copy2(exported_path, target_path)
    else:
        target_path = exported_path

    print(f"✅ ONNX model saved -> {target_path}")
    return target_path


if __name__ == "__main__":
    args = parse_args()
    convert_to_onnx(args.input_model, args.output_model, args.imgsz)
