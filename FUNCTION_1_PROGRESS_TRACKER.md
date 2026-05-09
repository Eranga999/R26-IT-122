# Function 1 Progress Tracker
## Landmark Recognition - Model Training

---

## 📊 Overall Status

**Project**: HeritageAR - Heritage Site Detection AR
**Function**: Function 1 - Landmark Recognition (Yours)
**Start Date**: April 9, 2026
**Target Completion**: When all 7 tasks ✅

---

## ✅ Task Completion Checklist

### Task 1: Data Collection
**Status**: ⬜ **PENDING**  
**Description**: Collect 200-300 images per Sigiriya sub-landmark class (1,000+ total)
**Deadline**: -
**Location**: `backend/dataset/sigiriya/{class_name}/`

**Sub-tasks**:
- [ ] Created folder: `backend/dataset/sigiriya/sigiriya_entrance/`
- [ ] Created folder: `backend/dataset/sigiriya/sigiriya_water_gardens/`
- [ ] Created folder: `backend/dataset/sigiriya/sigiriya_mirror_wall/`
- [ ] Created folder: `backend/dataset/sigiriya/sigiriya_lion_staircase/`
- [ ] Created folder: `backend/dataset/sigiriya/sigiriya_summit/`
- [ ] Collected ≥200 images for entrance class
- [ ] Collected ≥200 images for water_gardens class
- [ ] Collected ≥200 images for mirror_wall class
- [ ] Collected ≥200 images for lion_staircase class
- [ ] Collected ≥200 images for summit class
- [ ] **Total images**: ____ / 1,000+
- [ ] Images are clear and visible
- [ ] Images show good diversity (angles, lighting, seasons)

**Notes**:
```
Start date: _______
End date: _______
Total images collected: _______
Source breakdown:
  - Google Images: _____
  - Flickr: _____
  - Kaggle: _____
  - Own photos: _____
  - Other: _____
```

---

### Task 2: Data Annotation
**Status**: ⬜ **PENDING**  
**Description**: Draw bounding boxes on all images using Roboflow or LabelImg (YOLO format)
**Deadline**: -
**Tool Used**: [ ] Roboflow   [ ] LabelImg   [ ] Other: _______

**Sub-tasks**:
- [ ] Tool installed and configured
- [ ] All 1,000 images uploaded to annotation tool
- [ ] Class IDs correctly set (0-4 for 5 classes)
- [ ] All images have ≥1 bounding box annotation
- [ ] All bounding boxes follow rules (60-95% landmark coverage)
- [ ] Coordinates are normalized (0.0-1.0 range)
- [ ] No coordinate errors detected
- [ ] Dataset split configured: 80% train / 10% val / 10% test
- [ ] Downloaded annotations in YOLO format
- [ ] Created directory structure: `sigiriya_dataset/images/{train,val,test}/`
- [ ] Created directory structure: `sigiriya_dataset/labels/{train,val,test}/`
- [ ] All .txt files in correct YOLO format

**Statistics**:
```
Total images: 1,000+
├── Train images: 800 (80%)
├── Val images: 100 (10%)
├── Test images: 100 (10%)

Annotations verified:
├── Train: ____ (should be 800)
├── Val: ____ (should be 100)
├── Test: ____ (should be 100)
```

**Notes**:
```
Annotation tool: _______
Tool version: _______
Start date: _______
End date: _______
Total time spent: _______
Issues encountered: _______
```

---

### Task 3: Dataset Validation
**Status**: ⬜ **NOT STARTED**  
**Description**: Prepare YOLO dataset and verify structure
**Location**: `backend/dataset/sigiriya_dataset/` and `backend/training/sigiriya_yolov8_data.yaml`
**Duration**: ~5-10 minutes

