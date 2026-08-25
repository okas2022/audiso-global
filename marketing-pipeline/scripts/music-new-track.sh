#!/usr/bin/env bash
# Allocate AUD-MUS track folder + music_brief from Jarvis template; log episode.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
MUSIC="${ROOT}/pipeline_data/assets/music"
TEMPLATE="${ROOT}/pipeline_data/jarvis_memory/templates/music_brief.json"
INDEX_DIR="${MUSIC}/.track_index"
EP_DIR="${ROOT}/pipeline_data/jarvis_memory/episodes"

TITLE=""
GENRE=""
BPM=""
PURPOSE=""
HOOK=""
BRAND="Audiso"
CREATED_BY="Steve"

usage() {
  cat <<'EOF'
Usage: music-new-track.sh [--title T] [--genre G] [--bpm N] [--purpose P] [--hook H] [--by Steve|Jarvis]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --genre) GENRE="${2:-}"; shift 2 ;;
    --bpm) BPM="${2:-}"; shift 2 ;;
    --purpose) PURPOSE="${2:-}"; shift 2 ;;
    --hook) HOOK="${2:-}"; shift 2 ;;
    --by) CREATED_BY="${2:-Steve}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -f "$TEMPLATE" ]] || { echo "missing template: $TEMPLATE" >&2; exit 1; }

mkdir -p "$MUSIC" "$INDEX_DIR" "$EP_DIR" \
  "${MUSIC}/_inbox/suno" "${MUSIC}/_library" "${MUSIC}/_stems" "${MUSIC}/_masters"

DAY=$(date -u +%Y%m%d)
SEQ_FILE="${INDEX_DIR}/seq-${DAY}.txt"
if [[ -f "$SEQ_FILE" ]]; then
  SEQ=$(( $(cat "$SEQ_FILE") + 1 ))
else
  SEQ=1
fi
echo "$SEQ" > "$SEQ_FILE"
SEQ3=$(printf '%03d' "$SEQ")
TRACK_ID="AUD-MUS-${DAY}-${SEQ3}"
TRACK_DIR="${MUSIC}/${TRACK_ID}"

if [[ -d "$TRACK_DIR" ]]; then
  echo "track dir already exists: $TRACK_DIR" >&2
  exit 1
fi

mkdir -p \
  "${TRACK_DIR}/prompts" \
  "${TRACK_DIR}/suno" \
  "${TRACK_DIR}/stems" \
  "${TRACK_DIR}/masters" \
  "${TRACK_DIR}/refs"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 - "$TEMPLATE" "${TRACK_DIR}/music_brief.json" <<PY
import json, sys, pathlib
src, dst = sys.argv[1], sys.argv[2]
brief = json.loads(pathlib.Path(src).read_text())
brief["track_id"] = "${TRACK_ID}"
brief["title_working"] = """${TITLE}"""
brief["status"] = "briefed"
brief["created_at"] = "${NOW}"
brief["updated_at"] = "${NOW}"
brief["created_by"] = "${CREATED_BY}"
brief["purpose"]["use_case"] = """${PURPOSE}"""
brief["purpose"]["brand"] = "${BRAND}"
if """${GENRE}""".strip():
    brief["musical"]["genre"] = [g.strip() for g in """${GENRE}""".split(",") if g.strip()]
if """${BPM}""".strip():
    brief["musical"]["bpm"] = int("""${BPM}""")
brief["hook"]["one_liner"] = """${HOOK}"""
brief["pipeline"]["root"] = f"pipeline_data/assets/music/${TRACK_ID}/"
brief["pipeline"]["episode_glob"] = f"pipeline_data/jarvis_memory/episodes/music-*-${TRACK_ID}.json"
pathlib.Path(dst).write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
PY

cat > "${TRACK_DIR}/prompts/style_prompt.txt" <<EOF
# Fill Suno style / genre tags here
${GENRE}
EOF
cat > "${TRACK_DIR}/prompts/lyrics_prompt.txt" <<EOF
# Fill lyrics or instrumental direction here
Hook: ${HOOK}
EOF
cat > "${TRACK_DIR}/prompts/negative_prompt.txt" <<'EOF'
# Avoid: muddy mix, off-key vocals, generic stock feel
EOF

python3 - "${TRACK_DIR}/checklist.json" <<'PY'
import json, pathlib, sys
dst = pathlib.Path(sys.argv[1])
data = {
  "schema": "audiso.music_checklist.v1",
  "track_id": None,
  "stages": [
    {"id": "brief_ready", "label": "music_brief filled", "done": True},
    {"id": "suno_prompted", "label": "Suno style+lyrics prompts saved", "done": False},
    {"id": "suno_imported", "label": "Suno export in suno/", "done": False},
    {"id": "stems_done", "label": "Stem separation in stems/", "done": False},
    {"id": "daw_edit", "label": "DAW edit / arrange", "done": False},
    {"id": "master_done", "label": "Master in masters/ (LUFS check)", "done": False},
    {"id": "rights_ok", "label": "Commercial rights noted", "done": False},
    {"id": "delivered", "label": "Deliverable linked / published", "done": False}
  ],
  "updated_at": None
}
pathlib.Path(dst).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY

python3 - <<PY
import json, pathlib
from datetime import datetime, timezone
p = pathlib.Path("${TRACK_DIR}/checklist.json")
d = json.loads(p.read_text())
d["track_id"] = "${TRACK_ID}"
d["updated_at"] = "${NOW}"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
PY

# index row
INDEX_JSON="${INDEX_DIR}/index.json"
python3 - <<PY
import json, pathlib
idx_path = pathlib.Path("${INDEX_JSON}")
rows = []
if idx_path.exists():
    rows = json.loads(idx_path.read_text()).get("tracks", [])
rows.append({
    "track_id": "${TRACK_ID}",
    "title_working": """${TITLE}""",
    "created_at": "${NOW}",
    "path": "pipeline_data/assets/music/${TRACK_ID}/",
    "status": "briefed"
})
idx_path.write_text(json.dumps({"updated_at": "${NOW}", "tracks": rows}, ensure_ascii=False, indent=2) + "\n")
PY

EP="${EP_DIR}/music-new-${TRACK_ID}.json"
python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("${TRACK_DIR}/music_brief.json").read_text())
ep = {
  "at": "${NOW}",
  "actor": "${CREATED_BY}",
  "orchestrator": "Jarvis",
  "event": "music_track_created",
  "track_id": "${TRACK_ID}",
  "title_working": brief.get("title_working"),
  "prompts": {
    "style_prompt": pathlib.Path("${TRACK_DIR}/prompts/style_prompt.txt").read_text(),
    "lyrics_prompt": pathlib.Path("${TRACK_DIR}/prompts/lyrics_prompt.txt").read_text(),
    "negative_prompt": pathlib.Path("${TRACK_DIR}/prompts/negative_prompt.txt").read_text(),
    "suno": brief.get("suno", {})
  },
  "brief": {
    "genre": brief.get("musical", {}).get("genre"),
    "bpm": brief.get("musical", {}).get("bpm"),
    "hook": brief.get("hook"),
    "purpose": brief.get("purpose")
  },
  "paths": {
    "track_dir": "${TRACK_DIR}",
    "brief": "${TRACK_DIR}/music_brief.json",
    "checklist": "${TRACK_DIR}/checklist.json"
  }
}
pathlib.Path("${EP}").write_text(json.dumps(ep, ensure_ascii=False, indent=2) + "\n")
print("${TRACK_ID}")
print("${TRACK_DIR}")
print("${EP}")
PY
