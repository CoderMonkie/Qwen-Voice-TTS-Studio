#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Qwen Voice TTS Studio 1.1 - Setup Script (macOS)"
echo "========================================"
echo

echo "This script is for macOS (zsh users can run it directly)."
echo

QWEN_MODEL_SOURCE="${QWEN_MODEL_SOURCE:-hf}"
echo "Model source env: QWEN_MODEL_SOURCE=${QWEN_MODEL_SOURCE}"
read -r -p "Model source HuggingFace (H) or ModelScope (M)? [H/M]: " MODEL_SRC
MODEL_SRC="${MODEL_SRC:-H}"
MODEL_SRC_UPPER="$(printf "%s" "$MODEL_SRC" | tr '[:lower:]' '[:upper:]')"
if [[ "$MODEL_SRC_UPPER" == "M" ]]; then
  QWEN_MODEL_SOURCE="modelscope"
else
  QWEN_MODEL_SOURCE="hf"
fi
export QWEN_MODEL_SOURCE
echo "Using model source: ${QWEN_MODEL_SOURCE}"
echo

choose_python() {
  local candidates
  candidates=("python3.12" "python3.11" "python3.10" "python3")
  local cmd
  for cmd in "${candidates[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

PY="$(choose_python || true)"
if [[ -z "${PY}" ]]; then
  echo "ERROR: python3 not found."
  echo "Please install Python 3.10+ (3.12 recommended) and re-run."
  exit 1
fi

if ! "$PY" - <<'PY_CHECK'
import sys
sys.exit(0 if sys.version_info >= (3, 10) else 1)
PY_CHECK
then
  echo "ERROR: $PY is below Python 3.10."
  echo "Please install Python 3.10+ (3.12 recommended)."
  exit 1
fi

echo "Using Python: $PY"
echo

VENV_PATH="$SCRIPT_DIR/venv"
if [[ -d "$VENV_PATH" ]]; then
  read -r -p "venv exists. Reuse (R) or create New (N)? [R/N]: " REUSE
  REUSE="${REUSE:-R}"
  REUSE_UPPER="$(printf "%s" "$REUSE" | tr '[:lower:]' '[:upper:]')"
  if [[ "$REUSE_UPPER" == "N" ]]; then
    echo "Removing existing virtual environment"
    rm -rf "$VENV_PATH"
    echo "Creating virtual environment"
    "$PY" -m venv "$VENV_PATH"
  else
    echo "Using existing virtual environment."
  fi
else
  echo "Creating virtual environment"
  "$PY" -m venv "$VENV_PATH"
fi

echo
# shellcheck disable=SC1091
source "$VENV_PATH/bin/activate"

python -m pip install --upgrade pip

echo
echo "Installing PyTorch (pinned compatible set for macOS)"
python -m pip install --upgrade --force-reinstall \
  torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0

echo
echo "Installing requirements"
python -m pip install -r "$SCRIPT_DIR/requirements.txt"

if [[ "$QWEN_MODEL_SOURCE" == "modelscope" ]]; then
  echo
  echo "Installing modelscope for ModelScope downloads"
  python -m pip install -U modelscope || {
    echo
    echo "WARNING: modelscope install failed."
    echo "ModelScope download option may fail."
  }
fi

echo
echo "Installing qwen-asr (for Voice ASR tab)"
python -m pip install -U qwen-asr || {
  echo
  echo "WARNING: qwen-asr install failed."
  echo "Voice ASR tab will prompt manual installation."
}

echo
echo "Pinning transformers==4.57.3 (required by qwen-tts)"
python -m pip install --upgrade --no-deps transformers==4.57.3 || {
  echo
  echo "WARNING: Failed to pin transformers to 4.57.3."
}

echo
echo "flash-attn is skipped on macOS."

mkdir -p "$SCRIPT_DIR/models"

echo
read -r -p "Download Qwen3-TTS models now (~10-12GB)? (y/N): " DOWNLOAD_MODELS
DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-N}"
DOWNLOAD_MODELS_UPPER="$(printf "%s" "$DOWNLOAD_MODELS" | tr '[:lower:]' '[:upper:]')"

if [[ "$DOWNLOAD_MODELS_UPPER" == "Y" ]]; then
  echo
  echo "Downloading models into ./models (source: $QWEN_MODEL_SOURCE) ..."
  python - <<'PY_DL'
import os

source = (os.environ.get("QWEN_MODEL_SOURCE") or "hf").strip().lower()

repos = [
  "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
  "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
  "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
]
for repo in repos:
  name = repo.split("/")[-1]
  local_dir = f"models/{name}"
  print(f"Downloading: {repo} -> {local_dir}")

  if source in ("ms", "modelscope"):
    try:
      from modelscope.hub.snapshot_download import snapshot_download
    except Exception as e:
      raise RuntimeError(
        "ModelScope download selected, but modelscope is unavailable"
      ) from e
    try:
      snapshot_download(
        model_id=repo,
        local_dir=local_dir,
      )
    except TypeError:
      snapshot_download(
        model_id=repo,
        cache_dir=local_dir,
      )
  else:
    from huggingface_hub import snapshot_download
    snapshot_download(
      repo_id=repo,
      local_dir=local_dir,
      local_dir_use_symlinks=False,
    )
print("Model download step finished.")
PY_DL
else
  echo
  echo "Skipping model download. Models will be pulled on first use."
fi

echo
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo
echo "Run: ./02Start.macos.sh"
