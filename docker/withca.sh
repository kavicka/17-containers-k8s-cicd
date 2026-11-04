#!/bin/sh
# Run a command with an optional build-secret CA trusted (pip, uv, requests/httpx). No-op without the secret.
if [ -f /run/secrets/extra_ca ]; then
  export SSL_CERT_FILE=/run/secrets/extra_ca REQUESTS_CA_BUNDLE=/run/secrets/extra_ca PIP_CERT=/run/secrets/extra_ca
fi
exec "$@"
