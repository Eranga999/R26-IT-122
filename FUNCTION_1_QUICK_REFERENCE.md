# Function 1 - Quick Reference Card
## Landmark Recognition Model Training

---

## 🚀 Start Here

**Your Goal**: Train YOLOv8 model to detect 5 Sigiriya sub-landmarks

**Timeline**: ~1 month (mostly image collection)

**Current Status**: ✅ Backend training scripts ready | ⚠️ Frontend live inference integration pending

---

## Reality Check (Current Code)

- Training/evaluation/conversion scripts are ready.
- Real-time Flutter inference is not complete yet (recognition service is a stub).
- Model deployment step is only complete after `tflite_flutter` integration and prediction mapping.

---

## �📋 The 7 Tasks (In Order)

| # | Task | Duration | Status | Start |
|---|------|----------|--------|-------|
| 1 | **Collect Images** | 2-3 weeks | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-1-data-collection) |
| 2 | **Annotate Boxes** | 1-2 weeks | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-2-data-annotation) |
| 3 | **Validate Dataset** | 1 hour | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-3-dataset-validation) |
| 4 | **Train Model** | 1-2 hours | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-4-model-training) |
| 5 | **Evaluate** | 30 mins | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-5-model-evaluation) |
| 6 | **Convert to TFLite** | 30 mins | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-6-model-conversion) |
| 7 | **Integrate to Flutter** | 30 mins | ⬜ Pending | [Guide](FUNCTION_1_LANDMARK_RECOGNITION.md#-task-7-frontend-integration--output-delivery) |

---

## 📁 5 Sigiriya Sub-Landmarks

Collect images for EXACTLY these 5 classes:

```
0: sigiriya_entrance       → Main entrance gate/ramp
1: sigiriya_water_gardens  → Ancient water system
2: sigiriya_mirror_wall    → Polished wall with frescoes
3: sigiriya_lion_staircase → Lion-shaped staircase entry
4: sigiriya_summit         → Rock summit/crater top
```

**Target**: 200-300 images per class (1,000+ total)

---

## 🎯 All Created For You ✅

```
✅ Training script:        train_sigiriya_yolov8.py
✅ YOLO config file:       sigiriya_yolov8_data.yaml
✅ Class IDs mapping:      sigiriya_sub_landmark_ids.json
✅ Complete guides:        FUNCTION_1_LANDMARK_RECOGNITION.md
✅ Progress tracker:       FUNCTION_1_PROGRESS_TRACKER.md
✅ Dataset setup:          backend/dataset/sigiriya/README.md
✅ Training pipeline:      backend/training/README.md

❌ Images:                 YOU COLLECT (Task 1)
❌ Annotations:            YOU ANNOTATE (Task 2)
```

---

## 📞 When You're Ready...

### Task 3: Validate Dataset (YOLO)
```text
Confirm these are ready:
- backend/dataset/sigiriya_dataset/images/{train,val,test}/
- backend/dataset/sigiriya_dataset/labels/{train,val,test}/
- class IDs are only 0-4
- each image has matching label file
```

### Task 4: Train Model
```bash
python training/train_sigiriya_yolov8.py
# Takes 30-60 mins on GPU
```

### Task 5: Evaluate
```bash
python training/evaluate_sigiriya_yolov8.py
# Records: mAP, precision, recall, F1
```

### Task 6: Convert to TFLite
```bash
python conversion/pytorch_to_onnx.py
python conversion/onnx_to_tflite.py
python conversion/quantize_model.py
python conversion/test_tflite_model.py
```

### Task 7: Integrate to Flutter
```powershell
Copy-Item backend/output/sigiriya_best_quantized.tflite frontend/assets/models/landmark_model.tflite
# Then: implement model inference in recognition_service.dart and enable tflite_flutter
```

---

## 🎨 Annotation Format (YOLO)

Each image needs a `.txt` file with format:
```
<class_id> <x_center> <y_center> <width> <height>
```

**Example** (entrance box in 640×480 image):
```
0 0.4375 0.4375 0.5 0.5
```

**All values**: 0.0 to 1.0 (normalized)

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| mAP@0.5 | ≥ 85% |
| Precision | ≥ 88% |
| Recall | ≥ 88% |
| F1 Score | ≥ 88% |
| FPS (Mobile) | ≥ 25 FPS |
| Model Size | < 50MB |

---

## 🛠️ Tools You'll Need

### Task 1: Collection
- [ ] Internet access
- [ ] Google Images / Flickr / Kaggle accounts

### Task 2: Annotation
- [ ] **Roboflow** (recommended) - roboflow.com
- [ ] OR **LabelImg** - `pip install labelImg`

### Task 3-7: Training + Integration
- [ ] Python 3.8+
- [ ] `pip install ultralytics torch torchvision`
- [ ] GPU (strongly recommended)
  - [ ] OR Google Colab (free GPU)
- [ ] Enable `tflite_flutter` in Flutter for live on-device inference

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| GPU out of memory | Reduce: `batch=8` |
| Model accuracy low | More images (300+) |
| Data leakage | Ensure no same image appears in multiple splits |
| Import errors | `pip install` missing packages |
| TFLite slow | Use smaller model or imgsz=416 |

---

## 📚 Full Guides

| Document | Link |
|----------|------|
| **Complete 7-Task Guide** | [FUNCTION_1_LANDMARK_RECOGNITION.md](FUNCTION_1_LANDMARK_RECOGNITION.md) |
| **Dataset Setup** | [backend/dataset/sigiriya/README.md](backend/dataset/sigiriya/README.md) |
| **Training Pipeline Details** | [backend/training/README.md](backend/training/README.md) |
| **Progress Tracker** | [FUNCTION_1_PROGRESS_TRACKER.md](FUNCTION_1_PROGRESS_TRACKER.md) |
| **YOLOv8 Official** | https://docs.ultralytics.com/ |
| **Roboflow Guide** | https://roboflow.com/formats/yolov8-pytorch |

---

## ✅ Pre-Launch Checklist

Before starting Task 1:
- [ ] Read FUNCTION_1_LANDMARK_RECOGNITION.md (full guide)
- [ ] Print or bookmark this Quick Reference
- [ ] Open FUNCTION_1_PROGRESS_TRACKER.md for tracking
- [ ] Join Roboflow (for annotation)
- [ ] Create folder: `backend/dataset/sigiriya/`
- [ ] You're ready! 🚀

---

## 🎯 Next Action

**NOW**: Go to [FUNCTION_1_LANDMARK_RECOGNITION.md](FUNCTION_1_LANDMARK_RECOGNITION.md)
**Task**: Read Task 1 - Data Collection section
**Action**: Start collecting Sigiriya images

---

## 📞 Support

**Stuck?** Check:
1. Full section in FUNCTION_1_LANDMARK_RECOGNITION.md
2. Specific how-to in backend/training/README.md
3. Dataset guide in backend/dataset/sigiriya/README.md

**Still stuck?**
- YOLOv8 docs: https://docs.ultralytics.com/
- Roboflow help: https://roboflow.com/support
- Common issues section in this guide

---

## 💡 Pro Tips

✅ Use **Roboflow** - easiest, cloud-based, handles augmentation
✅ Collect **300+ images per class** - better accuracy
✅ Use **Google Colab** - free GPU training
✅ Check metrics after each task - don't skip evaluation
✅ Save this Quick Reference card - you'll need it

---

**Created**: April 9, 2026  
**Project**: HeritageAR - Function 1  
**Status**: Ready for Task 1
