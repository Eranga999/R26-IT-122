from flask import Flask, request, jsonify
from main import get_answer

app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    req_data = request.get_json()
    question = req_data.get('question')
    landmark_id = (req_data.get('landmark_id') or 'sigiriya').strip().lower()
    language = (req_data.get('language') or 'en').strip().lower()
    if not question:
        return jsonify({'error': 'Missing question'}), 400

    if language not in ('en', 'hi', 'zh', 'ru', 'de', 'si', 'ta'):
        language = 'en'

    answer = get_answer(question, landmark_id, language=language)
    
    return jsonify({'answer': answer})

if __name__ == '__main__':
    # Use debug=False to prevent Flask from initializing twice
    app.run(host='0.0.0.0', port=5001, debug=False)
