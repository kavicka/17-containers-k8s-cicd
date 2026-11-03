#!/usr/bin/env bash
# Build both images. Extra flags only when behind a TLS-inspecting proxy (like the cloud session this was written in):
#   EXTRA_CA=/path/to/ca.crt PROXY=http://host:port scripts/build.sh
set -euo pipefail
TAG=${TAG:-dev}
args=()
if [[ -n "${EXTRA_CA:-}" ]]; then args+=(--secret "id=extra_ca,src=$EXTRA_CA"); fi
if [[ -n "${PROXY:-}" ]]; then
  args+=(--network host --build-arg "HTTPS_PROXY=$PROXY" --build-arg "HTTP_PROXY=$PROXY" --build-arg "NO_PROXY=localhost,127.0.0.1")
fi
docker build "${args[@]}" -f docker/api.Dockerfile -t "rag-clinical-api:$TAG" --build-arg "EMBED_BACKEND=${EMBED_BACKEND:-onnx}" .
docker build "${args[@]}" -f docker/web.Dockerfile -t "rag-clinical-web:$TAG" .
