# ─────────────────────────────────────────────
#  config.py  –  Central configuration
# ─────────────────────────────────────────────

# Class labels (must match dataset folder names)
CLASS_NAMES = ["sigiriya", "dambulla", "polonnaruwa"]
NUM_CLASSES = len(CLASS_NAMES)

# Dataset paths
DATASET_DIR   = "../dataset"
TRAIN_DIR     = "../dataset/train"
VAL_DIR       = "../dataset/val"
TEST_DIR      = "../dataset/test"

# Model
INPUT_SIZE    = 224          # MobileNetV2 input size
BATCH_SIZE    = 32
EPOCHS        = 30
LEARNING_RATE = 0.001
PRETRAINED    = True         # Use ImageNet pretrained weights

# Output paths
MODEL_SAVE_PATH         = "../output/landmark_model.pth"
TFLITE_MODEL_PATH       = "../output/landmark_model.tflite"
TFLITE_QUANT_PATH       = "../output/landmark_model_quantized.tflite"
ONNX_MODEL_PATH         = "../output/landmark_model.onnx"
CLASS_LABELS_JSON       = "../output/class_labels.json"
TRAINING_RESULTS_DIR    = "../output/training_results"

# Embeddings
KNOWLEDGE_BASE_DIR      = "../embeddings/knowledge_base"
EMBEDDINGS_OUTPUT_DIR   = "../embeddings/embeddings_output"
