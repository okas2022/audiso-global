#!/usr/bin/env bash
# Connect to CEO's logged-in Chrome (CDP) and fill 3 KOMCA online forms.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/komca-load-env.sh" 2>/dev/null || true

TRACK="${KOMCA_TRACK_ID:-AUD-MUS-20260825-003}"
CDP="${KOMCA_CDP_URL:-http://127.0.0.1:9222}"
NO_CDP=0
FORMS_URL="${KOMCA_FORMS_URL:-}"

usage() {
  cat <<'EOF'
Usage: komca-online-forms-run.sh [--track AUD-MUS-…] [--cdp URL] [--no-cdp] [--url PAGE_URL]

Mac — CEO가 Chrome에 KOMCA 로그인 + 3개 온라인등록 화면까지 연 상태:

  1) Chrome 디버그 모드 (한 번):
     bash scripts/mac-komca-chrome-debug.sh

  2) 같은 화면에서 자동입력:
     bash scripts/komca-online-forms-run.sh

CEO: '다음 단계(핸드폰 인증)' + 본인인증만
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --track) TRACK="$2"; shift 2 ;;
    --cdp) CDP="$2"; shift 2 ;;
    --no-cdp) NO_CDP=1; shift ;;
    --url) FORMS_URL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

bash "${ROOT}/scripts/mac-install-komca-playwright.sh" 2>/dev/null || true

ARGS=(--track "$TRACK")
[[ "$NO_CDP" -eq 0 ]] && ARGS+=(--cdp "$CDP")
[[ "$NO_CDP" -eq 1 ]] && ARGS+=(--no-cdp)
[[ -n "$FORMS_URL" ]] && ARGS+=(--url "$FORMS_URL")

export KOMCA_TRACK_ID="$TRACK"
python3 "${ROOT}/scripts/komca-online-three-forms.py" "${ARGS[@]}"
