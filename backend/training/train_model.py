"""
train_model.py
──────────────
Main training script for the HeritageAR landmark classifier.

Steps:
  1. Load dataset via DataLoader
  2. Build MobileNetV2 model
  3. Train with Cross-Entropy loss + Adam optimizer
  4. Save best model checkpoint
  5. Plot accuracy / loss curves

Usage:
    python training/train_model.py
"""

import json
import os
import time
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
import matplotlib.pyplot as plt

import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import (
    EPOCHS, LEARNING_RATE, MODEL_SAVE_PATH,
    CLASS_LABELS_JSON, TRAINING_RESULTS_DIR
)
from training.dataset_loader import get_dataloaders
from training.model_architecture import build_model

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ── Helpers ───────────────────────────────────────────────────────────────────

def train_one_epoch(model, loader, criterion, optimizer):
    model.train()
    running_loss, correct, total = 0.0, 0, 0
    for images, labels in loader:
        images, labels = images.to(DEVICE), labels.to(DEVICE)
        optimizer.zero_grad()
        outputs = model(images)
        loss    = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * images.size(0)
        _, predicted  = outputs.max(1)
        correct       += predicted.eq(labels).sum().item()
        total         += labels.size(0)

    return running_loss / total, correct / total


def evaluate(model, loader, criterion):
    model.eval()
    running_loss, correct, total = 0.0, 0, 0
    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            outputs  = model(images)
            loss     = criterion(outputs, labels)
            running_loss += loss.item() * images.size(0)
            _, predicted  = outputs.max(1)
            correct       += predicted.eq(labels).sum().item()
            total         += labels.size(0)
    return running_loss / total, correct / total


def save_plots(history: dict, results_dir: str) -> None:
    Path(results_dir).mkdir(parents=True, exist_ok=True)

    # Accuracy plot
    plt.figure()
    plt.plot(history["train_acc"], label="Train Accuracy")
    plt.plot(history["val_acc"],   label="Val Accuracy")
    plt.xlabel("Epoch"); plt.ylabel("Accuracy")
    plt.title("Training vs Validation Accuracy")
    plt.legend(); plt.grid(True)
    plt.savefig(os.path.join(results_dir, "accuracy_plot.png"))
    plt.close()

    # Loss plot
    plt.figure()
    plt.plot(history["train_loss"], label="Train Loss")
    plt.plot(history["val_loss"],   label="Val Loss")
    plt.xlabel("Epoch"); plt.ylabel("Loss")
    plt.title("Training vs Validation Loss")
    plt.legend(); plt.grid(True)
    plt.savefig(os.path.join(results_dir, "loss_plot.png"))
    plt.close()

    print(f"✅ Plots saved to {results_dir}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print(f"\nUsing device: {DEVICE}\n")

    train_loader, val_loader, _, class_names = get_dataloaders()
    print(f"Classes: {class_names}")

    # Save class labels
    Path(CLASS_LABELS_JSON).parent.mkdir(parents=True, exist_ok=True)
    with open(CLASS_LABELS_JSON, "w") as f:
        json.dump({i: name for i, name in enumerate(class_names)}, f, indent=2)
    print(f"Class labels saved → {CLASS_LABELS_JSON}")

    model     = build_model().to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=LEARNING_RATE
    )
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=10, gamma=0.5)

    history   = {"train_loss": [], "train_acc": [],
                 "val_loss":   [], "val_acc":   []}
    best_val_acc = 0.0

    Path(MODEL_SAVE_PATH).parent.mkdir(parents=True, exist_ok=True)

    for epoch in range(1, EPOCHS + 1):
        t0 = time.time()
        train_loss, train_acc = train_one_epoch(model, train_loader, criterion, optimizer)
        val_loss,   val_acc   = evaluate(model, val_loader, criterion)
        scheduler.step()

        history["train_loss"].append(train_loss)
        history["train_acc"].append(train_acc)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)

        elapsed = time.time() - t0
        print(f"Epoch [{epoch:>3}/{EPOCHS}] "
              f"Train Loss: {train_loss:.4f}  Acc: {train_acc:.4f} | "
              f"Val Loss: {val_loss:.4f}  Acc: {val_acc:.4f} | "
              f"{elapsed:.1f}s")

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save(model.state_dict(), MODEL_SAVE_PATH)
            print(f"  ✅ Best model saved (val_acc={best_val_acc:.4f})")

    save_plots(history, TRAINING_RESULTS_DIR)
    print(f"\n🏁 Training complete. Best val accuracy: {best_val_acc:.4f}")


if __name__ == "__main__":
    main()
