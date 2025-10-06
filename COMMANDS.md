# ALL ai CLI Commands Reference

The `all-ai` command provides a unified interface to manage the ALL ai snap and invoke common llama.cpp tools packaged in the snap.

- Binary path: the CLI is exposed as a snap app `all-ai`.
- If `all-ai` is not on your PATH, prefix commands with `snap run`, e.g.: `snap run all-ai.all-ai status`.

## Quick syntax

```bash
all-ai <command> [args]
all-ai -- [SERVER_ARGS...]           # pass-through directly to llama-server
```

## Notes and behavior
- The snap includes a daemon app `server` (service name: `all-ai.server`) that auto-starts after install.
- The server binds to `0.0.0.0` and auto-selects a free port in `8080..8200`.
- The default model is Mistral 7B Instruct v0.2 Q4_K_M and is auto-fetched on first start if missing.
- Service control (start/stop/restart) must be done on the host with `snap`.
- A lightweight state file is written for status at: `$SNAP_COMMON/all-ai/state.json`.

Environment variables that influence behavior:
- `ALLAI_DEFAULT_MODEL` – default model path (set by snap to Mistral 7B Instruct v0.2)
- `ALLAI_MODEL` – override model path when running foreground
- `ALLAI_PORT` – override port when running foreground
- `ALLAI_ARGS` – extra args passed to `llama-server` by the foreground start script (e.g., `-c 4096 --threads 6`)
- `HF_TOKEN` – auth token for private Hugging Face repos (used by `--fetch`)

Models are stored under: `$SNAP_COMMON/models/`.

---

## Commands

### 1) Status
Show whether the server appears to be running, last known port and model, and a URL hint.

```bash
all-ai status
```

Notes:
- Uses the state file written by the daemon/foreground start script.
- Also attempts a quick TCP check against the recorded port.

### 2) Start (foreground)
Run the server in the foreground (debug mode) using the snap’s start script.

```bash
all-ai start
```

- Auto-selects a free port if `ALLAI_PORT` is not set.
- Uses `ALLAI_MODEL` when set; otherwise falls back to `ALLAI_DEFAULT_MODEL`.
- Persists state (port and model path) to `$SNAP_COMMON/all-ai/state.json`.
- Binds to `0.0.0.0` for LAN access.
- Pass extra args via `ALLAI_ARGS`:
  ```bash
  ALLAI_ARGS="-c 4096 --threads 6" all-ai start
  ```

### 3) Start daemon (service)
Print host commands to manage the daemon service.

```bash
all-ai start all
```

Host commands you’ll see:
```bash
sudo snap start all-ai.server
snap logs -n 100 -f all-ai.server
```

### 4) Fetch models
Download the default model, a repo file by name, or a direct URL into `$SNAP_COMMON/models/`.

```bash
# default model (Mistral 7B Instruct v0.2)
all-ai --fetch

# file from the default repo
all-ai -f mistral-7b-instruct-v0.2.Q4_K_M.gguf

# direct URL
all-ai -f https://huggingface.co/.../model.gguf
```

- Private repos may require:
  ```bash
  export HF_TOKEN=hf_xxx
  all-ai --fetch
  ```

Aliases: `all-ai fetch [MODEL|URL]` is equivalent.

### 5) llama.cpp tools wrappers
The CLI can call common llama.cpp binaries if they were built into the snap.

- Server (alias to `llama-server`):
  ```bash
  all-ai server --help
  all-ai -- -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -c 4096 --threads 6
  ```
  Pass-through: if the first token begins with `-`, the CLI forwards args to `llama-server`.

- CLI (alias to `llama-cli` / `main` / `llama` depending on what’s available):
  ```bash
  all-ai cli -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -p "Hello"
  ```

- Quantize (alias to `quantize` / `llama-quantize`):
  ```bash
  all-ai quantize --help
  ```

- Embedding (alias to `embedding` / `embed`):
  ```bash
  all-ai embed --help
  ```

- Perplexity:
  ```bash
  all-ai perplexity --help
  ```

- Benchmark (alias to `llama-bench` / `bench`):
  ```bash
  all-ai bench --help
  ```

If a tool isn’t present in the snap build, the CLI prints a clear error with the names it tried.

---

## Service management (host)
From the host (not inside the confined app), manage the daemon:

```bash
sudo snap start all-ai.server
sudo snap stop all-ai.server
sudo snap restart all-ai.server
snap services all-ai
snap logs all-ai.server -n 200 -f
```

---

## Examples

```bash
# 1) Check status
all-ai status

# 2) Foreground server with custom args
ALLAI_ARGS="-c 4096 --threads 6" all-ai start

# 3) Fetch the default model
all-ai --fetch

# 4) Run a quick prompt via CLI
all-ai cli -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -p "Hello"

# 5) Pass-through to llama-server
all-ai -- -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -c 4096 --threads 6
```

---

## Troubleshooting
- If the daemon doesn’t start, check logs: `snap logs all-ai.server -n 200`.
- If the model is missing and auto-fetch failed, run `all-ai --fetch` or set `ALLAI_MODEL`.
- Ensure firewall allows the selected port (default range `8080..8200`).
- If a tool subcommand fails, rebuild the snap with examples/server enabled and ensure the tool is staged.
