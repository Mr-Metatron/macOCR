#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title OCR Capture
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.packageName macOCR
# @raycast.description Capture a screen region with macOCR and copy recognized text to the clipboard
# @raycast.argument1 { "type": "dropdown", "placeholder": "Backend", "optional": true, "data": [{ "title": "Auto", "value": "auto" }, { "title": "Vision", "value": "vision" }, { "title": "Ollama", "value": "ollama" }] }
# @raycast.argument2 { "type": "text", "placeholder": "Language hint, e.g. zh-Hans", "optional": true }
# @raycast.needsConfirmation false

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DEFAULT_BIN="$REPO_ROOT/build/Release/ocr"

if [[ -n "${MACOCR_BIN:-}" ]]; then
  OCR_BIN="$MACOCR_BIN"
elif [[ -x "$DEFAULT_BIN" ]]; then
  OCR_BIN="$DEFAULT_BIN"
elif command -v ocr >/dev/null 2>&1; then
  OCR_BIN="$(command -v ocr)"
else
  echo "Error: Could not find the macOCR binary." >&2
  echo "Build $REPO_ROOT first, or set MACOCR_BIN to your ocr executable." >&2
  exit 1
fi

args=()
if [[ -n "${1:-}" ]]; then
  args+=(--backend "$1")
fi

if [[ -n "${2:-}" ]]; then
  args+=(--language "$2")
fi

stdout_file="$(mktemp)"
stderr_file="$(mktemp)"
cleanup() {
  rm -f "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

if "$OCR_BIN" "${args[@]}" >"$stdout_file" 2>"$stderr_file"; then
  if [[ -s "$stdout_file" ]]; then
    cat "$stdout_file"
  else
    echo "OCR completed, but no text was recognized."
  fi
else
  cat "$stderr_file" >&2
  exit 1
fi
