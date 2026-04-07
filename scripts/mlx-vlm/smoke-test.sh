#!/bin/zsh

set -euo pipefail

: "${MACOCR_MLX_VENV:=$HOME/.local/share/macocr-mlx-vlm/.venv}"
: "${MACOCR_MLX_PYTHON:=$MACOCR_MLX_VENV/bin/python}"
: "${MLX_VLM_MODEL:=mlx-community/GLM-OCR-bf16}"
: "${MLX_VLM_HOST:=127.0.0.1}"
: "${MLX_VLM_PORT:=18080}"
: "${MLX_VLM_PROMPT:=Text Recognition:}"
: "${MLX_VLM_MAX_TOKENS:=512}"
: "${MLX_VLM_ENABLE_THINKING:=true}"
: "${HF_HOME:=$HOME/.cache/huggingface}"

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 <image-path> [more-image-paths...]" >&2
  exit 1
fi

if [[ ! -x "$MACOCR_MLX_PYTHON" ]]; then
  echo "Error: MLX-VLM Python environment not found: $MACOCR_MLX_PYTHON" >&2
  echo "Run scripts/mlx-vlm/setup-venv.sh first, or override MACOCR_MLX_VENV." >&2
  exit 1
fi

server_base="http://$MLX_VLM_HOST:$MLX_VLM_PORT"
thinking_args=()
if [[ "$MLX_VLM_ENABLE_THINKING" == "true" ]]; then
  thinking_args+=(--enable-thinking)
fi

echo "== Server health ==" >&2
curl -sS "$server_base/health"
echo

echo "== Server models ==" >&2
curl -sS "$server_base/models"
echo

for image_path in "$@"; do
  if [[ ! -f "$image_path" ]]; then
    echo "Error: Missing image file: $image_path" >&2
    exit 1
  fi

  echo "== CLI run 1: $image_path ==" >&2
  env HF_HOME="$HF_HOME" \
    "$MACOCR_MLX_PYTHON" -m mlx_vlm generate \
    --model "$MLX_VLM_MODEL" \
    --image "$image_path" \
    --prompt "$MLX_VLM_PROMPT" \
    --max-tokens "$MLX_VLM_MAX_TOKENS" \
    "${thinking_args[@]}"
  echo

  echo "== CLI run 2: $image_path ==" >&2
  env HF_HOME="$HF_HOME" \
    "$MACOCR_MLX_PYTHON" -m mlx_vlm generate \
    --model "$MLX_VLM_MODEL" \
    --image "$image_path" \
    --prompt "$MLX_VLM_PROMPT" \
    --max-tokens "$MLX_VLM_MAX_TOKENS" \
    "${thinking_args[@]}"
  echo

  echo "== /chat/completions: $image_path ==" >&2
  "$MACOCR_MLX_PYTHON" - "$server_base" "$MLX_VLM_MODEL" "$image_path" "$MLX_VLM_PROMPT" "$MLX_VLM_MAX_TOKENS" "$MLX_VLM_ENABLE_THINKING" <<'PY'
import json
import sys
import urllib.request

server_base, model, image_path, prompt, max_tokens, enable_thinking = sys.argv[1:7]

payload = {
    "model": model,
    "stream": False,
    "max_tokens": int(max_tokens),
    "enable_thinking": enable_thinking.lower() == "true",
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "input_image", "image_url": image_path},
                {"type": "input_text", "text": prompt},
            ],
        }
    ],
}

request = urllib.request.Request(
    f"{server_base}/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
)

with urllib.request.urlopen(request, timeout=600) as response:
    print(response.read().decode("utf-8"))
PY
  echo
done
