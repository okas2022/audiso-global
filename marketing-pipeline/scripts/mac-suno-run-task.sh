#!/usr/bin/env bash
# Mac task: Suno create+download+Demucs stems for AUD-MUS (CEO already logged in).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${KOMCA_TRACK_ID:-${SUNO_TRACK_ID:-AUD-MUS-20260825-004}}"
PORT="${SUNO_CDP_PORT:-9223}"

# Email hint only (password not required if Chrome session exists)
mkdir -p "${ROOT}/pipeline_data/secrets"
if [[ ! -f "${ROOT}/pipeline_data/secrets/suno.env" ]]; then
  cat > "${ROOT}/pipeline_data/secrets/suno.env" <<'EOF'
SUNO_USER=okas2000@gmail.com
SUNO_TRACK_ID=AUD-MUS-20260825-004
SUNO_CDP_URL=http://127.0.0.1:9223
EOF
  chmod 600 "${ROOT}/pipeline_data/secrets/suno.env"
fi

set -a
# shellcheck disable=SC1091
source "${ROOT}/pipeline_data/secrets/suno.env" 2>/dev/null || true
[[ -f "${ROOT}/.env" ]] && source "${ROOT}/.env" || true
set +a

TRACK="${SUNO_TRACK_ID:-$TRACK}"
export SUNO_CDP_URL="${SUNO_CDP_URL:-http://127.0.0.1:${PORT}}"
export SUNO_USER="${SUNO_USER:-okas2000@gmail.com}"

bash "${ROOT}/scripts/mac-install-komca-playwright.sh" 2>/dev/null || true
bash "${ROOT}/scripts/mac-suno-chrome-debug.sh" "https://suno.com/create"

# Give CEO a moment if first login needed
if ! curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "[suno-task] waiting for Chrome CDP…"
  sleep 8
fi

echo "[suno-task] Attaching to logged-in Chrome as ${SUNO_USER} → ${TRACK}"
bash "${ROOT}/scripts/suno-auto-run.sh" "$TRACK" --cdp "$SUNO_CDP_URL"

echo "[suno-task] Uploading to Google Drive for smartphone…"
if bash "${ROOT}/scripts/music-drive-upload.sh" "$TRACK" --share-link 2>/dev/null; then
  echo "[suno-task] Drive API upload OK — check Google Drive app: Audiso Music"
elif bash "${ROOT}/scripts/mac-music-drive-desktop-sync.sh" "$TRACK" 2>/dev/null; then
  echo "[suno-task] Drive desktop sync OK — check Google Drive app: Audiso Music"
else
  echo "[suno-task] Drive skipped — install Google Drive desktop OR: bash scripts/mac-google-drive-setup.sh" >&2
fi
