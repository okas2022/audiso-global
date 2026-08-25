#!/usr/bin/env bash
# Mac task: KOMCA 3 online forms (신탁계약·입회·저작물) → CEO phone auth only.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${KOMCA_TRACK_ID:-AUD-MUS-20260825-003}"
PORT="${KOMCA_CDP_PORT:-9222}"

if [[ -n "${KOMCA_USER:-}" && -n "${KOMCA_PASS:-}" ]]; then
  bash "${ROOT}/scripts/mac-komca-write-env.sh"
else
  bash "${ROOT}/scripts/komca-load-env.sh" 2>/dev/null || true
fi

bash "${ROOT}/scripts/mac-install-komca-playwright.sh"
bash "${ROOT}/scripts/komca-trust-doc-pack.sh" --track "$TRACK"

# Launch debug Chrome if port not open
if ! curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  KOMCA_PROFILE="${ROOT}/pipeline_data/browser_profiles/komca_chrome_cdp"
  mkdir -p "$KOMCA_PROFILE"
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port="${PORT}" \
    "--user-data-dir=${KOMCA_PROFILE}" \
    "https://www.komca.or.kr/" &
  echo "[komca-task] Chrome started — CEO: log in + open 3-forms page if needed, waiting 45s…"
  sleep 45
fi

export KOMCA_CDP_URL="http://127.0.0.1:${PORT}"
bash "${ROOT}/scripts/komca-online-forms-run.sh" --track "$TRACK" --cdp "$KOMCA_CDP_URL"
