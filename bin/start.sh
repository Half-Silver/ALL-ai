#!/usr/bin/env bash
set -euo pipefail

# ALL ai start script for llama.cpp server with embedded Web UI
# - Auto-detects free port starting from 8080 unless ALLAI_PORT is set
# - Uses default model at $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf unless ALLAI_MODEL is set
# - Additional args can be provided via ALLAI_ARGS env var

log() { printf "[ALL ai] %s\n" "$*"; }
err() { printf "[ALL ai][ERROR] %s\n" "$*" >&2; }

# Resolve server binary path
resolve_server() {
  local candidates=(
    "${SNAP:-}/usr/bin/llama-server"
    "${SNAP:-}/bin/llama-server"
    "${SNAP:-}/llama-server"
    "llama-server"
  )
  for c in "${candidates[@]}"; do
    if [ -n "$c" ] && command -v "$c" >/dev/null 2>&1; then
      echo "$(command -v "$c")"
      return 0
    fi
    if [ -x "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

find_free_port() {
  local start="${1:-8080}"
  local max="${2:-8200}"
  local p=$start
  while [ "$p" -le "$max" ]; do
    if ! nc -z -w1 127.0.0.1 "$p" >/dev/null 2>&1; then
      echo "$p"
      return 0
    fi
    p=$((p+1))
  done
  return 1
}

main() {
  local server
  if ! server="$(resolve_server)"; then
    err "Could not locate llama-server binary."
    err "Ensure the snap built correctly and includes llama-server."
    exit 1
  fi

  local port="${ALLAI_PORT:-}"
  if [ -z "$port" ]; then
    if ! port="$(find_free_port 8080 8200)"; then
      err "No free port found in range 8080-8200"
      exit 1
    fi
  fi

  local model_path="${ALLAI_MODEL:-}"
  if [ -z "$model_path" ]; then
    model_path="${ALLAI_DEFAULT_MODEL:-${SNAP_COMMON:-$PWD}/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf}"
    if [ ! -f "$model_path" ]; then
      # fallback to staged read-only location inside the snap, if present
      local staged_model="${SNAP:-}/backend/models/$(basename "$model_path")"
      if [ -f "$staged_model" ]; then
        model_path="$staged_model"
      fi
    fi
  fi

  if [ ! -f "$model_path" ]; then
    log "Model not found at: $model_path"
    log "Attempting automatic fetch of default model..."
    if "$SNAP/bin/fetch_model.sh"; then
      # Re-evaluate path to pick up newly fetched default
      local default_model_path="${ALLAI_DEFAULT_MODEL:-${SNAP_COMMON:-$PWD}/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf}"
      if [ -f "$default_model_path" ]; then
        model_path="$default_model_path"
      fi
    fi
    if [ ! -f "$model_path" ]; then
      err "Automatic fetch did not produce a model at: $model_path"
      err "Run: all-ai --fetch"
      err "Or:  snap run all-ai.fetch-model"
      err "Or set ALLAI_MODEL to the path of your .gguf model"
      exit 1
    fi
  fi

  log "Starting ALL ai (llama.cpp server)"
  log "Binary : $server"
  log "Model  : $model_path"
  log "Port   : $port"
  log "URL    : http://127.0.0.1:$port"

  # Allow additional user-provided args via ALLAI_ARGS
  # Example: ALLAI_ARGS="-c 4096 --threads 6" all-ai.all-ai
  # Persist lightweight state for the CLI status command
  STATE_DIR="${SNAP_COMMON:-${SNAP:-$PWD}/common}/all-ai"
  STATE_FILE="$STATE_DIR/state.json"
  mkdir -p "$STATE_DIR"
  printf '{ "port": "%s", "model_path": "%s" }\n' "$port" "$model_path" > "$STATE_FILE"

  exec "$server" -m "$model_path" --host 0.0.0.0 --port "$port" ${ALLAI_ARGS:-}
}

main "$@"
