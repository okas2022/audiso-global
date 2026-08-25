#!/usr/bin/env bash
# Install Playwright + Chromium for KOMCA portal automation (Mac once).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"

if ! python3 -c "import playwright" 2>/dev/null; then
  echo "[komca-playwright] installing playwright…"
  python3 -m pip install --user playwright 2>/dev/null || pip3 install playwright
fi

python3 -m playwright install chromium 2>/dev/null || true
echo "[komca-playwright] ready"