**Sub-tasks**:
- [ ] Verified `backend/training/sigiriya_yolov8_data.yaml` path and class names
- [ ] Verified `backend/dataset/sigiriya_dataset/images/{train,val,test}/`
- [ ] Verified `backend/dataset/sigiriya_dataset/labels/{train,val,test}/`
- [ ] Verified image/label filename pairs match
- [ ] Verified no empty label files unless image truly has no object
- [ ] Verified class IDs are 0-4 only
- [ ] Optional: used Roboflow export preprocessing/augmentation settings
- [ ] **Final dataset ready**: `backend/dataset/sigiriya_dataset/`

**Output Verification**:
```
Folder structure:
├── images/train/: ____ files
├── images/val/: ____ files (should be 100)
├── images/test/: ____ files (should be 100)
├── labels/train/: ____ files
├── labels/val/: ____ files (should be 100)
└── labels/test/: ____ files (should be 100)
```

Note:
- `backend/preprocessing/*.py` currently follows an older classification pipeline and is not required for the YOLO `sigiriya_dataset` flow.

**Notes**:
```
Start date: _______
End date: _______
Command output: _______
Any errors: _______
```

---

### Task 4: Model Training
**Status**: ⬜ **NOT STARTED**  
**Description**: Train YOLOv8n on Sigiriya dataset
**Location**: `backend/training/train_sigiriya_yolov8.py`
**Duration**: 30-60 minutes (GPU required)
**Platform**: [ ] Local GPU   [ ] Google Colab   [ ] Other: _______

**Sub-tasks**:
- [ ] Installed YOLOv8 (`pip install ultralytics`)
- [ ] Verified GPU availability (or Colab GPU activated)
- [ ] Reviewed training script configuration
- [ ] Dataset config verified: `sigiriya_yolov8_data.yaml`
- [ ] Started training: `python training/train_sigiriya_yolov8.py`
- [ ] Training completed without errors
- [ ] Best model saved: `runs/detect/sigiriya_v1/weights/best.pt`
- [ ] Training plots generated: `results.png`
- [ ] Training CSV saved: `results.csv`

**Training Configuration**:
```
Epochs: 100
Image Size: 640
Batch Size: 16
Device: GPU-0 / CPU
Learning Rate: (auto)
Optimizer: SGD
```

**Output Files**:
```
runs/detect/sigiriya_v1/
├── weights/
│   ├── best.pt: ✅ REQUIRED FOR NEXT STEP
│   └── last.pt: (optional backup)
├── results.csv: Training metrics log
└── results.png: Accuracy/loss plots
```

**Training Log**:
```
Start date: _______
End date: _______
Total time: _______
Final epochs trained: _______
GPU memory used: _______
Training error/loss: _______
Any issues: _______
```

---

### Task 5: Model Evaluation
**Status**: ⬜ **NOT STARTED**  
**Description**: Evaluate model performance on test set
**Location**: `backend/training/evaluate_sigiriya_yolov8.py`
**Duration**: ~5 minutes

**Sub-tasks**:
- [ ] Run evaluation script: `python training/evaluate_sigiriya_yolov8.py`
- [ ] mAP@0.5 measured
- [ ] mAP@0.5:0.95 measured
- [ ] Per-class precision recorded
- [ ] Per-class recall recorded
- [ ] Confusion matrix generated
- [ ] Accuracy/loss plots reviewed
- [ ] All metrics meet or exceed targets

**Evaluation Results**:

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| **mAP@0.5** | ___% | ≥ 85% | ⬜ |
| **mAP@0.5:0.95** | ___% | ≥ 80% | ⬜ |
| **Precision** | ___% | ≥ 88% | ⬜ |
| **Recall** | ___% | ≥ 88% | ⬜ |
| **F1 Score** | ___% | ≥ 88% | ⬜ |

**Per-Class Breakdown**:
```
Class 0 (sigiriya_entrance):
  - Precision: ___% | Recall: ___% | F1: ___%

Class 1 (sigiriya_water_gardens):
  - Precision: ___% | Recall: ___% | F1: ___%

Class 2 (sigiriya_mirror_wall):
  - Precision: ___% | Recall: ___% | F1: ___%

Class 3 (sigiriya_lion_staircase):
  - Precision: ___% | Recall: ___% | F1: ___%

Class 4 (sigiriya_summit):
  - Precision: ___% | Recall: ___% | F1: ___%
```

