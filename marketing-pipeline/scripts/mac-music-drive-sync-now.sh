#!/usr/bin/env bash
# Mac: immediate Google Drive sync — Gmail (okas2000@gmail.com) ONLY.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${1:-AUD-MUS-20260825-004}"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/music-drive-sync-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG")"

export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

echo "[drive-sync-now] $(date -u +%Y-%m-%dT%H:%M:%SZ) track=${TRACK} account=${GOOGLE_DRIVE_REQUIRED_ACCOUNT}" | tee -a "$LOG"

# OAuth API if configured (also asserts Gmail)
if [[ -f "${ROOT}/pipeline_data/secrets/google_drive_token.json" ]]; then
  if bash "${ROOT}/scripts/music-drive-upload.sh" "$TRACK" --share-link 2>&1 | tee -a "$LOG"; then
    echo "[drive-sync-now] Drive API OK (${GOOGLE_DRIVE_REQUIRED_ACCOUNT})" | tee -a "$LOG"
    exit 0
  fi
fi

# Desktop Google Drive folder — Gmail only (refuses yonsei)
bash "${ROOT}/scripts/mac-music-drive-desktop-sync.sh" "$TRACK" 2>&1 | tee -a "$LOG"
