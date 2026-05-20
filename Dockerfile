# First stage
FROM python:3.11-slim AS builder
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends git; \
    && pip3 install --upgrade pip \
    && pip3 install --no-cache-dir psycopg2-binary gunicorn \
        git+https://github.com/michi-zuri/asreview@mama \
    && rm -rf /var/lib/apt/lists/*
