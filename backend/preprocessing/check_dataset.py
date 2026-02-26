"""
check_dataset.py
────────────────
Verifies the dataset is ready before training.
Prints image counts per class and flags any issues.

Usage:
    python preprocessing/check_dataset.py
"""

from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import DATASET_DIR, CLASS_NAMES

MIN_IMAGES_PER_CLASS = 100


def check_dataset(dataset_dir: str) -> None:
    dataset_path = Path(dataset_dir)
    all_ok = True

    print(f"\n{'Class':<20} {'Count':>8}  Status")
    print("─" * 40)

    for class_name in CLASS_NAMES:
        class_dir = dataset_path / class_name
        if not class_dir.exists():
            print(f"{class_name:<20} {'—':>8}  ❌ Directory missing")
            all_ok = False
            continue

        images = list(class_dir.glob("*.jpg")) + \
                 list(class_dir.glob("*.jpeg")) + \
                 list(class_dir.glob("*.png"))
        count  = len(images)
        status = "✅" if count >= MIN_IMAGES_PER_CLASS else "⚠️  (need more images)"
        print(f"{class_name:<20} {count:>8}  {status}")
        if count < MIN_IMAGES_PER_CLASS:
            all_ok = False

    print()
    if all_ok:
        print("✅ Dataset looks good – ready for preprocessing.")
    else:
        print("⚠️  Fix the issues above before continuing.")


if __name__ == "__main__":
    check_dataset(DATASET_DIR)
