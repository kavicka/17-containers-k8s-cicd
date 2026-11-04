# syntax=docker/dockerfile:1
# The RAG API (and the indexer job: same image, other command). Multi-stage: build tools stay out of the
# final image. EMBED_BACKEND selects the extra: onnx (default, no PyTorch) or torch (for the size comparison).
ARG EMBED_BACKEND=onnx

FROM python:3.12-slim AS build
ARG EMBED_BACKEND
# Behind a TLS-inspecting corporate proxy, pass its CA as a *build secret*: it is mounted only while a RUN step
# executes and never ends up in a layer.  docker build --secret id=extra_ca,src=/path/to/ca.crt ...
COPY docker/withca.sh /usr/local/bin/withca
RUN --mount=type=secret,id=extra_ca,required=false withca pip install --no-cache-dir uv==0.11.32
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PROJECT_ENVIRONMENT=/venv
# dependencies first: this layer is cached until uv.lock changes, so code edits rebuild in seconds
COPY app/pyproject.toml app/uv.lock ./
RUN --mount=type=secret,id=extra_ca,required=false withca uv sync --frozen --no-dev --no-install-project --extra ${EMBED_BACKEND}
COPY app/rag rag
COPY app/api api
COPY app/eval/study_ids.txt app/eval/questions.jsonl app/eval/run_eval.py eval/

FROM python:3.12-slim
ARG EMBED_BACKEND
RUN useradd --uid 10001 --create-home app \
    && mkdir /data && chown app /data   # a new volume mounted here inherits this owner
COPY --from=build /venv /venv
COPY --from=build /app /app
COPY --from=build /usr/local/bin/withca /usr/local/bin/withca
WORKDIR /app
ENV PATH=/venv/bin:$PATH PYTHONUNBUFFERED=1 EMBED_BACKEND=${EMBED_BACKEND} \
    FASTEMBED_CACHE_PATH=/models HF_HOME=/models HF_HUB_DISABLE_XET=1 DATA_DIR=/data
# Bake the models into the image: pods then start without internet, and every replica runs the exact same weights.
RUN --mount=type=secret,id=extra_ca,required=false withca python -c "from rag.config import Settings; from rag.embed import get_embedder, get_reranker; \
s = Settings(); get_embedder(s); get_reranker(s)" && chmod -R a+rX /models
ENV HF_HUB_OFFLINE=1
USER app
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health', timeout=2)"
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
