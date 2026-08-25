#!/usr/bin/env bash
# Suno → stem → master checklist for one AUD-MUS track; episode logs track_id + prompts.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
MUSIC="${ROOT}/pipeline_data/assets/music"
EP_DIR="${ROOT}/pipeline_data/jarvis_memory/episodes"

TRACK_ID=""
MARK=""
SHOW_ONLY=0
IMPORT_SUNO=""

usage() {
  cat <<'EOF'
Usage:
  music-suno-checklist.sh <TRACK_ID>
  music-suno-checklist.sh <TRACK_ID> --mark <stage_id>
  music-suno-checklist.sh <TRACK_ID> --import-suno /path/to/export.mp3
  music-suno-checklist.sh <TRACK_ID> --show

Stages: brief_ready | suno_prompted | suno_imported | stems_done | daw_edit | master_done | rights_ok | delivered
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mark) MARK="${2:-}"; shift 2 ;;
    --import-suno) IMPORT_SUNO="${2:-}"; shift 2 ;;
    --show) SHOW_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    AUD-MUS-*) TRACK_ID="$1"; shift ;;
    *)
      if [[ -z "$TRACK_ID" ]]; then TRACK_ID="$1"; shift; else echo "unknown: $1" >&2; exit 1; fi
      ;;
  esac
done

[[ -n "$TRACK_ID" ]] || { usage; exit 1; }
TRACK_DIR="${MUSIC}/${TRACK_ID}"
BRIEF="${TRACK_DIR}/music_brief.json"
CHECK="${TRACK_DIR}/checklist.json"

[[ -d "$TRACK_DIR" ]] || { echo "missing track: $TRACK_DIR" >&2; exit 1; }
[[ -f "$BRIEF" && -f "$CHECK" ]] || { echo "missing brief/checklist in $TRACK_DIR" >&2; exit 1; }

mkdir -p "$EP_DIR" "${TRACK_DIR}/suno" "${TRACK_DIR}/stems" "${TRACK_DIR}/masters" "${TRACK_DIR}/prompts"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

