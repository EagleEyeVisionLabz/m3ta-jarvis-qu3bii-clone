#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for MARK XXXIX (Linux).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[cloud-agent-install] Ensuring system packages..."
PKGS=(
  portaudio19-dev libportaudio2 libasound2-dev
  python3-tk python3-dev python3-venv
  libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 libxcb-image0
  libxcb-render-util0 libxcb-xinerama0 libxkbcommon-x11-0
  libegl1 ffmpeg
  libnss3 libnspr4 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2
  libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1
  libpango-1.0-0 libcairo2
)
missing=()
for p in "${PKGS[@]}"; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then
    missing+=("$p")
  fi
done
if ((${#missing[@]})); then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
else
  echo "[cloud-agent-install] System packages already present."
fi

echo "[cloud-agent-install] Ensuring Python venv at .venv..."
if [[ ! -x .venv/bin/python ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip -q

echo "[cloud-agent-install] Filtering Linux Python requirements..."
python - <<'PY'
from pathlib import Path
windows_only = {
    "comtypes", "pycaw", "win10toast", "pywinauto", "pygetwindow",
}
seen = set()
out = []
for line in Path("requirements.txt").read_text(encoding="utf-8-sig").splitlines():
    raw = line.strip()
    if not raw or raw.startswith("#"):
        continue
    name = raw.split("==")[0].split(">=")[0].split("<=")[0].split("~=")[0].split("[")[0].strip().lower()
    if name in seen or name in windows_only:
        continue
    seen.add(name)
    out.append(raw)
Path("/tmp/requirements-linux.txt").write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Wrote {len(out)} packages to /tmp/requirements-linux.txt")
PY

echo "[cloud-agent-install] Installing Python packages into .venv..."
python -m pip install -r /tmp/requirements-linux.txt -q

echo "[cloud-agent-install] Installing Playwright Chromium..."
python -m playwright install --with-deps chromium

if [[ ! -f face.png ]]; then
  echo "[cloud-agent-install] Generating placeholder face.png..."
  python - <<'PY'
from PIL import Image, ImageDraw
img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.ellipse((40, 40, 472, 472), fill=(0, 180, 120, 255))
d.ellipse((160, 180, 230, 250), fill=(0, 40, 30, 255))
d.ellipse((282, 180, 352, 250), fill=(0, 40, 30, 255))
d.arc((180, 250, 332, 380), 20, 160, fill=(0, 40, 30, 255), width=8)
img.save("face.png")
print("wrote face.png")
PY
fi

echo "[cloud-agent-install] Verifying core imports..."
python - <<'PY'
mods = [
    "sounddevice", "google.genai", "PIL", "playwright", "pyautogui",
    "cv2", "PyQt6.QtWidgets",
]
for m in mods:
    __import__(m)
    print("OK", m)
print("install verification passed")
PY

echo "[cloud-agent-install] Done."
