#!/usr/bin/env bash
# Allocate AUD-MUS track folder + music_brief from Jarvis template; log episode.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

MUSIC="${MUSIC_ROOT}"
TEMPLATE="${ROOT}/pipeline_data/jarvis_memory/templates/music_brief.json"
INDEX_DIR="${MUSIC}/.track_index"

TITLE=""
GENRE=""
BPM=""
PURPOSE=""
HOOK=""
BRAND="Audiso"
CREATED_BY="Steve"
AWAIT_SUNO=0
PRIORITY="standard"

usage() {
  cat <<'EOF'
Usage: music-new-track.sh [--title T] [--genre G] [--bpm N] [--purpose P] [--hook H]
       [--by Steve|Jarvis] [--await-suno] [--important]
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
    --await-suno) AWAIT_SUNO=1; shift ;;
    --important) PRIORITY="important"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -f "$TEMPLATE" ]] || { echo "missing template: $TEMPLATE" >&2; exit 1; }

mkdir -p "$MUSIC" "$INDEX_DIR" "$MUSIC_EPISODES" \
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
  "${TRACK_DIR}/daw" \
  "${TRACK_DIR}/versions" \
  "${TRACK_DIR}/lyrics" \
  "${TRACK_DIR}/evidence" \
  "${TRACK_DIR}/masters" \
  "${TRACK_DIR}/registration" \
  "${TRACK_DIR}/refs"

NOW=$(music_now_utc)

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
brief["registration"]["priority"] = "${PRIORITY}"
if "${PRIORITY}" == "important":
    brief["registration"]["copyright_commission"]["status"] = "pending"
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

grep -v '^#' "${TRACK_DIR}/prompts/lyrics_prompt.txt" | sed '/^$/d' > "${TRACK_DIR}/lyrics/ai.txt" || true
[[ -s "${TRACK_DIR}/lyrics/ai.txt" ]] || echo "(AI lyrics draft — edit lyrics/final.txt)" > "${TRACK_DIR}/lyrics/ai.txt"
cp "${TRACK_DIR}/lyrics/ai.txt" "${TRACK_DIR}/lyrics/final.txt"

python3 "${ROOT}/scripts/music-checklist-init.py" "$TRACK_ID" "${TRACK_DIR}/checklist.json"
python3 - <<PY
import json, pathlib
p = pathlib.Path("${TRACK_DIR}/checklist.json")
d = json.loads(p.read_text())
d["track_id"] = "${TRACK_ID}"
d["updated_at"] = "${NOW}"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
PY

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
    "status": "briefed",
    "priority": "${PRIORITY}"
})
idx_path.write_text(json.dumps({"updated_at": "${NOW}", "tracks": rows}, ensure_ascii=False, indent=2) + "\n")
PY

EP="${MUSIC_EPISODES}/music-new-${TRACK_ID}.json"
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
    "purpose": brief.get("purpose"),
    "priority": brief.get("registration", {}).get("priority")
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

bash "${ROOT}/scripts/music-catalog-update.sh" "$TRACK_ID"

if [[ "$AWAIT_SUNO" -eq 1 ]]; then
  bash "${ROOT}/scripts/music-await-suno.sh" "$TRACK_ID" --title-hint "$TITLE"
fi
