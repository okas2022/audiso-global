#!/usr/bin/env bash
# Cloud unified entry — marketing-pipeline 작업 라우터
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"

cmd="${1:-status}"

case "$cmd" in
  status)
    bash "${ROOT}/scripts/jarvis-status.sh"
    echo "unified: JARVIS_UNIFIED=${JARVIS_UNIFIED:-0}"
    echo "global:  ${GLOBAL}"
    ls -la "${ROOT}/pipeline_data/" 2>/dev/null || true
    ;;
  build-site)
    cd "${GLOBAL}" && npm run build
    ;;
  mac-queue)
    ls -la "${ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
    ;;
  *)
    echo "Usage: jarvis-cloud-entry.sh {status|build-site|mac-queue}"
    exit 1
    ;;
esac
