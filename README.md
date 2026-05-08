# macOCR

> This is an enhanced fork of [schappim/macOCR](https://github.com/schappim/macOCR) that adds Ollama-powered OCR, flexible backend selection (auto/Vision/Ollama), and Raycast Script Command integration — while keeping the original Vision-based OCR fully functional.

macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard.
When you invoke the `ocr` command, a "screen capture" like cursor is shown.
Any text within the bounds will be converted to text.

You could invoke the app using the likes of [Alfred.app](https://www.alfredapp.com/), [LaunchBar](https://obdev.at/products/launchbar/index.html), [Hammerspoon](http://www.hammerspoon.org/), [Quicksilver](https://qsapp.com/), [Raycast](https://raycast.com/) etc.

Examples:
- [macOS Shortcut Workflow](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b)
- [Alfred.app Workflow](https://files.littlebird.com.au/OCR2-ONrTkn.zip)
- [Raycast Script](https://gist.github.com/cheeaun/1405816e5ceb397cbc9028204f82dc98)
- [LaunchBar Action](https://github.com/jsmjsm/macOCR-LaunchBar-Action)

An example Alfred.app workflow is [available here](https://files.littlebird.com.au/OCR2-ONrTkn.zip).

If you're still wondering "how does this work?", I always find the .gif is the best way to clarify things:

![How it works](https://files.littlebird.com.au/Screen-Recording-2021-05-21-13-27-27-FEPQtcuk6FFweb4QEk7Y1mXhsv8B.gif)


## Installation

Compile the code in this repo, or download a prebuilt binary ([Apple Silicon](https://files.littlebird.com.au/ocr.zip), [Intel](https://files.littlebird.com.au/ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip)) and put it on your path.

### Build From Source

For the current repository layout, the most reliable shell build flow is:

```bash
cd /path/to/macOCR

xcodebuild \
  -project Pods/Pods.xcodeproj \
  -scheme Pods-ocr \
  -configuration Release \
  -derivedDataPath build-release \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project ocr.xcodeproj \
  -scheme ocr \
  -configuration Release \
  -derivedDataPath build-release \
  BUILD_DIR=build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This produces the CLI binary at:

```bash
build/Release/ocr
```

If you are working interactively in Xcode, prefer opening `ocr.xcworkspace`.

### Put a Local Build on Your PATH

To expose the current `Release` build as `ocr` without copying the binary each time:

```bash
mkdir -p ~/.local/bin
ln -sf /path/to/macOCR/build/Release/ocr ~/.local/bin/ocr
```

For a parallel debug command, you can keep a second link:

```bash
ln -sf /path/to/macOCR/build/Debug/ocr ~/.local/bin/ocr-debug
```

### Raycast Script Command

This repository now includes a ready-to-import Raycast Script Command at:

```bash
raycast/ocr-capture.sh
```

To install it in Raycast:

1. Build `macOCR` so the binary exists at `build/Release/ocr`, or expose `ocr` on your `PATH`.
2. In Raycast, open `Settings` -> `Extensions`.
3. Choose `Add Script Directory`.
4. Select the repository's `raycast/` directory.
5. Assign a hotkey to `OCR Capture`.

The script command:

- launches the existing interactive region capture flow
- accepts optional backend and language arguments
- prints recognized text in Raycast
- still lets `macOCR` copy the final text to the clipboard

If your `ocr` binary lives somewhere else, set `MACOCR_BIN` in Raycast to point at that executable.

Apple Silicon Install (via Homebrew):

```
brew install schappim/ocr/ocr
```

> **Note:** The Homebrew formula and prebuilt binaries above install the **original upstream** macOCR without Ollama backend support. To use all features described in this README (auto backend, Ollama integration, etc.), [build from source](#build-from-source).

Once installed, you can then use the [macOS Shortcut Workflow](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b) (see below for details)

Apple Silicon Install (via Curl):

```
curl -O https://files.littlebird.com.au/ocr2.zip
unzip ocr.zip
sudo cp ocr /usr/local/bin
```

Intel Install:

```
curl -O https://files.littlebird.com.au/ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip
unzip ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip
sudo cp ocr /usr/local/bin
```


When running the app the first time, you will likely be asked to allow the app access to your screen.

If you launch `macOCR` through Raycast, make sure Raycast also has the required screen recording permissions in macOS System Settings.

![Enabling access to screen](https://files.littlebird.com.au/Shared-Image-2021-05-20-08-58-38.png)

## Usage

### Basic Usage

Simply run `ocr` to interactively select a region of your screen:

```bash
ocr
```

By default, `ocr` uses the `auto` backend: it prefers a local Ollama OCR/vision model, and falls back to Apple's Vision OCR if Ollama is unavailable or the request fails.

The recognized text will be printed to stdout and copied to your clipboard.
Backend-selection and fallback notices are written to stderr so stdout remains OCR text only.
When Ollama is used, macOCR asks the Ollama server to keep the selected model loaded for 45 minutes between requests to reduce repeated model reloads.

### Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | | Display available options |
| `--backend <auto\|vision\|ollama>` | `-b` | Select OCR backend. Defaults to `auto`, which prefers Ollama and falls back to Vision |
| `--language <code>` | `-l` | Set Vision OCR language (macOS 11+), or pass a language hint to Ollama |
| `--list-languages` | | List supported OCR languages for the selected backend |
| `--rect <x,y,w,h>` | `-R` | Capture a specific screen region without interactive selection |
| `--input <file>` | `-i` | Use an existing image file instead of screen capture |
| `--save-image <path>` | `-s` | Save the captured screenshot to the specified path |
| `--ollama-model <name>` | `-m` | Vision-capable Ollama model to use with `--backend ollama` |
| `--ollama-host <url>` | | Ollama server URL or `/api` base URL. Defaults to `http://127.0.0.1:11434` |
| `--ollama-prompt <text>` | | Override the default OCR extraction prompt sent to Ollama |

### Examples

**OCR with a specific language:**
```bash
ocr -l zh-Hans          # Simplified Chinese
ocr -l ja-JP            # Japanese
ocr --language de-DE    # German
```

**List supported languages:**
```bash
ocr --list-languages
ocr --backend auto --list-languages
ocr --backend ollama --list-languages
```

**Capture a specific screen region (for scripting):**
```bash
ocr --rect 100,200,500,300
```

**OCR an existing image file:**
```bash
ocr --input ./screenshot.png
ocr -i ~/Documents/image.jpg
```

**Save the captured screenshot:**
```bash
ocr --save-image ~/Desktop/capture.png
```

**Combine options:**
```bash
# Capture region, save image, and use Chinese OCR
ocr --rect 0,0,800,600 --save-image ~/Desktop/shot.png -l zh-Hans
```

**Use Ollama as the OCR backend:**
```bash
# Let macOCR auto-select a local Ollama OCR/vision model first
ocr

# Force a local vision model served by Ollama
ocr --backend ollama --ollama-model glm-ocr:latest

# OCR an existing image with Ollama
ocr -b ollama -m glm-ocr:latest -i ~/Desktop/scan.png

# Point to a non-default Ollama host
ocr -b ollama -m glm-ocr:latest --ollama-host http://192.168.1.10:11434

# Force Apple's Vision OCR only
ocr --backend vision
```

You can also configure Ollama via environment variables:

```bash
export OLLAMA_MODEL=glm-ocr:latest
export OLLAMA_HOST=http://127.0.0.1:11434
ocr
```

If `OLLAMA_MODEL` is not set, macOCR will try to auto-detect a local Ollama model and prefer OCR/vision-looking names such as `glm-ocr:latest`.
`--ollama-host` accepts either the server root such as `http://127.0.0.1:11434` or a base URL ending in `/api`.
Successful Ollama OCR requests are sent with `keep_alive` set to `45m`.

### Supported Languages

On macOS 11 (Big Sur) and later, the following languages are supported:

- `en-US` - English
- `fr-FR` - French
- `it-IT` - Italian
- `de-DE` - German
- `es-ES` - Spanish
- `pt-BR` - Portuguese
- `zh-Hans` - Simplified Chinese
- `zh-Hant` - Traditional Chinese

Run `ocr --list-languages` to see all available Vision languages on your system. The Ollama backend uses the selected model's native language support instead.

## Add as Shortcut Workflow (Mac Monterey 12+)
1. Open up [MacOS Shortcuts](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b) available on MacOS 12+.
2. Create new `Shortcut`
3. Add `Run Shell script`
4. Set input to one of these (runs this app):
  - `/opt/homebrew/bin/ocr` (if installed via Homebrew on Apple Silicon)
  - `/usr/local/bin/ocr` (if installed manually or built from source)
5. Goto `Shortcut Details`

<img width="300px" src="https://user-images.githubusercontent.com/11782590/164676495-3c07a73f-5254-47eb-a4ff-d6a943617954.png" alt="settings" />

7. Set `Pin in menubar` as true

![Kapture 2022-04-22 at 19 09 40](https://user-images.githubusercontent.com/11782590/164675564-e4e03c3c-7065-4083-9978-7fd316251b0e.gif)

## OS Support

This should run on macOS Catalina (10.15) and above. Language selection and extended language support requires macOS Big Sur (11.0) or later.

## Who made this?

macOCR was originally created by [Marcus Schappi](https://twitter.com/schappi). This fork adds:

- **Ollama backend** — use local vision-language models via Ollama for OCR, with automatic model detection and keep-alive support
- **Auto backend** — prefers Ollama when available, falls back gracefully to Apple Vision OCR
- **Raycast Script Command** — drop-in script for Raycast users with backend and language selection
- **Expanded CLI** — model selection, host configuration, custom OCR prompts, and more

Original upstream: [schappim/macOCR](https://github.com/schappim/macOCR)

> From the original author: I create software ([and even hardware](https://chickcom.com/hardware)) to automate ecommerce, including [USDZ.app](https://usdz.app), [Chick Commerce](https://chickcom.com/), [Australia Post app on Shopify](https://apps.shopify.com/auspost-shipping), and [Script Ninja](https://apps.shopify.com/cockatoo).

## Thoughts on Sherlocking?

Apple, please sherlock this software!

## MIT License

Copyright 2021 Marcus Schappi (original), with modifications.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
