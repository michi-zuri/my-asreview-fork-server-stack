# First stage
FROM python:3.11-slim AS builder
WORKDIR /app

RUN apt-get update \
    && pip3 install --upgrade pip \
    && pip3 install --no-cache-dir \
        psycopg2-binary \
        git+https://github.com/michi-zuri/asreview@mama \
        gunicorn
