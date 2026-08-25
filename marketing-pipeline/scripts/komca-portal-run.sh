#!/usr/bin/env bash
# Mac: headed KOMCA browser — CEO does phone auth only.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/komca-load-env.sh"

MODE="full"
TRACK_ID="${KOMCA_TRACK_ID:-AUD-MUS-20260825-003}"
HEADLESS=0

usage() {
  cat <<'EOF'
Usage: komca-portal-run.sh [--mode login|trust|register|full] [--track AUD-MUS-…] [--headless]

Requires KOMCA_USER / KOMCA_PASS in .env or pipeline_data/secrets/komca.env
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-full}"; shift 2 ;;
    --track) TRACK_ID="${2:-}"; shift 2 ;;
    --headless) HEADLESS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

bash "${ROOT}/scripts/mac-install-komca-playwright.sh" 2>/dev/null || true

export KOMCA_TRACK_ID="$TRACK_ID"
ARGS=(--mode "$MODE" --track "$TRACK_ID")
[[ "$HEADLESS" -eq 1 ]] && ARGS+=(--headless)

python3 "${ROOT}/scripts/komca-portal-automation.py" "${ARGS[@]}"
