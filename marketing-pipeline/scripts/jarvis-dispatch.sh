#!/usr/bin/env bash
# Jarvis agent router — Cloud relays prompts; MacBook Pro executes locally
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
GLOBAL="${AUDISO_GLOBAL:-/Users/Mac/Audiso/audiso-global}"
REGISTRY="${ROOT}/pipeline_data/jarvis_memory/agents_registry.json"

intent="${*:-status}"
intent_lower=$(echo "$intent" | tr '[:upper:]' '[:lower:]')

route() {
  local agent="$1"
  shift
  echo "[jarvis-dispatch] → agent: ${agent}"
  case "$agent" in
    jarvis|status)
      bash "${ROOT}/scripts/jarvis-status.sh"
      python3 -c "import json; r=json.load(open('${REGISTRY}')); print('agents:', len(r.get('agents',[])), '| policy:', r.get('policy'))"
      ;;
    steve|marketing)
      echo "[jarvis-dispatch] Steve (marketing) — assets: ${ROOT}/pipeline_data/assets/"
      ls -la "${ROOT}/pipeline_data/assets/" 2>/dev/null || mkdir -p "${ROOT}/pipeline_data/assets/"
      echo "Ready: IG cards, quiz, promo copy, Higgsfield image/video"
      ;;
    site|audiso-global|build)
      cd "${GLOBAL}" && npm run build
      ;;
    bd|whitepaper|global-bd)
      echo "[jarvis-dispatch] Global BD — ${ROOT}/pipeline_data/global_bd/"
      ls -la "${ROOT}/pipeline_data/global_bd/" 2>/dev/null || true
      ;;
    mac|sync)
      echo "[jarvis-dispatch] Queue Mac delegate tasks"
      ls -la "${ROOT}/pipeline_data/jarvis_memory/mac_tasks/" 2>/dev/null || true
      ;;
    *)
      echo "[jarvis-dispatch] Unknown route '${agent}' — Jarvis handles via full registry"
      cat "${REGISTRY}" | python3 -c "import json,sys; [print('-',a['id'],':',a['name']) for a in json.load(sys.stdin).get('agents',[])]"
      ;;
  esac
}

# Keyword routing
case "$intent_lower" in
  *steve*|*마케팅*|*ig*|*카드*|*promo*) route steve ;;
  *사이트*|*빌드*|*deploy*|*audimall*|*vercel*) route site ;;
  *whitepaper*|*화이트*|*ir*|*bd*|*deck*) route bd ;;
  *sync*|*mac*|*ssd*|*storage*) route mac ;;
  *네이버*|*naver*|*식스샵*|*sixshop*|*몰*) 
    echo "[jarvis-dispatch] → Mac worker (local execution on MacBook Pro)"
    route mac ;;
  *status*|*jarvis*|*에이전트*) route jarvis ;;
  *)
    route jarvis
    echo "[jarvis-dispatch] intent: ${intent}"
    ;;
esac
