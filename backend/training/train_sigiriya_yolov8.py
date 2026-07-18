"""
FUNCTION 1 - Task 4: Model Training
YOLOv8n Training Script for Sigiriya Sub-Landmark Detection

Usage:
  Local:  python backend/training/train_sigiriya_yolov8.py
  Colab:  !python backend/training/train_sigiriya_yolov8.py
  
Output:
  - Best model: runs/detect/sigiriya_v1/weights/best.pt
  - Training plots: runs/detect/sigiriya_v1/results.png
  - Training metrics: runs/detect/sigiriya_v1/results.csv
"""

import os
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from ultralytics import YOLO
    print("✓ YOLOv8 (ultralytics) imported successfully")
except ImportError:
    print("❌ YOLOv8 not installed. Install with:")
    print("   pip install ultralytics torch torchvision")
    sys.exit(1)


class SigiriyaYOLOv8Trainer:
    """
    YOLOv8 trainer for Sigiriya sub-landmark detection.
    
    Classes:
    - 0: sigiriya_entrance
    - 1: sigiriya_lion_rock
    - 2: sigiriya_mirror_wall
    - 3: sigiriya_lion_staircase
    - 4: sigiriya_throne
    """
    
    def __init__(self, dataset_yaml: str = "backend/training/sigiriya_yolov8_data.yaml"):
        """
        Initialize trainer with dataset config.
        
        Args:
            dataset_yaml: Path to sigiriya_yolov8_data.yaml
        """
        self.dataset_yaml = dataset_yaml
        self.model = None
        self.results = None
        
        # Verify dataset config exists
        if not os.path.exists(self.dataset_yaml):
            raise FileNotFoundError(f"Dataset config not found: {self.dataset_yaml}")
        print(f"✓ Dataset config found: {self.dataset_yaml}")
    
    def train(
        self,
        epochs: int = 100,
        imgsz: int = 640,
        batch: int = 16,
        device: int = 0,
        patience: int = 20,
        project: str = "runs/detect",
        name: str = "sigiriya_v1",
    ):
        """
        Train YOLOv8n model on Sigiriya dataset.
        
        Args:
            epochs: Number of training epochs (default: 100)
            imgsz: Input image size (default: 640)
            batch: Batch size (default: 16, adjust based on GPU memory)
            device: GPU device ID (default: 0 for first GPU, set to 'cpu' for CPU)
            patience: Early stopping patience (default: 20 epochs)
            project: Output project directory
            name: Experiment name (creates project/name/ folder)
        
        Returns:
            YOLO results object
        """
        
        print("\n" + "="*60)
        print(" YOLOv8n Training - Sigiriya Sub-Landmarks")
        print("="*60)
        print(f"Dataset: {self.dataset_yaml}")
        print(f"Epochs: {epochs} | Batch: {batch} | Image Size: {imgsz}")
        print(f"Device: {device} | Patience: {patience}")
        print(f"Output: {project}/{name}/")
        print("="*60 + "\n")
        
        # Load pretrained YOLOv8n model
        print("Loading YOLOv8n pretrained weights...")
        self.model = YOLO('yolov8n.pt')
        
        # Conservative augmentation works better for fixed heritage landmarks.
        # Avoid strong vertical flips or aggressive geometric warping.
        augmentation_config = dict(
            augment=True,
            degrees=8,
            translate=0.05,
            scale=0.20,
            shear=0.0,
            perspective=0.0,
            fliplr=0.20,
            flipud=0.0,
            hsv_h=0.015,
            hsv_s=0.45,
            hsv_v=0.30,
            mosaic=0.20,
            mixup=0.0,
            copy_paste=0.0,
        )

        # Train model
        print("Starting training...\n")
        self.results = self.model.train(
            data=self.dataset_yaml,      # Dataset config
            epochs=epochs,               # Training epochs
            imgsz=imgsz,                # Input image size
            batch=batch,                # Batch size
            device=device,              # GPU device
            patience=patience,          # Early stopping patience
            save=True,                  # Save checkpoints
            plots=True,                 # Generate plots
            project=project,            # Output directory
            name=name,                  # Experiment name
            verbose=True,               # Verbose logging
            **augmentation_config,
        )
        
        return self.results
    
    def validate(self):
        """
        Validate trained model on validation set.
        
        Returns:
            Validation results
        """
        if self.model is None:
            raise ValueError("Model not trained yet. Call train() first.")
        
        print("\nValidating model on validation set...")
        val_results = self.model.val()
        
        print(f"\nValidation Results:")
        print(f"  mAP@0.5: {val_results.box.map50:.2%}")
        print(f"  mAP@0.5:0.95: {val_results.box.map:.2%}")
        print(f"  Precision: {val_results.box.p.mean():.2%}")
        print(f"  Recall: {val_results.box.r.mean():.2%}")
        
        return val_results
    
    def test(self):
        """
        Test trained model on test set.
        
        Returns:
            Test results
        """
        if self.model is None:
            raise ValueError("Model not trained yet. Call train() first.")
        
        print("\nTesting model on test set...")
        test_results = self.model.val(
            data=self.dataset_yaml,
            split='test',
        )
        
        print(f"\nTest Results:")
        print(f"  mAP@0.5: {test_results.box.map50:.2%}")
        print(f"  mAP@0.5:0.95: {test_results.box.map:.2%}")
        print(f"  Precision: {test_results.box.p.mean():.2%}")
        print(f"  Recall: {test_results.box.r.mean():.2%}")
        
        return test_results
    
    def get_best_model_path(self):
        """
        Get path to best trained model.
        
        Returns:
            Path to best.pt
        """
        if self.results is None:
            raise ValueError("Model not trained yet. Call train() first.")
        
        project = self.results.save_dir.parent
        best_path = project / "weights" / "best.pt"
        return str(best_path)
    
    def export_metrics(self):
        """
        Print training summary and metrics.
        """
        if self.results is None:
            raise ValueError("Model not trained yet. Call train() first.")
        
        print("\n" + "="*60)
        print(" Training Summary")
        print("="*60)
        print(f"Best model saved at: {self.get_best_model_path()}")
        print(f"Plots saved at: {self.results.save_dir}")
        print("="*60 + "\n")


def main():
    """
    Main training function.
    """
    
    # Initialize trainer
    trainer = SigiriyaYOLOv8Trainer(
        dataset_yaml="backend/training/sigiriya_yolov8_data.yaml"
    )
    
    # Train model
    results = trainer.train(
        epochs=100,         # Full training (100+ epochs)
        imgsz=640,         # Standard input size
        batch=16,          # Adjust if GPU memory is limited (8, 12, etc.)
        device=0,          # First GPU (set to 'cpu' if no GPU)
        patience=20,       # Early stopping after 20 epochs without improvement
        project="runs/detect",
        name="sigiriya_v1",
    )
    
    # Export metrics
    trainer.export_metrics()
    
    print("\n✅ Training completed successfully!")
    print(f"   Next steps:")
    print(f"   1. Run evaluation: python backend/training/evaluate_sigiriya_yolov8.py")
    print(f"   2. Convert to TFLite: python backend/conversion/onnx_to_tflite.py")
    print(f"   3. Copy to Flutter: cp {trainer.get_best_model_path()} frontend/assets/models/")


if __name__ == "__main__":
    main()
