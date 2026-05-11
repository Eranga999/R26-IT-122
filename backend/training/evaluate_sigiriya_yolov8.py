"""
evaluate_sigiriya_yolov8.py
---------------------------
Evaluates the best trained YOLOv8 Sigiriya detector on val/test split.

Usage:
  python backend/training/evaluate_sigiriya_yolov8.py
"""

from pathlib import Path

from ultralytics import YOLO


def evaluate(
    model_path: str = "runs/detect/sigiriya_v1/weights/best.pt",
    data_yaml: str = "backend/training/sigiriya_yolov8_data.yaml",
    split: str = "test",
):
    model_file = Path(model_path)
    if not model_file.exists():
        raise FileNotFoundError(
            f"Model not found: {model_path}. Train first with train_sigiriya_yolov8.py"
        )

    model = YOLO(str(model_file))
    results = model.val(data=data_yaml, split=split)

    print("\n" + "=" * 52)
    print(f"YOLOv8 Evaluation ({split})")
    print("=" * 52)
    print(f"mAP@0.5      : {results.box.map50:.4f} ({results.box.map50 * 100:.2f}%)")
    print(f"mAP@0.5:0.95 : {results.box.map:.4f} ({results.box.map * 100:.2f}%)")
    print(f"Precision    : {results.box.p.mean():.4f} ({results.box.p.mean() * 100:.2f}%)")
    print(f"Recall       : {results.box.r.mean():.4f} ({results.box.r.mean() * 100:.2f}%)")
    print("=" * 52)
    print(f"Artifacts saved in: {results.save_dir}")


if __name__ == "__main__":
    evaluate()
