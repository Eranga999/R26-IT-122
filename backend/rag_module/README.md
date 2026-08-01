# Offline RAG Question Answering Module

This module provides a fully offline Retrieval-Augmented Generation (RAG) question answering system. It is self-contained and does not depend on any external APIs or services.

## Structure
- `data/` — JSON datasets for knowledge base and Q&A pairs
- `src/` — Python source code for the module
- `models/` — Local embedding models (e.g., sentence transformers)

## Usage
1. Install dependencies: `pip install -r requirements.txt`
2. Run the entry point: `python src/main.py`

## Collaboration
- All code and data for this module are isolated in `rag_module/`.
- Please follow clean code and modular design principles.
- PRs and issues are welcome!
