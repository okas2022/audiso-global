#!/usr/bin/env bash
# Assign internal ISRC placeholder; replace with distributor ISRC when released.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

TRACK_ID=""
DISTRIBUTOR=""
REAL_ISRC=""

usage() {
  echo "Usage: music-isrc-assign.sh AUD-MUS-… [--distributor NAME] [--isrc CODE]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distributor) DISTRIBUTOR="${2:-}"; shift 2 ;;
    --isrc) REAL_ISRC="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }

TRACK_DIR=$(music_track_dir "$TRACK_ID")
BRIEF="${TRACK_DIR}/music_brief.json"
NOW=$(music_now_utc)

python3 - <<PY
import json, pathlib, re
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
tid = brief.get("track_id", "")
# Internal until DistroKid/TuneCore assigns GS1 ISRC
internal = "${REAL_ISRC}".strip() or f"AUDISO-{tid.replace('AUD-MUS-', '')}"
reg = brief.setdefault("registration", {})
isrc = reg.setdefault("isrc", {})
isrc.update({
    "status": "assigned" if "${REAL_ISRC}".strip() else "internal_pending",
    "code": internal,
    "assignee": "Audiso",
    "distributor": "${DISTRIBUTOR}" or None,
    "assigned_at": "${NOW}",
    "note": "Replace with official ISRC from distributor before Spotify/YouTube Content ID"
})
brief.setdefault("rights", {})["isrc"] = internal
brief["updated_at"] = "${NOW}"
pathlib.Path("${TRACK_DIR}/registration/isrc.json").write_text(json.dumps(isrc, ensure_ascii=False, indent=2) + "\n")
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
print(internal)
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark isrc_assigned
bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"
echo "[isrc] assigned for ${TRACK_ID}"
