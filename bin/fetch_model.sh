#!/usr/bin/env bash
set -euo pipefail

# Fetch Gemma 2B Q4_K_M model into $SNAP_COMMON/models (or ./backend/models if SNAP_COMMON not set)
# Source: https://huggingface.co/mlabonne/gemma-2b-GGUF/blob/main/gemma-2b-Q4_K_M.gguf
# Optional: export HF_TOKEN=<token> if the repo requires authentication

log() { printf "[ALL ai] %s\n" "$*"; }
err() { printf "[ALL ai][ERROR] %s\n" "$*" >&2; }

MODEL_REPO="https://huggingface.co/mlabonne/gemma-2b-GGUF/resolve/main"
MODEL_FILE="gemma-2b-Q4_K_M.gguf"

TARGET_ROOT="${SNAP_COMMON:-${SNAP:-$PWD}/backend}"
TARGET_DIR="${TARGET_ROOT}/models"
TARGET_PATH="${TARGET_DIR}/${MODEL_FILE}"

mkdir -p "$TARGET_DIR"

curl_cmd=(curl -L --fail --retry 3 --retry-all-errors)
# Resume if partial
curl_cmd+=( -C - )
# Auth header if HF_TOKEN present
if [ -n "${HF_TOKEN:-}" ]; then
  curl_cmd+=( -H "Authorization: Bearer ${HF_TOKEN}" )
fi

URL="${MODEL_REPO}/${MODEL_FILE}"
log "Downloading model: ${URL}"
log "Target: ${TARGET_PATH}"

# Use a temporary file then move atomically
TMP_FILE="${TARGET_PATH}.part"

if "${curl_cmd[@]}" -o "$TMP_FILE" "$URL"; then
  if [ ! -s "$TMP_FILE" ]; then
    err "Downloaded file is empty: $TMP_FILE"
    exit 1
  fi
  mv -f "$TMP_FILE" "$TARGET_PATH"
  log "Model saved to: $TARGET_PATH"
else
  err "Download failed. Check connectivity or HF token (HF_TOKEN)."
  exit 1
fi

# Print usage hint
log "To start the server:"
log "  snap run all-ai.all-ai"
log "This will look for the model at: $TARGET_PATH"
