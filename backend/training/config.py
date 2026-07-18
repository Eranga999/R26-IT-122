# ─────────────────────────────────────────────
#  config.py  –  Central configuration
# ─────────────────────────────────────────────

# Class labels (must match the extracted Sigiriya dataset folder names)
CLASS_NAMES = [
	"sigiriya_entrance",
	"sigiriya_lion_rock",
	"sigiriya_mirror_wall",
	"sigiriya_lion_staircase",
	"sigiriya_throne",
]
NUM_CLASSES = len(CLASS_NAMES)

# Dataset paths
DATASET_DIR   = "../dataset/sigiriya_dataset"
TRAIN_DIR     = "../dataset/sigiriya_dataset/train"
VAL_DIR       = "../dataset/sigiriya_dataset/valid"
TEST_DIR      = "../dataset/sigiriya_dataset/test"

# Model
INPUT_SIZE    = 640          # YOLOv8 input size
BATCH_SIZE    = 16
EPOCHS        = 100
LEARNING_RATE = 0.001
PRETRAINED    = True         # Use pretrained YOLOv8 weights

# Output paths
MODEL_SAVE_PATH         = "../output/sigiriya_best.pt"
TFLITE_MODEL_PATH       = "../output/sigiriya_best.tflite"
TFLITE_QUANT_PATH       = "../output/sigiriya_best_quantized.tflite"
ONNX_MODEL_PATH         = "../output/sigiriya_best.onnx"
CLASS_LABELS_JSON       = "../output/sigiriya_class_labels.json"
TRAINING_RESULTS_DIR    = "../output/sigiriya_training_results"

# Embeddings
KNOWLEDGE_BASE_DIR      = "../embeddings/knowledge_base"
EMBEDDINGS_OUTPUT_DIR   = "../embeddings/embeddings_output"
