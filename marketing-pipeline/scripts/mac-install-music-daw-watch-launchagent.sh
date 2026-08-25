#!/usr/bin/env bash
# LaunchAgent: poll daw/versions/lyrics → human evidence refresh (YouTube Stage 1–2)
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PLIST_SRC="${ROOT}/infra/launchagents/com.audiso.jarvis-music-daw-watch.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-music-daw-watch.plist"
LABEL="com.audiso.jarvis-music-daw-watch"

mkdir -p "${HOME}/Library/LaunchAgents" "${ROOT}/pipeline_data/jarvis_memory/episodes"

cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/${LABEL}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "[music-daw-launchagent] installed → ${PLIST_DST}"
bash "${ROOT}/scripts/music-daw-watch.sh"
