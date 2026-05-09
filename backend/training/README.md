# Backend Training Pipeline
## Function 1 - Landmark Recognition

---

## 📌 Overview

This directory contains the complete training pipeline for **YOLOv8n** landmark detection model.

**Pipeline**: Collect → Annotate → Validate → Train → Evaluate → Convert → Deploy

---

## 📁 File Structure

```
backend/training/
├── README.md                           # This file
├── train_sigiriya_yolov8.py           # ✅ NEW - Task 4: YOLOv8 training
├── evaluate_sigiriya_yolov8.py         # ✅ Task 5: YOLOv8 evaluation
├── sigiriya_yolov8_data.yaml          # ✅ YOLO dataset config (5 classes)
├── sigiriya_sub_landmark_ids.json     # ✅ Class ID mapping
└── sigiriya_sub_landmark_classes.txt  # ✅ Class names reference
```

---

## 🚀 Quick Start

### For Beginners (Google Colab)

```bash
# 1. Mount drive & upload dataset
from google.colab import drive
drive.mount('/content/drive')

# 2. Clone repo
!git clone YOUR_REPO_URL heritage_ar
cd heritage_ar

# 3. Install dependencies
!pip install ultralytics torch torchvision

# 4. Run training
!python backend/training/train_sigiriya_yolov8.py
```

### For Advanced Users (Local GPU)

```bash
# 1. Setup environment
py -3.10 -m venv .venv
.venv\Scripts\activate
pip install -r backend/requirements.txt

# 2. Put the Roboflow export here
# backend/dataset/sigiriya_dataset/
#   ├── train/images
#   ├── train/labels
#   ├── valid/images
#   ├── valid/labels
#   └── test/images
#       └── test/labels

# 3. Train model
cd backend
python training/train_sigiriya_yolov8.py

# 4. Evaluate
python training/evaluate_sigiriya_yolov8.py

# 5. Convert to TFLite
python conversion/onnx_to_tflite.py --input_model runs/detect/sigiriya_v1/weights/best.pt --output_model output/sigiriya_best.tflite

# 6. Test converted model
python conversion/test_tflite_model.py --tflite_model output/sigiriya_best.tflite --data_yaml training/sigiriya_yolov8_data.yaml --split test
```

---

## 📋 Complete Workflow

### Task 1: Data Collection ✅
**Status**: Awaiting user to collect images
**Reference**: [backend/dataset/sigiriya/README.md](../dataset/sigiriya/README.md)

Collect 1,000+ images across 5 classes:
```bash
mkdir -p backend/dataset/sigiriya/{sigiriya_entrance,sigiriya_lion_rock,sigiriya_mirror_wall,sigiriya_lion_staircase,sigiriya_throne}
# Add images to each folder
```

---

### Task 2: Data Annotation ✅
**Status**: Awaiting user to annotate with Roboflow/LabelImg
**Tools**: Roboflow, LabelImg, VGG Annotator
**Output Format**: YOLO (bounding boxes in `.txt` files)

Expected structure after Roboflow export:
```
backend/dataset/sigiriya_dataset/
├── train/images/
├── train/labels/
├── valid/images/
├── valid/labels/
├── test/images/
└── test/labels/                    # .txt files with YOLO format
```

---

### Task 3: Dataset Validation ✅
**Goal**: Ensure YOLO dataset is ready before training.

Validate these items:
- `backend/dataset/sigiriya_dataset/images/{train,val,test}/` exists
- `backend/dataset/sigiriya_dataset/labels/{train,val,test}/` exists
- Image and label filenames match
- Class IDs in label files are only 0-4
- No duplicate images across train/val/test

---

### Task 4: Model Training ✅ NEW
**Script**: `backend/training/train_sigiriya_yolov8.py`
**Model**: YOLOv8n (nano - optimized for mobile)
**Duration**: 30-60 minutes on GPU

#### Local Training
```bash
cd backend
python training/train_sigiriya_yolov8.py
```

#### Colab Training
```python
# Copy to Colab and run
!python backend/training/train_sigiriya_yolov8.py
```

#### Custom Configuration
```python
from backend.training.train_sigiriya_yolov8 import SigiriyaYOLOv8Trainer

trainer = SigiriyaYOLOv8Trainer()
results = trainer.train(
    epochs=100,
    imgsz=640,
    batch=16,
    device=0,  # GPU
)
```

