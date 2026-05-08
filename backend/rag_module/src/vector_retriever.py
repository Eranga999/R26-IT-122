"""
Offline Vector Retrieval System for Heritage Chatbot (RAG)
---------------------------------------------------------
- Loads heritage dataset from JSON
- Converts text to embeddings using SentenceTransformers (all-MiniLM-L6-v2)
- Builds FAISS index for fast similarity search
- Maps FAISS indices to dataset entries
- Accepts user query and retrieves top 3 relevant results

Requirements:
    pip install sentence-transformers faiss-cpu
"""
import json
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer

# 1. Load JSON dataset
def load_dataset(json_path):
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data

# 2. Convert all "text" fields into vector embeddings
def compute_embeddings(texts, model_name="all-MiniLM-L6-v2"):
    model = SentenceTransformer(model_name)
    embeddings = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)
    return embeddings, model

# 3. Create FAISS index (IndexFlatL2)
def build_faiss_index(embeddings):
    dim = embeddings.shape[1]
    index = faiss.IndexFlatL2(dim)
    index.add(embeddings)
    return index

# 4. Store mapping between vector index and dataset entries
def create_index_mapping(dataset):
    mapping = {i: entry for i, entry in enumerate(dataset)}
    return mapping

# 5. Query and retrieve top-k results
def retrieve(query, model, index, mapping, top_k=3):
    query_emb = model.encode([query], convert_to_numpy=True)
    D, I = index.search(query_emb, top_k)
    results = []
    for idx in I[0]:
        entry = mapping[idx]
        results.append(entry)
    return results

if __name__ == "__main__":
    # Path to your dataset
    DATASET_PATH = "../data/sigiriya_dataset.json"

    # 1. Load dataset
    dataset = load_dataset(DATASET_PATH)
    texts = [entry["text"] for entry in dataset]

    # 2. Compute embeddings
    embeddings, model = compute_embeddings(texts)

    # 3. Build FAISS index
    index = build_faiss_index(embeddings)

    # 4. Create mapping
    mapping = create_index_mapping(dataset)

    # 5. Accept user query
    print("\nHeritage RAG Vector Search (offline)")
    print("Type your question (or 'exit' to quit):")
    while True:
        query = input("\nYou: ").strip()
        if query.lower() == 'exit':
            break
        # 6. Retrieve top 3 results
        results = retrieve(query, model, index, mapping, top_k=3)
        print("\nTop 3 relevant results:")
        for i, entry in enumerate(results, 1):
            print(f"\nResult {i}:")
            print(f"Landmark: {entry['landmark']}")
            print(f"Category: {entry['category']}")
            print(f"Text: {entry['text']}")
            print("-"*40)

"""
How vector similarity search works:
- Each text and query is converted into a high-dimensional vector (embedding) using a transformer model.
- FAISS stores all text embeddings in an index.
- When a query is entered, its embedding is compared to all stored embeddings using L2 (Euclidean) distance.
- The closest vectors (lowest distance) are considered most similar, and their corresponding dataset entries are returned as the most relevant results.
"""
