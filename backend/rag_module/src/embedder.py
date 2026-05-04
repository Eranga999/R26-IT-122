"""
Handles embedding generation using a local SentenceTransformer model.
"""
from sentence_transformers import SentenceTransformer

class Embedder:
    def __init__(self, local_model_path: str):
        """
        Initialize the embedder with a local model path.
        :param local_model_path: Path to the locally saved SentenceTransformer model
        """
        self.model = SentenceTransformer(local_model_path)

    def generate_embeddings(self, texts):
        """
        Generate embeddings for a list of texts.
        :param texts: List of strings to embed
        :return: Numpy array of embeddings
        """
        return self.model.encode(texts, show_progress_bar=False)
