Place model output files here after running conversion scripts.

Expected files:
- sigiriya_best.pt                ← saved by train_sigiriya_yolov8.py
- sigiriya_best.onnx              ← saved by conversion/export step
- sigiriya_best.tflite            ← saved by conversion/export step
- sigiriya_best_quantized.tflite  ← saved by conversion/export step
- training_results/
    results.csv
    results.png
    confusion_matrix.png

After generating landmark_model.tflite, copy it to:
    ../frontend/assets/models/landmark_model.tflite
