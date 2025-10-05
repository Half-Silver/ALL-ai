#!/usr/bin/env bash
set -euo pipefail

# Resolve runtime paths
SNAP_DIR=${SNAP:-""}
USER_DATA=${SNAP_USER_DATA:-"$(cd "$(dirname "$0")/.." && pwd)"}/backend
MODEL_DIR="${SNAP_USER_DATA:-"$(cd "$(dirname "$0")/.." && pwd)"}/backend/models"
mkdir -p "$MODEL_DIR"

# Defaults (overridable)
API_HOST=127.0.0.1
API_PORT=${ALLCHAT_API_PORT:-8080}
MODEL_NAME=${ALLCHAT_MODEL:-gemma-2b-it.Q4_K_M.gguf}
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"
THREADS=${ALLCHAT_THREADS:-0} # 0 = auto in llama.cpp server

# Determine llama-server binary path (inside snap or local build)
if [[ -n "$SNAP_DIR" && -x "$SNAP_DIR/bin/llama-server" ]]; then
  LLAMA_SERVER="$SNAP_DIR/bin/llama-server"
elif command -v llama-server >/dev/null 2>&1; then
  LLAMA_SERVER="$(command -v llama-server)"
else
  # Fallback to staged location when running locally from repo after building llama.cpp
  if [[ -x "$(cd "$(dirname "$0")" && pwd)/llama.cpp/build/bin/llama-server" ]]; then
    LLAMA_SERVER="$(cd "$(dirname "$0")" && pwd)/llama.cpp/build/bin/llama-server"
  else
    echo "[ALLchat] ERROR: llama-server binary not found. Build llama.cpp or install snap." >&2
    exit 1
  fi
fi

# Port probing helpers
is_port_in_use() {
  local port=$1
  local host=${2:-127.0.0.1}
  if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE "(${host//\./\\.}|\\*):$port$"
    return $?
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null | awk '{print $4}' | grep -qE "(${host//\./\\.}|0\\.0\\.0\\.0):$port$"
    return $?
  elif command -v nc >/dev/null 2>&1; then
    nc -z "$host" "$port" >/dev/null 2>&1
    return $?
  else
    (echo >"/dev/tcp/$host/$port") >/dev/null 2>&1
    return $?
  fi
}

# Simple port incrementer if busy
pick_port() {
  local port=$1
  local limit=$((port+50))
  local host=${2:-127.0.0.1}
  while [[ $port -le $limit ]]; do
    if ! is_port_in_use "$port" "$host"; then
      echo "$port"; return 0
    fi
    port=$((port+1))
  done
  echo ""; return 1
}

API_PORT=$(pick_port "$API_PORT" "$API_HOST") || { echo "[ALLchat] No free API port found" >&2; exit 1; }

# Ensure default model exists (download if missing)
if [[ ! -f "$MODEL_PATH" ]]; then
  echo "[ALLchat] Downloading model: $MODEL_NAME"
  # Gemma 2B Instruct Q4_K_M community mirror (GGUF). Replace with your vetted URL/mirror as needed.
  # If you have access-restricted models, set ALLCHAT_MODEL_URL to a tokenized Hugging Face URL or internal mirror.
  MODEL_URL=${ALLCHAT_MODEL_URL:-"https://huggingface.co/TheBloke/gemma-2b-it-GGUF/resolve/main/gemma-2b-it.Q4_K_M.gguf?download=true"}
  set +e
  if [[ -n "${HF_TOKEN:-}" ]]; then
    (
      cd "$MODEL_DIR" && \
      curl -L --fail --retry 3 --retry-delay 5 -C - -H "Authorization: Bearer $HF_TOKEN" -o "$MODEL_NAME" "$MODEL_URL"
    )
  else
    (
      cd "$MODEL_DIR" && \
      curl -L --fail --retry 3 --retry-delay 5 -C - -o "$MODEL_NAME" "$MODEL_URL"
    )
  fi
  rc=$?
  set -e
  if [[ $rc -ne 0 || ! -s "$MODEL_PATH" ]]; then
    echo "[ALLchat] ERROR: Model download failed. Set ALLCHAT_MODEL_URL to a reachable GGUF URL and, if required, export HF_TOKEN." >&2
    exit 1
  fi
fi

# Start llama.cpp server (CPU only)
# Key flags: --threads 0 (auto), --host 127.0.0.1, --port, --no-embeddings (reduce RAM), --stream
exec "$LLAMA_SERVER" \
  --host "$API_HOST" \
  --port "$API_PORT" \
  --model "$MODEL_PATH" \
  --threads "$THREADS" \
  --no-embeddings \
  --chunk-size 128 \
  --timeout 120 \
  --mlock false \
  --flash-attn false \
  --cache-reuse true \
  --embedding false \
  --ctx-size 4096 \
  --parallel 1 \
  --log-format text \
  --verbose \
  --prompt-cache "$MODEL_DIR/prompt.cache"
