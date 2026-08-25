#!/usr/bin/env bash
# One-click / LaunchAgent entry: pull main, then Suno generate NOW on Mac Chrome.
# Absolute paths only — does not depend on stale JARVIS_ROOT copies.
set -euo pipefail

export HOME="${HOME:-/Users/Mac}"
export JARVIS_ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
export AUDISO_GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
export AUDISO_SYNC_BRANCH="${AUDISO_SYNC_BRANCH:-main}"
export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export SUNO_USE_DEFAULT_CHROME_PROFILE="${SUNO_USE_DEFAULT_CHROME_PROFILE:-1}"
export SUNO_USER="${SUNO_USER:-okas2000@gmail.com}"
export SUNO_TRACK_ID="${SUNO_TRACK_ID:-AUD-MUS-20260825-004}"
export PATH="/Users/Mac/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG="${JARVIS_ROOT}/pipeline_data/jarvis_memory/episodes/suno-force-now-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

echo "[suno-force-now] $(date -u +%Y-%m-%dT%H:%M:%SZ) start"

if [[ ! -d "${AUDISO_GLOBAL}/.git" ]]; then
  echo "[suno-force-now] missing ${AUDISO_GLOBAL}" >&2
  exit 1
fi

cd "$AUDISO_GLOBAL"
git fetch origin main 2>&1 || true
git pull --ff-only origin main 2>&1 || echo "[suno-force-now] pull skipped"

GLOBAL_MP="${AUDISO_GLOBAL}/marketing-pipeline"
mkdir -p "${GLOBAL_MP}/scripts" "${JARVIS_ROOT}/scripts" \
  "${JARVIS_ROOT}/pipeline_data/jarvis_memory/mac_tasks" \
  "${HOME}/Desktop" 2>/dev/null || true

# Always (re)write .command into the path CEO checks — even if git pull lagged
CMD_BODY='#!/bin/bash
cd /Users/Mac/Audiso/audiso-global || exit 1
git fetch origin main
git pull --ff-only origin main || true
exec bash /Users/Mac/Audiso/audiso-global/marketing-pipeline/scripts/mac-suno-force-now.sh
'
for dest in \
  "${GLOBAL_MP}/scripts/AUDISO-SUNO-NOW.command" \
  "${JARVIS_ROOT}/scripts/AUDISO-SUNO-NOW.command" \
  "${HOME}/Desktop/AUDISO-SUNO-NOW.command"
do
  printf '%s\n' "$CMD_BODY" >"$dest" 2>/dev/null || true
  chmod +x "$dest" 2>/dev/null || true
done
echo "[suno-force-now] wrote AUDISO-SUNO-NOW.command → GLOBAL/ROOT/Desktop"

# If local force script missing, seed from GitHub raw
if [[ ! -f "${GLOBAL_MP}/scripts/mac-suno-force-now.sh" ]]; then
  curl -fsSL \
    "https://raw.githubusercontent.com/okas2022/audiso-global/main/marketing-pipeline/scripts/mac-suno-force-now.sh" \
    -o "${GLOBAL_MP}/scripts/mac-suno-force-now.sh" || true
  chmod +x "${GLOBAL_MP}/scripts/mac-suno-force-now.sh" || true
fi

# Sync critical scripts into JARVIS_ROOT if separate tree
if [[ -d "${GLOBAL_MP}/scripts" ]]; then
  cp -f "${GLOBAL_MP}/scripts/"mac-suno*.sh "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/scripts/"suno-* "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/scripts/AUDISO-SUNO-NOW.command" "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/scripts/mac-bootstrap-from-git.sh" "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/scripts/mac-create-audiso-music-mydrive.sh" "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/scripts/lib-google-drive-account.sh" "${JARVIS_ROOT}/scripts/" 2>/dev/null || true
  cp -f "${GLOBAL_MP}/pipeline_data/jarvis_memory/mac_tasks/"pending-suno*.json \
    "${JARVIS_ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
fi

# Install/refresh LaunchAgent to THIS script (absolute GLOBAL path)
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-suno-force.plist"
mkdir -p "${HOME}/Library/LaunchAgents"
cat >"$PLIST_DST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.audiso.jarvis-suno-force</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${GLOBAL_MP}/scripts/mac-suno-force-now.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>180</integer>
  <key>StandardOutPath</key>
  <string>${JARVIS_ROOT}/pipeline_data/jarvis_memory/episodes/suno-force-launchagent.log</string>
  <key>StandardErrorPath</key>
  <string>${JARVIS_ROOT}/pipeline_data/jarvis_memory/episodes/suno-force-launchagent.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>JARVIS_ROOT</key>
    <string>${JARVIS_ROOT}</string>
    <key>AUDISO_GLOBAL</key>
    <string>${AUDISO_GLOBAL}</string>
    <key>HOME</key>
    <string>${HOME}</string>
    <key>PATH</key>
    <string>/Users/Mac/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
PLIST

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/com.audiso.jarvis-suno-force" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "$PLIST_DST" 2>/dev/null || true
launchctl enable "gui/${UID_NUM}/com.audiso.jarvis-suno-force" 2>/dev/null || true

# Also refresh main relay LaunchAgent to GLOBAL bootstrap
RELAY_SRC="${GLOBAL_MP}/infra/launchagents/com.audiso.jarvis-relay-loop.plist"
RELAY_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-relay-loop.plist"
if [[ -f "$RELAY_SRC" ]]; then
  cp "$RELAY_SRC" "$RELAY_DST"
  launchctl bootout "gui/${UID_NUM}/com.audiso.jarvis-relay-loop" 2>/dev/null || true
  launchctl bootstrap "gui/${UID_NUM}" "$RELAY_DST" 2>/dev/null || true
fi

echo "[suno-force-now] running Suno bootstrap+generate"
bash "${GLOBAL_MP}/scripts/mac-suno-bootstrap-and-run.sh"
echo "[suno-force-now] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
