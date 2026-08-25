#!/usr/bin/env bash
# Mac: Suno generate+download for a track, then Demucs stems (editable).
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
TRACK="${1:-AUD-MUS-20260825-004}"
shift || true

# Load secrets (never jarvis_memory)
[[ -f "${ROOT}/.env" ]] && set -a && source "${ROOT}/.env" && set +a
[[ -f "${ROOT}/pipeline_data/secrets/suno.env" ]] && set -a && source "${ROOT}/pipeline_data/secrets/suno.env" && set +a

bash "${ROOT}/scripts/mac-install-komca-playwright.sh" 2>/dev/null || true
bash "${ROOT}/scripts/music-await-suno.sh" "$TRACK" 2>/dev/null || true

ARGS=(--track "$TRACK")
[[ -n "${SUNO_CDP_URL:-}" ]] && ARGS+=(--cdp "$SUNO_CDP_URL")

echo "[suno-run] Generating ${TRACK} — CEO may need to confirm login/OAuth once"
python3 "${ROOT}/scripts/suno-generate-download.py" "${ARGS[@]}" "$@"

echo "[suno-run] If stems skipped, run: bash scripts/music-stem-separate.sh ${TRACK}"
echo "[suno-run] DAW folders: ${ROOT}/pipeline_data/assets/music/${TRACK}/{suno,stems,masters}/"
