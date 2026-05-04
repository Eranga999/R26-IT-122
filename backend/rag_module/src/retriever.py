"""
Retrieves relevant documents using FAISS vector search.
"""
import faiss
import numpy as np
import json

def load_json_texts(json_path, text_field="text"):
    """
    Load a local JSON dataset and return a list of text content fields.
    :param json_path: Path to the JSON file
    :param text_field: Field name containing the text (default: 'text')
    :return: List of text content
    """
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return [item[text_field] for item in data if text_field in item]

class Retriever:
    def __init__(self, vector_store, embedder, texts):
        self.vector_store = vector_store
        self.embedder = embedder
        self.texts = texts

    def retrieve(self, query_embedding, top_k=3):
        D, I = self.vector_store.index.search(np.array([query_embedding]), top_k)
        return I[0], D[0]

    def query(self, user_query, top_k=3):
        """
        Generate embedding for user query and retrieve top_k similar results.
        :param user_query: Query string
        :param top_k: Number of results to return
        :return: List of (text, score) tuples
        """
        query_emb = self.embedder.generate_embeddings([user_query])[0]
        D, I = self.vector_store.index.search(np.array([query_emb]).astype('float32'), top_k)
        results = [(self.texts[idx], float(D[0][i])) for i, idx in enumerate(I[0])]
        return results