**Output**:
```
runs/detect/sigiriya_v1/
├── weights/
│   ├── best.pt           # ← Use this for conversion
│   └── last.pt
├── results.csv           # Training metrics
└── results.png           # Plots (accuracy/loss curves)
```

---

### Task 5: Model Evaluation ✅
**Script**: `backend/training/evaluate_sigiriya_yolov8.py`
**Metrics**: mAP, precision, recall, F1 score

```bash
cd backend
python training/evaluate_sigiriya_yolov8.py
```

**Expected Output**:
```
mAP@0.5: 87.5%
mAP@0.5:0.95: 82.3%
Precision: 89.2%
Recall: 85.6%
```

**Recording Results**: Update this table in `FUNCTION_1_LANDMARK_RECOGNITION.md`:
```markdown
| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| mAP@0.5 | 87.5% | ≥ 85% | ✅ |
```

---

### Task 6: Model Conversion ✅
**Pipeline**: `.pt` → `.onnx` → `.tflite` → quantized

#### Step 1: PyTorch → ONNX
```bash
cd backend
python conversion/pytorch_to_onnx.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --output_model output/sigiriya_best.onnx
```

#### Step 2: PyTorch → TFLite
```bash
python conversion/onnx_to_tflite.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --output_model output/sigiriya_best.tflite
```

#### Step 3: Quantization
```bash
python conversion/quantize_model.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --data_yaml training/sigiriya_yolov8_data.yaml \
    --output_model output/sigiriya_best_quantized.tflite
```

#### Step 4: Test Converted Model
```bash
python conversion/test_tflite_model.py \
    --tflite_model output/sigiriya_best_quantized.tflite \
    --data_yaml training/sigiriya_yolov8_data.yaml \
    --split test
```

**Output**:
```
backend/output/
└── sigiriya_best_quantized.tflite  # ← Copy to Flutter
```

---

### Task 7: Deployment ✅
**Destination**: `frontend/assets/models/`

```powershell
# Copy converted model to Flutter assets
Copy-Item backend/output/sigiriya_best_quantized.tflite frontend/assets/models/landmark_model.tflite
```

**Verify in Flutter** (`frontend/pubspec.yaml`):
```yaml
flutter:
  assets:
    - assets/models/landmark_model.tflite
```

---

## 📊 Configuration Files

### sigiriya_yolov8_data.yaml
YOLO dataset config - points to train/val/test splits and class names:

```yaml
path: backend/dataset/sigiriya_dataset
train: images/train
val: images/val
test: images/test

names:
  0: sigiriya_entrance
    1: sigiriya_lion_rock
  2: sigiriya_mirror_wall
  3: sigiriya_lion_staircase
    4: sigiriya_throne
```

### sigiriya_sub_landmark_ids.json
Maps class names to unique sub-landmark IDs:

```json
{
  "sigiriya_entrance": "SLM_SIG_001",
    "sigiriya_lion_rock": "SLM_SIG_002",
  "sigiriya_mirror_wall": "SLM_SIG_003",
  "sigiriya_lion_staircase": "SLM_SIG_004",
    "sigiriya_throne": "SLM_SIG_005"
}
```

### sigiriya_sub_landmark_classes.txt
Simple list of class names:

```
sigiriya_entrance
sigiriya_lion_rock
sigiriya_mirror_wall
sigiriya_lion_staircase
sigiriya_throne
```

---

## 🔧 Advanced Configuration

### Train on GPU with Multiple GPUs
```python
# Use DataParallel for multi-GPU training
trainer = SigiriyaYOLOv8Trainer()
trainer.train(device=[0, 1, 2])  # Use GPUs 0, 1, 2
```

### Train on CPU (Slow - Not Recommended)
```python
trainer = SigiriyaYOLOv8Trainer()
trainer.train(device='cpu')  # CPU only (very slow)
```

### Increase Batch Size for Better Convergence
```python
trainer.train(batch=32)  # If GPU has enough VRAM
```

### Decrease Batch Size for Limited GPU Memory
```python
trainer.train(batch=8)  # If 16 causes OOM
```

### Train Longer for Better Accuracy
```python
trainer.train(epochs=150)  # Instead of default 100
```

