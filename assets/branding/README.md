# ALL ai Branding Assets

Place your branding assets here and update the Web UI build to include them.

Recommended files:
- logo.svg or logo.png
- favicon.svg or favicon.ico

How to apply branding to the embedded Web UI:
1. Replace `tools/server/webui/static/favicon.svg` in the llama.cpp source with your favicon:
   - Source path: `backend/llama.cpp/tools/server/webui/static/favicon.svg`
   - After replacement, rebuild the Web UI (see step 3 below).

2. Optionally update any other images or icons used by the UI under:
   - `backend/llama.cpp/tools/server/webui/static/`

3. Rebuild the Web UI and server binary so the new assets are embedded:
   - The Snap build part `llama-cpp` already runs:
     ```sh
     npm ci && npm run build
     cmake -B build -S . && cmake --build build --config Release -t llama-server
     ```
   - When building via Snap (`snapcraft`), this is done automatically.

Notes:
- The server serves the pre-built single-file UI from `tools/server/public/index.html.gz`, which is generated from the SvelteKit app.
- The CMake target `llama-server` includes `index.html.gz.hpp` generated from the `public` output.
