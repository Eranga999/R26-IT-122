import json

# Load tokenizer.json
with open('lib/features/sigiriya_guide/heritageAR-chatbot/models/all-MiniLM-L6-v2/tokenizer.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Extract vocabulary (token -> id mapping)
vocab = data['model']['vocab']

# Create assets/data directory if it doesn't exist
import os
os.makedirs('assets/data', exist_ok=True)

# Write vocab.txt (one token per line, line number = token id)
with open('assets/data/vocab.txt', 'w', encoding='utf-8') as f:
    # Sort by token ID to ensure correct line numbers
    sorted_vocab = sorted(vocab.items(), key=lambda x: x[1])
    for token, _ in sorted_vocab:
        f.write(f'{token}\n')

print(f'Vocab extracted successfully: {len(vocab)} tokens')
