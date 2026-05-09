import faiss
import numpy as np
import json

def load_json_data(json_path):
    """
    Load a local JSON dataset and return a list of all item dictionaries.
    :param json_path: Path to the JSON file
    :return: List of dictionaries
    """
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data

class Retriever:
    def __init__(self, vector_store, embedder, data):
        self.vector_store = vector_store
        self.embedder = embedder
        self.data = data
        self.texts = [item.get("text", "") for item in data]

    def query(self, user_query, top_k=3):
        """
        Generate embedding for user query and retrieve top_k similar results with metadata.
        :param user_query: Query string
        :param top_k: Number of results to return
        :return: List of dictionaries containing text, category, and score
        """
        query_emb = self.embedder.generate_embeddings([user_query])[0]
        D, I = self.vector_store.index.search(np.array([query_emb]).astype('float32'), top_k)
        
        results = []
        for i, idx in enumerate(I[0]):
            if idx != -1 and idx < len(self.data):
                item = self.data[idx].copy()
                item['score'] = float(D[0][i])
                results.append(item)
        return results
