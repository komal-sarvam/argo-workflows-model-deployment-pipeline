import os
from typing import List
from fastapi import FastAPI
from pydantic import BaseModel

MODEL_ID = os.getenv("MODEL_ID", "BAAI/bge-small-en-v1.5")

app = FastAPI(title="Embeddings Server", version="0.1.0")

try:
    from fastembed import TextEmbedding
    _backend = "fastembed"
    embedder = TextEmbedding(model_name=MODEL_ID)
except Exception as e:  # fallback to sentence-transformers if fastembed fails
    from sentence_transformers import SentenceTransformer
    _backend = "sentence-transformers"
    embedder = SentenceTransformer(MODEL_ID)

class EmbedRequest(BaseModel):
    inputs: List[str]

@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_ID}

@app.post("/embed")
async def embed(req: EmbedRequest):
    if _backend == "fastembed":
        # fastembed returns iterator of embeddings
        embs = list(embedder.embed(req.inputs))
        return {"embeddings": [list(map(float, e)) for e in embs]}
    else:
        embs = embedder.encode(req.inputs, normalize_embeddings=True).tolist()
        return {"embeddings": embs}
