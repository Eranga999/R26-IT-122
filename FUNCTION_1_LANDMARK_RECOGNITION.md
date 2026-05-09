# 🔵 FUNCTION 1 – Landmark Recognition
### *ML Model Training – Camera Feed → Landmark Detection*

---

## 📊 Quick Status

| Task | Status | Script |
|------|--------|--------|
| **Task 1** - Data Collection | ⬜ Pending | Manual (Your responsibility) |
| **Task 2** - Data Annotation | ⬜ Pending | Roboflow / LabelImg |
| **Task 3** - Dataset Validation | 🟡 Ready | `backend/dataset/sigiriya_dataset/` |
| **Task 4** - Model Training | 🟡 Ready | `backend/training/train_sigiriya_yolov8.py` |
| **Task 5** - Model Evaluation | 🟡 Ready | `backend/training/evaluate_sigiriya_yolov8.py` |
| **Task 6** - Model Conversion | 🟡 Ready | `backend/conversion/*.py` |
| **Task 7** - Frontend Integration | 🔴 Pending | `frontend/lib/features/recognition/recognition_service.dart` |

---

## Current Reality Check

- Backend YOLO pipeline (Task 1-6) is prepared and usable.
- Frontend real-time inference is NOT complete yet.
- `recognition_service.dart` is currently a stub and returns no predictions.
- `tflite_flutter` is commented out in `frontend/pubspec.yaml`, so on-device model inference is not active.

---

## �📁 Task 1: Data Collection

### 🎯 Objective
Collect **200-300 images per class** for Sigiriya sub-landmarks.

### 📋 Classes to Collect
```
backend/dataset/sigiriya/
├── sigiriya_entrance/           (200-300 images)
├── sigiriya_lion_rock/          (200-300 images)
├── sigiriya_mirror_wall/        (200-300 images)
├── sigiriya_lion_staircase/     (200-300 images)
└── sigiriya_throne/             (200-300 images)
```

### 📸 Sources
- Google Images
- Flickr (heritage landmark images)
- Kaggle (cultural site datasets)
- Your own photos (5-10% of dataset)
- Stock photo sites (Unsplash, Pexels)

### 💡 Image Requirements
- **Format**: JPEG or PNG
- **Minimum Resolution**: 480×480px (higher is better)
- **Content**: Clear, well-lit images showing the target sub-landmark
- **Diversity**: Different angles, seasons, lighting conditions
- **File Naming**: Descriptive or auto-numbered (e.g., `entrance_001.jpg`, `entrance_002.jpg`)

### ✅ Checklist for Task 1
- [ ] Created folders: `backend/dataset/sigiriya/{class_name}/`
- [ ] Collected ≥200 images for each of 5 classes (minimum 1,000 images total)
- [ ] Images are clear and visible
- [ ] Images cover different angles and lighting conditions
- [ ] **Proceed to Task 2** when ready

---

## 🏷️ Task 2: Data Annotation

### 🎯 Objective
Annotate images with **bounding boxes** in **YOLO format**.

### 📢 Tools (Choose One)

