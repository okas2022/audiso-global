#!/usr/bin/env bash
# Orchestrate AUD-MUS pipeline Phase A → B → C for one track.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
PHASE="all"
IMPORTANT=0
FORCE=0
DISTRIBUTOR=""
REAL_ISRC=""

usage() {
  cat <<'EOF'
Usage: music-pipeline-run.sh AUD-MUS-… [--phase A|B|C|all] [--important] [--force]
       [--distributor NAME] [--isrc CODE]

Phase A: checklist refresh (Suno → stem → master)
Phase B: human evidence → KOMCA pack → (important) Copyright Commission pack
Phase C: ISRC assign + catalog report
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="${2:-all}"; shift 2 ;;
    --important) IMPORTANT=1; shift ;;
    --force) FORCE=1; shift ;;
    --distributor) DISTRIBUTOR="${2:-}"; shift 2 ;;
    --isrc) REAL_ISRC="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }
TRACK_DIR=$(music_track_dir "$TRACK_ID")
[[ -d "$TRACK_DIR" ]] || { echo "missing track: $TRACK_DIR" >&2; exit 1; }

run_phase_a() {
  echo "=== Phase A: Suno → stem → master ==="
  bash "${ROOT}/scripts/music-upgrade-tracks.sh" "$TRACK_ID"
  bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --show
}

run_phase_b() {
  echo "=== Phase B: Human evidence → KOMCA → Copyright Commission ==="
  bash "${ROOT}/scripts/music-human-evidence.sh" "$TRACK_ID"

  KOMCA_ARGS=()
  [[ "$FORCE" -eq 1 ]] && KOMCA_ARGS+=(--force)
  bash "${ROOT}/scripts/music-komca-pack.sh" "$TRACK_ID" "${KOMCA_ARGS[@]}" || {
    echo "[pipeline] KOMCA pack blocked — add daw/ or edit lyrics/final.txt + masters/" >&2
    return 1
  }

  if [[ "$IMPORTANT" -eq 1 ]]; then
    CC_ARGS=()
    [[ "$FORCE" -eq 1 ]] && CC_ARGS+=(--force)
    bash "${ROOT}/scripts/music-copyright-commission-pack.sh" "$TRACK_ID" "${CC_ARGS[@]}"
  else
    PRIORITY=$(python3 - <<PY
import json, pathlib
b = json.loads(pathlib.Path("${TRACK_DIR}/music_brief.json").read_text())
print(b.get("registration", {}).get("priority", "standard"))
PY
)
    if [[ "$PRIORITY" == "important" ]]; then
      bash "${ROOT}/scripts/music-copyright-commission-pack.sh" "$TRACK_ID"
    fi
  fi
}

run_phase_c() {
  echo "=== Phase C: ISRC + catalog report ==="
  ISRC_ARGS=()
  [[ -n "$DISTRIBUTOR" ]] && ISRC_ARGS+=(--distributor "$DISTRIBUTOR")
  [[ -n "$REAL_ISRC" ]] && ISRC_ARGS+=(--isrc "$REAL_ISRC")
  bash "${ROOT}/scripts/music-isrc-assign.sh" "$TRACK_ID" "${ISRC_ARGS[@]}"
  bash "${ROOT}/scripts/music-catalog-report.sh"
}

case "$PHASE" in
  A|a) run_phase_a ;;
  B|b) run_phase_b ;;
  C|c) run_phase_c ;;
  all|ALL)
    run_phase_a
    run_phase_b || true
    run_phase_c
    ;;
  *) echo "unknown phase: $PHASE" >&2; exit 1 ;;
esac

echo "[pipeline] ${TRACK_ID} phase ${PHASE} complete"
bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID"
