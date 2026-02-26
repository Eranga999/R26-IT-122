"""
pytorch_to_onnx.py
──────────────────
Converts the trained PyTorch model (.pth) to ONNX format.

Usage:
    python conversion/pytorch_to_onnx.py
"""

import torch
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import MODEL_SAVE_PATH, ONNX_MODEL_PATH, INPUT_SIZE, NUM_CLASSES
from training.model_architecture import build_model

DEVICE = torch.device("cpu")


def convert_to_onnx():
    print(f"Loading model from: {MODEL_SAVE_PATH}")
    model = build_model().to(DEVICE)
    model.load_state_dict(torch.load(MODEL_SAVE_PATH, map_location=DEVICE))
    model.eval()

    # Dummy input: batch=1, RGB, INPUT_SIZE × INPUT_SIZE
    dummy_input = torch.randn(1, 3, INPUT_SIZE, INPUT_SIZE, device=DEVICE)

    Path(ONNX_MODEL_PATH).parent.mkdir(parents=True, exist_ok=True)

    torch.onnx.export(
        model,
        dummy_input,
        ONNX_MODEL_PATH,
        export_params=True,
        opset_version=11,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
    )

    print(f"✅ ONNX model saved → {ONNX_MODEL_PATH}")


if __name__ == "__main__":
    convert_to_onnx()
