#!/usr/bin/env bash
# Mac: Suno generate + stems + Finder-local Google Drive folder for smartphone.
# CEO policy: mkdir into Drive desktop My Drive = auto sync. No OAuth/API required.
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

# Primary: Finder-local mkdir/rsync into Gmail My Drive (Drive desktop auto-sync)
if bash "${ROOT}/scripts/mac-create-audiso-music-mydrive.sh" "$TRACK" 2>&1 | tee -a "$LOG"; then
  echo "[music-phone] My Drive folder OK (no API)" | tee -a "$LOG"
  exit 0
fi

echo "[music-phone] Drive desktop My Drive not mounted." | tee -a "$LOG" >&2
echo "  Fix: Google Drive for desktop → sign in ONLY okas2000@gmail.com" | tee -a "$LOG" >&2
echo "  Then: bash scripts/mac-create-audiso-music-mydrive.sh ${TRACK}" | tee -a "$LOG" >&2
exit 1
