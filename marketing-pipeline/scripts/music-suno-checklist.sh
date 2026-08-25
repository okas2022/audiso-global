#!/usr/bin/env bash
# Full AUD-MUS pipeline checklist (Phase A–C) + auto-detect; episode logs track_id + prompts.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

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

Stages (Phase A–C):
  brief_ready | suno_prompted | suno_imported | stems_done
  daw_edit | lyrics_revised | versions_logged | human_evidence_ok
  master_done | komca_pack_ready | komca_submitted
  copyright_commission_pack_ready | copyright_commission_submitted
  isrc_assigned | rights_ok | delivered
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
TRACK_DIR=$(music_track_dir "$TRACK_ID")
BRIEF="${TRACK_DIR}/music_brief.json"
CHECK="${TRACK_DIR}/checklist.json"

[[ -d "$TRACK_DIR" ]] || { echo "missing track: $TRACK_DIR" >&2; exit 1; }
[[ -f "$BRIEF" ]] || { echo "missing brief in $TRACK_DIR" >&2; exit 1; }

if [[ ! -f "$CHECK" ]]; then
  python3 "${ROOT}/scripts/music-checklist-init.py" "$TRACK_ID" "$CHECK"
else
  python3 "${ROOT}/scripts/music-checklist-init.py" "$TRACK_ID" "$CHECK" >/dev/null
fi

mkdir -p "$MUSIC_EPISODES" \
  "${TRACK_DIR}/suno" "${TRACK_DIR}/stems" "${TRACK_DIR}/daw" \
  "${TRACK_DIR}/versions" "${TRACK_DIR}/lyrics" "${TRACK_DIR}/evidence" \
  "${TRACK_DIR}/masters" "${TRACK_DIR}/registration" "${TRACK_DIR}/prompts"

NOW=$(music_now_utc)

