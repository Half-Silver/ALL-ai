# ALL ai (CPU-only llama.cpp + Web UI) – Snap

A private, CPU-only AI chat app that runs the llama.cpp server with its built-in modern Web UI, rebranded as ALL ai.

- Backend: `llama.cpp` server (`llama-server`)
- UI: SvelteKit-based web UI embedded into the server
- Packaging: Snap (strict confinement) targeting ALL Core OS (Ubuntu Core based)

## Project Layout

- `snap/snapcraft.yaml` – Snap build definition
- `bin/start.sh` – Starts the server, auto-selects a free port, and prints the URL
- `bin/fetch_model.sh` – Downloads Gemma 2B Q4_K_M model to `$SNAP_COMMON/models`
- `backend/models/.gitkeep` – Placeholder for local models
- `assets/branding/` – Guidance for replacing favicon/logo

The build pulls source for `llama.cpp` from `../backend/llama.cpp` and builds `llama-server` with the embedded UI.

## Requirements (for building)

- Linux build host (Ubuntu 22.04+ recommended)
- Snapcraft (Core24)
- Internet access (for fetching build dependencies and NPM packages)

## Build

From this `ALL-ai/` directory (where this README is located):

```bash
snapcraft
```

This will:
- build the web UI (SvelteKit) and emit `tools/server/public/index.html.gz`
- build and install `llama-server`
- stage `bin/` scripts and helper files into the snap

The resulting `.snap` will be in the project directory.

## Install (local / unsigned)

```bash
sudo snap install --dangerous ./all-ai_1.0.0_amd64.snap
```

If you built for arm64, install the corresponding file.

## Fetch the default model

By default, the app expects Gemma 2B Q4_K_M model at `$SNAP_COMMON/models/gemma-2b-Q4_K_M.gguf`.
Use the helper app to download it:

```bash
snap run all-ai.fetch-model
```

You can also download manually and place it at the same path.

## Run

The snap runs as a daemon named `all-ai` and auto-starts after install. To (re)start manually:

```bash
sudo snap restart all-ai
```

The daemon listens on the first free port from 8080..8200. On start, it prints the selected URL to logs:

```bash
snap logs all-ai -n 100 -f
```

Then open the printed URL in your browser (e.g., `http://127.0.0.1:8080`).

## Configuration

- Default model path: `$SNAP_COMMON/models/gemma-2b-Q4_K_M.gguf`
- Override using environment variables when running the command directly (for debugging):

```bash
ALLAI_MODEL=/path/to/your-model.gguf ALLAI_PORT=8090 snap run all-ai.all-ai
```

- Extra server args can be provided via `ALLAI_ARGS` (e.g., `-c 4096 --threads 6`).

## Branding

To customize favicon/logo:
- Replace `backend/llama.cpp/tools/server/webui/static/favicon.svg`
- Optionally add other assets under `static/`
- Rebuild the snap so the embedded UI picks up the assets

See `assets/branding/README.md` for details.

## Notes

- This Snap targets CPU-only inference (no GPU offload). For GPU support, additional dependencies and flags would be required when building llama.cpp.
- The upstream server binary remains `llama-server` for compatibility, but user-facing UI strings have been rebranded to "ALL ai".