---

## 📈 Training Monitoring

### TensorBoard Visualization (Optional)
```bash
tensorboard --logdir runs/detect/
```

### Real-Time Metrics
The training script outputs:
- Epoch progress
- Loss values (train, val)
- Accuracy metrics (precision, recall, mAP)
- ETA to completion

### Save Training Logs
```bash
python training/train_sigiriya_yolov8.py | tee training_log.txt
```

---

## ⚠️ Common Issues & Solutions

### Issue: "CUDA out of memory"
**Solution**: Reduce batch size
```python
trainer.train(batch=8)  # from 16
```

### Issue: "Dataset not found"
**Solution**: Verify `sigiriya_yolov8_data.yaml` points to correct paths
```yaml
path: /absolute/path/to/sigiriya_dataset  # Use absolute path if relative fails
```

### Issue: "Model accuracy is low (< 80%)"
**Solutions**:
1. Collect more images (300+ per class)
2. Check bounding box quality (60-95% landmark coverage)
3. Increase training epochs to 150+
4. Use Roboflow augmentation (2x) for more diversity

### Issue: "TFLite inference is slow"
**Solutions**:
1. Use YOLOv8n (nano) - already set
2. Reduce input size: `imgsz=416` instead of 640
3. Enable GPU acceleration in Flutter

### Issue: "Data leakage errors in dataset"
**Solution**:
1. Ensure the same filename does not appear in multiple splits.
2. Re-export split from annotation tool if duplicates are found.

---

## 🎯 Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| mAP@0.5 | ≥ 85% | Mean Average Precision at IoU=0.5 |
| mAP@0.5:0.95 | ≥ 80% | Standard COCO metric |
| Precision | ≥ 88% | Fewer false positives |
| Recall | ≥ 88% | Fewer missed detections |
| F1 Score | ≥ 88% | Balanced precision/recall |
| FPS (Mobile) | ≥ 25 FPS | Real-time inference |
| Model Size | < 50MB | Storage & download |

---

## 📚 Script Reference

### train_sigiriya_yolov8.py
```python
trainer = SigiriyaYOLOv8Trainer(
    dataset_yaml="backend/training/sigiriya_yolov8_data.yaml"
)

results = trainer.train(
    epochs=100,
    imgsz=640,
    batch=16,
    device=0,
    patience=20,
    project="runs/detect",
    name="sigiriya_v1",
)

# Get best model path
best_pt = trainer.get_best_model_path()
```

### evaluate_sigiriya_yolov8.py
```python
# Automatically runs on best model from training

# Metrics reported:
# - mAP@0.5
# - mAP@0.5:0.95
# - Precision per class
# - Recall per class
# - Confusion matrix
```

---

## 🔄 Complete Pipeline Script

Run entire pipeline at once (if starting fresh):

```bash
#!/bin/bash
cd backend

# Step 1: Train
echo "Step 1: Training..."
python training/train_sigiriya_yolov8.py

# Step 2: Evaluate
echo "Step 2: Evaluating..."
python training/evaluate_sigiriya_yolov8.py

# Step 3: Convert
echo "Step 3: Converting to TFLite..."
python conversion/pytorch_to_onnx.py
python conversion/onnx_to_tflite.py
python conversion/quantize_model.py
python conversion/test_tflite_model.py

# Step 4: Deploy
echo "Step 4: Deploying to Flutter..."
cp output/sigiriya_best_quantized.tflite ../frontend/assets/models/landmark_model.tflite

echo "✅ Pipeline complete!"
```

---

## 📖 Next Steps

1. **Collect images** → `backend/dataset/sigiriya/{class_name}/`
2. **Annotate** → Use Roboflow or LabelImg
3. **Organize** → Create `sigiriya_dataset/` structure
4. **Validate** → Check dataset structure and label consistency
5. **Train** → Run `train_sigiriya_yolov8.py`
6. **Evaluate** → Run `evaluate_sigiriya_yolov8.py`
7. **Convert** → Run conversion scripts
8. **Deploy** → Copy to Flutter
9. **Test** → Run on real device at Sigiriya

---

**Last Updated**: April 9, 2026
**Project**: HeritageAR (Function 1 - Landmark Recognition)
**Status**: Ready for data collection and annotation
