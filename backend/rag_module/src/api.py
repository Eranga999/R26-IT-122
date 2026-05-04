from flask import Flask, request, jsonify
from main import get_answer

app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json()
    question = data.get('question')
    landmark_id = data.get('landmark_id', 'sigiriya')  # default for demo
    if not question:
        return jsonify({'error': 'Missing question'}), 400
    answer = get_answer(question, landmark_id)
    return jsonify({'answer': answer})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
