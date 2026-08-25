#!/usr/bin/env bash
# LaunchAgent: poll ~/Downloads for Suno exports → AUD-MUS import
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PLIST_SRC="${ROOT}/infra/launchagents/com.audiso.jarvis-music-suno-watch.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-music-suno-watch.plist"
LABEL="com.audiso.jarvis-music-suno-watch"

mkdir -p "${HOME}/Library/LaunchAgents" "${ROOT}/pipeline_data/jarvis_memory/episodes"

cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/${LABEL}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "[music-launchagent] installed → ${PLIST_DST}"
bash "${ROOT}/scripts/music-suno-inbox-watch.sh"
