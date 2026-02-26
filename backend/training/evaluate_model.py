"""
evaluate_model.py
─────────────────
Loads the best trained model and evaluates it on the test set.
Prints Accuracy, Precision, Recall, F1 Score and plots a confusion matrix.

Usage:
    python training/evaluate_model.py
"""

import json
import os
from pathlib import Path

import torch
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score,
    f1_score, confusion_matrix, classification_report
)

import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import (
    MODEL_SAVE_PATH, CLASS_LABELS_JSON, TRAINING_RESULTS_DIR, CLASS_NAMES
)
from training.dataset_loader import get_dataloaders
from training.model_architecture import build_model

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


def evaluate():
    _, _, test_loader, class_names = get_dataloaders()

    model = build_model().to(DEVICE)
    model.load_state_dict(torch.load(MODEL_SAVE_PATH, map_location=DEVICE))
    model.eval()

    all_preds, all_labels = [], []

    with torch.no_grad():
        for images, labels in test_loader:
            images = images.to(DEVICE)
            outputs = model(images)
            _, preds = outputs.max(1)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())

    # ── Metrics ────────────────────────────────────────────────────────────
    acc  = accuracy_score(all_labels, all_preds)
    prec = precision_score(all_labels, all_preds, average="weighted", zero_division=0)
    rec  = recall_score(all_labels, all_preds, average="weighted", zero_division=0)
    f1   = f1_score(all_labels, all_preds, average="weighted", zero_division=0)

    print(f"\n{'='*45}")
    print(f"  Test Accuracy  : {acc:.4f}  ({acc*100:.2f}%)")
    print(f"  Precision      : {prec:.4f}")
    print(f"  Recall         : {rec:.4f}")
    print(f"  F1 Score       : {f1:.4f}")
    print(f"{'='*45}\n")
    print(classification_report(all_labels, all_preds,
                                target_names=class_names, zero_division=0))

    # ── Confusion Matrix ───────────────────────────────────────────────────
    Path(TRAINING_RESULTS_DIR).mkdir(parents=True, exist_ok=True)
    cm = confusion_matrix(all_labels, all_preds)
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
                xticklabels=class_names, yticklabels=class_names)
    plt.title("Confusion Matrix")
    plt.ylabel("Actual"); plt.xlabel("Predicted")
    save_path = os.path.join(TRAINING_RESULTS_DIR, "confusion_matrix.png")
    plt.savefig(save_path, bbox_inches="tight")
    plt.close()
    print(f"✅ Confusion matrix saved → {save_path}")


if __name__ == "__main__":
    evaluate()
