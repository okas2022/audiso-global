#!/bin/bash
# Double-click in Finder (repo OR Drive → Audiso Music) to run Suno generate NOW.
# Works even if Mac has not git-pulled yet: falls back to curl from GitHub main.
set -euo pipefail

export HOME="${HOME:-/Users/Mac}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
FORCE="${GLOBAL}/marketing-pipeline/scripts/mac-suno-force-now.sh"
# Same folder as this .command when dropped into Drive Audiso Music
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
RAW="https://raw.githubusercontent.com/okas2022/audiso-global/main/marketing-pipeline/scripts/mac-suno-force-now.sh"

echo "AUDISO Suno NOW — 「너의 행복이 나라면」(AUD-MUS-20260825-004)"
echo "account: okas2000@gmail.com (ss2013)"

if [[ -d "${GLOBAL}/.git" ]]; then
  cd "$GLOBAL" || true
  git fetch origin main 2>/dev/null || true
  git pull --ff-only origin main 2>/dev/null || true
fi

run_force() {
  local script="$1"
  chmod +x "$script" 2>/dev/null || true
  bash "$script"
}

if [[ -f "$FORCE" ]]; then
  run_force "$FORCE"
elif [[ -f "${HERE}/mac-suno-force-now.sh" ]]; then
  run_force "${HERE}/mac-suno-force-now.sh"
else
  echo "Local script missing — downloading from GitHub main…"
  curl -fsSL "$RAW" -o /tmp/mac-suno-force-now.sh
  run_force /tmp/mac-suno-force-now.sh
fi

echo ""
echo "Done. Check Suno Create for 「너의 행복이 나라면」."
read -r -p "Press Enter to close…" || true
