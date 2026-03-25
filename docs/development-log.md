# Development Log

## 2026-03-25

### Scope

Document the recent work done on `macOCR`, especially the new local Ollama OCR backend and the default backend behavior change.

### Work Completed

1. Confirmed the active Xcode workspace and repository state.
   - Active workspace: `ocr.xcworkspace`
   - Repository was already up to date with `origin/master`

2. Refactored the main CLI implementation in `ocr/main.swift`.
   - Moved the old single-path Vision OCR flow into a backend-aware structure.
   - Added shared helpers for argument parsing, image resolution, output emission, and error handling.

3. Added an Ollama HTTP backend.
   - New backend name: `ollama`
   - Request path: `POST /api/generate`
   - Sends image input as base64 in the `images` array
   - Uses a default OCR prompt that asks for plain transcription only

4. Added backend selection modes.
   - `auto`: default behavior
   - `vision`: Apple Vision OCR only
   - `ollama`: Ollama only

5. Changed default runtime behavior.
   - Bare `ocr` now uses `auto`
   - `auto` prefers Ollama first
   - If Ollama setup or request fails, it falls back to Vision OCR
   - Explicit `--backend ollama` does not fall back

6. Added Ollama model configuration and auto-detection.
   - CLI options:
     - `--backend`
     - `--ollama-model`
     - `--ollama-host`
     - `--ollama-prompt`
   - Environment variables:
     - `OLLAMA_MODEL`
     - `OLLAMA_HOST`
     - `OLLAMA_PROMPT`
   - If no model is configured, the app queries `GET /api/tags` and picks the best local candidate by simple scoring.

7. Updated documentation in `README.md`.
   - Added Ollama usage examples
   - Documented `auto` as the default backend
   - Documented the fallback behavior and model auto-detection

8. Added `docs/` handoff material.
   - `docs/development-log.md`
   - `docs/project-overview.md`

### Validation Performed

1. Xcode source diagnostics
   - `ocr/main.swift` ended with zero file diagnostics
   - Workspace issue navigator ended with zero errors

2. Local Ollama service check
   - `http://127.0.0.1:11434/api/tags` responded successfully
   - Installed local models included:
     - `glm-ocr:latest`
     - `modelscope.cn/ggml-org/GLM-OCR-GGUF:latest`

3. End-to-end HTTP OCR request check
   - Generated a temporary PNG image containing:
     - `HELLO 123`
     - `OCR TEST`
   - Sent the image to local Ollama using the same request shape used by the app
   - Result returned by Ollama:
     - `HELLO 123`
     - `OCR TEST`

### Important Notes

1. The local `ollama` CLI currently crashes on this machine, but the Ollama HTTP API works.
   - This project uses the HTTP API, so the app can still function correctly.

2. Shell-based `xcodebuild` verification is currently noisy and unreliable in this environment.
   - `xcodebuild -workspace ...` reported the workspace as invalid in shell tests
   - `xcodebuild -project ...` also ran into signing and CocoaPods-related build environment issues
   - Xcode editor diagnostics were used as the authoritative compile check during this task

3. The repository is still very small and centralized.
   - Most application logic lives in `ocr/main.swift`
   - Any future backend or argument work will probably touch this file first

### Files Changed During This Work

- `ocr/main.swift`
- `README.md`
- `docs/development-log.md`
- `docs/project-overview.md`

## 2026-03-25 - Documentation Follow-up

### Scope

Add repository-level agent workflow instructions so future agents follow the same intake, planning, implementation, logging, documentation, and commit process.

### Work Completed

1. Added `AGENTS.md` at the repository root.
   - Defined the expected workflow for future agents
   - Explicitly required reading docs first
   - Explicitly required free exploration before changes
   - Explicitly required writing an implementation plan before substantial work
   - Explicitly required updating the development log and project docs
   - Explicitly required creating a git commit at the end

2. Updated project documentation references.
   - Synced `docs/project-overview.md` to mention `AGENTS.md` as a starting point

### Validation Performed

1. Verified that `AGENTS.md` exists at the repository root.
2. Verified that the `docs/` handoff files still exist and remain aligned with the new workflow document.

### Files Changed During This Follow-up

- `AGENTS.md`
- `docs/development-log.md`
- `docs/project-overview.md`
