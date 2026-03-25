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

## 2026-03-25 - Predictability Fixes

### Scope

Address three user-visible behaviors that could feel unpredictable:

1. canceled screen capture reusing an old temp image
2. `auto` mode not telling the user which backend/model actually ran
3. `--ollama-host` duplicating `/api` in some common host inputs

### Work Completed

1. Reworked temporary screenshot handling in `ocr/main.swift`.
   - Stopped using a shared fixed temp filename
   - Switched to a unique temporary PNG path per run
   - Added cleanup after OCR completes
   - This prevents stale screenshot reuse after a canceled interactive selection

2. Added runtime backend notices to stderr for `auto` mode.
   - When Ollama is selected, the app now reports the chosen model
   - When Ollama fails and Vision is used, the fallback is explicitly reported
   - Stdout remains reserved for OCR text output

3. Hardened Ollama host URL normalization.
   - `--ollama-host` now accepts both server roots and `/api` base URLs
   - Paths ending in `/api` no longer become `/api/api/...`
   - Paths already ending in `/api/<endpoint>` are normalized to the requested endpoint

4. Updated user and handoff documentation.
   - README now explains stderr backend notices
   - README now documents `/api`-suffixed host compatibility
   - Project overview now reflects the temp file and stderr behavior

### Validation Performed

1. Re-ran Xcode source diagnostics on `ocr/main.swift`
   - No file diagnostics remained
   - No workspace errors remained in the issue navigator

2. Reviewed the final runtime paths in source.
   - Temporary captures now use unique files
   - `auto` mode now emits explicit backend notices
   - Ollama URL building now normalizes `/api` correctly

### Files Changed During This Fix

- `ocr/main.swift`
- `README.md`
- `docs/development-log.md`
- `docs/project-overview.md`
