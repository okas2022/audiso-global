#!/usr/bin/env bash
# Mac task entry: write credentials from env → full KOMCA automation.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${KOMCA_TRACK_ID:-AUD-MUS-20260825-003}"

if [[ -n "${KOMCA_USER:-}" && -n "${KOMCA_PASS:-}" ]]; then
  bash "${ROOT}/scripts/mac-komca-write-env.sh"
else
  echo "[komca-task] KOMCA_USER/KOMCA_PASS not in env — trying .env" >&2
  bash "${ROOT}/scripts/komca-load-env.sh"
fi

bash "${ROOT}/scripts/mac-install-komca-playwright.sh"
bash "${ROOT}/scripts/komca-full-automation.sh" --track "$TRACK"
