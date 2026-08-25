#!/usr/bin/env bash
# Mac one-time: Google Drive OAuth for okas2000@gmail.com ONLY (never yonsei.ac.kr).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
SECRETS="${ROOT}/pipeline_data/secrets"
CREDS="${SECRETS}/google_drive_credentials.json"
TOKEN="${SECRETS}/google_drive_token.json"
REQUIRED="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"

mkdir -p "$SECRETS"
export GOOGLE_DRIVE_REQUIRED_ACCOUNT="$REQUIRED"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

if [[ ! -f "$CREDS" ]]; then
  cat <<EOF
[google-drive-setup] OAuth client JSON 필요 (1회)

1. https://console.cloud.google.com/ → 프로젝트 생성 (${REQUIRED})
2. APIs & Services → Enable "Google Drive API"
3. Credentials → Create OAuth client ID → Desktop app
4. JSON 다운로드 → 저장:
   pipeline_data/secrets/google_drive_credentials.json

다시 실행: bash scripts/mac-google-drive-setup.sh
EOF
  exit 1
fi

# Wipe prior token if it might be school account
if [[ -f "$TOKEN" ]]; then
  echo "[google-drive-setup] removing old token (force re-auth as ${REQUIRED})"
  rm -f "$TOKEN"
fi

bash "${ROOT}/scripts/mac-install-google-drive.sh"
echo "[google-drive-setup] Browser opens — MUST choose ${REQUIRED} (NOT yonsei.ac.kr)"
python3 "${ROOT}/scripts/music-drive-upload.py" AUD-MUS-20260825-004 || true
echo "[google-drive-setup] token saved → pipeline_data/secrets/google_drive_token.json"
echo "[google-drive-setup] If upload refused wrong account: delete token and re-run"
