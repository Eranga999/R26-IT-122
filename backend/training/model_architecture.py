"""
model_architecture.py
─────────────────────
Builds a fine-tuned MobileNetV2 classifier for heritage landmark recognition.

Usage:
    from training.model_architecture import build_model
    model = build_model()
"""

import torch
import torch.nn as nn
from torchvision import models
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import NUM_CLASSES, PRETRAINED


def build_model() -> nn.Module:
    """
    Loads MobileNetV2 with ImageNet weights and replaces the
    classifier head to output NUM_CLASSES logits.
    """
    weights = models.MobileNet_V2_Weights.DEFAULT if PRETRAINED else None
    model   = models.mobilenet_v2(weights=weights)

    # Freeze all base layers (feature extractor)
    for param in model.features.parameters():
        param.requires_grad = False

    # Replace final classifier
    in_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(in_features, NUM_CLASSES),
    )

    return model


def unfreeze_last_n_blocks(model: nn.Module, n: int = 3) -> None:
    """
    Unfreezes the last n convolutional blocks for fine-tuning.
    Call this after initial training to improve accuracy.
    """
    blocks = list(model.features.children())
    for block in blocks[-n:]:
        for param in block.parameters():
            param.requires_grad = True