auto_detect() {
  python3 - <<PY
import json, pathlib
root = pathlib.Path("${TRACK_DIR}")
check = json.loads(pathlib.Path("${CHECK}").read_text())
by_id = {s["id"]: s for s in check["stages"]}

def set_done(sid, cond):
    if sid in by_id and cond:
        by_id[sid]["done"] = True

style = (root / "prompts/style_prompt.txt").read_text().strip() if (root/"prompts/style_prompt.txt").exists() else ""
lyrics = (root / "prompts/lyrics_prompt.txt").read_text().strip() if (root/"prompts/lyrics_prompt.txt").exists() else ""
# prompted if not only template headers
prompted = bool(style and not style.startswith("# Fill")) or bool(lyrics and "Hook:" in lyrics and lyrics.split("Hook:",1)[-1].strip())
set_done("suno_prompted", prompted)

audio_ext = {".mp3", ".wav", ".flac", ".m4a", ".ogg"}
suno_files = [p for p in (root/"suno").iterdir() if p.is_file() and p.suffix.lower() in audio_ext] if (root/"suno").exists() else []
set_done("suno_imported", len(suno_files) > 0)

stem_files = [p for p in (root/"stems").rglob("*") if p.is_file() and p.suffix.lower() in audio_ext] if (root/"stems").exists() else []
set_done("stems_done", len(stem_files) > 0)

master_files = [p for p in (root/"masters").iterdir() if p.is_file() and p.suffix.lower() in audio_ext] if (root/"masters").exists() else []
set_done("master_done", len(master_files) > 0)

brief = json.loads(pathlib.Path("${BRIEF}").read_text())
rights = brief.get("rights") or {}
set_done("rights_ok", rights.get("commercial_ok") is True or bool(str(rights.get("clearance_notes") or "").strip()))

check["updated_at"] = "${NOW}"
pathlib.Path("${CHECK}").write_text(json.dumps(check, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(check, ensure_ascii=False, indent=2))
PY
}

if [[ -n "$IMPORT_SUNO" ]]; then
  [[ -f "$IMPORT_SUNO" ]] || { echo "file not found: $IMPORT_SUNO" >&2; exit 1; }
  base=$(basename "$IMPORT_SUNO")
  cp "$IMPORT_SUNO" "${TRACK_DIR}/suno/${base}"
  MARK="suno_imported"
  echo "[music] imported → ${TRACK_DIR}/suno/${base}"
fi

if [[ -n "$MARK" ]]; then
  python3 - <<PY
import json, pathlib, sys
check = json.loads(pathlib.Path("${CHECK}").read_text())
found = False
for s in check["stages"]:
    if s["id"] == "${MARK}":
        s["done"] = True
        found = True
        break
if not found:
    sys.exit(f"unknown stage: ${MARK}")
check["updated_at"] = "${NOW}"
pathlib.Path("${CHECK}").write_text(json.dumps(check, ensure_ascii=False, indent=2) + "\n")

# mirror key fields into brief.suno export_paths / status
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
brief["updated_at"] = "${NOW}"
if "${MARK}" == "suno_imported":
    exports = sorted(str(p) for p in pathlib.Path("${TRACK_DIR}/suno").iterdir() if p.is_file())
    brief.setdefault("suno", {})["export_paths"] = exports
    brief["status"] = "suno_imported"
elif "${MARK}" == "stems_done":
    brief["status"] = "stems"
elif "${MARK}" == "master_done":
    brief["status"] = "mastered"
elif "${MARK}" == "delivered":
    brief["status"] = "delivered"
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
print("marked ${MARK}")
PY
fi

RESULT=$(auto_detect)

# episode with track_id + prompts (always, unless pure --show with no mutation)
if [[ "$SHOW_ONLY" -eq 0 || -n "$MARK" || -n "$IMPORT_SUNO" ]]; then
EP="${EP_DIR}/music-checklist-${TRACK_ID}-$(date -u +%Y%m%dT%H%M%S).json"
python3 - <<PY
import json, pathlib
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
check = json.loads(pathlib.Path("${CHECK}").read_text())
prompts_dir = pathlib.Path("${TRACK_DIR}/prompts")
def readp(name):
    p = prompts_dir / name
    return p.read_text() if p.exists() else ""
ep = {
  "at": "${NOW}",
  "actor": "Steve",
  "orchestrator": "Jarvis",
  "event": "music_checklist",
  "track_id": "${TRACK_ID}",
  "mark": """${MARK}""" or None,
  "import_suno": """${IMPORT_SUNO}""" or None,
  "prompts": {
    "style_prompt": readp("style_prompt.txt"),
    "lyrics_prompt": readp("lyrics_prompt.txt"),
    "negative_prompt": readp("negative_prompt.txt"),
    "suno": brief.get("suno", {})
  },
  "brief": {
    "title_working": brief.get("title_working"),
    "genre": (brief.get("musical") or {}).get("genre"),
    "bpm": (brief.get("musical") or {}).get("bpm"),
    "hook": brief.get("hook"),
    "purpose": brief.get("purpose")
  },
  "checklist": check,
  "paths": {
    "track_dir": "${TRACK_DIR}",
    "suno": "${TRACK_DIR}/suno",
    "stems": "${TRACK_DIR}/stems",
    "masters": "${TRACK_DIR}/masters"
  }
}
pathlib.Path("${EP}").write_text(json.dumps(ep, ensure_ascii=False, indent=2) + "\n")
print("episode:", "${EP}")
PY
fi

if [[ "$SHOW_ONLY" -eq 1 ]]; then
  echo "$RESULT"
  exit 0
fi

# print human checklist
python3 - <<PY
import json
check = json.loads('''${RESULT}''')
print(f"Track: {check['track_id']}")
print("Suno → stem → master checklist")
for s in check["stages"]:
    mark = "x" if s.get("done") else " "
    print(f"  [{mark}] {s['id']:16} {s['label']}")
pending = [s['id'] for s in check['stages'] if not s.get('done')]
print("next:", ", ".join(pending[:3]) if pending else "all done")
PY
