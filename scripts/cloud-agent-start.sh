#!/usr/bin/env bash
# Per-boot Cloud Agent start: materialize Gemini config from secrets.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -x .venv/bin/python ]]; then
  echo "[cloud-agent-start] Missing .venv — run scripts/cloud-agent-install.sh first." >&2
  exit 1
fi

mkdir -p config

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  .venv/bin/python - <<'PY'
import json, os
from pathlib import Path
path = Path("config/api_keys.json")
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {}
data["gemini_api_key"] = os.environ["GEMINI_API_KEY"].strip()
data.setdefault("os_system", "linux")
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print("[cloud-agent-start] Wrote config/api_keys.json from GEMINI_API_KEY")
PY
else
  echo "[cloud-agent-start] GEMINI_API_KEY not set; UI setup overlay will prompt for a key." >&2
fi

echo "[cloud-agent-start] Ready. Run: .venv/bin/python main.py"
