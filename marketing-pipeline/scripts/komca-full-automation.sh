#!/usr/bin/env bash
# One-shot: trust doc pack → browser login/register → pause at phone auth only.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK_ID="${KOMCA_TRACK_ID:-AUD-MUS-20260825-003}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --track) TRACK_ID="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

echo "=== KOMCA full automation (CEO: 휴대폰 인증만) ==="

bash "${ROOT}/scripts/komca-trust-doc-pack.sh" --track "$TRACK_ID"
bash "${ROOT}/scripts/komca-portal-run.sh" --mode full --track "$TRACK_ID"

echo "[komca-full] Portal session ended."
echo "[komca-full] After KOMCA 접수 확인: bash scripts/music-komca-mark-submitted.sh ${TRACK_ID} --work-code …"
echo "[komca-full] Trust pack → ${ROOT}/pipeline_data/assets/komca_trust_pack/"
