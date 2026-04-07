#!/bin/zsh

set -euo pipefail

: "${MACOCR_MLX_PYTHON:=/Users/metatron/.local/share/uv/python/cpython-3.11-macos-aarch64-none/bin/python3.11}"
: "${MACOCR_MLX_VENV:=$HOME/.local/share/macocr-mlx-vlm/.venv}"
: "${MACOCR_MLX_UV_CACHE_DIR:=/tmp/codex-uv-cache}"

if ! command -v uv >/dev/null 2>&1; then
  echo "Error: uv is required but was not found on PATH." >&2
  exit 1
fi

if [[ ! -x "$MACOCR_MLX_PYTHON" ]]; then
  echo "Error: Python interpreter not found or not executable: $MACOCR_MLX_PYTHON" >&2
  exit 1
fi

mkdir -p "$MACOCR_MLX_UV_CACHE_DIR"
mkdir -p "$(dirname "$MACOCR_MLX_VENV")"

if [[ ! -x "$MACOCR_MLX_VENV/bin/python" ]]; then
  env UV_CACHE_DIR="$MACOCR_MLX_UV_CACHE_DIR" \
    uv venv --python "$MACOCR_MLX_PYTHON" "$MACOCR_MLX_VENV"
else
  echo "Reusing existing virtual environment: $MACOCR_MLX_VENV" >&2
fi

env UV_CACHE_DIR="$MACOCR_MLX_UV_CACHE_DIR" \
  uv pip install --python "$MACOCR_MLX_VENV/bin/python" mlx-vlm pillow

echo "MLX-VLM environment is ready." >&2
echo "  Python: $MACOCR_MLX_VENV/bin/python" >&2
echo "  Next:   scripts/mlx-vlm/start-server.sh" >&2
echo "  Note:   Run MLX commands from a normal Terminal session with Metal access." >&2
