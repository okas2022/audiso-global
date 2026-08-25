#!/usr/bin/env bash
# Mac: create Audiso Music in My Drive (내 드라이브) then sync track — Gmail only.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${1:-AUD-MUS-20260825-004}"
export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

bash "${ROOT}/scripts/mac-create-audiso-music-mydrive.sh" "$TRACK"
