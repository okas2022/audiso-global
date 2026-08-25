#!/usr/bin/env bash
# Mac: immediate Google Drive sync (no Suno) — lyrics + track files to phone.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${1:-AUD-MUS-20260825-004}"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/music-drive-sync-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG")"

echo "[drive-sync-now] $(date -u +%Y-%m-%dT%H:%M:%SZ) track=${TRACK}" | tee -a "$LOG"

# OAuth API if configured
if [[ -f "${ROOT}/pipeline_data/secrets/google_drive_token.json" ]]; then
  if bash "${ROOT}/scripts/music-drive-upload.sh" "$TRACK" --share-link 2>&1 | tee -a "$LOG"; then
    echo "[drive-sync-now] Drive API OK" | tee -a "$LOG"
    exit 0
  fi
fi

# Desktop Google Drive folder (recommended)
bash "${ROOT}/scripts/mac-music-drive-desktop-sync.sh" "$TRACK" 2>&1 | tee -a "$LOG"
