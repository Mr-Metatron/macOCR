#!/bin/zsh

set -euo pipefail

: "${MACOCR_MLX_VENV:=$HOME/.local/share/macocr-mlx-vlm/.venv}"
: "${MACOCR_MLX_PYTHON:=$MACOCR_MLX_VENV/bin/python}"
: "${MLX_VLM_MODEL:=mlx-community/GLM-OCR-bf16}"
: "${MLX_VLM_HOST:=127.0.0.1}"
: "${MLX_VLM_PORT:=18080}"
: "${HF_HOME:=$HOME/.cache/huggingface}"

if [[ ! -x "$MACOCR_MLX_PYTHON" ]]; then
  echo "Error: MLX-VLM Python environment not found: $MACOCR_MLX_PYTHON" >&2
  echo "Run scripts/mlx-vlm/setup-venv.sh first, or override MACOCR_MLX_VENV." >&2
  exit 1
fi

mkdir -p "$HF_HOME"

echo "Starting mlx-vlm server on http://$MLX_VLM_HOST:$MLX_VLM_PORT" >&2
echo "Model: $MLX_VLM_MODEL" >&2
echo "HF_HOME: $HF_HOME" >&2

exec env HF_HOME="$HF_HOME" \
  "$MACOCR_MLX_PYTHON" -m mlx_vlm server \
  --model "$MLX_VLM_MODEL" \
  --host "$MLX_VLM_HOST" \
  --port "$MLX_VLM_PORT"
