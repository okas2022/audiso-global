#!/usr/bin/env python3
"""Build or upgrade checklist.json from music_checklist_stages.json template."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
STAGES_FILE = ROOT / "pipeline_data/jarvis_memory/templates/music_checklist_stages.json"


def load_stages():
    data = json.loads(STAGES_FILE.read_text())
    return data["stages"]


def init_checklist(track_id: str, mark_brief_ready: bool = True) -> dict:
    stages = []
    for s in load_stages():
        done = s["id"] == "brief_ready" and mark_brief_ready
        stages.append({"id": s["id"], "label": s["label"], "done": done})
    return {
        "schema": "audiso.music_checklist.v2",
        "track_id": track_id,
        "stages": stages,
        "updated_at": None,
    }


def upgrade_checklist(existing: dict) -> dict:
    by_id = {s["id"]: s for s in existing.get("stages", [])}
    stages = []
    for s in load_stages():
        old = by_id.get(s["id"])
        stages.append({
            "id": s["id"],
            "label": s["label"],
            "done": bool(old.get("done")) if old else False,
        })
    existing["schema"] = "audiso.music_checklist.v2"
    existing["stages"] = stages
    return existing


def main():
    if len(sys.argv) < 3:
        print("usage: music-checklist-init.py <track_id> <checklist.json path>", file=sys.stderr)
        sys.exit(1)
    track_id, dst = sys.argv[1], pathlib.Path(sys.argv[2])
    if dst.exists():
        data = upgrade_checklist(json.loads(dst.read_text()))
    else:
        data = init_checklist(track_id)
    data["track_id"] = track_id
    dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(dst)


if __name__ == "__main__":
    main()