**Evaluation Notes**:
```
Start date: _______
End date: _______
Observations: _______
Issues found: _______
Recommendations: _______
```

---

### Task 6: Model Conversion
**Status**: ⬜ **NOT STARTED**  
**Description**: Convert PyTorch → ONNX → TFLite → Quantized
**Location**: `backend/conversion/*.py`
**Duration**: ~10-20 minutes

**Sub-tasks**:

#### Step 1: PyTorch → ONNX
- [ ] Run: `python conversion/pytorch_to_onnx.py`
- [ ] Output: `backend/output/sigiriya_best.onnx`
- [ ] File size: ____ MB
- [ ] Verified no errors

#### Step 2: ONNX → TFLite
- [ ] Run: `python conversion/onnx_to_tflite.py`
- [ ] Output: `backend/output/sigiriya_best.tflite`
- [ ] File size: ____ MB
- [ ] Verified no errors

#### Step 3: Quantization
- [ ] Run: `python conversion/quantize_model.py`
- [ ] Output: `backend/output/sigiriya_best_quantized.tflite`
- [ ] File size: ____ MB (should be < 50MB)
- [ ] Verified no errors

#### Step 4: Test Converted Model
- [ ] Run: `python conversion/test_tflite_model.py`
- [ ] Test accuracy: ___% (compare with best.pt)
- [ ] Inference time: ___ ms per image
- [ ] No conversion errors

**Conversion Pipeline**:
```
best.pt (PyTorch)
  ↓ [pytorch_to_onnx.py]
sigiriya_best.onnx
  ↓ [onnx_to_tflite.py from best.pt]
sigiriya_best.tflite
  ↓ [quantize_model.py from best.pt + data.yaml]
sigiriya_best_quantized.tflite  ← FINAL
```

**Output Files**:
```
backend/output/
├── sigiriya_best.onnx: ___ MB
├── sigiriya_best.tflite: ___ MB
├── sigiriya_best_quantized.tflite: ___ MB ← DEPLOY THIS
└── conversion_log.txt: (optional)
```

**Conversion Notes**:
```
Start date: _______
End date: _______
Total conversion time: _______
Any issues: _______
Accuracy drop after quantization: ___%
```

---

### Task 7: Frontend Integration & Output Delivery
**Status**: ⬜ **NOT STARTED**  
**Description**: Integrate model in Flutter and verify JSON output format
**Location**: `frontend/assets/models/`
**Duration**: ~5 minutes

**Sub-tasks**:
- [ ] Copied `.tflite` to `frontend/assets/models/landmark_model.tflite`
- [ ] Enabled `tflite_flutter` in `frontend/pubspec.yaml`
- [ ] Replaced stub logic in `frontend/lib/features/recognition/recognition_service.dart`
- [ ] Verified `frontend/lib/features/recognition/recognition_service.dart` loads model correctly
- [ ] Tested inference on sample images
- [ ] JSON output format verified (has all required fields)
- [ ] Bounding boxes output correctly
- [ ] Confidence scores output correctly
- [ ] Timestamps included in output
- [ ] Sub-landmark IDs correctly mapped
- [ ] Ready for teammate Function 2 (AR visualization)

**Deployment Checklist**:
```
Frontend setup:
├── [ ] Model file copied: frontend/assets/models/landmark_model.tflite
├── [ ] File size: ___ MB
├── [ ] pubspec.yaml updated with assets
├── [ ] recognition_service.dart imports tflite_flutter
├── [ ] Model loads without errors

Testing:
├── [ ] Ran inference on sample image
├── [ ] Output JSON format correct
├── [ ] Contains: landmark_id, sub_landmark_id, confidence_score
├── [ ] Contains: bounding_box with x, y, width, height
├── [ ] Inference time: ___ ms (target: < 40ms for 25 FPS)
├── [ ] Accuracy acceptable (≥85%)
```

