"""
resize_images.py
────────────────
Resize every image in dataset/ to 224×224 pixels (MobileNetV2 input size).
Run this FIRST before any other preprocessing step.

Usage:
    python preprocessing/resize_images.py
"""

import os
from pathlib import Path
from PIL import Image
from tqdm import tqdm
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import DATASET_DIR, INPUT_SIZE, CLASS_NAMES

TARGET_SIZE = (INPUT_SIZE, INPUT_SIZE)


def resize_images(dataset_dir: str) -> None:
    dataset_path = Path(dataset_dir)

    for class_name in CLASS_NAMES:
        class_dir = dataset_path / class_name
        if not class_dir.exists():
            print(f"[WARN] Directory not found: {class_dir}")
            continue

        images = list(class_dir.glob("*.jpg")) + \
                 list(class_dir.glob("*.jpeg")) + \
                 list(class_dir.glob("*.png"))

        print(f"[{class_name}] Resizing {len(images)} images …")

        for img_path in tqdm(images, desc=class_name):
            try:
                with Image.open(img_path) as img:
                    img_resized = img.convert("RGB").resize(TARGET_SIZE, Image.LANCZOS)
                    img_resized.save(img_path)
            except Exception as e:
                print(f"  [ERROR] {img_path.name}: {e}")

    print("\n✅ All images resized to", TARGET_SIZE)


if __name__ == "__main__":
    resize_images(DATASET_DIR)
