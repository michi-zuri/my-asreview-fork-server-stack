# ============================================================
# Stage 1: build a wheel that contains the compiled frontend
# ============================================================
FROM python:3.11-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch mama --single-branch \
        https://github.com/michi-zuri/asreview.git /src/asreview

WORKDIR /src/asreview
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/src/asreview/asreview/webapp/node_modules \
    --mount=type=cache,target=/root/.cache/pip \
    pip install build \
    && python setup.py compile_assets \
    && python -m build --wheel --no-isolation
    # Wheel is now at /src/asreview/dist/*.whl

# ============================================================
# Stage 2: lean runtime image
# ============================================================
FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /src/asreview/dist/*.whl /tmp/

RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --upgrade pip \
    && pip3 install \
        psycopg2-binary \
        gunicorn \
        /tmp/*.whl \
    && rm -rf /tmp/*.whl