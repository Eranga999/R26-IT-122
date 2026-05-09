import os
import sys
from embedder import Embedder
from retriever import Retriever, load_json_data
from vector_store import VectorStore
from response_formatter import ResponseFormatter

def get_answer(question, landmark_id):
    """
    Offline RAG pipeline with personalized conversational formatting.
    :param question: User question string
    :param landmark_id: Landmark identifier (used to select dataset)
    :return: Formatted conversational answer
    """
    # Map landmark_id to dataset file
    dataset_map = {
        'sigiriya': '../data/sigiriya_dataset.json',
        'dambulla': '../data/dambulla_dataset.json',
        'polonnaruwa': '../data/polonnaruwa_dataset.json',
    }
    
    rel_dataset_path = dataset_map.get(landmark_id.lower())
    if not rel_dataset_path:
        return f"Greetings! I'm still learning about '{landmark_id}', but I'd be happy to talk about Sigiriya or other major sites instead! 🏛️"
        
    dataset_path = os.path.join(os.path.dirname(__file__), rel_dataset_path)
    model_path = os.path.join(os.path.dirname(__file__), '../models/sentence_model')

    if not os.path.exists(dataset_path):
        return f"I apologize, but I can't access my records for {landmark_id} right now. Please try again later! 🏛️"
    
    # Load full JSON data with categories
    data = load_json_data(dataset_path)
    if not data:
        return "I'm sorry, my knowledge base seems to be empty for this location. 🏺"
        
    if not os.path.exists(model_path):
        return "System Error: Neural model not found. Please ensure the model is downloaded for offline use."
        
    # Initialize components
    embedder = Embedder(model_path)
    
    # Generate embeddings and initialize vector store
    # Note: In a production app, embeddings should be pre-calculated
    texts = [item.get("text", "") for item in data]
    embeddings = embedder.generate_embeddings(texts)
    
    dim = embeddings[0].shape[0]
    vector_store = VectorStore(dim)
    vector_store.add_embeddings(embeddings)
    
    # Retrieve relevant info
    retriever = Retriever(vector_store, embedder, data)
    results = retriever.query(question, top_k=3)
    
    # Format as conversational guide response
    formatter = ResponseFormatter()
    answer = formatter.format_response(results, landmark_id, query=question)
    
    return answer

# CLI for manual testing
def main():
    print("--- 🏛️ Heritage Guide RAG System (Conversational Mode) ---")
    landmark_id = input("Enter landmark id (e.g., sigiriya): ").strip() or "sigiriya"
    print(f"\nGuide is ready! Type your question about {landmark_id} (or 'exit' to quit):")
    
    while True:
        user_query = input('\nYou: ').strip()
        if user_query.lower() in ('exit', 'quit'):
            print("Guide: Safe travels on your journey! Goodbye! 👋")
            break
        if not user_query:
            continue
            
        answer = get_answer(user_query, landmark_id)
        print(f"\nGuide: {answer}")

if __name__ == "__main__":
    main()
