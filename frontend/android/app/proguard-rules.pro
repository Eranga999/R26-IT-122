# TFLite Flutter ProGuard Rules
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep GPU delegate classes to avoid missing class errors
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# (Optional) If you have select-tf-ops or other Firebase ML components
-dontwarn com.google.android.gms.internal.**
-keep class com.google.android.gms.internal.** { *; }
