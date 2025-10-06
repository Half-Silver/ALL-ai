#!/usr/bin/env bash
set -euo pipefail

# Fetch a .gguf model into $SNAP_COMMON/models (or ./backend/models if SNAP_COMMON not set)
# Defaults to Mistral 7B Instruct v0.2 Q4_K_M
# Usage:
#   fetch_model.sh                # default Mistral 7B Instruct v0.2
#   fetch_model.sh MODEL.gguf     # from default repo
#   fetch_model.sh https://...gguf # from direct URL
# Optional: export HF_TOKEN=<token> if the repo requires authentication

log() { printf "[ALL ai] %s\n" "$*"; }
err() { printf "[ALL ai][ERROR] %s\n" "$*" >&2; }

MODEL_REPO="https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main"
DEFAULT_MODEL_FILE="mistral-7b-instruct-v0.2.Q4_K_M.gguf"

TARGET_ROOT="${SNAP_COMMON:-${SNAP:-$PWD}/backend}"
TARGET_DIR="${TARGET_ROOT}/models"

mkdir -p "$TARGET_DIR"

curl_cmd=(curl -L --fail --retry 3 --retry-all-errors)
# Resume if partial
curl_cmd+=( -C - )
# Auth header if HF_TOKEN present
if [ -n "${HF_TOKEN:-}" ]; then
  curl_cmd+=( -H "Authorization: Bearer ${HF_TOKEN}" )
fi

ARG="${1:-}"
if [ -n "$ARG" ]; then
  if echo "$ARG" | grep -Eqi '^https?://'; then
    URL="$ARG"
    TARGET_FILE="$(basename "$ARG")"
  else
    TARGET_FILE="$ARG"
    URL="${MODEL_REPO}/${TARGET_FILE}"
  fi
else
  TARGET_FILE="$DEFAULT_MODEL_FILE"
  URL="${MODEL_REPO}/${TARGET_FILE}"
fi

TARGET_PATH="${TARGET_DIR}/${TARGET_FILE}"
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
log "  snap start all-ai.server   # as a daemon"
log "Or run in foreground for debug:"
log "  snap run all-ai.all-ai start"
log "This will look for the model at: $TARGET_PATH"