#### Option A: **Roboflow** (Recommended - Cloud-based)
1. Visit [roboflow.com](https://roboflow.com)
2. Create free account
3. Create new project → "Object Detection" → "YOLO v8"
4. Upload all 5 class folders to Roboflow
5. Roboflow will auto-detect and help annotate (or use manual labeling)
6. Set preprocessing:
   - Auto-orient: ✅
   - Resize: 640×640
   - Augmentation: 2x
7. Generate dataset → Download as "YOLO v8" format

#### Option B: **LabelImg** (Local - Manual)
1. Install: `pip install labelImg`
2. Run: `labelImg`
3. Open directory: `backend/dataset/sigiriya/sigiriya_entrance/`
4. Draw bounding box around the landmark
5. Select class name from dropdown (only use the 5 classes below)
6. Save as `.txt` YOLO format (auto-generated)
7. Repeat for all 5 classes

#### Option C: **VGG Image Annotator** (Web-based)
1. Visit [www.robots.ox.ac.uk/~vgg/software/via/](https://www.robots.ox.ac.uk/~vgg/software/via/)
2. Load project → "COCO 1.0"
3. Import images folder
4. Draw boxes and assign class labels (5 classes only)
5. Export as COCO → convert to YOLO format

### 🎨 Annotation Rules
- **Draw ONE box** per image (around the visible target sub-landmark)
- **Use ONLY these 5 class names**:
  ```
  0: sigiriya_entrance
    1: sigiriya_lion_rock
  2: sigiriya_mirror_wall
  3: sigiriya_lion_staircase
    4: sigiriya_throne
  ```
- **Box coverage**: 60-95% of the landmark (not entire image)
- **Format**: YOLO `.txt` format:
  ```
  <class_id> <x_center> <y_center> <width> <height>
  ```
  (All values normalized to 0-1 range)

### ✅ Suitable Augmentation for This Project
Use conservative augmentation because these are fixed heritage structures, not flexible everyday objects.

Recommended settings for `backend/training/train_sigiriya_yolov8.py`:
```python
augment=True
degrees=8
translate=0.05
scale=0.20
shear=0.0
perspective=0.0
fliplr=0.20
flipud=0.0
hsv_h=0.015
hsv_s=0.45
hsv_v=0.30
mosaic=0.20
mixup=0.0
copy_paste=0.0
```

Why this works:
- Small rotation and translation help with camera angle changes.
- Mild color jitter helps with lighting changes.
- Horizontal flip is limited because some heritage views are not fully symmetric.
- Vertical flip stays off because it creates unrealistic landmark views.
- Heavy mosaic, mixup, and perspective warp are kept low to avoid damaging landmark geometry.

### 📁 Expected Output Structure
After annotation, organize as:
```
backend/dataset/sigiriya_dataset/
├── images/
│   ├── train/       (80% of 1,000 = 800 images)
│   ├── val/         (10% of 1,000 = 100 images)
│   └── test/        (10% of 1,000 = 100 images)
└── labels/
    ├── train/       (800 .txt files)
    ├── val/         (100 .txt files)
    └── test/        (100 .txt files)
```

### ✅ Checklist for Task 2
- [ ] All 1,000+ images have bounding box annotations
- [ ] All `.txt` files are in correct YOLO format
- [ ] No float errors (all values 0.0-1.0)
- [ ] Dataset split: 80% train / 10% val / 10% test
- [ ] Total annotated: 800 train + 100 val + 100 test images
- [ ] **Proceed to Task 3** when ready

---

## ⚙️ Task 3: Dataset Validation

### 🎯 Objective
Validate YOLO dataset before training.

### 📊 Required Dataset Structure
```
backend/dataset/sigiriya_dataset/
├── images/
│   ├── train/
│   ├── val/
│   └── test/
└── labels/
        ├── train/
        ├── val/
        └── test/
```

### ✅ Checklist for Task 3
- [ ] Verified `backend/training/sigiriya_yolov8_data.yaml` path and class names
- [ ] Verified images + labels exist for train/val/test
- [ ] Verified image/label file names match
- [ ] Verified all label class IDs are only 0-4
- [ ] Verified no duplicate images across train/val/test
- [ ] **Proceed to Task 4** when ready

---

## 🧠 Task 4: Model Training

### 🎯 Objective
Train **YOLOv8n** detection model on Sigiriya sub-landmarks.

### 🚀 Training on Google Colab (Recommended - Free GPU)

#### Step 1: Setup Colab Environment
```python
# Install YOLOv8
!pip install ultralytics opencv-python

# Clone your dataset
from google.colab import drive
drive.mount('/content/drive')

# Copy dataset to Colab
!cp -r '/content/drive/MyDrive/heritage_ar/backend/dataset/sigiriya_dataset' /content/
```

#### Step 2: Create Training Script
Location: `backend/training/train_sigiriya_yolov8.py`

```python
from ultralytics import YOLO

def train_sigiriya_yolov8():
    # Load pretrained YOLOv8n model
    model = YOLO('yolov8n.pt')
    
    # Train on Sigiriya dataset
    results = model.train(
        data='backend/training/sigiriya_yolov8_data.yaml',  # Config file
        epochs=100,           # Number of training epochs
        imgsz=640,           # Image size
        batch=16,            # Batch size (adjust for GPU memory)
        device=0,            # GPU device (0 for first GPU)
        patience=20,         # Early stopping patience
        save=True,
        plots=True,          # Generate training plots
        project='runs/detect',
        name='sigiriya_v1',
    )
    
    # Save best model
    best_model = results.best
    print(f"Best model saved: {best_model}")
    
    return results

if __name__ == '__main__':
    results = train_sigiriya_yolov8()
```

#### Step 3: Run in Colab
```python
# Execute in Colab cell
exec(open('/content/backend/training/train_sigiriya_yolov8.py').read())
```

### 💻 Training on Local Machine (with NVIDIA GPU)

#### Prerequisites
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install ultralytics opencv-python
```

#### Run Training
```bash
cd backend
python training/train_sigiriya_yolov8.py
```

### ⚙️ Training Configuration

Referenced file: `backend/training/sigiriya_yolov8_data.yaml`
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

### 📈 Training Timeline
- **Duration**: ~30-60 minutes on GPU (100 epochs)
- **Output Location**: `runs/detect/sigiriya_v1/`
- **Key Files**:
  - `runs/detect/sigiriya_v1/weights/best.pt` ← Use this
  - `runs/detect/sigiriya_v1/results.png` (accuracy/loss plots)

### ✅ Checklist for Task 4
- [ ] Training script created: `backend/training/train_sigiriya_yolov8.py`
- [ ] Training completed (≥100 epochs)
- [ ] Best weights saved: `runs/detect/sigiriya_v1/weights/best.pt`
- [ ] Training plots generated (results.png)
- [ ] Training logs reviewed (no errors)
- [ ] **Proceed to Task 5** when ready

---

## 📊 Task 5: Model Evaluation

### 🎯 Objective
Evaluate model performance on test set.

### 🔍 Metrics to Record

| Metric | Target | Command |
|--------|--------|---------|
| **Mean Average Precision** (mAP@0.5) | ≥ 85% | `results.box.map50` |
| **mAP@0.5:0.95** | ≥ 80% | `results.box.map` |
| **Precision (per-class)** | ≥ 88% | See confusion matrix |
| **Recall (per-class)** | ≥ 88% | See confusion matrix |
| **F1 Score** | ≥ 88% | Calculated |
| **Inference Speed** (FPS on mobile) | ≥ 25 FPS | Task 6 |

### 📝 Evaluation Script
Location: `backend/training/evaluate_sigiriya_yolov8.py`

```python
from ultralytics import YOLO
import torch

def evaluate_sigiriya_model():
    # Load trained model
    model = YOLO('runs/detect/sigiriya_v1/weights/best.pt')
    
    # Validate on test set
    results = model.val(
        data='backend/training/sigiriya_yolov8_data.yaml',
        device=0,
    )
    
    # Print metrics
    print(f"mAP@0.5: {results.box.map50:.2%}")
    print(f"mAP@0.5:0.95: {results.box.map:.2%}")
    print(f"Precision: {results.box.p.mean():.2%}")
    print(f"Recall: {results.box.r.mean():.2%}")
    
    return results

if __name__ == '__main__':
    results = evaluate_sigiriya_model()
```

### 🎨 Generate Confusion Matrix
```python
from torch.utils.data import DataLoader
import matplotlib.pyplot as plt

# Create confusion matrix
confusion_matrix = results.confusion_matrix.matrix
plt.imshow(confusion_matrix)
plt.title('Confusion Matrix - Sigiriya Sub-Landmarks')
plt.colorbar()
plt.savefig('backend/output/confusion_matrix.png')
```

### ✅ Checklist for Task 5
- [ ] Ran evaluation script (`evaluate_sigiriya_yolov8.py`)
- [ ] Recorded all metrics in table below
- [ ] Generated confusion matrix
- [ ] Generated accuracy/loss plots (from Task 4)
- [ ] All metrics meet targets or documented
- [ ] **Proceed to Task 6** when ready

### 📊 Results Table

Fill this in with your model's results:

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| mAP@0.5 | ___ % | ≥ 85% | ⬜ |
| mAP@0.5:0.95 | ___ % | ≥ 80% | ⬜ |
| Precision | ___ % | ≥ 88% | ⬜ |
| Recall | ___ % | ≥ 88% | ⬜ |
| F1 Score | ___ % | ≥ 88% | ⬜ |
| FPS (mobile) | ___ FPS | ≥ 25 FPS | ⬜ |

---

## 🔄 Task 6: Model Conversion

### 🎯 Objective
Convert YOLOv8 model → TensorFlow Lite for mobile deployment.

### 🔗 Conversion Pipeline

```
YOLOv8 (.pt)
    ↓
ONNX (.onnx)           [pytorch_to_onnx.py]
    ↓
TFLite (.tflite)       [onnx_to_tflite.py]
    ↓
Quantized TFLite       [quantize_model.py]
    ↓
frontend/assets/models/
```

### 🔧 Conversion Scripts

#### Step 1: PyTorch → ONNX
Location: `backend/conversion/pytorch_to_onnx.py`

```bash
cd backend
python conversion/pytorch_to_onnx.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --output_model output/sigiriya_best.onnx
```

#### Step 2: PyTorch → TFLite
Location: `backend/conversion/onnx_to_tflite.py`

```bash
python conversion/onnx_to_tflite.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --output_model output/sigiriya_best.tflite
```

#### Step 3: Quantization (INT8)
Location: `backend/conversion/quantize_model.py`

```bash
python conversion/quantize_model.py \
    --input_model runs/detect/sigiriya_v1/weights/best.pt \
    --data_yaml training/sigiriya_yolov8_data.yaml \
    --output_model output/sigiriya_best_quantized.tflite
```

#### Step 4: Test Converted Model
Location: `backend/conversion/test_tflite_model.py`

```bash
python conversion/test_tflite_model.py \
    --tflite_model output/sigiriya_best_quantized.tflite \
    --data_yaml training/sigiriya_yolov8_data.yaml \
    --split test
```

### 📦 Copy to Flutter Assets

```powershell
# Copy quantized model to Flutter
Copy-Item backend/output/sigiriya_best_quantized.tflite frontend/assets/models/landmark_model.tflite

# Or for sub-landmarks specifically
Copy-Item backend/output/sigiriya_best_quantized.tflite frontend/assets/models/sigiriya_sublandmarks_model.tflite
```

### ✅ Checklist for Task 6
- [ ] Ran pytorch_to_onnx.py (created .onnx file)
- [ ] Ran onnx_to_tflite.py (created .tflite file)
- [ ] Ran quantize_model.py (created quantized .tflite)
- [ ] Ran test_tflite_model.py (verified accuracy)
- [ ] Copied .tflite to `frontend/assets/models/landmark_model.tflite`
- [ ] File size < 50MB
- [ ] **Proceed to Task 7** when ready

---

### Task 7: Frontend Integration & Output Delivery

### 🎯 Objective
Integrate the converted model into Flutter and ensure output format is correct for downstream systems.

### 📋 Expected Output Format

Your model's inference MUST output this JSON structure:

```json
{
  "landmark_id": "LM_001",          // Primary landmark (e.g., Sigiriya)
  "sub_landmark_id": "SLM_SIG_001", // Sub-landmark (entrance, water_gardens, etc.)
  "landmark_name": "Sigiriya",      // Human-readable name
  "sub_landmark_name": "Entrance",  // Sub-landmark human-readable name
  "confidence_score": 0.94,         // Detection confidence (0.0-1.0)
  "bounding_box": {
    "x": 120,                       // Box top-left x (pixels)
    "y": 85,                        // Box top-left y (pixels)
    "width": 300,                   // Box width (pixels)
    "height": 250,                  // Box height (pixels)
    "x_center_normalized": 0.35,    // Normalized x_center (0.0-1.0)  
    "y_center_normalized": 0.28,    // Normalized y_center (0.0-1.0)
    "width_normalized": 0.42,       // Normalized width (0.0-1.0)
    "height_normalized": 0.38       // Normalized height (0.0-1.0)
  },
  "timestamp": "2026-04-09T14:30:00Z", // ISO timestamp
  "model_version": "yolov8n_v1"    // Model identifier
}
```

### 🔗 Sub-Landmark ID Mapping

Reference file: `backend/training/sigiriya_sub_landmark_ids.json`

```json
{
  "sigiriya_entrance": "SLM_SIG_001",
    "sigiriya_lion_rock": "SLM_SIG_002",
  "sigiriya_mirror_wall": "SLM_SIG_003",
  "sigiriya_lion_staircase": "SLM_SIG_004",
    "sigiriya_throne": "SLM_SIG_005"
}
```

### 🔧 Flask API Example (Optional - for Teammates)

```python
# backend/app.py (if serving via API)
from flask import Flask, request, jsonify
from ultralytics import YOLO
import cv2
import json
from datetime import datetime

app = Flask(__name__)
model = YOLO('output/sigiriya_best_quantized.tflite')

SUB_LANDMARK_MAP = {
    0: {"id": "SLM_SIG_001", "name": "Entrance"},
    1: {"id": "SLM_SIG_002", "name": "Water Gardens"},
    2: {"id": "SLM_SIG_003", "name": "Mirror Wall"},
    3: {"id": "SLM_SIG_004", "name": "Lion Staircase"},
    4: {"id": "SLM_SIG_005", "name": "Summit"},
}

@app.route('/predict', methods=['POST'])
def predict():
    image = request.files['image']
    img = cv2.imread(image)
    results = model(img)[0]
    
    output = []
    for detection in results.boxes:
        cls_id = int(detection.cls[0])
        conf = float(detection.conf[0])
        box = detection.xyxy[0].tolist()  # [x1, y1, x2, y2]
        
        x, y, w, h = box[0], box[1], box[2]-box[0], box[3]-box[1]
        
        output.append({
            "landmark_id": "LM_001",
            "sub_landmark_id": SUB_LANDMARK_MAP[cls_id]["id"],
            "landmark_name": "Sigiriya",
            "sub_landmark_name": SUB_LANDMARK_MAP[cls_id]["name"],
            "confidence_score": conf,
            "bounding_box": {
                "x": int(x),
                "y": int(y),
                "width": int(w),
                "height": int(h),
                "x_center_normalized": (x + w/2) / img.shape[1],
                "y_center_normalized": (y + h/2) / img.shape[0],
                "width_normalized": w / img.shape[1],
                "height_normalized": h / img.shape[0]
            },
            "timestamp": datetime.now().isoformat() + "Z",
            "model_version": "yolov8n_v1"
        })
    
    return jsonify(output)

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

### ✅ Checklist for Task 7
- [ ] Enable `tflite_flutter` in `frontend/pubspec.yaml`
- [ ] Implement real model loading and inference in `frontend/lib/features/recognition/recognition_service.dart`
- [ ] Map predicted class names to IDs in `backend/training/sigiriya_sub_landmark_ids.json`
- [ ] Model outputs JSON format with all required fields
- [ ] landmark_id = "LM_001" (Sigiriya)
- [ ] sub_landmark_id correctly mapped (SLM_SIG_001-005)
- [ ] confidence_score is float 0.0-1.0
- [ ] bounding_box contains x, y, width, height in pixels
- [ ] bounding_box contains normalized coordinates
- [ ] timestamp is ISO 8601 format
- [ ] model_version = "yolov8n_v1" or your version
- [ ] **READY FOR TEAMMATES** ✅

---

## ✅ Function 1 Final Checklist

| Task | Description | Status |
|------|-------------|--------|
| **Task 1** | Dataset collected (1,000+ images) | ⬜ Pending |
| **Task 2** | Bounding boxes annotated (YOLO format) | ⬜ Pending |
| **Task 3** | Dataset validated (YOLO structure & labels) | ⬜ Pending |
| **Task 4** | Model trained (YOLOv8n, 100 epochs) | ⬜ Pending |
| **Task 5** | Model evaluated (metrics recorded) | ⬜ Pending |
| **Task 6** | Converted to TFLite (quantized) | ⬜ Pending |
| **Task 7** | JSON output format verified | ⬜ Pending |
| **FINAL** | Model delivered to frontend | ⬜ Pending |

---

## 🔗 Related Functions

**Function 2** – AR Visualization (receives output from Task 7)
**Function 3** – Database Lookup (uses landmark_id for info retrieval)
**Function 4** – Offline RAG (uses sub_landmark_name for context)

---

## 📝 Notes & Best Practices

### ⚠️ Common Mistakes to Avoid
1. ❌ Using mismatched image/label filenames
2. ❌ Using different normalization for train vs. test
3. ❌ Images < 480×480 (too small for detection)
4. ❌ Forgetting to use exact 5 class names
5. ❌ Not checking for data leakage between train/val/test

### 💡 Tips for Better Results
1. ✅ Collect diverse images (different angles, seasons, lighting)
2. ✅ Ensure bounding boxes are consistent (60-95% landmark coverage)
3. ✅ Use Roboflow 2x augmentation to double dataset size
4. ✅ Train for ≥100 epochs (don't stop early)
5. ✅ Use mAP@0.5 as primary metric (not just accuracy)

### 🆘 Troubleshooting

**Problem**: Model accuracy is low (< 80%)
- Solution: More images needed (collect 300+ per class)
- Solution: Check bounding boxes (may be incorrectly labeled)
- Solution: Increase epochs to 150+

**Problem**: TFLite inference is slow (< 10 FPS)
- Solution: Use YOLOv8n (nano) for mobile
- Solution: Reduce image size to 416×416
- Solution: Enable GPU acceleration in Flutter

**Problem**: Data leakage errors
- Solution: Ensure the same image filename does not appear in multiple splits
- Solution: Remove old augmented images before preprocessing

---

## 📚 References

- [YOLOv8 Official Docs](https://docs.ultralytics.com/)
- [Roboflow Object Detection Guide](https://roboflow.com/formats/yolov8-pytorch)
- [TensorFlow Lite Documentation](https://www.tensorflow.org/lite)
- [TFLite Flutter Plugin](https://pub.dev/packages/tflite_flutter)

---

**Last Updated**: April 9, 2026  
**Status**: Ready for Data Collection  
**Next Step**: Begin collecting Sigiriya sub-landmark images (Task 1)
