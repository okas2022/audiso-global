#!/usr/bin/env bash
# Mac Cursor Agent가 실행 — Cloud Agent가 Mac에 tool call을 보내도록 worker 연결
set -euo pipefail

WORKER_DIR="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
WORKER_NAME="${JARVIS_WORKER_NAME:-macbook-pro-audiso}"
export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v agent >/dev/null 2>&1; then
  echo "[jarvis-worker] Cursor agent CLI 없음 — 설치 시도"
  curl https://cursor.com/install -fsS | bash
  export PATH="${HOME}/.local/bin:${PATH}"
fi

if ! command -v agent >/dev/null 2>&1; then
  echo "[jarvis-worker] Cursor CLI 설치 실패. https://cursor.com/install 확인" >&2
  exit 1
fi

if ! agent status >/dev/null 2>&1; then
  echo "[jarvis-worker] Cursor CLI 미로그인 — agent login 필요 (브라우저 1회)" >&2
  agent login || true
  if ! agent status >/dev/null 2>&1; then
    echo "[jarvis-worker] 로그인 미완료 — worker 시작 보류" >&2
    exit 1
  fi
fi

cd "$WORKER_DIR"
mkdir -p "${WORKER_DIR}/pipeline_data/jarvis_memory/episodes"

if pgrep -f "agent worker start" >/dev/null 2>&1; then
  echo "[jarvis-worker] 이미 실행 중 (name=${WORKER_NAME})"
  agent worker list 2>/dev/null || true
  exit 0
fi

echo "[jarvis-worker] Starting My Machines worker..."
echo "  dir:  ${WORKER_DIR}"
echo "  name: ${WORKER_NAME}"

nohup agent worker start \
  --name "${WORKER_NAME}" \
  --worker-dir "${WORKER_DIR}" \
  >> "${WORKER_DIR}/pipeline_data/jarvis_memory/episodes/worker.log" 2>&1 &

sleep 3
if pgrep -f "agent worker start" >/dev/null 2>&1; then
  echo "[jarvis-worker] Connected — cursor.com/agents 에서 My Machine '${WORKER_NAME}' 선택"
else
  echo "[jarvis-worker] worker 시작 실패 — episodes/worker.log 확인" >&2
  tail -20 "${WORKER_DIR}/pipeline_data/jarvis_memory/episodes/worker.log" 2>/dev/null || true
  exit 1
fi
