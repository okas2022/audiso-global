#!/usr/bin/env bash
# Shared paths for music pipeline scripts
set -euo pipefail

MUSIC_ROOT="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}/pipeline_data/assets/music"
MUSIC_STAGES="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}/pipeline_data/jarvis_memory/templates/music_checklist_stages.json"
MUSIC_CATALOG="${MUSIC_ROOT}/.track_index/music-catalog.json"
MUSIC_EPISODES="${JARVIS_ROOT:-/Users/Mac/Audiso/marketing-pipeline}/pipeline_data/jarvis_memory/episodes"

music_track_dir() {
  echo "${MUSIC_ROOT}/$1"
}

music_now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

music_log_episode() {
  local track_id="$1" event="$2" payload_json="$3"
  local ep="${MUSIC_EPISODES}/music-${event}-${track_id}-$(date -u +%Y%m%dT%H%M%S).json"
  python3 - <<PY
import json, pathlib
payload = json.loads('''${payload_json}''')
payload.setdefault("at", "${NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}")
payload.setdefault("track_id", "${track_id}")
payload.setdefault("orchestrator", "Jarvis")
pathlib.Path("${ep}").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
print("${ep}")
PY
}
