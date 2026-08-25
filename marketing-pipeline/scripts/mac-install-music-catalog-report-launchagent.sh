#!/usr/bin/env bash
# LaunchAgent: weekly music catalog / registration status report
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PLIST_SRC="${ROOT}/infra/launchagents/com.audiso.jarvis-music-catalog-report.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-music-catalog-report.plist"
LABEL="com.audiso.jarvis-music-catalog-report"

mkdir -p "${HOME}/Library/LaunchAgents" "${ROOT}/pipeline_data/jarvis_memory/episodes"

cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/${LABEL}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "[music-catalog-launchagent] installed → ${PLIST_DST}"
bash "${ROOT}/scripts/music-catalog-report.sh"
