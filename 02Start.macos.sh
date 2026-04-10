#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "$SCRIPT_DIR/venv/bin/activate" ]]; then
  echo "ERROR: venv not found. Run ./01Setup.macos.sh first."
  exit 1
fi

export HF_HOME="$SCRIPT_DIR/models"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/venv/bin/activate"

ARGS=()

echo
echo "========================================"
echo "Qwen Voice TTS Studio 1.1 - Startup (macOS)"
echo "========================================"
echo

python --version
python -c "import torch; \
print('Torch:', torch.__version__); \
print('CUDA Available:', torch.cuda.is_available()); \
print('MPS Available:', getattr(torch.backends, 'mps', None) and torch.backends.mps.is_available())" \
2>/dev/null || true

echo
read -r -p "Use in LAN mode (other devices can access)? (y/N): " LAN
LAN="${LAN:-N}"
LAN_UPPER="$(printf "%s" "$LAN" | tr '[:lower:]' '[:upper:]')"

if [[ "$LAN_UPPER" == "Y" ]]; then
  LOCAL_IP="$(python - <<'PY_IP'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
  s.connect(("8.8.8.8", 80))
  print(s.getsockname()[0])
except Exception:
  print("")
finally:
  s.close()
PY_IP
)"

  if [[ -n "$LOCAL_IP" ]]; then
    echo "LAN address: http://${LOCAL_IP}:7860"
  fi

  read -r -p "Listen IP (default 0.0.0.0): " LISTEN_IP
  LISTEN_IP="${LISTEN_IP:-0.0.0.0}"

  read -r -p "Port (default 7860): " LISTEN_PORT
  LISTEN_PORT="${LISTEN_PORT:-7860}"

  if [[ -n "$LOCAL_IP" ]]; then
    echo "LAN address: http://${LOCAL_IP}:${LISTEN_PORT}"
  fi

  ARGS+=(--listen "$LISTEN_IP" --port "$LISTEN_PORT")
fi

echo
echo "Launch command:"
if [[ ${#ARGS[@]} -gt 0 ]]; then
  echo "python $SCRIPT_DIR/qwen_voice_gui.py ${ARGS[*]}"
else
  echo "python $SCRIPT_DIR/qwen_voice_gui.py"
fi
echo

if [[ ${#ARGS[@]} -gt 0 ]]; then
  python "$SCRIPT_DIR/qwen_voice_gui.py" "${ARGS[@]}"
else
  python "$SCRIPT_DIR/qwen_voice_gui.py"
fi
