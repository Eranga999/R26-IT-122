import os
from flask import Flask, request, jsonify
from embedder import Embedder
from retriever import Retriever, load_json_data
from vector_store import VectorStore
from response_formatter import ResponseFormatter

app = Flask(__name__)

# Pre-load Sigiriya RAG engine at startup for high performance
DATASET_PATH = os.path.join(os.path.dirname(__file__), '../data/sigiriya_dataset.json')
MODEL_PATH = os.path.join(os.path.dirname(__file__), '../models/sentence_model')

print("--- Heritage Guide API: Initializing Sigiriya Engine ---")
_embedder = Embedder(MODEL_PATH)
_data = load_json_data(DATASET_PATH)
_texts = [item.get("text", "") for item in _data]
_embeddings = _embedder.generate_embeddings(_texts)
_dim = _embeddings[0].shape[0]
_vector_store = VectorStore(_dim)
_vector_store.add_embeddings(_embeddings)
_retriever = Retriever(_vector_store, _embedder, _data)
_formatter = ResponseFormatter()
print("--- RAG Engine Ready! ---")

@app.route('/chat', methods=['POST'])
def chat():
    req_data = request.get_json()
    question = req_data.get('question')
    if not question:
        return jsonify({'error': 'Missing question'}), 400
    
    # Fast retrieval from pre-loaded memory
    results = _retriever.query(question, top_k=3)
    answer = _formatter.format_response(results, 'sigiriya', query=question)
    
    return jsonify({'answer': answer})

if __name__ == '__main__':
    # Use debug=False to prevent Flask from initializing twice
    app.run(host='0.0.0.0', port=5001, debug=False)