auto_detect() {
  python3 - <<PY
import json, pathlib
root = pathlib.Path("${TRACK_DIR}")
check = json.loads(pathlib.Path("${CHECK}").read_text())
by_id = {s["id"]: s for s in check["stages"]}

def set_done(sid, cond):
    if sid in by_id and cond:
        by_id[sid]["done"] = True

audio_ext = {".mp3", ".wav", ".flac", ".m4a", ".ogg"}
daw_ext = {".mid", ".midi", ".logicx", ".band", ".cpr", ".ptx", ".flp", ".als", ".rpp"}

style = (root / "prompts/style_prompt.txt").read_text().strip() if (root/"prompts/style_prompt.txt").exists() else ""
lyrics = (root / "prompts/lyrics_prompt.txt").read_text().strip() if (root/"prompts/lyrics_prompt.txt").exists() else ""
prompted = bool(style and not style.startswith("# Fill")) or bool(lyrics and "Hook:" in lyrics and lyrics.split("Hook:",1)[-1].strip())
set_done("suno_prompted", prompted)

suno_files = [p for p in (root/"suno").iterdir() if p.is_file() and p.suffix.lower() in audio_ext] if (root/"suno").exists() else []
set_done("suno_imported", len(suno_files) > 0)

stem_files = [p for p in (root/"stems").rglob("*") if p.is_file() and p.suffix.lower() in audio_ext] if (root/"stems").exists() else []
set_done("stems_done", len(stem_files) > 0)

daw_files = [p for p in (root/"daw").rglob("*") if p.is_file() and p.suffix.lower() in daw_ext] if (root/"daw").exists() else []
set_done("daw_edit", len(daw_files) > 0)

ai_lyrics = (root / "lyrics/ai.txt").read_text().strip() if (root / "lyrics/ai.txt").exists() else ""
final_lyrics = (root / "lyrics/final.txt").read_text().strip() if (root / "lyrics/final.txt").exists() else ""
set_done("lyrics_revised", bool(final_lyrics) and ai_lyrics != final_lyrics)

version_files = [p for p in (root/"versions").iterdir() if p.is_file()] if (root/"versions").exists() else []
set_done("versions_logged", len(version_files) >= 1)

evidence_doc = root / "evidence/human_contribution_ko.md"
brief = json.loads(pathlib.Path("${BRIEF}").read_text())
hc = brief.get("human_contribution") or {}
human_ok = hc.get("melody_harmony_edits") or hc.get("lyrics_rewrite") or (
    hc.get("stem_rearrangement") and hc.get("melody_harmony_edits")
)
set_done("human_evidence_ok", evidence_doc.exists() and human_ok)

master_files = [p for p in (root/"masters").iterdir() if p.is_file() and p.suffix.lower() in audio_ext] if (root/"masters").exists() else []
set_done("master_done", len(master_files) > 0)

komca_form = root / "registration/komca_form.json"
if komca_form.exists():
    kf = json.loads(komca_form.read_text())
    set_done("komca_pack_ready", kf.get("status") == "pack_ready")
reg = brief.get("registration") or {}
komca = reg.get("komca") or {}
set_done("komca_submitted", komca.get("status") == "submitted")

cc_form = root / "registration/copyright_commission_form.json"
cc = reg.get("copyright_commission") or {}
set_done("copyright_commission_pack_ready", cc_form.exists() or cc.get("status") == "pack_ready")
set_done("copyright_commission_submitted", cc.get("status") == "submitted")

isrc = reg.get("isrc") or {}
set_done("isrc_assigned", bool(isrc.get("code")))

rights = brief.get("rights") or {}
set_done("rights_ok", rights.get("commercial_ok") is True or bool(str(rights.get("clearance_notes") or "").strip()))

deliverables = brief.get("deliverables") or {}
set_done("delivered", brief.get("status") == "delivered" or bool(deliverables.get("master_mp3") or deliverables.get("master_wav")))

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

brief = json.loads(pathlib.Path("${BRIEF}").read_text())
brief["updated_at"] = "${NOW}"
mark = "${MARK}"
if mark == "suno_imported":
    exports = sorted(str(p) for p in pathlib.Path("${TRACK_DIR}/suno").iterdir() if p.is_file())
    brief.setdefault("suno", {})["export_paths"] = exports
    brief["status"] = "suno_imported"
elif mark == "stems_done":
    brief["status"] = "stems"
elif mark == "master_done":
    brief["status"] = "mastered"
elif mark == "komca_pack_ready":
    brief["status"] = "komca_pack_ready"
elif mark == "komca_submitted":
    brief.setdefault("registration", {}).setdefault("komca", {})["status"] = "submitted"
    brief["registration"]["komca"]["submitted_at"] = "${NOW}"
    brief["status"] = "komca_submitted"
elif mark == "copyright_commission_pack_ready":
    brief.setdefault("registration", {}).setdefault("copyright_commission", {})["status"] = "pack_ready"
elif mark == "copyright_commission_submitted":
    brief.setdefault("registration", {}).setdefault("copyright_commission", {})["status"] = "submitted"
    brief["registration"]["copyright_commission"]["submitted_at"] = "${NOW}"
elif mark == "isrc_assigned":
    brief["status"] = "isrc_assigned"
elif mark == "delivered":
    brief["status"] = "delivered"
pathlib.Path("${BRIEF}").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
print("marked ${MARK}")
PY
fi

RESULT=$(auto_detect)

if [[ "$SHOW_ONLY" -eq 0 || -n "$MARK" || -n "$IMPORT_SUNO" ]]; then
EP="${MUSIC_EPISODES}/music-checklist-${TRACK_ID}-$(date -u +%Y%m%dT%H%M%S).json"
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
    "purpose": brief.get("purpose"),
    "registration": brief.get("registration")
  },
  "checklist": check,
  "paths": {
    "track_dir": "${TRACK_DIR}",
    "suno": "${TRACK_DIR}/suno",
    "stems": "${TRACK_DIR}/stems",
    "daw": "${TRACK_DIR}/daw",
    "versions": "${TRACK_DIR}/versions",
    "lyrics": "${TRACK_DIR}/lyrics",
    "evidence": "${TRACK_DIR}/evidence",
    "masters": "${TRACK_DIR}/masters",
    "registration": "${TRACK_DIR}/registration"
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

python3 - <<PY
import json
check = json.loads('''${RESULT}''')
print(f"Track: {check['track_id']}")
print("AUD-MUS pipeline (Phase A → B → C)")
for s in check["stages"]:
    mark = "x" if s.get("done") else " "
    print(f"  [{mark}] {s['id']:32} {s['label']}")
pending = [s['id'] for s in check['stages'] if not s.get('done')]
print("next:", ", ".join(pending[:3]) if pending else "all done")
PY