**Model Deployment**:
```
Copied from: backend/output/sigiriya_best_quantized.tflite
Copied to: frontend/assets/models/landmark_model.tflite
File size: ___ MB
Date deployed: _______
Test result: _____ (PASS/FAIL)
```

---

## 📈 Timeline

```
Task 1 (Collection):      [_____] Estimated: 2-3 weeks
Task 2 (Annotation):      [_____] Estimated: 1-2 weeks
Task 3 (Validation):      [_____] Estimated: 1 hour
Task 4 (Training):        [_____] Estimated: 1-2 hours
Task 5 (Evaluation):      [_____] Estimated: 30 mins
Task 6 (Conversion):      [_____] Estimated: 30 mins
Task 7 (Deployment):      [_____] Estimated: 30 mins

TOTAL PROJECT TIME: ~1 month (with dataset collection)
```

---

## 📞 Issues & Blockers

### Current Blockers
```
[ ] No blocker - Ready to start Task 1
[ ] Dataset not collected yet
[ ] GPU not available (using Colab instead)
[ ] Other: _______
```

### Known Issues
```
Issue 1: _______
  Status: [ ] Open [ ] In Progress [ ] Resolved
  Notes: _______

Issue 2: _______
  Status: [ ] Open [ ] In Progress [ ] Resolved
  Notes: _______
```

---

## 🔎 Current Implementation Notes

- Backend model training/conversion pipeline is ready.
- Frontend inference service is currently stubbed and must be implemented before real offline detection works.

---

## 🎯 Success Criteria

- [x] 5 Sigiriya sub-landmark classes defined
- [x] YOLOv8 training script created
- [x] YOLO dataset config created
- [ ] 1,000+ images collected (YOUR TASK)
- [ ] Images annotated with bounding boxes (YOUR TASK)
- [ ] Model trained to ≥85% mAP@0.5
- [ ] Model converted to TFLite
- [ ] Model deployed to Flutter
- [ ] JSON output format verified
- [ ] Ready for Function 2 (AR overlay)

---

## 📚 Key Files

| File | Purpose | Status |
|------|---------|--------|
| [FUNCTION_1_LANDMARK_RECOGNITION.md](FUNCTION_1_LANDMARK_RECOGNITION.md) | Complete guide (7 tasks) | ✅ Created |
| [backend/training/train_sigiriya_yolov8.py](backend/training/train_sigiriya_yolov8.py) | Training script | ✅ Created |
| [backend/training/sigiriya_yolov8_data.yaml](backend/training/sigiriya_yolov8_data.yaml) | YOLO dataset config | ✅ Created |
| [backend/dataset/sigiriya/README.md](backend/dataset/sigiriya/README.md) | Dataset organization | ✅ Created |
| [backend/training/README.md](backend/training/README.md) | Backend pipeline guide | ✅ Created |
| This file | Progress tracker | ✅ Created |

---

## 🔗 Quick Links

- **Main Guide**: [FUNCTION_1_LANDMARK_RECOGNITION.md](FUNCTION_1_LANDMARK_RECOGNITION.md)
- **Training Details**: [backend/training/README.md](backend/training/README.md)
- **Dataset Setup**: [backend/dataset/sigiriya/README.md](backend/dataset/sigiriya/README.md)
- **YOLOv8 Docs**: https://docs.ultralytics.com/
- **Roboflow**: https://roboflow.com

---

## 📝 Notes

```
General observations:
_____________________________________________________________________

What went well:
_____________________________________________________________________

What was difficult:
_____________________________________________________________________

Lessons learned:
_____________________________________________________________________

Next steps:
_____________________________________________________________________
```

---

**Created**: April 9, 2026
**Last Updated**: April 9, 2026
**Project**: HeritageAR - Function 1 Landmark Recognition
**Assigned To**: Your Team
**Status**: 📋 Ready for Task 1 (Data Collection)
