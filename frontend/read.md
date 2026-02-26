# HeritageAR – AI-Powered Offline AR Heritage Exploration System

---

## 📌 Project Overview

HeritageAR is a final-year research-based mobile application designed to provide immersive offline augmented reality (AR) experiences for cultural heritage sites.

The system integrates:

- On-device AI landmark recognition
- Augmented Reality (AR) overlays
- Offline SQLite database
- Optional Retrieval-Augmented Generation (RAG)
- GPS-free visual landmark navigation

This project eliminates internet dependency and provides real-time contextual heritage exploration.

---

## 🎯 Research Objectives

1. Develop fine-grained landmark & sub-landmark recognition.
2. Provide immersive AR visualization.
3. Enable fully offline contextual information retrieval.
4. Reduce GPS dependency using vision-based tracking.
5. Deliver educational and interactive heritage experiences.

---

## 🏗 System Architecture

Camera Feed  
↓  
TensorFlow Lite Model (Landmark Detection)  
↓  
Landmark ID  
↓  
SQLite Database  
↓  
AR Overlay Rendering  
↓  
Optional Offline RAG Assistant  

---

## 🛠 Technology Stack

| Component | Technology |
|------------|------------|
| Mobile Framework | Flutter |
| AR Engine | ar_flutter_plugin (ARCore) |
| AI Model | PyTorch → TensorFlow Lite |
| Database | SQLite (sqflite) |
| Model Inference | tflite_flutter |
| Backend | Not Required (Fully Offline) |

---

## 📂 Project Structure

```
heritage_ar/
│
├── android/
├── ios/
├── assets/
│   ├── models/
│   │   └── landmark_model.tflite
│   ├── images/
│   ├── embeddings/
│
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── theme/
│   │   └── utils/
│   │
│   ├── features/
│   │   ├── home/
│   │   ├── camera/
│   │   ├── recognition/
│   │   ├── ar/
│   │   ├── database/
│   │   └── rag/
│   │
│   └── widgets/
│
├── pubspec.yaml
└── README.md
```

---

## 🚀 Installation & Setup Guide

### 1️⃣ Install Required Software

- Flutter SDK (Latest Stable)
- Android Studio
- VS Code (Optional)
- Python 3.10+
- Git

Check Flutter installation:

```
flutter doctor
```

Fix all reported issues before continuing.

---

### 2️⃣ Create Flutter Project

```
flutter create heritage_ar
cd heritage_ar
```

---

### 3️⃣ Add Required Dependencies

Edit `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  camera: ^0.10.5
  tflite_flutter: ^0.10.4
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  ar_flutter_plugin: ^0.7.3
```

Run:

```
flutter pub get
```

---

### 4️⃣ Android Configuration

Open:

```
android/app/src/main/AndroidManifest.xml
```

Add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-feature android:name="android.hardware.camera.ar" android:required="false"/>
```

Ensure minimum SDK version is 24 or above:

```
android/app/build.gradle
```

```
minSdkVersion 24
```

---

### 5️⃣ Add Model File

Place trained model inside:

```
assets/models/landmark_model.tflite
```

Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/
    - assets/images/
    - assets/embeddings/
```

---

### 6️⃣ Run Application

```
flutter run
```

Use a real Android device that supports ARCore.

---

## 🧠 AI Model Training Pipeline

1. Collect dataset images (200–300 per class).
2. Organize folder structure:

```
dataset/
 ├── sigiriya/
 ├── dambulla/
 ├── polonnaruwa/
```

3. Train model using PyTorch (MobileNetV2 recommended).
4. Convert trained model to TensorFlow Lite.
5. Quantize model for mobile optimization.
6. Place `.tflite` model inside assets folder.

---

## 🗄 Database Schema

SQLite Table:

```
CREATE TABLE landmarks(
  id INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT
);
```

Stores:

- Landmark name
- Historical description
- Metadata

---

## 📊 Evaluation Metrics

- Accuracy
- Precision
- Recall
- F1 Score
- Inference Time (ms)
- FPS Performance
- Memory Usage

---

## 🔐 Ethical Considerations

- No personal user data collected
- Fully offline system
- Consent required for field photography
- Academic research use only

---

## 📈 Future Enhancements

- Multi-language support
- Voice-based assistant
- 3D historical reconstruction
- AR-based navigation waypoints
- Advanced on-device RAG integration

---

## 📝 Research Contribution

This project contributes to:

- Offline AR heritage systems
- Fine-grained landmark detection
- On-device AI deployment
- Sustainable cultural education technologies

---
