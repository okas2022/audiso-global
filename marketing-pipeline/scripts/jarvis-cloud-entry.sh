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
  dispatch)
    shift
    bash "${ROOT}/scripts/jarvis-dispatch.sh" "$@"
    ;;
  agents)
    python3 -c "import json; r=json.load(open('${ROOT}/pipeline_data/jarvis_memory/agents_registry.json')); [print(f\"{a['id']:20} cloud={a['cloud']:8} {a['name']}\") for a in r['agents']]"
    ;;
  mac-queue)
    ls -la "${ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
    ;;
  *)
    echo "Usage: jarvis-cloud-entry.sh {status|build-site|dispatch|agents|mac-queue}"
    exit 1
    ;;
esac
