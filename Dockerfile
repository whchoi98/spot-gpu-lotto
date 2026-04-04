# syntax=docker/dockerfile:1
FROM python:3.11-slim AS base

WORKDIR /app

# Install dependencies only (cached layer)
COPY pyproject.toml .
RUN pip install --no-cache-dir . && rm -rf /root/.cache/pip

# Copy source code
COPY src/ src/

# --- API Server ---
FROM base AS api-server
EXPOSE 8000
CMD ["uvicorn", "api_server.main:app", "--host", "0.0.0.0", "--port", "8000"]
ENV PYTHONPATH=/app/src

# --- Dispatcher ---
FROM base AS dispatcher
CMD ["python", "-m", "dispatcher.main"]
ENV PYTHONPATH=/app/src

# --- Price Watcher ---
FROM base AS price-watcher
CMD ["python", "-m", "price_watcher.main"]
ENV PYTHONPATH=/app/src
