"""
augment_data.py
───────────────
Augments the dataset by applying random flips, rotations, brightness
and contrast adjustments to each image, doubling the dataset size.

Usage:
    python preprocessing/augment_data.py
"""

import os
import random
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps
from tqdm import tqdm
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import DATASET_DIR, CLASS_NAMES


def augment_image(img: Image.Image) -> Image.Image:
    """Applies a random set of augmentations to a PIL image."""
    # Random horizontal flip
    if random.random() > 0.5:
        img = ImageOps.mirror(img)

    # Random rotation ±20°
    angle = random.uniform(-20, 20)
    img = img.rotate(angle, expand=False, fillcolor=(0, 0, 0))

    # Random brightness (0.7 – 1.3)
    factor = random.uniform(0.7, 1.3)
    img = ImageEnhance.Brightness(img).enhance(factor)

    # Random contrast (0.7 – 1.3)
    factor = random.uniform(0.7, 1.3)
    img = ImageEnhance.Contrast(img).enhance(factor)

    return img


def augment_dataset(dataset_dir: str) -> None:
    dataset_path = Path(dataset_dir)

    for class_name in CLASS_NAMES:
        class_dir = dataset_path / class_name
        if not class_dir.exists():
            print(f"[WARN] Directory not found: {class_dir}")
            continue

        originals = list(class_dir.glob("*.jpg")) + \
                    list(class_dir.glob("*.jpeg")) + \
                    list(class_dir.glob("*.png"))

        print(f"[{class_name}] Augmenting {len(originals)} images …")

        for img_path in tqdm(originals, desc=class_name):
            try:
                with Image.open(img_path) as img:
                    aug = augment_image(img.convert("RGB"))
                    aug_name = img_path.stem + "_aug" + img_path.suffix
                    aug.save(class_dir / aug_name)
            except Exception as e:
                print(f"  [ERROR] {img_path.name}: {e}")

    print("\n✅ Augmentation complete.")


if __name__ == "__main__":
    augment_dataset(DATASET_DIR)
