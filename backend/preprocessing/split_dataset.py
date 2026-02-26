"""
split_dataset.py
────────────────
Splits the raw dataset/ into train / val / test subsets (80 / 10 / 10).

Before:
    dataset/sigiriya/   (all images)

After:
    dataset/train/sigiriya/
    dataset/val/sigiriya/
    dataset/test/sigiriya/

Usage:
    python preprocessing/split_dataset.py
"""

import os
import shutil
import random
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import DATASET_DIR, CLASS_NAMES, TRAIN_DIR, VAL_DIR, TEST_DIR

SPLIT_RATIOS = {"train": 0.80, "val": 0.10, "test": 0.10}
RANDOM_SEED  = 42


def split_dataset(dataset_dir: str) -> None:
    random.seed(RANDOM_SEED)
    dataset_path = Path(dataset_dir)

    for split in ("train", "val", "test"):
        for cls in CLASS_NAMES:
            (dataset_path / split / cls).mkdir(parents=True, exist_ok=True)

    for class_name in CLASS_NAMES:
        class_dir = dataset_path / class_name
        if not class_dir.exists():
            print(f"[WARN] {class_dir} not found – skipping.")
            continue

        images = [
            p for p in class_dir.iterdir()
            if p.suffix.lower() in {".jpg", ".jpeg", ".png"}
               and "_aug" not in p.stem          # keep raw & augmented together
        ]
        # Include augmented images
        images += [
            p for p in class_dir.iterdir()
            if p.suffix.lower() in {".jpg", ".jpeg", ".png"}
               and "_aug" in p.stem
        ]
        # Deduplicate
        images = list(set(images))
        random.shuffle(images)

        n      = len(images)
        n_val  = max(1, int(n * SPLIT_RATIOS["val"]))
        n_test = max(1, int(n * SPLIT_RATIOS["test"]))

        splits = {
            "val":   images[:n_val],
            "test":  images[n_val:n_val + n_test],
            "train": images[n_val + n_test:],
        }

        for split, paths in splits.items():
            dest = dataset_path / split / class_name
            for src in paths:
                shutil.copy2(src, dest / src.name)
            print(f"  [{class_name}] {split}: {len(paths)} images")

    print("\n✅ Dataset split complete.")


if __name__ == "__main__":
    split_dataset(DATASET_DIR)
