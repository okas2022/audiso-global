#!/usr/bin/env bash
# Weekly composer catalog report — registration pipeline status.
set -euo pipefail

ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}"
source "${ROOT}/scripts/music-lib.sh"

bash "${ROOT}/scripts/music-catalog-update.sh"

REPORT="${MUSIC_EPISODES}/music-catalog-report-$(date -u +%Y%m%d).json"
NOW=$(music_now_utc)

python3 - <<PY
import json, pathlib
cat = json.loads(pathlib.Path("${MUSIC_CATALOG}").read_text())
tracks = cat.get("tracks", [])

def bucket(name):
    return [t for t in tracks if name in (t.get("checklist_pending") or []) or t.get("komca_status") == name.replace("_status","")]

report = {
    "at": "${NOW}",
    "event": "music_catalog_report",
    "total": len(tracks),
    "ready_komca_pack": [t["track_id"] for t in tracks if "komca_pack_ready" in (t.get("checklist_done") or [])],
    "needs_human_edit": [t["track_id"] for t in tracks if not t.get("human_ok")],
    "needs_master": [t["track_id"] for t in tracks if "master_done" not in (t.get("checklist_done") or [])],
    "komca_pending_submit": [t["track_id"] for t in tracks if t.get("komca_status") == "pack_ready"],
    "isrc_pending": [t["track_id"] for t in tracks if not t.get("isrc")],
    "tracks": tracks[:50],
}
pathlib.Path("${REPORT}").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

print(f"=== Audiso Music Catalog ({report['total']} tracks) ===")
print(f"needs human edit: {', '.join(report['needs_human_edit'][:5]) or 'none'}")
print(f"needs master: {', '.join(report['needs_master'][:5]) or 'none'}")
print(f"KOMCA pack ready (CEO submit): {', '.join(report['komca_pending_submit'][:5]) or 'none'}")
print(f"ISRC pending: {', '.join(report['isrc_pending'][:5]) or 'none'}")
print(f"report → ${REPORT}")
PY
