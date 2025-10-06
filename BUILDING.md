# ALL ai – Snapcraft Build Guide

This document describes how to build, install, run, and troubleshoot the ALL ai snap (CPU‑only llama.cpp + embedded Web UI).

## Overview
- **Base:** `core24`
- **Daemon app:** `server` (service name: `all-ai.server`)
- **Helper CLI:** `all-ai` (status/start/fetch)
- **Default model:** Mistral 7B Instruct v0.2 Q4_K_M `mistral-7b-instruct-v0.2.Q4_K_M.gguf`
- **Model storage:** `$SNAP_COMMON/models/`
- **Networking:** binds to `0.0.0.0` on an auto-selected free port in `8080..8200`

## Requirements
- **Linux build host:** Ubuntu 22.04+ recommended (or Ubuntu Core/Server)
- **Snapcraft:** Core24 (install instructions below)
- **Internet access:** to fetch npm packages and build deps at build-time
- Sufficient disk space (a few GB) and bandwidth (UI and model downloads)

## Install Snapcraft
On Ubuntu 22.04+:
```bash
sudo snap install snapcraft --classic
```

If you’re using LXD or Multipass, Snapcraft will prompt you. LXD is generally recommended for Core24 builds.

## Project layout recap
- `snap/snapcraft.yaml` – Snap build definition
- `bin/start.sh` – Daemon entrypoint; selects a free port; writes a status file
- `bin/all-ai.sh` – CLI helper (status/start/fetch)
- `bin/fetch_model.sh` – Default/explicit model downloader
- `backend/llama.cpp/` – llama.cpp sources used at build time (see options below)

## llama.cpp source options
You have two supported options to provide `llama.cpp` to the build:

- Option A (current default): **Local source** in `backend/llama.cpp/`.
  - `snap/snapcraft.yaml` uses `parts.llama-cpp.source: backend/llama.cpp`
  - Keep only sources in git (your `.gitignore` already excludes build artifacts)

- Option B: **Fetch from upstream in Snapcraft** (no local source checkout required).
  - Edit `snap/snapcraft.yaml` and replace the `source` with a remote URL and pinned tag/commit:
    ```yaml
    parts:
      llama-cpp:
        plugin: cmake
        source: https://github.com/ggerganov/llama.cpp
        source-tag: b123456     # pin to a known-good commit or release
        cmake-parameters:
          - -DCMAKE_BUILD_TYPE=Release
        build-packages:
          - build-essential
          - cmake
          - pkg-config
          - nodejs
          - npm
          - python3
        stage-packages:
          - libstdc++6
        override-build: |
          set -eux
          pushd "$CRAFT_PART_SRC/tools/server/webui"
          npm ci
          npm run build
          popd
          craftctl default
    ```

## Build
From the repository root (this directory):
```bash
snapcraft
```
This will:
- Build the web UI under `tools/server/webui` and embed it into the server
- Compile and install `llama-server` into the snap
- Stage `bin/` and other helper files

The resulting `.snap` will be written in the project directory.

### Clean builds (optional)
If you need to clean:
```bash
snapcraft clean
# or only a specific part
snapcraft clean llama-cpp
```

## Install the snap (unsigned/local)
```bash
sudo snap install --dangerous ./all-ai_1.0.0_amd64.snap
# or the arm64 build on arm devices
```

## Running
- The daemon app `server` (service `all-ai.server`) auto-starts after install.
- It binds to `0.0.0.0` on the first free port in `8080..8200`.

Useful commands:
```bash
# view logs (watch for selected URL)
snap logs all-ai.server -n 200 -f

# manage service
sudo snap start all-ai.server
sudo snap stop all-ai.server
sudo snap restart all-ai.server
snap services all-ai
```

Open the UI from another device on your LAN:
```bash
http://<device-ip>:<port>
# e.g., http://192.168.1.10:8080
```

## CLI helper
```bash
# show status (port, URL, model)
all-ai status

# run in foreground (debug; binds a port and prints URL)
snap run all-ai.all-ai start

# print host commands to start the daemon
all-ai start all

# fetch models (default or specific)
all-ai --fetch                              # default Mistral 7B Instruct v0.2
all-ai -f mistral-7b-instruct-v0.2.Q4_K_M.gguf  # specific filename from default repo
all-ai -f https://huggingface.co/.../x.gguf     # direct URL
```

Note: If `all-ai` isn’t on your PATH, prefix with `snap run`:
```bash
snap run all-ai.all-ai status
```

## Models
- Default model: `$SNAP_COMMON/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf`
- On first start, the daemon will auto-fetch the default model if missing.
- Manual fetch via CLI as shown above.
- Hugging Face private repos may require `HF_TOKEN`:
  ```bash
  export HF_TOKEN=hf_xxx
  all-ai --fetch
  ```
- Use a custom model with the `ALLAI_MODEL` env var when running foreground:
  ```bash
  ALLAI_MODEL=/path/to/your.gguf snap run all-ai.all-ai start
  ```

## Networking and firewall
- The server binds to `0.0.0.0` and is accessible on your LAN.
- Ensure the chosen port is allowed through your firewall. On Ubuntu with UFW:
  ```bash
  sudo ufw allow 8080:8200/tcp
  sudo ufw reload
  ```

## Environment variables
- `ALLAI_DEFAULT_MODEL` – default model path (set by snap to Mistral 7B Instruct v0.2)
- `ALLAI_MODEL` – override model path when running foreground
- `ALLAI_PORT` – override port when running foreground
- `ALLAI_ARGS` – extra args passed to `llama-server` (e.g. `-c 4096 --threads 6`)
- `HF_TOKEN` – auth token for private Hugging Face repos

## Troubleshooting
- **No URL in logs / won’t start**
  - Check logs: `snap logs all-ai.server -n 200`.
  - If model missing and auto-fetch failed, run: `all-ai --fetch` or provide `ALLAI_MODEL`.
- **Cannot access from LAN**
  - Confirm service is running: `snap services all-ai`.
  - Verify port is open locally: `ss -ltnp | grep 8080` (or check logs for actual port).
  - Open firewall (see UFW example above).
- **Port already in use**
  - The daemon auto-selects a free port in `8080..8200`. Stop other services or check logs for the chosen port.
- **Build failures**
  - Clean and retry: `snapcraft clean && snapcraft`.
  - Ensure network access for npm during `webui` build.
- **Model download fails**
  - Check connectivity and, if private repo, export `HF_TOKEN`.

## Cross-architecture notes
- Building on the target architecture is simplest (amd64 on x86_64, arm64 on ARM).
- For cross-building, consider using LXD with an appropriate container and run `snapcraft` inside it.

## Updating
- To rebuild after changes, bump `version:` if you plan to install multiple revisions side-by-side.
- Reinstall the new artifact:
  ```bash
  sudo snap remove all-ai || true
  sudo snap install --dangerous ./all-ai_1.0.0_amd64.snap
  ```

---
For any issues or enhancements, see `README.md` for quick start and this guide for deeper details.
