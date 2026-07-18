import os
import shutil
import subprocess

model_path = r"E:\Research Project\R26-IT-122\frontend\lib\features\sigiriya_guide\heritageAR-chatbot\models\all-MiniLM-L6-v2"
output_dir = r"E:\Research Project\R26-IT-122\frontend\assets\models\onnx_export"

# We use optimum-cli to export to ONNX
# The optimum-cli command is automatically installed when you pip install optimum[exporters]
print(f"Exporting model from {model_path} to ONNX format...")
try:
    subprocess.run([
        "optimum-cli", "export", "onnx", 
        "--model", model_path, 
        "--task", "feature-extraction",
        output_dir
    ], check=True)
except subprocess.CalledProcessError as e:
    print(f"Export failed with error code: {e.returncode}")
    print("\nIf you see 'unrecognized arguments: onnx', you need to install the exporters package:")
    print("Run this command in your terminal:  pip install \"optimum[exporters]\"")
    exit(1)

# Copy the exported model to minilm.onnx
onnx_file = os.path.join(output_dir, "model.onnx")
target_file = r"E:\Research Project\R26-IT-122\frontend\assets\models\minilm.onnx"

if os.path.exists(onnx_file):
    shutil.copy(onnx_file, target_file)
    print("Successfully exported and copied minilm.onnx")
else:
    print("Failed to find the exported model.onnx")

