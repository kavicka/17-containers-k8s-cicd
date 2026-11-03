"""Embedding and reranking behind one interface, with two interchangeable backends.

torch  sentence-transformers on PyTorch: what steps 14–15 used. Great for research and the Mac (MPS),
       but PyTorch alone makes a serving image several GB.
onnx   the same models exported to ONNX and run by onnxruntime through fastembed: no PyTorch at all, so the API
       image is a fraction of the size. Step 17 checks that retrieval quality survives the switch (it does:
       identical evidence@k on all 141 questions).
"""

from typing import Protocol

import numpy as np

from rag.config import Settings

QUERY_PREFIX = "Represent this sentence for searching relevant passages: "  # bge: instruction on queries only
ONNX_RERANK = {"cross-encoder/ms-marco-MiniLM-L-6-v2": "Xenova/ms-marco-MiniLM-L-6-v2"}


class Embedder(Protocol):
    def encode(self, texts: list[str], batch_size: int = 32) -> np.ndarray: ...


class Reranker(Protocol):
    def score(self, query: str, docs: list[str]) -> np.ndarray: ...


def _normalize(v: np.ndarray) -> np.ndarray:
    return v / np.linalg.norm(v, axis=1, keepdims=True)


class TorchEmbedder:
    def __init__(self, s: Settings):
        from sentence_transformers import SentenceTransformer

        self.m = SentenceTransformer(s.embed_model, device=s.device)

    def encode(self, texts: list[str], batch_size: int = 32) -> np.ndarray:
        return self.m.encode(texts, batch_size=batch_size, normalize_embeddings=True, convert_to_numpy=True)


class TorchReranker:
    def __init__(self, s: Settings):
        from sentence_transformers import CrossEncoder

        self.m = CrossEncoder(s.rerank_model, device=s.device)

    def score(self, query: str, docs: list[str]) -> np.ndarray:
        return np.asarray(self.m.predict([(query, d) for d in docs]))


class OnnxEmbedder:
    def __init__(self, s: Settings):
        from fastembed import TextEmbedding

        self.m = TextEmbedding(s.embed_model)

    def encode(self, texts: list[str], batch_size: int = 32) -> np.ndarray:
        return _normalize(np.array(list(self.m.embed(texts, batch_size=batch_size)), dtype=np.float32))


class OnnxReranker:
    def __init__(self, s: Settings):
        from fastembed.rerank.cross_encoder import TextCrossEncoder

        self.m = TextCrossEncoder(ONNX_RERANK.get(s.rerank_model, s.rerank_model))

    def score(self, query: str, docs: list[str]) -> np.ndarray:
        return np.array(list(self.m.rerank(query, docs)), dtype=np.float32)


def get_embedder(s: Settings) -> Embedder:
    return OnnxEmbedder(s) if s.embed_backend == "onnx" else TorchEmbedder(s)


def get_reranker(s: Settings) -> Reranker:
    return OnnxReranker(s) if s.embed_backend == "onnx" else TorchReranker(s)
