"""
Handles embedding generation using local models.
"""
from sentence_transformers import SentenceTransformer

class Embedder:
    def __init__(self, model_path: str):
        self.model = SentenceTransformer(model_path)

    def embed(self, texts):
        return self.model.encode(texts, show_progress_bar=False)
