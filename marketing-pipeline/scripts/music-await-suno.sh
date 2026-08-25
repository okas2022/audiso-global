#!/usr/bin/env bash
# Mark a track as waiting for the next Suno download in ~/Downloads.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
MUSIC="${ROOT}/pipeline_data/assets/music"
INDEX="${MUSIC}/.track_index"
QUEUE="${INDEX}/awaiting_suno.json"
DOWNLOADS="${SUNO_DOWNLOADS_DIR:-${HOME}/Downloads}"

TRACK_ID=""
TITLE_HINT=""

usage() {
  echo "Usage: music-await-suno.sh AUD-MUS-… [--title-hint \"…\"]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title-hint) TITLE_HINT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *) echo "unknown: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }
TRACK_DIR="${MUSIC}/${TRACK_ID}"
BRIEF="${TRACK_DIR}/music_brief.json"
[[ -f "$BRIEF" ]] || { echo "missing brief: $BRIEF" >&2; exit 1; }

mkdir -p "$INDEX" "${TRACK_DIR}/suno"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_MS=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)

if [[ -z "$TITLE_HINT" ]]; then
  TITLE_HINT=$(python3 -c "import json; print(json.load(open('$BRIEF')).get('title_working',''))")
fi

python3 - <<PY
import json, pathlib
from datetime import datetime, timezone
queue_path = pathlib.Path("$QUEUE")
rows = []
if queue_path.exists():
    rows = json.loads(queue_path.read_text()).get("awaiting", [])
rows = [r for r in rows if r.get("track_id") != "$TRACK_ID"]
rows.append({
    "track_id": "$TRACK_ID",
    "since_ms": int("$NOW_MS"),
    "since_at": "$NOW",
    "title_hint": """$TITLE_HINT""",
    "downloads_dir": "$DOWNLOADS"
})
queue_path.write_text(json.dumps({
    "updated_at": "$NOW",
    "downloads_dir": "$DOWNLOADS",
    "awaiting": rows
}, ensure_ascii=False, indent=2) + "\n")

flag = pathlib.Path("$TRACK_DIR/awaiting_suno.json")
flag.write_text(json.dumps({
    "track_id": "$TRACK_ID",
    "since_ms": int("$NOW_MS"),
    "since_at": "$NOW",
    "title_hint": """$TITLE_HINT""",
    "instruction": "Generate in Suno, then Download once. Watcher imports from Downloads automatically."
}, ensure_ascii=False, indent=2) + "\n")
print("[music-await] $TRACK_ID waiting for Suno download in $DOWNLOADS")
PY

bash "${ROOT}/scripts/music-suno-checklist.sh" "$TRACK_ID" --mark suno_prompted >/dev/null
