# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS frontend

WORKDIR /build

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY tsconfig.json ./
COPY scripts/build_html.mjs scripts/build_html.mjs
COPY public/ public/

RUN npm run build \
    && mkdir -p /out/public \
    && cp public/*.css public/*.js public/index.html public/openapi.json /out/public/


FROM python:3.13-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=4312 \
    ALLOW_UNAUTHENTICATED_LAN=1 \
    SQUARES_CONFIG=/data/config.json \
    SQUARES_LIBRARY=/data/library.json \
    SQUARES_AUTOMATIONS=/data/automations.json \
    SQUARES_RUNTIME_POLICY=/data/runtime.json \
    SQUARES_MOVIE_ARCHIVE=/data/movies

RUN addgroup -g 10001 -S squares \
    && adduser -u 10001 -S -D -H -G squares squares \
    && mkdir -p /app /data \
    && chown -R squares:squares /app /data

WORKDIR /app

COPY --chown=squares:squares server.py ./
COPY --chown=squares:squares src/ src/
COPY --from=frontend --chown=squares:squares /out/public/ public/

USER squares

VOLUME ["/data"]
EXPOSE 4312
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD ["python3", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '4312') + '/api/v1/health', timeout=2).read()"]

CMD ["python3", "server.py"]
