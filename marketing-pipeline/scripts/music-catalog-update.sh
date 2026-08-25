#!/usr/bin/env bash
# Sync music-catalog.json from all AUD-MUS track folders.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

SINGLE=""
NOW=$(music_now_utc)

while [[ $# -gt 0 ]]; do
  case "$1" in
    AUD-MUS-*) SINGLE="$1"; shift ;;
    *) shift ;;
  esac
done

python3 - <<PY
import json, pathlib, glob
music = pathlib.Path("${MUSIC_ROOT}")
catalog_path = pathlib.Path("${MUSIC_CATALOG}")
single = "${SINGLE}"

def load_brief(td):
    p = td / "music_brief.json"
    return json.loads(p.read_text()) if p.exists() else {}

def load_check(td):
    p = td / "checklist.json"
    if not p.exists():
        return {}
    c = json.loads(p.read_text())
    done = {s["id"] for s in c.get("stages", []) if s.get("done")}
    return {"checklist_done": sorted(done), "checklist_pending": [s["id"] for s in c.get("stages", []) if not s.get("done")]}

tracks = []
if single:
    dirs = [music / single]
else:
    dirs = sorted(music.glob("AUD-MUS-*"))

for td in dirs:
    if not td.is_dir():
        continue
    b = load_brief(td)
    if not b:
        continue
    reg = b.get("registration") or {}
    ch = load_check(td)
    tracks.append({
        "track_id": b.get("track_id"),
        "title_working": b.get("title_working"),
        "status": b.get("status"),
        "priority": reg.get("priority", "standard"),
        "komca_status": (reg.get("komca") or {}).get("status"),
        "copyright_commission_status": (reg.get("copyright_commission") or {}).get("status"),
        "isrc": (reg.get("isrc") or {}).get("code") or b.get("rights", {}).get("isrc"),
        "human_ok": (b.get("human_contribution") or {}).get("melody_harmony_edits") or (b.get("human_contribution") or {}).get("lyrics_rewrite"),
        "path": str(td.relative_to(music.parent)),
        **ch,
    })

catalog_path.parent.mkdir(parents=True, exist_ok=True)
if single and catalog_path.exists():
    existing = json.loads(catalog_path.read_text()).get("tracks", [])
    by_id = {t["track_id"]: t for t in existing if t.get("track_id")}
    for t in tracks:
        by_id[t["track_id"]] = t
    tracks = list(by_id.values())

catalog_path.write_text(json.dumps({
    "schema": "audiso.music_catalog.v1",
    "updated_at": "${NOW}",
    "owner": "CEO",
    "label": "Audiso",
    "tracks": sorted(tracks, key=lambda x: x.get("track_id") or "", reverse=True)
}, ensure_ascii=False, indent=2) + "\n")
print(f"catalog: {len(tracks)} tracks")
PY
