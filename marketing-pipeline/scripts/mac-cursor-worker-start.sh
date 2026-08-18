#!/usr/bin/env bash
# Mac Cursor Agent가 실행 — Cloud Agent가 Mac에 tool call을 보내도록 worker 연결
set -euo pipefail

WORKER_DIR="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
WORKER_NAME="${JARVIS_WORKER_NAME:-macbook-pro-audiso}"

if ! command -v agent >/dev/null 2>&1; then
  echo "[jarvis-worker] Cursor CLI 없음 — 설치:"
  echo "  curl https://cursor.com/install -fsS | bash"
  exit 1
fi

if ! agent status >/dev/null 2>&1; then
  echo "[jarvis-worker] Cursor CLI 미로그인 — Mac Cursor에서: agent login"
  exit 1
fi

cd "$WORKER_DIR"

# 이미 실행 중이면 스킵
if pgrep -f "agent worker start" >/dev/null 2>&1; then
  echo "[jarvis-worker] 이미 실행 중 (name=${WORKER_NAME})"
  agent worker start --debug 2>&1 | head -20 || true
  exit 0
fi

echo "[jarvis-worker] Starting My Machines worker..."
echo "  dir:  ${WORKER_DIR}"
echo "  name: ${WORKER_NAME}"

# 백그라운드 long-lived worker (Cloud/mobile Pro가 tool call을 Mac에서 실행)
nohup agent worker start \
  --name "${WORKER_NAME}" \
  --worker-dir "${WORKER_DIR}" \
  >> "${WORKER_DIR}/pipeline_data/jarvis_memory/episodes/worker.log" 2>&1 &

sleep 3
if pgrep -f "agent worker start" >/dev/null 2>&1; then
  echo "[jarvis-worker] ✅ Connected — cursor.com/agents 에서 My Machine '${WORKER_NAME}' 선택"
else
  echo "[jarvis-worker] ❌ worker 시작 실패 — episodes/worker.log 확인"
  tail -20 "${WORKER_DIR}/pipeline_data/jarvis_memory/episodes/worker.log" 2>/dev/null || true
  exit 1
fi
