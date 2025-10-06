# ALL ai (CPU-only llama.cpp + Web UI) – Snap

ALL ai is a private, CPU‑only AI chat app built on llama.cpp. It packages the `llama-server` with its modern embedded Web UI as a Snap, and exposes a helper CLI `all-ai`.

## Features

- **CPU‑only inference** using upstream `llama.cpp`
- **Embedded Web UI** served directly by `llama-server`
- **Auto model bootstrap** (Mistral 7B Instruct v0.2 Q4_K_M)
- **Daemonized service** with automatic start on install
- **Helper CLI**: `all-ai status | start | --fetch` and wrappers for common llama.cpp tools
- **LAN access**: binds to `0.0.0.0` on a free port (8080..8200)

## Project Layout

- `snap/snapcraft.yaml` – Snap build definition
- `bin/all-ai.sh` – CLI: `all-ai status`, `all-ai start|start all`, `all-ai --fetch|-f`, `all-ai server|cli|quantize|embed|perplexity|bench`
- `bin/start.sh` – Starts the server, selects a free port, persists state
- `bin/fetch_model.sh` – Downloads default Mistral 7B Instruct v0.2 or a specified model/URL into `$SNAP_COMMON/models`
- `backend/models/.gitkeep` – Placeholder (models live under `$SNAP_COMMON/models` at runtime)
- `assets/branding/` – Guidance for customizing favicon/logo

## Requirements (for building)

- Linux build host (Ubuntu 22.04+ recommended)
- Snapcraft (Core24)
- Internet access (to fetch NPM packages and build deps)

## Build

From this `ALL-ai/` directory:

```bash
snapcraft
```

See `BUILDING.md` for a deeper build guide (clean builds, LXD, troubleshooting).

This will:
- Build the Web UI and embed it into the server
- Compile and install `llama-server`
- Stage CLI/helper scripts into the snap

The resulting `.snap` will be in the project directory.

## Install (local / unsigned)

```bash
sudo snap install --dangerous ./all-ai_1.0.0_amd64.snap
```

Install the arm64 build on ARM devices when applicable.

## Fetch the default model

Default model: Mistral 7B Instruct v0.2 Q4_K_M
Path: `$SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf`

Recommended via CLI:

```bash
all-ai --fetch                              # default model
all-ai -f mistral-7b-instruct-v0.2.Q4_K_M.gguf   # from default repo
all-ai -f https://huggingface.co/.../model.gguf  # direct URL
```

Legacy helper also available:

```bash
snap run all-ai.fetch-model
```

## Run

The daemon app is `server` (service name: `all-ai.server`) and auto‑starts after install.

```bash
sudo snap restart all-ai.server
snap logs all-ai.server -n 200 -f
```

Open the UI:

```bash
http://127.0.0.1:<port>
http://<device-ip>:<port>    # reachable on your LAN (binds to 0.0.0.0)
```

Quick status:

```bash
all-ai status
```

Foreground (debug) run:

```bash
snap run all-ai.all-ai start
```

## CLI quickstart

```bash
# status / fetch / start
all-ai status
all-ai --fetch
all-ai start         # foreground, prints URL
all-ai start all     # prints host command to start the daemon

# pass-through to llama-server
all-ai -- -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -c 4096 --threads 6
```

See `COMMANDS.md` for the full `all-ai` command reference.

## llama.cpp tools via all-ai

If built into the snap, you can call common tools:

- `all-ai server [ARGS...]` → `llama-server`
- `all-ai cli [ARGS...]` → `llama-cli` / `main` / `llama`
- `all-ai quantize [ARGS...]` → `quantize` / `llama-quantize`
- `all-ai embed [ARGS...]` → `embedding` / `embed`
- `all-ai perplexity [ARGS...]` → `perplexity`
- `all-ai bench [ARGS...]` → `llama-bench` / `bench`

Examples:

```bash
all-ai server --help
all-ai cli -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -p "Hello"
all-ai quantize --help
all-ai bench --help
```

## Networking and firewall

- Binds to `0.0.0.0` and auto‑selects a free port in `8080..8200`
- Open your firewall if needed (Ubuntu UFW example):

```bash
sudo ufw allow 8080:8200/tcp
sudo ufw reload
```

## Configuration

- Default model: `$SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf`
- Run in foreground with overrides:

```bash
ALLAI_MODEL=/path/to/model.gguf ALLAI_PORT=8090 snap run all-ai.all-ai start
```

Environment variables:
- `ALLAI_DEFAULT_MODEL` – default model path (set by snap)
- `ALLAI_MODEL` – override model path (foreground runs)
- `ALLAI_PORT` – override port (foreground runs)
- `ALLAI_ARGS` – extra args for `llama-server` (e.g., `-c 4096 --threads 6`)
- `HF_TOKEN` – Hugging Face token for private repos (used by `--fetch`)

## Storage paths

- Models: `$SNAP_COMMON/models/`
- CLI/daemon state: `$SNAP_COMMON/all-ai/state.json`

## Troubleshooting

- No URL / won’t start:
  - `snap logs all-ai.server -n 200`
  - Ensure a model exists. If auto-fetch failed: `all-ai --fetch` or set `ALLAI_MODEL`
- Cannot access from LAN:
  - Confirm service is running: `snap services all-ai`
  - Open firewall for selected port range
- Build failures:
  - `snapcraft clean && snapcraft`
  - Ensure internet access for UI build
- Model download fails:
  - Check connectivity and, if needed, set `HF_TOKEN`

## More docs

- Build guide: `BUILDING.md`
- CLI reference: `COMMANDS.md`
For a complete command reference, see `COMMANDS.md`.
## llama.cpp tools via all-ai

Use the `all-ai` CLI to access common llama.cpp tools packaged in this snap:

- **server**: `all-ai server [ARGS...]` → `llama-server`
{{ ... }}
  - If the first arg starts with a dash, it is passed to `llama-server`, e.g. `all-ai -c 4096 --threads 6`

Examples:

```bash
# show server status and last known port/model
all-ai status
server --help

# simple prompt with CLI
all-ai cli -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -p "Hello"

# quantization tool help
{{ ... }}

# benchmarking
all-ai bench --help

# pass-through to server (equivalent to llama-server ...)
all-ai -- -m $SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf -c 4096 --threads 6
```
