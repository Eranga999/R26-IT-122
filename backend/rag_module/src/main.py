"""
Entry point for the offline RAG question answering module.
"""
import os
import sys
from embedder import Embedder
from retriever import Retriever, load_json_texts
from vector_store import VectorStore

DATASET_PATH = os.path.join(os.path.dirname(__file__), '../data/sigiriya_dataset.json')
MODEL_PATH = os.path.join(os.path.dirname(__file__), '../models/sentence_model')

def main():
    print("Offline RAG QA module initialized.")
    # Load dataset
    if not os.path.exists(DATASET_PATH):
        print(f"Dataset not found at {DATASET_PATH}")
        sys.exit(1)
    texts = load_json_texts(DATASET_PATH, text_field="text")
    if not texts:
        print("No text data found in dataset.")
        sys.exit(1)

    # Load local embedding model
    if not os.path.exists(MODEL_PATH):
        print(f"Model not found at {MODEL_PATH}")
        sys.exit(1)
    embedder = Embedder(MODEL_PATH)

    # Generate embeddings for all texts
    print("Generating embeddings for dataset...")
    embeddings = embedder.generate_embeddings(texts)

    # Build FAISS index
    print("Building FAISS index...")
    dim = embeddings[0].shape[0]
    vector_store = VectorStore(dim)
    vector_store.add_embeddings(embeddings)

    # Initialize retriever
    retriever = Retriever(vector_store, embedder, texts)

    # Accept user input and print top matches
    print("\nType your question (or 'exit' to quit):")
    while True:
        user_query = input('> ').strip()
        if user_query.lower() in ('exit', 'quit'):
            print("Exiting.")
            break
        results = retriever.query(user_query, top_k=3)
        print("Top matches:")
        for i, (text, score) in enumerate(results, 1):
            print(f"{i}. {text} (Score: {score:.4f})")
        print()

if __name__ == "__main__":
    main()
