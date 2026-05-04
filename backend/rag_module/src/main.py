"""
Entry point for the offline RAG question answering module.
"""

import os
import sys
from embedder import Embedder
from retriever import Retriever, load_json_texts, combine_results_to_answer
from vector_store import VectorStore

def get_answer(question, landmark_id):
    """
    Offline RAG pipeline: returns a string answer for a question and landmark_id.
    :param question: User question string
    :param landmark_id: Landmark identifier (used to select dataset)
    :return: String answer
    """
    # Map landmark_id to dataset file
    dataset_map = {
        'sigiriya': '../data/sigiriya_dataset.json',
        'dambulla': '../data/dambulla_dataset.json',
        'polonnaruwa': '../data/polonnaruwa_dataset.json',
        # Add more mappings as needed
    }
    rel_dataset_path = dataset_map.get(landmark_id)
    if not rel_dataset_path:
        return f"No dataset found for landmark_id '{landmark_id}'."
    dataset_path = os.path.join(os.path.dirname(__file__), rel_dataset_path)
    model_path = os.path.join(os.path.dirname(__file__), '../models/sentence_model')

    if not os.path.exists(dataset_path):
        return f"Dataset not found at {dataset_path}"
    texts = load_json_texts(dataset_path, text_field="text")
    if not texts:
        return "No text data found in dataset."
    if not os.path.exists(model_path):
        return f"Model not found at {model_path}"
    embedder = Embedder(model_path)
    embeddings = embedder.generate_embeddings(texts)
    dim = embeddings[0].shape[0]
    vector_store = VectorStore(dim)
    vector_store.add_embeddings(embeddings)
    retriever = Retriever(vector_store, embedder, texts)
    results = retriever.query(question, top_k=3)
    answer = combine_results_to_answer(results)
    return answer

# Optional: CLI for manual testing
if __name__ == "__main__":
    print("Offline RAG QA module initialized.")
    print("\nType your question (or 'exit' to quit):")
    landmark_id = input("Enter landmark id (e.g., sigiriya): ").strip()
    while True:
        user_query = input('> ').strip()
        if user_query.lower() in ('exit', 'quit'):
            print("Exiting.")
            break
        answer = get_answer(user_query, landmark_id)
        print(f"Answer: {answer}\n")

if __name__ == "__main__":
    main()
