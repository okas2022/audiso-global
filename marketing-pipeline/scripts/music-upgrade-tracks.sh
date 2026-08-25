#!/usr/bin/env bash
# Upgrade existing AUD-MUS folders to v2 checklist + YouTube 3-stage folders.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

SINGLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    AUD-MUS-*) SINGLE="$1"; shift ;;
    -h|--help)
      echo "Usage: music-upgrade-tracks.sh [AUD-MUS-…]"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -n "$SINGLE" ]]; then
  DIRS=("$SINGLE")
else
  mapfile -t DIRS < <(find "$MUSIC_ROOT" -maxdepth 1 -type d -name 'AUD-MUS-*' -exec basename {} \; | sort)
fi

for tid in "${DIRS[@]}"; do
  TRACK_DIR=$(music_track_dir "$tid")
  [[ -d "$TRACK_DIR" ]] || continue

  mkdir -p \
    "${TRACK_DIR}/daw" "${TRACK_DIR}/versions" "${TRACK_DIR}/lyrics" \
    "${TRACK_DIR}/evidence" "${TRACK_DIR}/registration"

  if [[ -f "${TRACK_DIR}/checklist.json" ]]; then
    python3 "${ROOT}/scripts/music-checklist-init.py" "$tid" "${TRACK_DIR}/checklist.json" >/dev/null
  fi

  if [[ ! -f "${TRACK_DIR}/lyrics/ai.txt" && -f "${TRACK_DIR}/prompts/lyrics_prompt.txt" ]]; then
    grep -v '^#' "${TRACK_DIR}/prompts/lyrics_prompt.txt" | sed '/^$/d' > "${TRACK_DIR}/lyrics/ai.txt" || true
  fi
  if [[ ! -f "${TRACK_DIR}/lyrics/final.txt" && -f "${TRACK_DIR}/lyrics/ai.txt" ]]; then
    cp "${TRACK_DIR}/lyrics/ai.txt" "${TRACK_DIR}/lyrics/final.txt"
  fi

  bash "${ROOT}/scripts/music-suno-checklist.sh" "$tid" >/dev/null 2>&1 || true
  echo "[upgrade] ${tid}"
done

bash "${ROOT}/scripts/music-catalog-update.sh"
echo "[upgrade] done (${#DIRS[@]} track(s))"
