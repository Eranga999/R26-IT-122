"""
Handles FAISS index creation, saving, and loading.
"""
import faiss
import numpy as np

class VectorStore:
    def __init__(self, dim):
        """
        Create a FAISS index using IndexFlatL2.
        :param dim: Dimension of embeddings
        """
        self.index = faiss.IndexFlatL2(dim)

    def add_embeddings(self, embeddings):
        """
        Add embeddings to the FAISS index.
        :param embeddings: Numpy array or list of embeddings
        """
        self.index.add(np.array(embeddings).astype('float32'))

    def save(self, path):
        faiss.write_index(self.index, path)

    def load(self, path):
        self.index = faiss.read_index(path)
