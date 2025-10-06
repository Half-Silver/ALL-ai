#!/usr/bin/env bash
set -euo pipefail

# ALL ai CLI
# Provides helper subcommands:
#  - status: show server status and last known port
#  - start all: print instructions to start the daemon service
#  - start: run the server in the foreground (debug)
#  - -f|--fetch [MODEL|URL] or 'fetch [MODEL|URL]': fetch a model into $SNAP_COMMON/models
#
# Notes:
# - Service control (start/stop/restart) must be done via host 'snap' command.
#   From inside a confined snap we typically cannot invoke 'snap' directly.
#   We print the appropriate host commands for convenience.

log() { printf "[ALL ai] %s\n" "$*"; }
err() { printf "[ALL ai][ERROR] %s\n" "$*" >&2; }

SNAP_COMMON_DIR="${SNAP_COMMON:-${SNAP:-$PWD}/common}"
STATE_DIR="$SNAP_COMMON_DIR/all-ai"
STATE_FILE="$STATE_DIR/state.json"

# Resolve a binary path within the snap or PATH
resolve_bin() {
  local name="$1"
  local candidates=(
    "${SNAP:-}/usr/bin/$name"
    "${SNAP:-}/bin/$name"
    "$name"
  )
  for c in "${candidates[@]}"; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
    if command -v "$c" >/dev/null 2>&1; then echo "$(command -v "$c")"; return 0; fi
  done
  return 1
}

# Try a list of binary names, execute the first available with given args
run_one_of() {
  local names=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    names+=("$1"); shift
  done
  shift || true
  local n
  for n in "${names[@]}"; do
    local p
    if p="$(resolve_bin "$n")"; then
      exec "$p" "$@"
    fi
  done
  err "None of the following llama.cpp tools are available in this snap: ${names[*]}"
  exit 1
}

usage() {
  cat <<'EOF'
ALL ai CLI

Usage:
  all-ai status
  all-ai start all           # prints the host command to start the daemon service
  all-ai start               # runs server in the foreground (debug)
  all-ai -f [MODEL|URL]
  all-ai --fetch [MODEL|URL]
  all-ai fetch [MODEL|URL]
  
  # llama.cpp tools (if included in this snap build)
  all-ai server [ARGS...]        # alias to llama-server
  all-ai cli [ARGS...]           # alias to llama-cli/main
  all-ai quantize [ARGS...]      # alias to quantize/llama-quantize
  all-ai embed [ARGS...]         # alias to embedding
  all-ai perplexity [ARGS...]    # alias to perplexity
  all-ai bench [ARGS...]         # alias to llama-bench
  
  # pass-through to llama-server (treat unknown leading flags as server args)
  all-ai -- [SERVER_ARGS...]
  all-ai help

Examples:
  all-ai --fetch                     # downloads default Mistral 7B Instruct v0.2
  all-ai -f https://.../model.gguf   # downloads from a direct URL
  all-ai -f mistral-7b-instruct-v0.2.Q4_K_M.gguf  # downloads that file from the default repo
  
  # run llama.cpp tools
  all-ai server --help
  all-ai cli -m /path/model.gguf -p "Hello"
  all-ai quantize --help
  all-ai bench --help

Notes:
  - Managing the daemon requires host commands, e.g.:
      sudo snap start all-ai.server
      sudo snap stop all-ai.server
      snap services all-ai
      snap logs -n 100 -f all-ai.server
EOF
}

status() {
  local running="no"
  local pid=""
  if command -v pgrep >/dev/null 2>&1; then
    # Limit to processes within this snap (path contains $SNAP)
    if pid=$(pgrep -f "${SNAP:-}/usr/bin/llama-server" || true); then
      if [ -n "$pid" ]; then running="yes"; fi
    fi
  fi

  local port=""
  local model=""
  if [ -f "$STATE_FILE" ]; then
    port=$(sed -n 's/.*"port"\s*:\s*"\([0-9]*\)".*/\1/p' "$STATE_FILE" | head -n1 || true)
    model=$(sed -n 's/.*"model_path"\s*:\s*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n1 || true)
  fi

  if [ -n "$port" ] && command -v nc >/dev/null 2>&1; then
    if nc -z -w1 127.0.0.1 "$port" >/dev/null 2>&1; then
      running="yes"
    fi
  fi

  log "Status: $running"
  if [ -n "$port" ]; then
    log "Port: $port"
    log "URL : http://127.0.0.1:$port"
  fi
  if [ -n "$model" ]; then
    log "Model: $model"
  fi
  if [ "$running" != "yes" ]; then
    log "Service control (requires host): sudo snap start all-ai.server"
  fi
}

fetch_model() {
  local arg="${1:-}"
  if [ -n "$arg" ]; then
    "$SNAP/bin/fetch_model.sh" "$arg"
  else
    "$SNAP/bin/fetch_model.sh"
  fi
}

start_all() {
  # We cannot manage snap services from a confined app; print instructions.
  log "To start the daemon service (host):"
  log "  sudo snap start all-ai.server"
  log "To view logs:"
  log "  snap logs -n 100 -f all-ai.server"
}

start_fg() {
  log "Starting ALL ai server in the foreground (debug mode)"
  exec "$SNAP/bin/start.sh"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    status)
      status
      ;;
    start)
      shift || true
      if [ "${1:-}" = "all" ]; then
        start_all
      else
        start_fg
      fi
      ;;
    server|llama-server)
      shift || true
      run_one_of llama-server -- "$@"
      ;;
    cli|llama-cli|main|llama)
      shift || true
      run_one_of llama-cli main llama -- "$@"
      ;;
    quantize|llama-quantize|quant)
      shift || true
      run_one_of quantize llama-quantize -- "$@"
      ;;
    embed|embedding)
      shift || true
      run_one_of embedding embed -- "$@"
      ;;
    perplexity|ppl)
      shift || true
      run_one_of perplexity -- "$@"
      ;;
    bench|llama-bench|benchmark)
      shift || true
      run_one_of llama-bench bench -- "$@"
      ;;
    -f|--fetch|fetch)
      shift || true
      fetch_model "${1:-}"
      ;;
    --)
      shift || true
      run_one_of llama-server -- "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    "")
      usage
      ;;
    *)
      # If the first arg looks like a flag, treat as pass-through to llama-server
      if [[ "$cmd" == -* ]]; then
        run_one_of llama-server -- "$cmd" "$@"
      else
        err "Unknown command: $cmd"
        usage
        exit 1
      fi
      ;;
  esac
}

main "$@"
