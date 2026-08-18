#!/usr/bin/env bash
# 맥북 프로 24h — Cloud/폰이 push한 mac_tasks pull 후 실행
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
BRANCH="${AUDISO_SYNC_BRANCH:-main}"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/relay-loop-$(date +%Y%m%d).log"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

echo "[relay-loop] $(date -u +%Y-%m-%dT%H:%M:%SZ) start"

if [[ -d "${GLOBAL}/.git" ]]; then
  cd "$GLOBAL"
  git fetch origin "$BRANCH" 2>/dev/null || true
  git pull --ff-only origin "$BRANCH" 2>/dev/null || echo "[relay-loop] git pull skipped (local changes?)"
fi

cd "$ROOT"

# My Machines worker 유지
bash "${ROOT}/scripts/mac-cursor-worker-start.sh" 2>/dev/null || true

# Cloud가 push한 pending mac_tasks + relay 실행
export JARVIS_MAC_TASKS_RUNNING=0
bash "${ROOT}/scripts/jarvis-run-mac-tasks.sh" || true

echo "[relay-loop] done"
