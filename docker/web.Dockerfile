# syntax=docker/dockerfile:1
# React UI: built with Node, served by nginx, which also proxies /api to the API service.
FROM node:22-alpine AS build
WORKDIR /web
COPY app/frontend/package.json app/frontend/package-lock.json ./
# see api.Dockerfile: an optional build secret for a TLS-inspecting proxy, never stored in a layer
RUN --mount=type=secret,id=extra_ca,required=false \
    if [ -f /run/secrets/extra_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/extra_ca; fi; \
    npm ci --no-audit --no-fund
COPY app/frontend/ ./
RUN npm run build

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /web/dist /usr/share/nginx/html
EXPOSE 8080
