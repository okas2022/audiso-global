#!/usr/bin/env bash
# MacBook Pro — worker + 24h relay loop LaunchAgents 설치
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"

install_plist() {
  local label="$1" src="$2"
  local dst="${HOME}/Library/LaunchAgents/${label}.plist"
  cp "$src" "$dst"
  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$dst"
  launchctl enable "gui/$(id -u)/${label}"
  launchctl kickstart -k "gui/$(id -u)/${label}" 2>/dev/null || true
  echo "[jarvis-launchagent] ${label} → ${dst}"
}

mkdir -p "${HOME}/Library/LaunchAgents" "${ROOT}/pipeline_data/jarvis_memory/episodes"

install_plist "com.audiso.jarvis-cursor-worker" \
  "${ROOT}/infra/launchagents/com.audiso.jarvis-cursor-worker.plist"

install_plist "com.audiso.jarvis-relay-loop" \
  "${ROOT}/infra/launchagents/com.audiso.jarvis-relay-loop.plist"

bash "${ROOT}/scripts/mac-jarvis-relay-loop.sh"
