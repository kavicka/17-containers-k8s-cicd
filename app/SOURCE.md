# Where this code comes from

`app/` is the RAG app from [step 15](https://github.com/kavicka/15-rag-fullstack-clinical) at commit `7138329`,
copied (not a submodule) so this repo builds on its own. Changes made here for serving:

- `rag/embed.py`: embedding + reranking behind one interface with two backends, `torch` (as in step 15) and
  `onnx` (fastembed/onnxruntime, no PyTorch); `EMBED_BACKEND` in the environment picks one.
- `pyproject.toml`: `sentence-transformers` and `fastembed` moved into the optional extras `torch` / `onnx`;
  `matplotlib` moved to the dev group (not needed to serve).
- `eval/run_eval.py`: `--chunkings` filter, `RESULTS_PATH` (read-only containers write elsewhere), records the
  embedding backend.
