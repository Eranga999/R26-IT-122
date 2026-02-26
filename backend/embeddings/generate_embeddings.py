"""
generate_embeddings.py
──────────────────────
Reads each landmark's knowledge base text file, splits it into sentence
chunks, and saves the chunks as a JSON file consumable by the Flutter app's
offline RAG service.

(No vector embeddings are generated here – the Flutter RAG service uses
keyword matching.  Replace with sentence-transformers if you want cosine
similarity later.)

Usage:
    python embeddings/generate_embeddings.py
"""

import json
import re
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))
from training.config import (
    KNOWLEDGE_BASE_DIR, EMBEDDINGS_OUTPUT_DIR, CLASS_NAMES
)


def split_into_chunks(text: str, max_sentences: int = 3) -> list[str]:
    """Splits text into overlapping chunks of `max_sentences` sentences."""
    # Split on sentence-ending punctuation
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    sentences = [s.strip() for s in sentences if s.strip()]

    chunks = []
    for i in range(0, len(sentences), max_sentences):
        chunk = " ".join(sentences[i:i + max_sentences])
        if chunk:
            chunks.append(chunk)
    return chunks


def generate_embeddings():
    kb_path  = Path(KNOWLEDGE_BASE_DIR)
    out_path = Path(EMBEDDINGS_OUTPUT_DIR)
    out_path.mkdir(parents=True, exist_ok=True)

    for class_name in CLASS_NAMES:
        txt_file = kb_path / f"{class_name}.txt"
        if not txt_file.exists():
            print(f"[WARN] Knowledge base not found: {txt_file}")
            continue

        text   = txt_file.read_text(encoding="utf-8")
        chunks = split_into_chunks(text, max_sentences=3)

        payload = {"landmark": class_name.capitalize(), "chunks": chunks}
        out_file = out_path / f"{class_name}_embeddings.json"
        out_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False),
                            encoding="utf-8")
        print(f"✅ {class_name}: {len(chunks)} chunks → {out_file.name}")

    print("\n✅ All embedding files generated.")
    print(f"   Copy the JSON files from\n   {out_path}\n"
          f"   to\n   frontend/assets/embeddings/")


if __name__ == "__main__":
    generate_embeddings()
