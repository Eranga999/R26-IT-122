"""
dataset_loader.py
─────────────────
PyTorch DataLoader factory for the HeritageAR dataset.

Usage:
    from training.dataset_loader import get_dataloaders
    train_loader, val_loader, test_loader = get_dataloaders()
"""

from pathlib import Path
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import TRAIN_DIR, VAL_DIR, TEST_DIR, INPUT_SIZE, BATCH_SIZE


# ── Transforms ───────────────────────────────────────────────────────────────

TRAIN_TRANSFORMS = transforms.Compose([
    transforms.Resize((INPUT_SIZE, INPUT_SIZE)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),   # ImageNet stats
])

EVAL_TRANSFORMS = transforms.Compose([
    transforms.Resize((INPUT_SIZE, INPUT_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])


# ── Factory ───────────────────────────────────────────────────────────────────

def get_dataloaders(num_workers: int = 2):
    """Returns (train_loader, val_loader, test_loader) and class_names list."""
    train_dataset = datasets.ImageFolder(TRAIN_DIR, transform=TRAIN_TRANSFORMS)
    val_dataset   = datasets.ImageFolder(VAL_DIR,   transform=EVAL_TRANSFORMS)
    test_dataset  = datasets.ImageFolder(TEST_DIR,  transform=EVAL_TRANSFORMS)

    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE,
                              shuffle=True,  num_workers=num_workers)
    val_loader   = DataLoader(val_dataset,   batch_size=BATCH_SIZE,
                              shuffle=False, num_workers=num_workers)
    test_loader  = DataLoader(test_dataset,  batch_size=BATCH_SIZE,
                              shuffle=False, num_workers=num_workers)

    return train_loader, val_loader, test_loader, train_dataset.classes
