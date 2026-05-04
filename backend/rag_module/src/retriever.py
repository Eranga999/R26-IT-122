"""
Retrieves relevant documents using FAISS vector search.
"""
import faiss
import numpy as np

class Retriever:
    def __init__(self, vector_store):
        self.vector_store = vector_store

    def retrieve(self, query_embedding, top_k=5):
        D, I = self.vector_store.index.search(np.array([query_embedding]), top_k)
        return I[0], D[0]
