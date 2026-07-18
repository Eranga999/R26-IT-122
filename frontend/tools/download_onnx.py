import urllib.request
import os

url = "https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx"
output_file = r"E:\Research Project\R26-IT-122\frontend\assets\models\minilm.onnx"

print(f"Downloading {url} to {output_file}...")
try:
    urllib.request.urlretrieve(url, output_file)
    print("Download successful.")
except Exception as e:
    print(f"Failed to download: {e}")
