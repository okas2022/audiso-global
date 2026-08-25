#!/usr/bin/env bash
# Mac: Suno generate + stems + Google Drive (API or desktop sync) for smartphone.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${SUNO_TRACK_ID:-AUD-MUS-20260825-004}"
export SUNO_TRACK_ID="$TRACK"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/music-phone-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG")"

echo "[music-phone] $(date -u +%Y-%m-%dT%H:%M:%SZ) track=${TRACK}" | tee -a "$LOG"

# Suno + stems (may fail if Chrome/Suno unavailable — still sync existing files)
bash "${ROOT}/scripts/mac-suno-bootstrap-and-run.sh" 2>&1 | tee -a "$LOG" || \
  echo "[music-phone] suno step skipped/failed — syncing existing track files" | tee -a "$LOG"

# Drive API (share link) if OAuth token exists
if [[ -f "${ROOT}/pipeline_data/secrets/google_drive_token.json" ]]; then
  if bash "${ROOT}/scripts/music-drive-upload.sh" "$TRACK" --share-link 2>&1 | tee -a "$LOG"; then
    echo "[music-phone] Drive API OK" | tee -a "$LOG"
    exit 0
  fi
fi

# Fallback: Google Drive desktop folder (no OAuth JSON)
if bash "${ROOT}/scripts/mac-music-drive-desktop-sync.sh" "$TRACK" 2>&1 | tee -a "$LOG"; then
  exit 0
fi

echo "[music-phone] Drive setup needed — one of:" | tee -a "$LOG" >&2
echo "  A) Install Google Drive for desktop (auto sync to phone)" | tee -a "$LOG" >&2
echo "  B) bash scripts/mac-google-drive-setup.sh (OAuth once)" | tee -a "$LOG" >&2
exit 1
