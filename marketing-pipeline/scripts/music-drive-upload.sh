#!/usr/bin/env bash
# Upload AUD-MUS track to Google Drive (smartphone via Drive app).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${1:-AUD-MUS-20260825-004}"
SHARE="${MUSIC_DRIVE_SHARE_LINK:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --share-link) SHARE=1; shift ;;
    AUD-MUS-*) TRACK="$1"; shift ;;
    *) shift ;;
  esac
done

[[ -f "${ROOT}/.env" ]] && set -a && source "${ROOT}/.env" && set +a

if ! python3 -c "import googleapiclient" 2>/dev/null; then
  bash "${ROOT}/scripts/mac-install-google-drive.sh"
fi

ARGS=( "$TRACK" )
[[ "$SHARE" == "1" ]] && ARGS+=( --share-link )

python3 "${ROOT}/scripts/music-drive-upload.py" "${ARGS[@]}"
