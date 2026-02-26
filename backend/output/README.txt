Place model output files here after running conversion scripts.

Expected files:
- landmark_model.pth              ← saved by train_model.py
- landmark_model.onnx             ← saved by pytorch_to_onnx.py
- landmark_model.tflite           ← saved by onnx_to_tflite.py
- landmark_model_quantized.tflite ← saved by quantize_model.py
- class_labels.json               ← saved by train_model.py
- training_results/
    accuracy_plot.png
    loss_plot.png
    confusion_matrix.png

After generating landmark_model.tflite, copy it to:
    ../frontend/assets/models/landmark_model.tflite
