#!/usr/bin/env bash
# 맥북 프로 24h — Cloud/폰이 push한 mac_tasks pull 후 실행
# CRITICAL: Git lives in audiso-global; JARVIS_ROOT may be a separate tree — sync before run.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
BRANCH="${AUDISO_SYNC_BRANCH:-main}"
LOG="${ROOT}/pipeline_data/jarvis_memory/episodes/relay-loop-$(date +%Y%m%d).log"

mkdir -p "$(dirname "$LOG")" "${ROOT}/scripts" "${ROOT}/pipeline_data/jarvis_memory/mac_tasks"
exec >> "$LOG" 2>&1

echo "[relay-loop] $(date -u +%Y-%m-%dT%H:%M:%SZ) start"
export GOOGLE_DRIVE_REQUIRED_ACCOUNT="${GOOGLE_DRIVE_REQUIRED_ACCOUNT:-okas2000@gmail.com}"
export GOOGLE_DRIVE_BLOCKED_DOMAINS="${GOOGLE_DRIVE_BLOCKED_DOMAINS:-yonsei.ac.kr}"

GLOBAL_MP="${GLOBAL}/marketing-pipeline"

if [[ -d "${GLOBAL}/.git" ]]; then
  cd "$GLOBAL"
  git fetch origin "$BRANCH" 2>/dev/null || true
  git pull --ff-only origin "$BRANCH" 2>/dev/null || echo "[relay-loop] git pull skipped (local changes?)"
fi

# Sync scripts + mac_tasks from git tree → JARVIS_ROOT (fixes silent miss)
if [[ -d "${GLOBAL_MP}/scripts" ]]; then
  if [[ "$(cd "$ROOT" && pwd -P)" != "$(cd "$GLOBAL_MP" && pwd -P)" ]]; then
    echo "[relay-loop] syncing GLOBAL_MP → ROOT"
    cp -f "${GLOBAL_MP}/scripts/"mac-*.sh "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/lib-google-drive-account.sh" "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/"music-drive-* "${ROOT}/scripts/" 2>/dev/null || true
    cp -f "${GLOBAL_MP}/scripts/jarvis-run-mac-tasks.sh" "${ROOT}/scripts/" 2>/dev/null || true
    mkdir -p "${ROOT}/pipeline_data/jarvis_memory/mac_tasks"
    cp -f "${GLOBAL_MP}/pipeline_data/jarvis_memory/mac_tasks/"pending-*.json \
      "${ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
    if [[ -d "${GLOBAL_MP}/pipeline_data/assets/music/AUD-MUS-20260825-004" ]]; then
      mkdir -p "${ROOT}/pipeline_data/assets/music/AUD-MUS-20260825-004"
      rsync -a "${GLOBAL_MP}/pipeline_data/assets/music/AUD-MUS-20260825-004/" \
        "${ROOT}/pipeline_data/assets/music/AUD-MUS-20260825-004/" 2>/dev/null || true
    fi
  else
    echo "[relay-loop] ROOT == GLOBAL_MP (same tree)"
  fi
fi

chmod +x "${ROOT}/scripts/"mac-*.sh "${ROOT}/scripts/lib-google-drive-account.sh" \
  "${ROOT}/scripts/music-drive-upload.sh" 2>/dev/null || true

cd "$ROOT"

bash "${ROOT}/scripts/mac-cursor-worker-start.sh" 2>/dev/null || true

export JARVIS_MAC_TASKS_RUNNING=0
bash "${ROOT}/scripts/jarvis-run-mac-tasks.sh" || true

echo "[relay-loop] done"
