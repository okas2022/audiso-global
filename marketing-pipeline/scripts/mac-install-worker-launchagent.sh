#!/usr/bin/env bash
# MacBook Pro 부팅 시 My Machines worker 자동 시작 — CEO 수동 실행 불필요
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
PLIST_SRC="${ROOT}/infra/launchagents/com.audiso.jarvis-cursor-worker.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/com.audiso.jarvis-cursor-worker.plist"
LABEL="com.audiso.jarvis-cursor-worker"

mkdir -p "${HOME}/Library/LaunchAgents"
mkdir -p "${ROOT}/pipeline_data/jarvis_memory/episodes"

cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/${LABEL}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}"

echo "[jarvis-launchagent] installed → ${PLIST_DST}"
launchctl print "gui/$(id -u)/${LABEL}" 2>/dev/null | head -20 || true

bash "${ROOT}/scripts/mac-cursor-worker-start.sh"
