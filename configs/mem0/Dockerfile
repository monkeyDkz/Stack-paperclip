FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    libpq-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# psycopg2-binary évite la compilation depuis les sources
RUN pip install --no-cache-dir psycopg2-binary

# mem0ai sans [graph] — kuzu (graph C++ dep) crash sur ARM64
# graph_store est de toute façon désactivé dans config.yaml
RUN pip install --no-cache-dir \
    "mem0ai" \
    "fastapi" \
    "uvicorn[standard]" \
    "chromadb" \
    "pyyaml" \
    "httpx" \
    "anthropic" \
    "ollama" \
    "sentence-transformers"

COPY server.py /app/server.py
WORKDIR /app

EXPOSE 8050

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8050"]
