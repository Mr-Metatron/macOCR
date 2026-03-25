# Project Overview

## What This Project Is

`macOCR` is a macOS command line OCR tool. It captures a user-selected screen region or reads an existing image file, performs OCR, prints the recognized text to stdout, and copies the result to the system clipboard.

The original project only used Apple's Vision framework. It now supports multiple OCR backends:

- `auto`: default, prefers Ollama and falls back to Vision
- `vision`: Apple Vision OCR only
- `ollama`: local Ollama OCR/vision model only

## Repository Shape

This repository is intentionally small.

```text
macOCR/
  AGENTS.md
  README.md
  Podfile
  Pods/
  ocr/
    main.swift
  ocr.xcodeproj/
  ocr.xcworkspace/
  docs/
    development-log.md
    project-overview.md
```

## Key Files

- `ocr/main.swift`
  - Main program entrypoint
  - CLI argument parsing
  - Screen capture or input file resolution
  - Backend selection
  - Vision OCR implementation
  - Ollama HTTP implementation
  - Clipboard copy

- `README.md`
  - User-facing install and usage documentation

- `AGENTS.md`
  - Repository-level workflow for future agents
  - Defines the expected sequence: read docs, explore, plan, implement, log, sync docs, commit

- `Podfile`
  - Declares CocoaPods dependencies:
    - `ScreenCapture`
    - `ArgumentParserKit`

## Runtime Flow

At a high level, the application does this:

1. Parse command line arguments.
2. Decide which OCR backend to use.
3. Resolve the input image:
   - interactive screen capture
   - fixed rectangle screen capture
   - existing file via `--input`
4. Run OCR with the selected backend.
   - In `auto`, report the chosen backend to stderr
5. Print recognized text to stdout.
6. Copy the same text to the macOS clipboard.

## Backend Logic

### `auto`

This is the default mode used when the user runs plain `ocr`.

Behavior:

1. Try to build an Ollama configuration.
2. If no model is explicitly configured, query local Ollama model tags.
3. Prefer OCR/vision-looking local model names.
4. Attempt OCR through Ollama.
5. Print the chosen Ollama backend and model to stderr.
6. If Ollama setup or request fails, print a warning to stderr and fall back to Vision OCR.
7. Print the Vision fallback selection to stderr.

This mode is designed for the exact workflow: "type `ocr`, prefer local Ollama first".
Successful Ollama OCR requests ask Ollama to keep the chosen model loaded for 45 minutes so repeated OCR runs avoid unnecessary reloads.

### `ollama`

Strict Ollama-only mode.

Behavior:

1. Use `--ollama-model` if provided.
2. Otherwise use `OLLAMA_MODEL` if provided.
3. Otherwise try local model auto-detection through `GET /api/tags`.
4. Send OCR request to `POST /api/generate`.
5. Return plain OCR text.

This mode does not fall back to Vision.
Successful requests also ask Ollama to keep the selected model loaded for 45 minutes.

### `vision`

Apple Vision-only mode.

Behavior:

1. Load the image into `CIImage`
2. Convert to `CGImage`
3. Run `VNRecognizeTextRequest`
4. Join recognized lines with `\n`

This is the stable fallback path when Ollama is unavailable.

## Ollama Integration Details

Default host:

```text
http://127.0.0.1:11434
```

Accepted forms:

- `http://127.0.0.1:11434`
- `http://127.0.0.1:11434/api`

Relevant options and env vars:

- `--backend`
- `--ollama-model`
- `--ollama-host`
- `--ollama-prompt`
- `OLLAMA_MODEL`
- `OLLAMA_HOST`
- `OLLAMA_PROMPT`

The request body uses:

- `model`
- `prompt`
- `images` as base64
- `stream: false`
- `keep_alive: "45m"`
- `temperature: 0`

The default OCR prompt is intentionally strict: it asks for transcription only and avoids summaries or descriptions.

## Model Auto-Detection

When no explicit Ollama model is provided, the app queries `/api/tags` and ranks local model names with a simple heuristic.

Current preference signals include:

- `ocr`
- `vision`
- `vl`
- `llava`
- `glm`
- `:latest`

This is simple on purpose. It is easy to adjust if the local model naming strategy changes later.

## Screen Capture and Input Handling

Input sources:

- interactive region capture
- fixed rect capture with `--rect x,y,w,h`
- image file with `--input`

Optional image persistence:

- `--save-image <path>`

The screen capture implementation comes from the `ScreenCapture` CocoaPod and ultimately uses macOS screenshot tooling.
Captured images now use a unique temporary file per run and are removed after processing, which avoids reusing stale screenshots after a canceled selection.

## Dependencies

### First-party / platform frameworks

- `Foundation`
- `Cocoa`
- `CoreImage`
- `Vision`

### CocoaPods

- `ScreenCapture`
  - wraps region capture behavior

- `ArgumentParserKit`
  - older command line argument parsing library
  - note that option handles are `OptionArgument<T>`, not modern Swift ArgumentParser types

## Current Build and Verification Notes

1. The project should be treated as a workspace-based CocoaPods app.
   - Prefer `ocr.xcworkspace` inside Xcode.

2. Shell `xcodebuild` works most reliably as a two-step project build.
   - `xcodebuild -workspace ocr.xcworkspace ...` still reports the workspace as invalid in shell on this machine
   - Build CocoaPods dependencies first with `Pods/Pods.xcodeproj` and scheme `Pods-ocr`
   - Then build the app target with `ocr.xcodeproj`, scheme `ocr`, and `BUILD_DIR=build`
   - The resulting release binary lands at `build/Release/ocr`

3. Current reliable shell release build commands:

```bash
xcodebuild -project Pods/Pods.xcodeproj -scheme Pods-ocr -configuration Release -derivedDataPath build-release CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ocr.xcodeproj -scheme ocr -configuration Release -derivedDataPath build-release BUILD_DIR=build CODE_SIGNING_ALLOWED=NO build
```

4. The local `ollama` command line binary is unstable on this machine.
   - It crashes during `ollama list`
   - The Ollama HTTP API is healthy and should be used for diagnostics instead

## Suggested Agent Starting Points

If a future agent needs to extend behavior, start here:

1. Read `ocr/main.swift`
2. Read `AGENTS.md`
3. Read `README.md`
4. Check `docs/development-log.md`
5. Confirm local Ollama API availability with:

```bash
curl -sS http://127.0.0.1:11434/api/tags
```

6. Confirm the latest local release build with:

```bash
ls -l build/Release/ocr
```

7. If changing backend logic, focus on:
   - `parseBackend`
   - `makeOllamaConfiguration`
   - `recognizeTextWithVision`
   - `recognizeTextWithOllama`
   - the main backend switch near the bottom of `main.swift`

## Good Next Improvements

- Split `ocr/main.swift` into smaller files once feature surface grows further
- Add automated tests for backend selection and Ollama response parsing
- Improve model auto-detection with explicit capability metadata if Ollama exposes it
- Add optional structured debug logging for backend selection and fallback decisions
