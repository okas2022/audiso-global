#!/usr/bin/env bash
# Mac one-time: Google Drive OAuth for okas2000@gmail.com (opens browser).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
SECRETS="${ROOT}/pipeline_data/secrets"
CREDS="${SECRETS}/google_drive_credentials.json"

mkdir -p "$SECRETS"

if [[ ! -f "$CREDS" ]]; then
  cat <<'EOF'
[google-drive-setup] OAuth client JSON 필요 (1회)

1. https://console.cloud.google.com/ → 프로젝트 생성
2. APIs & Services → Enable "Google Drive API"
3. Credentials → Create OAuth client ID → Desktop app
4. JSON 다운로드 → 저장:
   pipeline_data/secrets/google_drive_credentials.json

다시 실행: bash scripts/mac-google-drive-setup.sh
EOF
  exit 1
fi

bash "${ROOT}/scripts/mac-install-google-drive.sh"
echo "[google-drive-setup] Browser opens — okas2000@gmail.com 으로 허용"
python3 "${ROOT}/scripts/music-drive-upload.py" AUD-MUS-20260825-004 || true
echo "[google-drive-setup] token saved → pipeline_data/secrets/google_drive_token.json"
