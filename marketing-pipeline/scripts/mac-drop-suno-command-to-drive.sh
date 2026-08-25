#!/usr/bin/env bash
# Drop AUDISO-SUNO-NOW.command + README into Gmail Drive → Audiso Music
# so Mac Drive desktop sync (or phone) delivers without CEO terminal paste.
# Account hard rule: okas2000@gmail.com ONLY (never yonsei.ac.kr).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
GLOBAL_MP="${GLOBAL}/marketing-pipeline"
LIB="${ROOT}/scripts/lib-google-drive-account.sh"
[[ -f "$LIB" ]] || LIB="${GLOBAL_MP}/scripts/lib-google-drive-account.sh"
# shellcheck source=lib-google-drive-account.sh
source "$LIB"

FOLDER_NAME="${GOOGLE_DRIVE_MUSIC_ROOT:-Audiso Music}"
REQUIRED="${GOOGLE_DRIVE_REQUIRED_ACCOUNT}"
EP="${ROOT}/pipeline_data/jarvis_memory/episodes"
mkdir -p "$EP"
LOG="${EP}/drop-suno-command-drive-$(date +%Y%m%dT%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "[drive-drop] $(date -u +%Y-%m-%dT%H:%M:%SZ) account=${REQUIRED}"

CMD_SRC="${GLOBAL_MP}/scripts/AUDISO-SUNO-NOW.command"
[[ -f "$CMD_SRC" ]] || CMD_SRC="${ROOT}/scripts/AUDISO-SUNO-NOW.command"
FORCE_SRC="${GLOBAL_MP}/scripts/mac-suno-force-now.sh"
[[ -f "$FORCE_SRC" ]] || FORCE_SRC="${ROOT}/scripts/mac-suno-force-now.sh"

drive_root="$(find_gmail_drive_root || true)"
if [[ -z "${drive_root}" ]]; then
  print_drive_account_help
  echo "[drive-drop] BLOCKED: no Gmail Drive mount"
  exit 2
fi

audiso_root="${drive_root}/${FOLDER_NAME}"
mkdir -p "$audiso_root"

if [[ -f "$CMD_SRC" ]]; then
  cp -f "$CMD_SRC" "${audiso_root}/AUDISO-SUNO-NOW.command"
  chmod +x "${audiso_root}/AUDISO-SUNO-NOW.command" 2>/dev/null || true
  echo "[drive-drop] wrote ${audiso_root}/AUDISO-SUNO-NOW.command"
else
  echo "[drive-drop] WARN: missing AUDISO-SUNO-NOW.command source" >&2
fi

# Also stage force script (LaunchAgent / advanced); Mac may exec without git pull
if [[ -f "$FORCE_SRC" ]]; then
  cp -f "$FORCE_SRC" "${audiso_root}/mac-suno-force-now.sh"
  chmod +x "${audiso_root}/mac-suno-force-now.sh" 2>/dev/null || true
fi

cat > "${audiso_root}/README_RUN_ME.txt" <<EOF
Audiso Music — Suno generate inbox
account: ${REQUIRED}
track: AUD-MUS-20260825-004 (너의 행복이 나라면)
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Prefer automatic:
  Mac LaunchAgent (com.audiso.jarvis-relay-loop / jarvis-suno-force)
  pulls GitHub main and runs mac-suno-force-now.sh — no terminal needed.

Only if still idle after a few minutes:
  Double-click AUDISO-SUNO-NOW.command in this folder (Finder).
  That pulls main and generates on Chrome (ss2013 = okas2000@gmail.com).

Do NOT use yonsei.ac.kr Drive. Phone: Drive app → 내 드라이브 → Audiso Music.
EOF

echo "[drive-drop] wrote ${audiso_root}/README_RUN_ME.txt"
echo "[drive-drop] DONE → ${audiso_root}"
