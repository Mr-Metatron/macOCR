# MLX-VLM Phase 0

## Goal

Validate `GLM-OCR` on local `mlx-vlm` before changing `macOCR` itself.

This phase keeps the current `macOCR` runtime untouched.
It only verifies the local MLX-VLM toolchain, the GLM-OCR model path, and the OpenAI-compatible server endpoints that a future Swift backend would call.

## Validated Local Runtime

- Python interpreter:
  - `/Users/metatron/.local/share/uv/python/cpython-3.11-macos-aarch64-none/bin/python3.11`
- Package manager:
  - `uv 0.11.3`
- Installed package:
  - `mlx-vlm 0.4.4`
- Default server address for this phase:
  - `http://127.0.0.1:18080`
- Baseline model:
  - `mlx-community/GLM-OCR-bf16`

## Important Environment Note

MLX needs direct Metal access on this machine.

During validation, importing `mlx.core` inside the Codex sandbox crashed with an `NSRangeException` because MLX saw no Metal devices.
The same import worked immediately outside the sandbox and reported:

```text
Device(gpu, 0)
```

For that reason, run the MLX commands below from a normal Terminal session, not from a sandboxed shell.

## Repo Scripts

- `scripts/mlx-vlm/setup-venv.sh`
  - Creates or reuses a dedicated MLX-VLM venv
  - Installs `mlx-vlm` and `pillow`
- `scripts/mlx-vlm/start-server.sh`
  - Starts `mlx_vlm.server` on `127.0.0.1:18080` by default
- `scripts/mlx-vlm/smoke-test.sh`
  - Calls both:
    - `mlx_vlm generate`
    - `/chat/completions`
  - Also prints `/health` and `/models`

Default environment variables used by the scripts:

- `MACOCR_MLX_PYTHON`
- `MACOCR_MLX_VENV`
- `MACOCR_MLX_UV_CACHE_DIR`
- `MLX_VLM_MODEL`
- `MLX_VLM_HOST`
- `MLX_VLM_PORT`
- `MLX_VLM_PROMPT`
- `MLX_VLM_MAX_TOKENS`
- `MLX_VLM_ENABLE_THINKING`
- `HF_HOME`

## Setup

```bash
scripts/mlx-vlm/setup-venv.sh
```

If you want to reproduce the exact Python path used during validation:

```bash
MACOCR_MLX_PYTHON=/Users/metatron/.local/share/uv/python/cpython-3.11-macos-aarch64-none/bin/python3.11 \
scripts/mlx-vlm/setup-venv.sh
```

## Start The Local Server

```bash
scripts/mlx-vlm/start-server.sh
```

Explicit host, port, and model example:

```bash
MLX_VLM_HOST=127.0.0.1 \
MLX_VLM_PORT=18080 \
MLX_VLM_MODEL=mlx-community/GLM-OCR-bf16 \
scripts/mlx-vlm/start-server.sh
```

## Smoke Test

With the server already running:

```bash
scripts/mlx-vlm/smoke-test.sh /path/to/image-1.png /path/to/image-2.jpg
```

The script runs:

1. `GET /health`
2. `GET /models`
3. `mlx_vlm generate` twice per image
4. `POST /chat/completions` once per image

## Verified Endpoint Shapes

Observed `GET /health` response:

```json
{"status":"healthy","loaded_model":"mlx-community/GLM-OCR-bf16","loaded_adapter":null}
```

Observed `GET /models` response after downloading two local checkpoints:

```json
{"object":"list","data":[{"id":"EZCon/GLM-OCR-8bit-mlx","object":"model","created":1775579838},{"id":"mlx-community/GLM-OCR-bf16","object":"model","created":1775578733}]}
```

Observed `POST /chat/completions` request shape that works with the local server:

```json
{
  "model": "mlx-community/GLM-OCR-bf16",
  "stream": false,
  "max_tokens": 512,
  "enable_thinking": true,
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "input_image", "image_url": "/path/to/image.jpg" },
        { "type": "input_text", "text": "Text Recognition:" }
      ]
    }
  ]
}
```

Observed response shape:

```json
{
  "model": "mlx-community/GLM-OCR-bf16",
  "choices": [
    {
      "finish_reason": "stop",
      "message": {
        "role": "assistant",
        "content": "```markdown\n\n```",
        "tool_calls": []
      }
    }
  ],
  "usage": {
    "input_tokens": 13,
    "output_tokens": 6,
    "total_tokens": 19,
    "prompt_tps": 62.88640125803765,
    "generation_tps": 62.67379439569241,
    "peak_memory": 2.258931156
  }
}
```

## Current Status

The runtime path is working:

- local Python environment is valid
- `mlx_vlm generate` runs on GPU
- `mlx_vlm server` starts on `127.0.0.1:18080`
- `/health`, `/models`, and `/chat/completions` all respond

The OCR quality is not yet acceptable:

- `mlx-community/GLM-OCR-bf16` produced either empty markdown or non-useful output on browser-rendered smoke images
- `EZCon/GLM-OCR-8bit-mlx` showed the same behavior on the same sample

That means Phase 0 has validated the environment and API wiring, but not yet the final OCR quality bar needed to replace the current Ollama backend in `macOCR`.

## Recommended Next Step

Before changing `ocr/main.swift`, resolve one of these:

1. confirm the correct GLM-OCR task prompt and message format for `mlx-vlm`
2. reproduce with real screenshots from the target workflow, not only synthetic/browser smoke images
3. test a different MLX OCR-capable model if GLM-OCR remains blank through the same validated server path
