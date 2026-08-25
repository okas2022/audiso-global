#!/usr/bin/env bash
# 맥북 프로 — pull git then bootstrap (Finder Audiso Music + mac_tasks).
# After pull, ALWAYS prefer GLOBAL scripts so ROOT staleness cannot block Drive folder create.
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
  git pull --ff-only origin "$BRANCH" 2>/dev/null || echo "[relay-loop] git pull skipped"
fi

BOOT="${GLOBAL}/marketing-pipeline/scripts/mac-bootstrap-from-git.sh"
if [[ -f "$BOOT" ]]; then
  echo "[relay-loop] exec GLOBAL bootstrap (Finder Audiso Music)"
  bash "$BOOT" || true
  echo "[relay-loop] done"
  exit 0
fi

# Fallback if bootstrap not yet on disk
cd "$ROOT"
bash "${ROOT}/scripts/mac-cursor-worker-start.sh" 2>/dev/null || true
export JARVIS_MAC_TASKS_RUNNING=0
bash "${ROOT}/scripts/jarvis-run-mac-tasks.sh" || true
echo "[relay-loop] done"
